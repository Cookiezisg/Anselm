package llm

import (
	"context"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Desktop-side speech-synthesis dialects (WRK-082 批C). FOUR ways keys can physically speak, but
// only THREE wire shapes: OpenAI and Zhipu share one (identical field names, raw-bytes response),
// DashScope is native-only (nested `input`, JSON + OSS URL — it has NO OpenAI-compatible TTS
// endpoint), and Gemini answers base64 headerless PCM that this file wraps into WAV itself.
//
// Everything converges on ONE intermediate representation: 24 kHz / 16-bit / mono PCM inside a
// WAV container. That is not a preference — it is what makes chunk-and-concat possible at all.
// Every provider caps a single request well below a long message (qwen3-tts ~500 characters,
// Zhipu 1024), so long text MUST be split and rejoined; PCM rejoins by byte concatenation while
// MP3 frames rejoin with audible seams. All four upstreams natively produce 24k/16/mono, so the
// pipeline never resamples.
//
// 桌面侧语音合成方言(批C)。key 物理上能说话的**四**条路,但只有**三**种 wire:OpenAI 与智谱共用
// 一种(字段名逐字相同、响应同为裸字节),DashScope 只有原生形(嵌套 `input`、JSON + OSS URL——它
// **没有** OpenAI 兼容 TTS 端点),Gemini 返 base64 无头 PCM、由本文件自己封 WAV。
//
// 一切收敛到**一个**中间表示:WAV 容器里的 24kHz/16bit/mono PCM。这不是偏好,而是「切块再拼」得以
// 成立的前提:各家单请求上限都远低于一条长消息(qwen3-tts 约 500 字符、智谱 1024),故长文本**必须**
// 切开再拼;而 PCM 靠字节拼接即可重合,MP3 帧拼接会留下听得见的缝。四家原生输出恰好全是 24k/16/mono,
// 于是整条流水线零重采样。

// ErrSpeechGenFailed is the neutral sentinel for a synthesis the upstream refused or broke on;
// Message carries the human-facing cause (the LLM reads it, S20).
//
// ErrSpeechGenFailed 是上游拒绝/失败的中立 sentinel;Message 携人话原因(LLM 读它,S20)。
var ErrSpeechGenFailed = errorspkg.New(errorspkg.KindUnavailable, "SPEECH_GEN_FAILED", "speech synthesis failed")

// GeneratedAudio is one produced artifact, bytes in hand (the GeneratedImage twin).
//
// GeneratedAudio 是一件已到手的音频产物(GeneratedImage 的孪生)。
type GeneratedAudio struct {
	Bytes []byte
	Mime  string
}

// speechGenBudget bounds one whole synthesis CALL (one chunk), not the whole utterance — a long
// text's total budget is the caller's chat-turn ceiling.
//
// speechGenBudget 界一次合成**调用**(一块),而非整段话——长文本的总预算由调用方的回合顶棚管。
const speechGenBudget = 90 * time.Second

// audioMaxBytes caps one downloaded/decoded chunk (defense against a hostile URL). 24k/16/mono is
// ~48 KB per second, so this holds several minutes of a single chunk's audio.
//
// audioMaxBytes 封顶单块下载/解码产物(防恶意 URL)。24k/16/mono ≈ 48KB/秒,故此值可容单块数分钟。
const audioMaxBytes = 32 << 20

// Canonical intermediate format. Every dialect either returns this natively or is converted to it
// before leaving this file.
//
// 规范中间格式。每个方言要么原生即此、要么在离开本文件前被转成它。
const (
	speechSampleRate = 24000
	speechBits       = 16
	speechChannels   = 1
)

// SpeechChunkLimit is the per-provider ceiling on ONE request's characters. Hand-written, like
// the image provider table (代拍 B6): the models.dev catalog's chat predicate (tool_call ∧ text
// output) filters pure-TTS models out entirely, so the capability catalog cannot discover any of
// this — a fact worth stating rather than rediscovering.
//
// SpeechChunkLimit 是各家**单请求**字符上限。与图像 provider 表同样手写(代拍 B6):models.dev 目录
// 的 chat 谓词(tool_call ∧ 文本输出)把纯 TTS 模型整个滤掉了,故能力目录**发现不了**这里的任何东西
// ——这条值得写下来,而不是让人再发现一次。
func SpeechChunkLimit(provider string) int {
	switch provider {
	case "openai":
		return 3000 // wire cap 4096; headroom for the sentence-boundary splitter
	case "google":
		return 3000
	case "zhipu":
		return 1000 // wire cap 1024
	case "qwen":
		return 480 // qwen3-tts caps ~500
	case "anselm":
		return 480 // the managed gateway's own maxInputChars is 500 (代拍 C5)
	default:
		return 480
	}
}

// SplitSpeechText splits text into chunks of at most maxRunes, preferring sentence boundaries so
// a seam never lands mid-clause (where the concatenated audio would audibly stutter). A run with
// no boundary in range is cut at the limit — a hard cut beats refusing to speak.
//
// SplitSpeechText 把文本切成不超过 maxRunes 的块,优先在句读处断开,使接缝永不落在句子中间(那里
// 拼出来的音频会听得出磕绊)。范围内找不到边界就在上限处硬切——硬切胜过拒绝朗读。
func SplitSpeechText(text string, maxRunes int) []string {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil
	}
	if maxRunes <= 0 {
		maxRunes = 480
	}
	if utf8.RuneCountInString(text) <= maxRunes {
		return []string{text}
	}
	boundary := func(r rune) bool {
		switch r {
		case '。', '！', '？', '；', '\n', '.', '!', '?', ';':
			return true
		}
		return false
	}
	var out []string
	runes := []rune(text)
	for len(runes) > 0 {
		if len(runes) <= maxRunes {
			if s := strings.TrimSpace(string(runes)); s != "" {
				out = append(out, s)
			}
			break
		}
		cut := maxRunes
		for i := maxRunes - 1; i > maxRunes/3; i-- {
			if boundary(runes[i]) {
				cut = i + 1 // keep the punctuation with its sentence / 标点跟着它的句子
				break
			}
		}
		if s := strings.TrimSpace(string(runes[:cut])); s != "" {
			out = append(out, s)
		}
		runes = runes[cut:]
	}
	return out
}

