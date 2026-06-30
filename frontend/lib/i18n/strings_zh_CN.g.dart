///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsZhCn extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZhCn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zhCn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-CN>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsZhCn _root = this; // ignore: unused_field

	@override 
	TranslationsZhCn $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZhCn(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$chat$zh_CN chat = _Translations$chat$zh_CN._(_root);
	@override String get appName => 'Anselm';
	@override late final _Translations$status$zh_CN status = _Translations$status$zh_CN._(_root);
	@override late final _Translations$action$zh_CN action = _Translations$action$zh_CN._(_root);
	@override late final _Translations$feedback$zh_CN feedback = _Translations$feedback$zh_CN._(_root);
	@override late final _Translations$shell$zh_CN shell = _Translations$shell$zh_CN._(_root);
	@override late final _Translations$ref$zh_CN ref = _Translations$ref$zh_CN._(_root);
	@override late final _Translations$a11y$zh_CN a11y = _Translations$a11y$zh_CN._(_root);
	@override late final _Translations$diff$zh_CN diff = _Translations$diff$zh_CN._(_root);
	@override late final _Translations$tree$zh_CN tree = _Translations$tree$zh_CN._(_root);
	@override late final _Translations$startup$zh_CN startup = _Translations$startup$zh_CN._(_root);
	@override late final _Translations$entities$zh_CN entities = _Translations$entities$zh_CN._(_root);
	@override late final _Translations$coldStart$zh_CN coldStart = _Translations$coldStart$zh_CN._(_root);
}

// Path: chat
class _Translations$chat$zh_CN extends Translations$chat$en {
	_Translations$chat$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get kNew => '新对话';
	@override String get filter => '搜索对话…';
	@override String get emptyTitle => '还没有对话';
	@override String get emptyHint => '开始一个新对话吧。';
	@override String get errorTitle => '对话列表加载失败';
	@override String get errorHint => '本地引擎没有返回对话列表。';
	@override String get retry => '重试';
	@override late final _Translations$chat$time$zh_CN time = _Translations$chat$time$zh_CN._(_root);
	@override late final _Translations$chat$bucket$zh_CN bucket = _Translations$chat$bucket$zh_CN._(_root);
}

// Path: status
class _Translations$status$zh_CN extends Translations$status$en {
	_Translations$status$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get idle => '空闲';
	@override String get run => '运行中';
	@override String get wait => '等待';
	@override String get err => '失败';
	@override String get done => '完成';
}

// Path: action
class _Translations$action$zh_CN extends Translations$action$en {
	_Translations$action$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get edit => '编辑';
	@override String get cancel => '取消';
	@override String get save => '保存';
	@override String get copy => '复制';
	@override String get wrap => '自动换行';
	@override String get delete => '删除';
}

// Path: feedback
class _Translations$feedback$zh_CN extends Translations$feedback$en {
	_Translations$feedback$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get info => '提示';
	@override String get success => '成功';
	@override String get warning => '警告';
	@override String get error => '错误';
	@override String get dismiss => '关闭';
	@override String get confirmDelete => '确认删除';
	@override String get dialogBarrier => '关闭对话框';
	@override String get loading => '加载中';
	@override String stepOf({required Object n, required Object m}) => '第 ${n} 步 / 共 ${m} 步';
	@override String goToStep({required Object n}) => '跳到第 ${n} 步';
	@override String removeTag({required Object name}) => '移除 ${name}';
	@override String get addTag => '添加标签';
	@override String get copied => '已复制';
	@override String get copyFailed => '复制失败';
}

// Path: shell
class _Translations$shell$zh_CN extends Translations$shell$en {
	_Translations$shell$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get collapseSidebar => '收起侧栏';
	@override String get expandSidebar => '展开侧栏';
	@override String get togglePanel => '切换面板';
	@override String get backToTop => '回到顶部';
	@override late final _Translations$shell$ocean$zh_CN ocean = _Translations$shell$ocean$zh_CN._(_root);
	@override String get comingSoonTitle => '即将推出';
	@override String get comingSoonHint => '该海洋尚未构建。';
	@override String get settings => '设置';
	@override String get notifications => '通知';
	@override String get notificationsHint => '没有新通知。';
	@override String get workspaceFallback => '工作区';
	@override String get newWorkspace => '新建工作区';
	@override String get workspaceSettings => '工作区设置';
}

