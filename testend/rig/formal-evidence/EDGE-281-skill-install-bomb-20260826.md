# EDGE-281 · skill 安装炸弹护栏

## L1 focused evidence

- `backend/internal/infra/skillfetch/skillfetch_test.go:TestFetch_GuardsAndJunk` 通过：gzip tar 的 symlink、越界条目与非 gzip 输入均不进入候选。
- `backend/internal/infra/skillfetch/skillfetch.go` 实现并执行压缩总量、解压总量、条目数、单文件大小四道限制；非 regular 条目直接丢弃。

## 判定

L1=`E4`：恶意或异常 skill 来源被拒绝/降级，不把安装资源消耗伪装成成功。L2-L5 本批未启动真实 App，记 `na`。
