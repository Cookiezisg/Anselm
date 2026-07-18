import 'package:flutter/widgets.dart';

import 'an_brand_icon.dart';

/// The vendored brand-asset registry (assets/brand/*.svg — lobe-icons MIT for LLM providers,
/// simple-icons CC0 for service brands; provenance in `assets/brand/LICENSES.md`). ONE lookup seam
/// for both consumers (the providers zone in Models & keys, the MCP marketplace/installed cards):
/// resolve a slug → tinted [AnBrandIcon.brand]; anything unmapped falls back to the first-letter
/// plate — every card always has an icon seat, no asset is ever required.
///
/// 品牌资产注册表(assets/brand/*.svg——LLM 厂牌 lobe-icons MIT、服务品牌 simple-icons CC0,出处见
/// LICENSES.md)。两个消费方(模型与密钥 provider 区、MCP 市场/已装卡)共用这一个查询缝:slug →
/// 着色 [AnBrandIcon.brand];查不到一律首字母圆徽兜底——每卡必有图标位,不强求资产。
const Set<String> kBrandAssets = {
  // LLM providers (lobe-icons). LLM 厂牌。
  'openai', 'anthropic', 'gemini', 'deepseek', 'openrouter', 'qwen', 'zhipu',
  'moonshot', 'doubao', 'ollama',
  // Service brands (simple-icons). 服务品牌。
  'brave', 'github', 'notion', 'supabase', 'sentry', 'postgresql', 'figma', 'zapier',
  'todoist', 'box', 'stripe', 'vercel', 'atlassian', 'mongodb', 'elastic', 'huggingface',
  'intercom', 'webflow', 'wix', 'stackoverflow', 'postman', 'terraform', 'googlechrome',
  'svelte', 'nuxt', 'mapbox', 'miro', 'pagerduty', 'snyk', 'upstash', 'dynatrace', 'jfrog',
  'pydantic', 'octopusdeploy', 'codacy', 'unity', 'sap', 'arm', 'netdata', 'sonatype',
  'githubcopilot', 'neon',
};

/// API-key provider name → brand slug. `anselm` renders [AnBrandIcon.anselm]; unmapped providers
/// (custom / serper / tavily / bocha) take the letter fallback. provider 名→slug;anselm 走自家标,
/// 未映射走字母兜底。
const Map<String, String> kProviderBrand = {
  'openai': 'openai',
  'anthropic': 'anthropic',
  'google': 'gemini',
  'deepseek': 'deepseek',
  'openrouter': 'openrouter',
  'qwen': 'qwen',
  'zhipu': 'zhipu',
  'moonshot': 'moonshot',
  'doubao': 'doubao',
  'ollama': 'ollama',
  'brave': 'brave',
};

/// Registry tokens → brand slug for MCP entries. Matched against the DNS-stripped org + name
/// TOKENS (never raw substrings — `io.github.*` would turn everything into GitHub). 注册表词元→
/// slug;按去 DNS 前缀后的词元匹配(绝不裸子串——io.github.* 会把一切认成 GitHub)。
const Map<String, String> _kMcpTokenBrand = {
  'github': 'github',
  'notion': 'notion', 'makenotion': 'notion',
  'supabase': 'supabase',
  'sentry': 'sentry', 'getsentry': 'sentry',
  'postgres': 'postgresql', 'postgresql': 'postgresql',
  'figma': 'figma',
  'zapier': 'zapier',
  'todoist': 'todoist', 'doist': 'todoist',
  'box': 'box',
  'stripe': 'stripe',
  'vercel': 'vercel',
  'atlassian': 'atlassian',
  'mongodb': 'mongodb',
  'elastic': 'elastic', 'elasticsearch': 'elastic',
  'huggingface': 'huggingface', 'hf': 'huggingface',
  'intercom': 'intercom',
  'webflow': 'webflow',
  'wix': 'wix',
  'stackoverflow': 'stackoverflow',
  'postman': 'postman',
  'terraform': 'terraform', 'hashicorp': 'terraform',
  'chrome': 'googlechrome', 'chromedevtools': 'googlechrome',
  'svelte': 'svelte',
  'nuxt': 'nuxt',
  'mapbox': 'mapbox',
  'miro': 'miro', 'miroapp': 'miro',
  'pagerduty': 'pagerduty',
  'snyk': 'snyk',
  'upstash': 'upstash',
  'dynatrace': 'dynatrace',
  'jfrog': 'jfrog',
  'pydantic': 'pydantic',
  'octopusdeploy': 'octopusdeploy',
  'codacy': 'codacy',
  'unity': 'unity',
  'sap': 'sap', 'ui5': 'sap',
  'arm': 'arm',
  'netdata': 'netdata',
  'sonatype': 'sonatype',
  'copilot': 'githubcopilot',
  'neon': 'neon', 'neondatabase': 'neon',
};

// Reverse-DNS / registry noise that never identifies a brand. 注册表 DNS 噪声词。
const Set<String> _kDnsNoise = {'io', 'com', 'dev', 'co', 'host', 'mcp'};

/// Resolve an MCP registry fullName (`io.github.getsentry/sentry-mcp`) to a brand slug, or null for
/// the letter fallback. 解析 MCP fullName→slug;解不出返 null 走字母兜底。
String? mcpBrandFor(String fullName) {
  final slash = fullName.indexOf('/');
  var org = slash < 0 ? fullName : fullName.substring(0, slash);
  final name = slash < 0 ? '' : fullName.substring(slash + 1);
  // `io.github.X` is a registry namespace, not the GitHub brand — the org is X. 命名空间非品牌。
  if (org.startsWith('io.github.')) org = org.substring('io.github.'.length);
  final tokens = <String>[
    ...org.toLowerCase().split(RegExp(r'[^a-z0-9]+')),
    ...name.toLowerCase().split(RegExp(r'[^a-z0-9]+')),
  ]..removeWhere((t) => t.isEmpty || _kDnsNoise.contains(t));
  for (final t in tokens) {
    final hit = _kMcpTokenBrand[t];
    if (hit != null && kBrandAssets.contains(hit)) return hit;
  }
  return null;
}

/// The one icon-seat builder both surfaces call: slug → tinted brand asset, else the first-letter
/// plate from [fallbackLabel]. 唯一图标位构造:slug→资产,缺者 [fallbackLabel] 首字母徽。
Widget brandIconOr(String? slug,
    {required String fallbackLabel, AnBrandSize size = AnBrandSize.md, bool managed = false}) {
  if (slug != null && kBrandAssets.contains(slug)) {
    return AnBrandIcon.brand('assets/brand/$slug.svg', size: size, managed: managed);
  }
  return AnBrandIcon.glyph(fallbackLabel, size: size, managed: managed);
}