// Path: ref
class _Translations$ref$zh_CN extends Translations$ref$en {
	_Translations$ref$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get function => '函数';
	@override String get handler => '处理器';
	@override String get workflow => '工作流';
	@override String get agent => '智能体';
	@override String get document => '文档';
	@override String get conversation => '会话';
	@override String get skill => '技能';
	@override String get mcp => 'MCP';
	@override String get trigger => '触发器';
	@override String get control => '控制';
	@override String get approval => '审批';
}

// Path: a11y
class _Translations$a11y$zh_CN extends Translations$a11y$en {
	_Translations$a11y$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String editingField({required Object field}) => '正在编辑 ${field}';
	@override String get displayOptions => '显示选项';
	@override String codeBlock({required Object lang, required Object lines}) => '代码块,${lang},${lines} 行';
	@override String codeBlockPlain({required Object lines}) => '代码块,${lines} 行';
	@override String jsonTree({required Object count}) => 'JSON 树,${count} 项';
	@override String diff({required Object added, required Object removed}) => '差异,新增 ${added},删除 ${removed}';
}

// Path: diff
class _Translations$diff$zh_CN extends Translations$diff$en {
	_Translations$diff$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get added => '新增';
	@override String get removed => '删除';
}

// Path: tree
class _Translations$tree$zh_CN extends Translations$tree$en {
	_Translations$tree$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get invalidJson => '无效 JSON';
	@override String get circular => '[循环引用]';
	@override String moreItems({required Object count}) => '${count} 项已省略';
}

// Path: startup
class _Translations$startup$zh_CN extends Translations$startup$en {
	_Translations$startup$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get connecting => '正在连接本地引擎…';
	@override String get crashedTitle => '无法连接本地引擎';
	@override String get crashedHint => '后端未启动。开发时把 ANSELM_BACKEND_URL 指向已运行的服务(make server)。';
	@override String get retry => '重试';
	@override String get errorTitle => '出错了';
	@override String get errorHint => '渲染此视图时发生了意外错误。';
}

// Path: entities
class _Translations$entities$zh_CN extends Translations$entities$en {
	_Translations$entities$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get kNew => '新建';
	@override String get filter => '筛选…';
	@override String get emptyTitle => '还没有实体';
	@override String get emptyHint => '新建一个函数、处理器、智能体或工作流来开始。';
	@override String get errorTitle => '无法加载实体';
	@override String get errorHint => '本地引擎没有返回实体列表。';
	@override String get retry => '重试';
	@override String get selectTitle => '选择一个实体';
	@override String get selectHint => '从左侧选择一个函数、处理器、智能体或工作流。';
	@override String get sortLabel => '排序';
	@override String get sortRecent => '最近更新';
	@override String get sortName => '名称';
	@override late final _Translations$entities$detail$zh_CN detail = _Translations$entities$detail$zh_CN._(_root);
	@override late final _Translations$entities$run$zh_CN run = _Translations$entities$run$zh_CN._(_root);
}

// Path: coldStart
class _Translations$coldStart$zh_CN extends Translations$coldStart$en {
	_Translations$coldStart$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get connecting => '正在准备工作区…';
	@override String get errorTitle => '无法准备工作区';
	@override String get errorHint => '本地引擎已连通,但工作区未就绪。';
	@override String get defaultWorkspace => '个人';
}

// Path: chat.time
class _Translations$chat$time$zh_CN extends Translations$chat$time$en {
	_Translations$chat$time$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get justNow => '刚刚';
	@override String minutesAgo({required Object n}) => '${n} 分钟前';
	@override String hoursAgo({required Object n}) => '${n} 小时前';
	@override String get yesterday => '昨天';
	@override String daysAgo({required Object n}) => '${n} 天前';
}

// Path: chat.bucket
class _Translations$chat$bucket$zh_CN extends Translations$chat$bucket$en {
	_Translations$chat$bucket$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get pinned => '置顶';
	@override String get recents => '最近';
}

