/// The sidestage auto-open follow intent (WRK-061 §12-1) — a shared PREFERENCE, not a chat-internal
/// detail: the chat sidestage head sets it (three-notch menu) AND the settings chat panel mirrors it.
/// The enum lives here (core, framework-free) so the pure [StageDirector] model can import it without
/// pulling in Riverpod, and neither feature imports the other. The persisted provider is in
/// [app_prefs_providers] (`followModeProvider`). 跟随三档=共享偏好;enum 放 core 无框架依赖,provider 在
/// app_prefs_providers,使 chat 纯模型/settings 面板都无需互相 import。
library;

enum FollowMode { never, firstPerConversation, always }
