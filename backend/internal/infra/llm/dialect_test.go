package llm

import "testing"

// TestCurated_EveryVouchedProviderReachesItsHandWrittenSpec is the invariant H12-c broke silently.
//
// `curatedProviders` says「we hand-wrote a spec for this one」and the UI prints that claim on the
// card. The claim is only true if a key for that provider actually DISPATCHES to the hand-written
// spec — and three of them (`alibaba` / `zhipuai` / `moonshotai`) are addressed by models.dev's id
// while the registry was keyed by ours (`qwen` / `zhipu` / `moonshot`). They fell through to a
// synthesized generic provider: right base URL, right models, and the wrong knob names on the wire.
//
// Nothing else could catch this. The build was green, the models listed, the card said「已验证」, and
// the first symptom would have been a 400 from a model the user had every reason to think worked.
//
// TestCurated_EveryVouchedProviderReachesItsHandWrittenSpec 是 H12-c **静默打破**的那条不变量。
//
// `curatedProviders` 说的是「这一家我们手写过 spec」,而 UI 把这句话印在卡上。这句话只有在
// 「这家的 key 真的**派发到**那份手写 spec」时才为真——而其中三家(`alibaba` / `zhipuai` /
// `moonshotai`)按 models.dev 的 id 寻址,注册表却按**我们的**名字(`qwen` / `zhipu` / `moonshot`)
// 建键。它们一路跌到一个合成的通用 provider:base URL 对、模型对,**线缆上的旋钮名字是错的**。
//
// 没有别的东西逮得到它。构建是绿的、模型列得出来、卡上写着「已验证」,而**第一个症状**会是一个
// 400——来自一个用户完全有理由认为它能用的模型。
func TestCurated_EveryVouchedProviderReachesItsHandWrittenSpec(t *testing.T) {
	for id := range curatedProviders {
		got := lookupProvider(Config{Provider: id})
		// A synthesized provider is not in the registry by identity. Compare pointers: whichever
		// registry entry serves this id, it must be one we wrote, not one we generated.
		// 合成的 provider 按**同一性**不在注册表里。比指针:无论哪条注册表条目服务这个 id,它必须是
		// 我们**写的**那一个、不是我们**生成的**那一个。
		found := false
		for _, p := range providerRegistry {
			if p == got {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("curated provider %q dispatches to a SYNTHESIZED provider — its knob spellings, "+
				"encoder and wire mask are all the generic ones, and the card still says we vouch for it", id)
		}
	}
}