// Path: shell.ocean
class _Translations$shell$ocean$zh_CN extends Translations$shell$ocean$en {
	_Translations$shell$ocean$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get chat => '对话';
	@override String get entities => '实体';
	@override String get scheduler => '调度';
	@override String get documents => '文档';
}

// Path: entities.detail
class _Translations$entities$detail$zh_CN extends Translations$entities$detail$en {
	_Translations$entities$detail$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get crumbRoot => '实体';
	@override String get moreActions => '更多操作';
	@override late final _Translations$entities$detail$tab$zh_CN tab = _Translations$entities$detail$tab$zh_CN._(_root);
	@override late final _Translations$entities$detail$verb$zh_CN verb = _Translations$entities$detail$verb$zh_CN._(_root);
	@override late final _Translations$entities$detail$sec$zh_CN sec = _Translations$entities$detail$sec$zh_CN._(_root);
	@override late final _Translations$entities$detail$card$zh_CN card = _Translations$entities$detail$card$zh_CN._(_root);
	@override late final _Translations$entities$detail$graph$zh_CN graph = _Translations$entities$detail$graph$zh_CN._(_root);
	@override late final _Translations$entities$detail$kv$zh_CN kv = _Translations$entities$detail$kv$zh_CN._(_root);
	@override late final _Translations$entities$detail$val$zh_CN val = _Translations$entities$detail$val$zh_CN._(_root);
	@override late final _Translations$entities$detail$mounts$zh_CN mounts = _Translations$entities$detail$mounts$zh_CN._(_root);
	@override late final _Translations$entities$detail$state$zh_CN state = _Translations$entities$detail$state$zh_CN._(_root);
}

// Path: entities.run
class _Translations$entities$run$zh_CN extends Translations$entities$run$en {
	_Translations$entities$run$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get method => '方法';
	@override String get streaming => '流式';
	@override String get noInputs => '无入参 —— 直接运行。';
	@override String get payload => '载荷(JSON,可选)';
	@override String get payloadInvalid => '载荷必须是合法 JSON。';
	@override String get payloadObject => '载荷必须是 JSON 对象。';
	@override String fieldInvalid({required Object name}) => '${name} 必须是合法 JSON。';
	@override String get boolTrue => 'true';
	@override String get boolFalse => 'false';
	@override String get runAgain => '再运行一次';
	@override String get cancel => '取消';
	@override String get close => '关闭运行终端';
	@override String get idleTitle => '准备运行';
	@override String get idleHint => '填好入参后运行。';
	@override String get cancelled => '已取消';
	@override String get outputHeading => '输出';
	@override String get resultHeading => '结果';
	@override String get logsHeading => '日志';
	@override String get traceHeading => '轨迹';
	@override String get reasoning => '推理';
	@override String get toolCall => '工具调用';
	@override String get nodesHeading => '节点';
	@override String get noTrace => '等待输出…';
	@override String steps({required Object n}) => '${n} 步';
	@override String tokens({required Object inT, required Object outT}) => '输入 ${inT} · 输出 ${outT}';
	@override String ms({required Object ms}) => '${ms} ms';
	@override late final _Translations$entities$run$danger$zh_CN danger = _Translations$entities$run$danger$zh_CN._(_root);
}

// Path: entities.detail.tab
class _Translations$entities$detail$tab$zh_CN extends Translations$entities$detail$tab$en {
	_Translations$entities$detail$tab$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get overview => '概览';
	@override String get versions => '版本';
	@override String get logs => '日志';
}

// Path: entities.detail.verb
class _Translations$entities$detail$verb$zh_CN extends Translations$entities$detail$verb$en {
	_Translations$entities$detail$verb$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get run => '运行';
	@override String get call => '调用';
	@override String get invoke => '唤起';
	@override String get trigger => '触发';
}

// Path: entities.detail.sec
class _Translations$entities$detail$sec$zh_CN extends Translations$entities$detail$sec$en {
	_Translations$entities$detail$sec$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get code => '代码';
	@override String get input => '输入';
	@override String get output => '输出';
	@override String get env => '环境';
	@override String get runtime => '常驻状态';
	@override String get initArgs => 'init 参数';
	@override String get methods => '方法';
	@override String get prompt => '提示词';
	@override String get capabilities => '能力挂载';
	@override String get mountHealth => '挂载健康';
	@override String get governance => '运行治理';
	@override String get alerts => '告警';
	@override String get graph => '编排图';
}

