# EDGE-241 · 换 master key 种子：真实现场边界

## 现场探针

- 使用隔离副本
  `/Users/sunweilin/Library/Containers/website.anselm.app/Data/.anselm-edge241-wrong-master-key-1`，保留已有 SQLite、加密 `api_keys` 与 `device-proof.key`。
- 以 backend-first 方式启动真实 sidecar，并设置仅用于故障注入的
  `ANSELM_MASTER_KEY=edge241-wrong-master-key`。台架 session=
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-170033`。
- sidecar 在启动阶段退出，原始 backend journal 为：
  `bootstrap: device proof: deviceproof: decrypt key: aesgcm: open: cipher: message authentication failed`。
  进程没有绑定服务端口，故没有伪造健康 App、SSE 或 LLM 产品证据。
- 该结果与 `TestAESGCMEncryptor_DifferentKeyFailsDecryption` 一致：不同 seed 不会错误解开旧密文。它同时说明 `device-proof.key` 也属于当前加密边界；这是一个不支持的运维变更，不是 Settings 中可操作的主密钥轮换路径。

## 适用性裁决

- L1 继续使用 `EDGE-241-master-key-rotation-20260826.md` 的 `F5`：旧密文在换 seed 后拒绝解密。
- L2 不适用：`ANSELM_MASTER_KEY` 不是产品用户入口，且错误 seed 会在 sidecar 提供 HTTP 服务前终止 bootstrap；本次负向启动探针不能冒充真实产品状态闭环。
- L3 不适用：没有受支持的用户动作或可观测产品反馈流程可以在该运维变更下继续重录密钥。
- L4 不适用：该内部密钥种子变更不产生独立产品视觉对象；不把通用启动失败页当作密钥轮换视觉 craft。
- L5 不适用：用户不能从产品导航发现或执行 `ANSELM_MASTER_KEY` 轮换；恢复入口属于出厂重置/重新录入的后置人工路径，不由本格虚构。

## 安全边界

- 真实 keychain 条目未被删除或改写；临时读取授权尝试在系统无可见授权面时中止，未留下密钥副本。
- 隔离 fixture 与 conductor 进程已收台；本记录不包含任何明文 key、device-proof 私钥或网关 secret。