// GenerateSpeechAnselm calls the managed gateway's speech endpoint. installID rides the
// deviceproof header (the transport signs the exact body); the returned OSS URL is downloaded
// through the same client.
//
// GenerateSpeechAnselm 打受管网关语音端点。installID 走 deviceproof 头;返回的 OSS URL 经同一
// client 下载。
func GenerateSpeechAnselm(ctx context.Context, httpc *http.Client, baseURL, installID, text, voice string) (GeneratedAudio, error) {
	ctx, cancel := context.WithTimeout(ctx, speechGenBudget)
	defer cancel()
	payload := map[string]any{"input": text}
	if voice != "" {
		payload["voice"] = voice
	}
	body, _ := json.Marshal(payload)
	req, err := newSpeechRequest(ctx, strings.TrimRight(baseURL, "/")+"/audio/speech", body)
	if err != nil {
		return GeneratedAudio{}, err
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	raw, _, err := doSpeechRequest(httpc, req, "anselm")
	if err != nil {
		return GeneratedAudio{}, err
	}
	var wire struct {
		Data []struct {
			URL string `json:"url"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || len(wire.Data) == 0 || wire.Data[0].URL == "" {
		return GeneratedAudio{}, fmt.Errorf("%w: gateway returned no artifact url", ErrSpeechGenFailed)
	}
	return downloadAudio(ctx, httpc, wire.Data[0].URL)
}

// GenerateSpeechOpenAIForm speaks the `/audio/speech` shape shared by OpenAI and Zhipu: identical
// field names, Bearer auth, and a RAW AUDIO body on success. `wav` is requested explicitly on
// both — the response is the concatenation unit, and asking for mp3 here would trade a free byte
// concat for an encoder round-trip with seams.
//
// GenerateSpeechOpenAIForm 讲 OpenAI 与智谱共用的 `/audio/speech` 形:字段名逐字相同、Bearer 鉴权、
// 成功返**裸音频**。两家都显式要 `wav`——响应就是拼接单位,这里要 mp3 等于拿一次免费的字节拼接去换
// 一次带缝的编码往返。
func GenerateSpeechOpenAIForm(ctx context.Context, httpc *http.Client, provider, baseURL, key, model, text, voice string) (GeneratedAudio, error) {
	ctx, cancel := context.WithTimeout(ctx, speechGenBudget)
	defer cancel()
	payload := map[string]any{"model": model, "input": text, "response_format": "wav"}
	if voice != "" {
		payload["voice"] = voice
	}
	body, _ := json.Marshal(payload)
	req, err := newSpeechRequest(ctx, strings.TrimRight(baseURL, "/")+"/audio/speech", body)
	if err != nil {
		return GeneratedAudio{}, err
	}
	req.Header.Set("Authorization", "Bearer "+key)
	raw, mime, err := doSpeechRequest(httpc, req, provider)
	if err != nil {
		return GeneratedAudio{}, err
	}
	// A JSON body on a 200 means the provider answered an error shape without an error status —
	// never hand that to a player as audio. 200 却是 JSON,说明上游用成功状态回了错误形——绝不
	// 把它当音频交给播放器。
	if strings.HasPrefix(mime, "application/json") || (len(raw) > 0 && raw[0] == '{') {
		return GeneratedAudio{}, fmt.Errorf("%w: %s returned a json body instead of audio", ErrSpeechGenFailed, provider)
	}
	if mime == "" || strings.HasPrefix(mime, "application/octet-stream") {
		mime = http.DetectContentType(raw)
	}
	if i := strings.IndexByte(mime, ';'); i > 0 {
		mime = strings.TrimSpace(mime[:i])
	}
	return GeneratedAudio{Bytes: raw, Mime: mime}, nil
}

// GenerateSpeechDashScope speaks the NATIVE multimodal-generation form. DashScope has no
// OpenAI-compatible TTS endpoint (`/compatible-mode/v1/audio/speech` does not exist), so this
// dialect is not optional — and the response is JSON carrying a 24h OSS URL, not bytes.
//
// GenerateSpeechDashScope 讲**原生** multimodal-generation 形。DashScope 没有 OpenAI 兼容 TTS 端点,
// 故这个方言不是可选项——且响应是带 24h OSS URL 的 JSON、不是字节。
func GenerateSpeechDashScope(ctx context.Context, httpc *http.Client, nativeBase, key, model, text, voice string) (GeneratedAudio, error) {
	ctx, cancel := context.WithTimeout(ctx, speechGenBudget)
	defer cancel()
	input := map[string]any{"text": text}
	if voice != "" {
		input["voice"] = voice
	}
	body, _ := json.Marshal(map[string]any{"model": model, "input": input})
	req, err := newSpeechRequest(ctx,
		strings.TrimRight(nativeBase, "/")+"/api/v1/services/aigc/multimodal-generation/generation", body)
	if err != nil {
		return GeneratedAudio{}, err
	}
	req.Header.Set("Authorization", "Bearer "+key)
	raw, _, err := doSpeechRequest(httpc, req, "qwen")
	if err != nil {
		return GeneratedAudio{}, err
	}
	var wire struct {
		Output struct {
			Audio struct {
				URL string `json:"url"`
			} `json:"audio"`
		} `json:"output"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || strings.TrimSpace(wire.Output.Audio.URL) == "" {
		return GeneratedAudio{}, fmt.Errorf("%w: dashscope returned no artifact url", ErrSpeechGenFailed)
	}
	// The OSS result host may answer on http; the downloader is https-only by iron rule and the
	// pre-signed signature does not cover the scheme (same normalization the gateway does).
	// OSS 结果主机可能返 http;下载器按铁律只认 https,而预签名不覆盖 scheme(与网关同一处归一)。
	u := strings.TrimSpace(wire.Output.Audio.URL)
	if strings.HasPrefix(u, "http://") {
		u = "https://" + strings.TrimPrefix(u, "http://")
	}
	return downloadAudio(ctx, httpc, u)
}

// GenerateSpeechGemini speaks the generateContent TTS form and wraps the returned HEADERLESS PCM
// into a WAV container. The wrapping is not a nicety: Gemini's `inlineData` is raw
// 24kHz/16-bit/mono samples with no RIFF header, so handing those bytes to any player (or to the
// concatenator) unchanged would produce noise.
//
// GenerateSpeechGemini 讲 generateContent TTS 形,并把返回的**无头** PCM 封进 WAV 容器。这不是锦上
// 添花:Gemini 的 `inlineData` 是没有 RIFF 头的 24kHz/16bit/mono 裸样本,原样交给播放器(或拼接器)
// 会出噪声。
func GenerateSpeechGemini(ctx context.Context, httpc *http.Client, baseURL, key, model, text, voice string) (GeneratedAudio, error) {
	ctx, cancel := context.WithTimeout(ctx, speechGenBudget)
	defer cancel()
	speech := map[string]any{}
	if voice != "" {
		speech["voiceConfig"] = map[string]any{
			"prebuiltVoiceConfig": map[string]any{"voiceName": voice},
		}
	}
	body, _ := json.Marshal(map[string]any{
		"contents": []any{map[string]any{"parts": []any{map[string]any{"text": text}}}},
		"generationConfig": map[string]any{
			"responseModalities": []string{"AUDIO"},
			"speechConfig":       speech,
		},
	})
	req, err := newSpeechRequest(ctx,
		strings.TrimRight(baseURL, "/")+"/models/"+model+":generateContent", body)
	if err != nil {
		return GeneratedAudio{}, err
	}
	req.Header.Set("x-goog-api-key", key)
	raw, _, err := doSpeechRequest(httpc, req, "google")
	if err != nil {
		return GeneratedAudio{}, err
	}
	var wire struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					InlineData struct {
						MimeType string `json:"mimeType"`
						Data     string `json:"data"`
					} `json:"inlineData"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil {
		return GeneratedAudio{}, fmt.Errorf("%w: gemini response unreadable", ErrSpeechGenFailed)
	}
	for _, c := range wire.Candidates {
		for _, p := range c.Content.Parts {
			if p.InlineData.Data == "" {
				continue
			}
			pcm, derr := base64.StdEncoding.DecodeString(p.InlineData.Data)
			if derr != nil || len(pcm) == 0 {
				return GeneratedAudio{}, fmt.Errorf("%w: gemini audio undecodable", ErrSpeechGenFailed)
			}
			return GeneratedAudio{
				Bytes: BuildWAV(pcm, speechSampleRate, speechChannels, speechBits),
				Mime:  "audio/wav",
			}, nil
		}
	}
	return GeneratedAudio{}, fmt.Errorf("%w: gemini returned no audio part", ErrSpeechGenFailed)
}

// ConcatAudio joins per-chunk artifacts into one. WAV inputs are re-joined at the PCM level (parse
// each, verify the formats agree, concatenate samples, emit one header) — a byte-level append of
// two WAV files would leave a RIFF header stranded mid-stream and most players stop at it.
// A single part passes through untouched.
//
// ConcatAudio 把逐块产物合成一件。WAV 输入在 **PCM 层**重接(逐个解析、核对格式一致、拼样本、只发
// 一个头)——把两个 WAV 文件按字节追加会在流中间留下一个 RIFF 头,多数播放器就停在那儿。单块原样返回。
func ConcatAudio(parts []GeneratedAudio) (GeneratedAudio, error) {
	switch len(parts) {
	case 0:
		return GeneratedAudio{}, fmt.Errorf("%w: nothing to join", ErrSpeechGenFailed)
	case 1:
		return parts[0], nil
	}
	var pcm []byte
	sr, ch, bits := 0, 0, 0
	for i, p := range parts {
		samples, psr, pch, pbits, err := ParseWAV(p.Bytes)
		if err != nil {
			return GeneratedAudio{}, fmt.Errorf("%w: chunk %d is not joinable wav: %v", ErrSpeechGenFailed, i, err)
		}
		if i == 0 {
			sr, ch, bits = psr, pch, pbits
		} else if psr != sr || pch != ch || pbits != bits {
			// Mixed formats cannot be concatenated without resampling; refusing is honest, and it
			// cannot happen while every dialect normalizes.
			// 格式不一致不重采样就拼不了;诚实拒绝,而在每个方言都归一的前提下这不会发生。
			return GeneratedAudio{}, fmt.Errorf("%w: chunk %d format differs (%d/%d/%d vs %d/%d/%d)",
				ErrSpeechGenFailed, i, psr, pch, pbits, sr, ch, bits)
		}
		pcm = append(pcm, samples...)
	}
	return GeneratedAudio{Bytes: BuildWAV(pcm, sr, ch, bits), Mime: "audio/wav"}, nil
}

// BuildWAV wraps raw little-endian PCM in a canonical 44-byte RIFF/WAVE header.
//
// BuildWAV 把小端裸 PCM 封进规范的 44 字节 RIFF/WAVE 头。
func BuildWAV(pcm []byte, sampleRate, channels, bitsPerSample int) []byte {
	blockAlign := channels * bitsPerSample / 8
	byteRate := sampleRate * blockAlign
	out := make([]byte, 44, 44+len(pcm))
	copy(out[0:4], "RIFF")
	binary.LittleEndian.PutUint32(out[4:8], uint32(36+len(pcm)))
	copy(out[8:12], "WAVE")
	copy(out[12:16], "fmt ")
	binary.LittleEndian.PutUint32(out[16:20], 16) // PCM fmt chunk size
	binary.LittleEndian.PutUint16(out[20:22], 1)  // PCM
	binary.LittleEndian.PutUint16(out[22:24], uint16(channels))
	binary.LittleEndian.PutUint32(out[24:28], uint32(sampleRate))
	binary.LittleEndian.PutUint32(out[28:32], uint32(byteRate))
	binary.LittleEndian.PutUint16(out[32:34], uint16(blockAlign))
	binary.LittleEndian.PutUint16(out[34:36], uint16(bitsPerSample))
	copy(out[36:40], "data")
	binary.LittleEndian.PutUint32(out[40:44], uint32(len(pcm)))
	return append(out, pcm...)
}

// ParseWAV extracts the PCM payload and format from a RIFF/WAVE file. It walks the chunk list
// rather than assuming a 44-byte header — real encoders interleave LIST/fact chunks, and a
// fixed-offset reader would silently treat metadata as samples.
//
// ParseWAV 从 RIFF/WAVE 文件取出 PCM 载荷与格式。它**遍历 chunk 表**而非假定 44 字节头——真实编码器
// 会夹带 LIST/fact 等 chunk,按固定偏移读会把元数据静默当成样本。
func ParseWAV(b []byte) (pcm []byte, sampleRate, channels, bitsPerSample int, err error) {
	if len(b) < 12 || string(b[0:4]) != "RIFF" || string(b[8:12]) != "WAVE" {
		return nil, 0, 0, 0, fmt.Errorf("not a RIFF/WAVE stream")
	}
	off := 12
	for off+8 <= len(b) {
		id := string(b[off : off+4])
		size := int(binary.LittleEndian.Uint32(b[off+4 : off+8]))
		body := off + 8
		if size < 0 || body+size > len(b) {
			// Truncated stream: keep whatever the declared chunk can still cover.
			// 流被截断:按实际可覆盖的部分收。
			size = len(b) - body
		}
		switch id {
		case "fmt ":
			if size < 16 {
				return nil, 0, 0, 0, fmt.Errorf("fmt chunk too short")
			}
			channels = int(binary.LittleEndian.Uint16(b[body+2 : body+4]))
			sampleRate = int(binary.LittleEndian.Uint32(b[body+4 : body+8]))
			bitsPerSample = int(binary.LittleEndian.Uint16(b[body+14 : body+16]))
		case "data":
			pcm = b[body : body+size]
		}
		off = body + size
		if size%2 == 1 {
			off++ // RIFF chunks are word-aligned / RIFF chunk 按字对齐
		}
	}
	if pcm == nil || sampleRate == 0 || channels == 0 || bitsPerSample == 0 {
		return nil, 0, 0, 0, fmt.Errorf("wav missing fmt or data chunk")
	}
	return pcm, sampleRate, channels, bitsPerSample, nil
}

func newSpeechRequest(ctx context.Context, u string, body []byte) (*http.Request, error) {
	req, err := newImageRequest(ctx, u, body)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrSpeechGenFailed, err)
	}
	return req, nil
}

// doSpeechRequest runs one call and normalizes failures into ErrSpeechGenFailed with a bounded,
// human-facing reason. It also returns the response mime, because in this family the SUCCESS body
// may be either JSON or raw audio and the caller has to tell them apart.
//
// doSpeechRequest 跑一次调用,失败归一成 ErrSpeechGenFailed + 有界人话原因。它另返响应 mime,因为
// 这一族的**成功**体可能是 JSON 也可能是裸音频,调用方必须分得清。
func doSpeechRequest(httpc *http.Client, req *http.Request, provider string) ([]byte, string, error) {
	resp, err := httpc.Do(req)
	if err != nil {
		return nil, "", fmt.Errorf("%w: %s: %v", ErrSpeechGenFailed, provider, err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, audioMaxBytes))
	if err != nil {
		return nil, "", fmt.Errorf("%w: %s: read: %v", ErrSpeechGenFailed, provider, err)
	}
	if resp.StatusCode != http.StatusOK {
		excerpt := strings.TrimSpace(string(raw))
		if len(excerpt) > 300 {
			excerpt = excerpt[:300] + "…"
		}
		return nil, "", fmt.Errorf("%w: %s: HTTP %d: %s", ErrSpeechGenFailed, provider, resp.StatusCode, excerpt)
	}
	return raw, resp.Header.Get("Content-Type"), nil
}

// downloadAudio fetches a returned artifact URL (https only) and sniffs its mime — the
// downloadImage twin, kept separate so the size cap and error sentinel belong to this family.
//
// downloadAudio 拉取返回的产物 URL(仅 https)并嗅 mime——downloadImage 的孪生,分开是为了让大小
// 上限与错误 sentinel 归属本族。
func downloadAudio(ctx context.Context, httpc *http.Client, rawURL string) (GeneratedAudio, error) {
	img, err := downloadImage(ctx, httpc, rawURL)
	if err != nil {
		// Re-label so the LLM hears "speech synthesis failed", not "image generation failed".
		// 换标签,让 LLM 听到的是「语音合成失败」而不是「图像生成失败」。
		return GeneratedAudio{}, fmt.Errorf("%w: %v", ErrSpeechGenFailed, err)
	}
	return GeneratedAudio{Bytes: img.Bytes, Mime: img.Mime}, nil
}

// AudioDurationMs is the exact playing length of a synthesized WAV, or 0 when the bytes are not a
// WAV this package can read (another provider's mp3, a truncated stream).
//
// It exists because the synthesis path already holds everything needed — ParseWAV hands back the
// PCM plus its sample rate, channel count and sample width — so the duration is arithmetic on data
// we have, not a second decode. Zero is the honest answer for "cannot tell": a receipt that
// guesses a length is worse than one that omits it, because a caller cannot tell a guess from a
// measurement.
//
// AudioDurationMs 是合成 WAV 的**精确**播放长度;字节不是本包读得懂的 WAV(别家的 mp3、截断的流)时返 0。
//
// 它存在,是因为合成路径手里**本来就有**所需的一切——ParseWAV 交回 PCM 及其采样率、声道数与位宽——故时长
// 是对**已有数据**的算术,不是第二次解码。「说不出来」的诚实答案是 **0**:一份**猜**长度的 receipt 比一份
// 干脆不写的更糟,因为调用方分不出猜测与测量。
func AudioDurationMs(b []byte) int64 {
	pcm, rate, channels, bits, err := ParseWAV(b)
	if err != nil || rate <= 0 || channels <= 0 || bits <= 0 {
		return 0
	}
	bytesPerSecond := rate * channels * (bits / 8)
	if bytesPerSecond <= 0 {
		return 0
	}
	return int64(len(pcm)) * 1000 / int64(bytesPerSecond)
}