// Path: entities.detail.card
class _Translations$entities$detail$card$zh_CN extends Translations$entities$detail$card$en {
	_Translations$entities$detail$card$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get deps => '依赖';
	@override String get venv => 'venv 状态';
	@override String get runtime => '运行时';
	@override String get config => '配置完整度';
	@override String get tools => '工具挂载';
	@override String get skill => '技能';
	@override String get knowledge => '知识';
	@override String get model => '模型覆盖';
	@override String get lifecycle => '生命周期';
	@override String get concurrency => '并发策略';
}

// Path: entities.detail.graph
class _Translations$entities$detail$graph$zh_CN extends Translations$entities$detail$graph$en {
	_Translations$entities$detail$graph$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get nodes => '节点';
	@override String get edges => '边';
	@override String get path => '路径';
	@override String get openEditor => '进入图编辑器';
}

// Path: entities.detail.kv
class _Translations$entities$detail$kv$zh_CN extends Translations$entities$detail$kv$en {
	_Translations$entities$detail$kv$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get name => '名称';
	@override String get tags => '标签';
	@override String get id => 'ID';
	@override String get activeVersion => '活动版本';
	@override String get currentVersion => '当前版本';
	@override String get python => 'Python';
	@override String get updated => '更新';
	@override String get desc => '说明';
	@override String get envId => 'env id';
	@override String get status => '状态';
	@override String get syncedAt => '最近同步';
	@override String get error => '错误';
	@override String get model => '模型';
	@override String get provider => '提供方';
	@override String get instanceId => '实例';
	@override String get version => '版本';
	@override String get elapsed => '耗时';
	@override String get time => '时间';
	@override String get replay => '重放';
	@override String get flowrunId => 'Flowrun id';
	@override String get workflow => '工作流';
	@override String get nodes => '节点';
	@override String get lifecycle => '生命周期';
	@override String get active => '在途';
	@override String get lastAction => '最近操作';
	@override String get concurrency => '并发';
	@override String get trigger => '触发器';
	@override String get input => '输入';
	@override String get output => '输出';
	@override String get ref => '引用';
	@override String get healthy => '健康';
	@override String get method => '方法';
	@override String get startedAt => '开始';
	@override String get completedAt => '结束';
	@override String get triggeredBy => '触发方';
}

// Path: entities.detail.val
class _Translations$entities$detail$val$zh_CN extends Translations$entities$detail$val$en {
	_Translations$entities$detail$val$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get listening => '监听中';
	@override String get stopped => '已停';
	@override String get noAlerts => '无告警';
	@override String get needsAttention => '需注意';
	@override String get required => '必填';
	@override String get optional => '可选';
	@override String get sensitive => '敏感';
	@override String get defaultPrefix => '默认';
	@override String get generator => '生成器';
	@override String get modelDefault => '工作区默认';
	@override String get modelOverridden => '已覆盖';
	@override String get none => '—';
}

// Path: entities.detail.mounts
class _Translations$entities$detail$mounts$zh_CN extends Translations$entities$detail$mounts$en {
	_Translations$entities$detail$mounts$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get healthy => '挂载正常';
	@override String unhealthy({required Object count}) => '${count} 项异常';
}

// Path: entities.detail.state
class _Translations$entities$detail$state$zh_CN extends Translations$entities$detail$state$en {
	_Translations$entities$detail$state$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get noVersions => '暂无版本';
	@override String get noLogs => '暂无运行记录';
	@override String get noLogsHint => '执行该实体后,记录会出现在这里。';
	@override String get noActiveVersion => '无活动版本';
	@override String get notFoundTitle => '未找到该实体';
	@override String get errorTitle => '无法加载该实体';
	@override String get errorHint => '本地引擎没有返回它。';
	@override String get loadMore => '加载更多';
	@override String get endOfList => '已到底';
	@override String get loadFailed => '加载失败,点此重试';
	@override String get earliest => '最早版本';
}

// Path: entities.run.danger
class _Translations$entities$run$danger$zh_CN extends Translations$entities$run$danger$en {
	_Translations$entities$run$danger$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get cautious => '谨慎';
	@override String get dangerous => '危险';
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZhCn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'chat.kNew' => '新对话',
			'chat.filter' => '搜索对话…',
			'chat.emptyTitle' => '还没有对话',
			'chat.emptyHint' => '开始一个新对话吧。',
			'chat.errorTitle' => '对话列表加载失败',
			'chat.errorHint' => '本地引擎没有返回对话列表。',
			'chat.retry' => '重试',
			'chat.time.justNow' => '刚刚',
			'chat.time.minutesAgo' => ({required Object n}) => '${n} 分钟前',
			'chat.time.hoursAgo' => ({required Object n}) => '${n} 小时前',
			'chat.time.yesterday' => '昨天',
			'chat.time.daysAgo' => ({required Object n}) => '${n} 天前',
			'chat.bucket.pinned' => '置顶',
			'chat.bucket.recents' => '最近',
			'appName' => 'Anselm',
			'status.idle' => '空闲',
			'status.run' => '运行中',
			'status.wait' => '等待',
			'status.err' => '失败',
			'status.done' => '完成',
			'action.edit' => '编辑',
			'action.cancel' => '取消',
			'action.save' => '保存',
			'action.copy' => '复制',
			'action.wrap' => '自动换行',
			'action.delete' => '删除',
			'feedback.info' => '提示',
			'feedback.success' => '成功',
			'feedback.warning' => '警告',
			'feedback.error' => '错误',
			'feedback.dismiss' => '关闭',
			'feedback.confirmDelete' => '确认删除',
			'feedback.dialogBarrier' => '关闭对话框',
			'feedback.loading' => '加载中',
			'feedback.stepOf' => ({required Object n, required Object m}) => '第 ${n} 步 / 共 ${m} 步',
			'feedback.goToStep' => ({required Object n}) => '跳到第 ${n} 步',
			'feedback.removeTag' => ({required Object name}) => '移除 ${name}',
			'feedback.addTag' => '添加标签',
			'feedback.copied' => '已复制',
			'feedback.copyFailed' => '复制失败',
			'shell.collapseSidebar' => '收起侧栏',
			'shell.expandSidebar' => '展开侧栏',
			'shell.togglePanel' => '切换面板',
			'shell.backToTop' => '回到顶部',
			'shell.ocean.chat' => '对话',
			'shell.ocean.entities' => '实体',
			'shell.ocean.scheduler' => '调度',
			'shell.ocean.documents' => '文档',
			'shell.comingSoonTitle' => '即将推出',
			'shell.comingSoonHint' => '该海洋尚未构建。',
			'shell.settings' => '设置',
			'shell.notifications' => '通知',
			'shell.notificationsHint' => '没有新通知。',
			'shell.workspaceFallback' => '工作区',
			'shell.newWorkspace' => '新建工作区',
			'shell.workspaceSettings' => '工作区设置',
			'ref.function' => '函数',
			'ref.handler' => '处理器',
			'ref.workflow' => '工作流',
			'ref.agent' => '智能体',
			'ref.document' => '文档',
			'ref.conversation' => '会话',
			'ref.skill' => '技能',
			'ref.mcp' => 'MCP',
			'ref.trigger' => '触发器',
			'ref.control' => '控制',
			'ref.approval' => '审批',
			'a11y.editingField' => ({required Object field}) => '正在编辑 ${field}',
			'a11y.displayOptions' => '显示选项',
			'a11y.codeBlock' => ({required Object lang, required Object lines}) => '代码块,${lang},${lines} 行',
			'a11y.codeBlockPlain' => ({required Object lines}) => '代码块,${lines} 行',
			'a11y.jsonTree' => ({required Object count}) => 'JSON 树,${count} 项',
			'a11y.diff' => ({required Object added, required Object removed}) => '差异,新增 ${added},删除 ${removed}',
			'diff.added' => '新增',
			'diff.removed' => '删除',
			'tree.invalidJson' => '无效 JSON',
			'tree.circular' => '[循环引用]',
			'tree.moreItems' => ({required Object count}) => '${count} 项已省略',
			'startup.connecting' => '正在连接本地引擎…',
			'startup.crashedTitle' => '无法连接本地引擎',
			'startup.crashedHint' => '后端未启动。开发时把 ANSELM_BACKEND_URL 指向已运行的服务(make server)。',
			'startup.retry' => '重试',
			'startup.errorTitle' => '出错了',
			'startup.errorHint' => '渲染此视图时发生了意外错误。',
			'entities.kNew' => '新建',
			'entities.filter' => '筛选…',
			'entities.emptyTitle' => '还没有实体',
			'entities.emptyHint' => '新建一个函数、处理器、智能体或工作流来开始。',
			'entities.errorTitle' => '无法加载实体',
			'entities.errorHint' => '本地引擎没有返回实体列表。',
			'entities.retry' => '重试',
			'entities.selectTitle' => '选择一个实体',
			'entities.selectHint' => '从左侧选择一个函数、处理器、智能体或工作流。',
			'entities.sortLabel' => '排序',
			'entities.sortRecent' => '最近更新',
			'entities.sortName' => '名称',
			'entities.detail.crumbRoot' => '实体',
			'entities.detail.moreActions' => '更多操作',
			'entities.detail.tab.overview' => '概览',
			'entities.detail.tab.versions' => '版本',
			'entities.detail.tab.logs' => '日志',
			'entities.detail.verb.run' => '运行',
			'entities.detail.verb.call' => '调用',
			'entities.detail.verb.invoke' => '唤起',
			'entities.detail.verb.trigger' => '触发',
			'entities.detail.sec.code' => '代码',
			'entities.detail.sec.input' => '输入',
			'entities.detail.sec.output' => '输出',
			'entities.detail.sec.env' => '环境',
			'entities.detail.sec.runtime' => '常驻状态',
			'entities.detail.sec.initArgs' => 'init 参数',
			'entities.detail.sec.methods' => '方法',
			'entities.detail.sec.prompt' => '提示词',
			'entities.detail.sec.capabilities' => '能力挂载',
			'entities.detail.sec.mountHealth' => '挂载健康',
			'entities.detail.sec.governance' => '运行治理',
			'entities.detail.sec.alerts' => '告警',
			'entities.detail.sec.graph' => '编排图',
			'entities.detail.card.deps' => '依赖',
			'entities.detail.card.venv' => 'venv 状态',
			'entities.detail.card.runtime' => '运行时',
			'entities.detail.card.config' => '配置完整度',
			'entities.detail.card.tools' => '工具挂载',
			'entities.detail.card.skill' => '技能',
			'entities.detail.card.knowledge' => '知识',
			'entities.detail.card.model' => '模型覆盖',
			'entities.detail.card.lifecycle' => '生命周期',
			'entities.detail.card.concurrency' => '并发策略',
			'entities.detail.graph.nodes' => '节点',
			'entities.detail.graph.edges' => '边',
			'entities.detail.graph.path' => '路径',
			'entities.detail.graph.openEditor' => '进入图编辑器',
			'entities.detail.kv.name' => '名称',
			'entities.detail.kv.tags' => '标签',
			'entities.detail.kv.id' => 'ID',
			'entities.detail.kv.activeVersion' => '活动版本',
			'entities.detail.kv.currentVersion' => '当前版本',
			'entities.detail.kv.python' => 'Python',
			'entities.detail.kv.updated' => '更新',
			'entities.detail.kv.desc' => '说明',
			'entities.detail.kv.envId' => 'env id',
			'entities.detail.kv.status' => '状态',
			'entities.detail.kv.syncedAt' => '最近同步',
			'entities.detail.kv.error' => '错误',
			'entities.detail.kv.model' => '模型',
			'entities.detail.kv.provider' => '提供方',
			'entities.detail.kv.instanceId' => '实例',
			'entities.detail.kv.version' => '版本',
			'entities.detail.kv.elapsed' => '耗时',
			'entities.detail.kv.time' => '时间',
			'entities.detail.kv.replay' => '重放',
			'entities.detail.kv.flowrunId' => 'Flowrun id',
			'entities.detail.kv.workflow' => '工作流',
			'entities.detail.kv.nodes' => '节点',
			'entities.detail.kv.lifecycle' => '生命周期',
			'entities.detail.kv.active' => '在途',
			'entities.detail.kv.lastAction' => '最近操作',
			'entities.detail.kv.concurrency' => '并发',
			'entities.detail.kv.trigger' => '触发器',
			'entities.detail.kv.input' => '输入',
			'entities.detail.kv.output' => '输出',
			'entities.detail.kv.ref' => '引用',
			'entities.detail.kv.healthy' => '健康',
			'entities.detail.kv.method' => '方法',
			'entities.detail.kv.startedAt' => '开始',
			'entities.detail.kv.completedAt' => '结束',
			'entities.detail.kv.triggeredBy' => '触发方',
			'entities.detail.val.listening' => '监听中',
			'entities.detail.val.stopped' => '已停',
			'entities.detail.val.noAlerts' => '无告警',
			'entities.detail.val.needsAttention' => '需注意',
			'entities.detail.val.required' => '必填',
			'entities.detail.val.optional' => '可选',
			'entities.detail.val.sensitive' => '敏感',
			'entities.detail.val.defaultPrefix' => '默认',
			'entities.detail.val.generator' => '生成器',
			'entities.detail.val.modelDefault' => '工作区默认',
			'entities.detail.val.modelOverridden' => '已覆盖',
			'entities.detail.val.none' => '—',
			'entities.detail.mounts.healthy' => '挂载正常',
			'entities.detail.mounts.unhealthy' => ({required Object count}) => '${count} 项异常',
			'entities.detail.state.noVersions' => '暂无版本',
			'entities.detail.state.noLogs' => '暂无运行记录',
			'entities.detail.state.noLogsHint' => '执行该实体后,记录会出现在这里。',
			'entities.detail.state.noActiveVersion' => '无活动版本',
			'entities.detail.state.notFoundTitle' => '未找到该实体',
			'entities.detail.state.errorTitle' => '无法加载该实体',
			'entities.detail.state.errorHint' => '本地引擎没有返回它。',
			'entities.detail.state.loadMore' => '加载更多',
			'entities.detail.state.endOfList' => '已到底',
			'entities.detail.state.loadFailed' => '加载失败,点此重试',
			'entities.detail.state.earliest' => '最早版本',
			'entities.run.method' => '方法',
			'entities.run.streaming' => '流式',
			'entities.run.noInputs' => '无入参 —— 直接运行。',
			'entities.run.payload' => '载荷(JSON,可选)',
			'entities.run.payloadInvalid' => '载荷必须是合法 JSON。',
			'entities.run.payloadObject' => '载荷必须是 JSON 对象。',
			'entities.run.fieldInvalid' => ({required Object name}) => '${name} 必须是合法 JSON。',
			'entities.run.boolTrue' => 'true',
			'entities.run.boolFalse' => 'false',
			'entities.run.runAgain' => '再运行一次',
			'entities.run.cancel' => '取消',
			'entities.run.close' => '关闭运行终端',
			'entities.run.idleTitle' => '准备运行',
			'entities.run.idleHint' => '填好入参后运行。',
			'entities.run.cancelled' => '已取消',
			'entities.run.outputHeading' => '输出',
			'entities.run.resultHeading' => '结果',
			'entities.run.logsHeading' => '日志',
			'entities.run.traceHeading' => '轨迹',
			'entities.run.reasoning' => '推理',
			'entities.run.toolCall' => '工具调用',
			'entities.run.nodesHeading' => '节点',
			'entities.run.noTrace' => '等待输出…',
			'entities.run.steps' => ({required Object n}) => '${n} 步',
			'entities.run.tokens' => ({required Object inT, required Object outT}) => '输入 ${inT} · 输出 ${outT}',
			'entities.run.ms' => ({required Object ms}) => '${ms} ms',
			'entities.run.danger.cautious' => '谨慎',
			'entities.run.danger.dangerous' => '危险',
			'coldStart.connecting' => '正在准备工作区…',
			'coldStart.errorTitle' => '无法准备工作区',
			'coldStart.errorHint' => '本地引擎已连通,但工作区未就绪。',
			'coldStart.defaultWorkspace' => '个人',
			_ => null,
		};
	}
}
