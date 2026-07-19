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
	@override late final _Translations$run$zh_CN run = _Translations$run$zh_CN._(_root);
	@override late final _Translations$scheduler$zh_CN scheduler = _Translations$scheduler$zh_CN._(_root);
	@override late final _Translations$action$zh_CN action = _Translations$action$zh_CN._(_root);
	@override late final _Translations$feedback$zh_CN feedback = _Translations$feedback$zh_CN._(_root);
	@override late final _Translations$shell$zh_CN shell = _Translations$shell$zh_CN._(_root);
	@override late final _Translations$notifications$zh_CN notifications = _Translations$notifications$zh_CN._(_root);
	@override late final _Translations$ref$zh_CN ref = _Translations$ref$zh_CN._(_root);
	@override late final _Translations$graph$zh_CN graph = _Translations$graph$zh_CN._(_root);
	@override late final _Translations$a11y$zh_CN a11y = _Translations$a11y$zh_CN._(_root);
	@override late final _Translations$diff$zh_CN diff = _Translations$diff$zh_CN._(_root);
	@override late final _Translations$tree$zh_CN tree = _Translations$tree$zh_CN._(_root);
	@override late final _Translations$startup$zh_CN startup = _Translations$startup$zh_CN._(_root);
	@override late final _Translations$entities$zh_CN entities = _Translations$entities$zh_CN._(_root);
	@override late final _Translations$coldStart$zh_CN coldStart = _Translations$coldStart$zh_CN._(_root);
	@override late final _Translations$documents$zh_CN documents = _Translations$documents$zh_CN._(_root);
	@override late final _Translations$settings$zh_CN settings = _Translations$settings$zh_CN._(_root);
	@override late final _Translations$markdown$zh_CN markdown = _Translations$markdown$zh_CN._(_root);
	@override late final _Translations$attach$zh_CN attach = _Translations$attach$zh_CN._(_root);
}

// Path: chat
class _Translations$chat$zh_CN extends Translations$chat$en {
	_Translations$chat$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get kNew => '新对话';
	@override String get filter => '搜索对话…';
	@override String get errorTitle => '对话列表加载失败';
	@override String get errorHint => '本地引擎没有返回对话列表。';
	@override String get retry => '重试';
	@override String get sortLabel => '排序';
	@override String get sortActivity => '最近活跃';
	@override String get sortCreated => '最近创建';
	@override String get sortName => '按名称';
	@override String get displayLabel => '显示';
	@override String get showArchived => '显示已归档';
	@override String get showCount => '显示分组计数';
	@override String get showTime => '显示时间';
	@override String get rename => '重命名';
	@override String get pin => '置顶';
	@override String get unpin => '取消置顶';
	@override String get archive => '归档';
	@override String get unarchive => '取消归档';
	@override String get deleteTitle => '删除这个对话？';
	@override String deleteBody({required Object title}) => '「${title}」将被移除。';
	@override String get deleteConfirm => '删除';
	@override String get actionFailed => '操作失败';
	@override late final _Translations$chat$time$zh_CN time = _Translations$chat$time$zh_CN._(_root);
	@override late final _Translations$chat$bucket$zh_CN bucket = _Translations$chat$bucket$zh_CN._(_root);
	@override String get placeholder => 'Ask anything…';
	@override String get send => '发送';
	@override String get stop => '停止生成';
	@override String get thinking => 'thinking';
	@override String get thought => 'thought';
	@override String get sendFailed => 'Couldn\'t send';
	@override String attachmentsFailedDropped({required Object n}) => '${n} 个附件上传失败,未随消息发送';
	@override String get retrySend => 'Retry';
	@override String get discard => 'Discard';
	@override String get stoppedCancelled => 'Stopped';
	@override String get stoppedError => 'Something went wrong';
	@override String get repickModel => '重选模型';
	@override String get stoppedMaxSteps => 'Paused — step limit reached';
	@override String get stoppedBudget => 'Paused — context window is full';
	@override String get stoppedMaxTokens => 'Reached the output limit';
	@override String get transcriptErrorTitle => 'Couldn\'t load this conversation';
	@override String get transcriptErrorHint => 'The local engine didn’t return the messages.';
	@override String get backToPresent => '回到现场';
	@override late final _Translations$chat$toc$zh_CN toc = _Translations$chat$toc$zh_CN._(_root);
	@override String get landingGreeting => 'What should we dig into?';
	@override String get modelAuto => 'Auto';
	@override String get mentionEntity => 'Mention an entity';
	@override String get attachFile => 'Attach files';
	@override String get dropToAttach => 'Drop files to attach';
	@override late final _Translations$chat$tool$zh_CN tool = _Translations$chat$tool$zh_CN._(_root);
	@override late final _Translations$chat$gate$zh_CN gate = _Translations$chat$gate$zh_CN._(_root);
	@override String get contextCompacted => '上下文已压缩';
	@override String contextCompactedCount({required Object n}) => '上下文已压缩 · ${n} 条更早消息已折叠进摘要';
	@override late final _Translations$chat$stage$zh_CN stage = _Translations$chat$stage$zh_CN._(_root);
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

// Path: run
class _Translations$run$zh_CN extends Translations$run$en {
	_Translations$run$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get runCompleted => '完成';
	@override String get failed => '失败';
	@override String get agentTimeout => '超时';
	@override String get runCancelled => '已取消';
	@override String get runStillFailed => '仍失败';
	@override String get runAwaitApproval => '等待审批';
	@override String get runStatusRunning => '运行中';
	@override String get replayPinNote => '用原 pin 版本重跑,事后修的代码不生效';
	@override String replayTimes({required Object n}) => '第 ${n} 次重放';
	@override String flowShown({required Object shown, required Object total}) => '显示 ${shown}/${total} 节点';
	@override String nodeCount({required Object n}) => '${n} 节点';
	@override String get nodeWait => '等待';
	@override String get beadPageScope => '本页';
	@override String get provConversation => '对话';
	@override String get provTrigger => '触发器';
	@override String get provFlowrun => '运行';
	@override String get provMessage => '消息';
	@override String get provFiring => '派发';
	@override String get provNode => '节点';
	@override String get emptyPayload => '空 payload';
	@override String get triggerStartedNote => '已启动运行——用 get_flowrun 看进展';
	@override String get ioInput => '输入';
	@override String get ioOutput => '输出';
	@override String countdownLeft({required Object d}) => '剩 ${d}';
	@override String get countdownOverdue => '已超时';
	@override String get approvalTitle => '等待审批';
	@override String get approve => '通过';
	@override String get reject => '驳回';
	@override String get approvalHint => 'first-wins:先到的决断生效。';
	@override String get reasonHint => '备注(可选)';
	@override String get addReason => '+ 理由';
	@override String get inferredRunning => '推测执行中';
	@override String get approveAll => '全部批准';
	@override String get rejectAll => '全部拒绝';
	@override String batchApproveTitle({required Object n}) => '批准全部 ${n} 项?';
	@override String batchRejectTitle({required Object n}) => '拒绝全部 ${n} 项?';
	@override String batchDecideBody({required Object list}) => '以下审批将被处理(先到的决断生效):\n${list}';
	@override String sumApproved({required Object n}) => '已批准 ${n} 项';
	@override String sumRejected({required Object n}) => '已拒绝 ${n} 项';
	@override String sumLost({required Object n}) => '${n} 项已被别处处理';
	@override String sumFailed({required Object n}) => '${n} 项失败';
}

// Path: scheduler
class _Translations$scheduler$zh_CN extends Translations$scheduler$en {
	_Translations$scheduler$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get railErrorTitle => 'workflow 加载失败';
	@override String get railErrorHint => '后端没有应答,检查连接后重试。';
	@override String get retry => '重试';
	@override String get overviewTitle => '总览';
	@override String get underConstruction => 'Scheduler 指挥中心建设中(S1–S5)。';
	@override String runningFor({required Object d}) => '运行中 · ${d}';
	@override String nextFireIn({required Object d}) => '${d} 后';
	@override String agoMeta({required Object d}) => '${d} 前';
	@override String get neverRan => '—';
	@override String get sectionNeverRan => '未运行';
	@override String get sectionInactive => '停用';
	@override String get filterPlaceholder => '搜索…';
	@override String get sortLabel => '排序';
	@override String get sortActivity => '最近活动';
	@override String get sortName => '名称';
	@override String get displayLabel => '显示';
	@override String get showNextFire => '显示下次触发';
	@override String get showLastRun => '显示上次运行';
	@override String get showInactive => '显示停用';
	@override late final _Translations$scheduler$overview$zh_CN overview = _Translations$scheduler$overview$zh_CN._(_root);
	@override late final _Translations$scheduler$status$zh_CN status = _Translations$scheduler$status$zh_CN._(_root);
	@override late final _Translations$scheduler$home$zh_CN home = _Translations$scheduler$home$zh_CN._(_root);
	@override late final _Translations$scheduler$run$zh_CN run = _Translations$scheduler$run$zh_CN._(_root);
	@override late final _Translations$scheduler$range$zh_CN range = _Translations$scheduler$range$zh_CN._(_root);
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
	@override String get expand => '展开';
	@override String get collapse => '收起';
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
	@override String showAll({required Object n}) => '展开其余 ${n} 个';
	@override String get copyFailed => '复制失败';
	@override late final _Translations$feedback$batch$zh_CN batch = _Translations$feedback$batch$zh_CN._(_root);
	@override String get retry => '重试';
	@override late final _Translations$feedback$cast$zh_CN cast = _Translations$feedback$cast$zh_CN._(_root);
}

// Path: shell
class _Translations$shell$zh_CN extends Translations$shell$en {
	_Translations$shell$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get collapseSidebar => '收起侧栏';
	@override String get expandSidebar => '展开侧栏';
	@override String get togglePanel => '切换面板';
	@override late final _Translations$shell$ocean$zh_CN ocean = _Translations$shell$ocean$zh_CN._(_root);
	@override String get comingSoonTitle => '即将推出';
	@override String get comingSoonHint => '该海洋尚未构建。';
	@override String get settings => '设置';
	@override String get notifications => '通知';
	@override String get workspaceFallback => '工作区';
	@override String get newWorkspace => '新建工作区';
	@override String get workspaceSettings => '工作区设置';
}

// Path: notifications
class _Translations$notifications$zh_CN extends Translations$notifications$en {
	_Translations$notifications$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '通知';
	@override String get needsYou => '待你处理';
	@override String get feed => '通知';
	@override String get markAllRead => '全部已读';
	@override String get markAllUnread => '全部未读';
	@override String get markRead => '标为已读';
	@override String get searchPlaceholder => '搜索通知…';
	@override String get unreadOnly => '仅显示未读';
	@override String get displayOptions => '显示';
	@override String get today => '今天';
	@override String get yesterday => '昨天';
	@override String get earlier => '更早';
	@override String get unknown => '有新动态';
	@override late final _Translations$notifications$kind$zh_CN kind = _Translations$notifications$kind$zh_CN._(_root);
	@override late final _Translations$notifications$verb$zh_CN verb = _Translations$notifications$verb$zh_CN._(_root);
	@override String get depBrokenOne => '删除后留下 1 处悬空引用';
	@override String depBrokenMany({required Object n}) => '删除后留下 ${n} 处悬空引用';
	@override String get view => '查看';
	@override String get errorTitle => '通知加载失败';
	@override String get errorHint => '本地引擎没有返回通知列表。';
	@override String get retry => '重试';
	@override String nameQuoted({required Object name}) => '「${name}」';
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

// Path: graph
class _Translations$graph$zh_CN extends Translations$graph$en {
	_Translations$graph$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _Translations$graph$kind$zh_CN kind = _Translations$graph$kind$zh_CN._(_root);
}

// Path: a11y
class _Translations$a11y$zh_CN extends Translations$a11y$en {
	_Translations$a11y$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get flagYes => '是';
	@override String get flagNo => '否';
	@override String editingField({required Object field}) => '正在编辑 ${field}';
	@override String editField({required Object field}) => '编辑 ${field}';
	@override String addTagTo({required Object field}) => '添加标签:${field}';
	@override String get displayOptions => '显示选项';
	@override String get moreActions => '更多操作';
	@override String get newSubpage => '新建子页面';
	@override String get graphZoomIn => '放大';
	@override String get graphZoomOut => '缩小';
	@override String get graphFit => '适应画布';
	@override String graphNode({required Object id, required Object kind, required Object ref}) => '节点 ${id},${kind},${ref}';
	@override String codeBlock({required Object lang, required Object lines}) => '代码块,${lang},${lines} 行';
	@override String codeBlockPlain({required Object lines}) => '代码块,${lines} 行';
	@override String jsonTree({required Object count}) => 'JSON 树,${count} 项';
	@override String diff({required Object added, required Object removed}) => '差异,新增 ${added},删除 ${removed}';
	@override String get loading => '加载中';
	@override String get timeoutBudget => '时限';
	@override String get fmtBold => '加粗';
	@override String get fmtItalic => '斜体';
	@override String get fmtStrike => '删除线';
	@override String get fmtCode => '行内代码';
	@override String get fmtLink => '链接';
	@override String relationSummary({required Object nodes, required Object edges}) => '关系图。${nodes} 个实体，${edges} 条关系。';
	@override String relationNode({required Object name, required Object kind, required Object count}) => '${name}，${kind}，被 ${count} 个实体引用';
	@override String get relationExpand => '展开关系图';
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
	@override String get filter => '搜索实体…';
	@override String get errorTitle => '无法加载实体';
	@override String get errorHint => '本地引擎没有返回实体列表。';
	@override String get retry => '重试';
	@override String get selectTitle => '选择一个实体';
	@override String get selectHint => '从左侧选择一个函数、处理器、智能体或工作流。';
	@override String get sortLabel => '排序';
	@override String get sortRecent => '最近活跃';
	@override String get sortCreated => '最近创建';
	@override String get sortName => '名称';
	@override String get displayLabel => '显示';
	@override String get showCount => '显示分组计数';
	@override late final _Translations$entities$detail$zh_CN detail = _Translations$entities$detail$zh_CN._(_root);
	@override late final _Translations$entities$run$zh_CN run = _Translations$entities$run$zh_CN._(_root);
	@override late final _Translations$entities$val$zh_CN val = _Translations$entities$val$zh_CN._(_root);
	@override late final _Translations$entities$overview$zh_CN overview = _Translations$entities$overview$zh_CN._(_root);
	@override late final _Translations$entities$graph$zh_CN graph = _Translations$entities$graph$zh_CN._(_root);
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

// Path: documents
class _Translations$documents$zh_CN extends Translations$documents$en {
	_Translations$documents$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get documents => '文档';
	@override String get skills => '技能';
	@override String get untitled => '未命名';
	@override String get editorHint => '输入正文,按 / 唤起命令';
	@override String get addDescription => '添加简介…';
	@override String get addTag => '添加标签';
	@override String get filter => '搜索文档…';
	@override String get kNew => '新建页面';
	@override String get errorTitle => '无法加载知识库';
	@override String get errorHint => '本地引擎没有返回它。';
	@override String get retry => '重试';
	@override String get pickTitle => '选一篇文档';
	@override String get pickHint => '在左侧选一篇文档或技能来阅读或编辑。';
	@override String get loadFailed => '打不开这个';
	@override String get rename => '改名';
	@override String get duplicate => '创建副本';
	@override String get deleteDocTitle => '删除这个页面?';
	@override String deleteDocBody({required Object name}) => '“${name}”及其下嵌套的所有内容都会被删除。';
	@override String get deleteSkillTitle => '删除这个技能?';
	@override String deleteSkillBody({required Object name}) => '技能“${name}”会被删除。';
	@override String get actionFailed => '操作失败';
	@override late final _Translations$documents$props$zh_CN props = _Translations$documents$props$zh_CN._(_root);
	@override late final _Translations$documents$slash$zh_CN slash = _Translations$documents$slash$zh_CN._(_root);
	@override String get linkHint => '输入或粘贴链接,回车确定';
	@override late final _Translations$documents$table$zh_CN table = _Translations$documents$table$zh_CN._(_root);
}

// Path: settings
class _Translations$settings$zh_CN extends Translations$settings$en {
	_Translations$settings$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '设置';
	@override late final _Translations$settings$scope$zh_CN scope = _Translations$settings$scope$zh_CN._(_root);
	@override late final _Translations$settings$sections$zh_CN sections = _Translations$settings$sections$zh_CN._(_root);
	@override late final _Translations$settings$panels$zh_CN panels = _Translations$settings$panels$zh_CN._(_root);
	@override String get filter => '搜索设置…';
	@override String get searchNoMatch => '无匹配的设置';
	@override String get building => '面板建设中';
	@override String get buildingHint => '此面板随建造切片逐步点亮。';
	@override String get appearance => '外观';
	@override String get theme => '主题';
	@override String get themeLight => '浅色';
	@override String get themeDark => '深色';
	@override String get themeSystem => '跟随系统';
	@override String get themeDesc => '跟随系统将随 macOS 外观自动切换';
	@override String get zoom => '界面缩放';
	@override String get zoomDesc => '整体缩放界面,与 ⌘+ / ⌘− / ⌘0 同步';
	@override String get fonts => '字体';
	@override String get fontUi => '界面字体';
	@override String get fontUiDesc => '整个界面。内置=Inter+MiSans(双语,各机一致);跟随系统=操作系统字体(macOS San Francisco · Windows Segoe UI)。重启后生效。';
	@override String get fontContent => '内容字体';
	@override String get fontContentDesc => '仅 chat 消息与文档正文。衬线=思源宋 SC(拉丁+简体中文)。即时生效。';
	@override String get fontCode => '代码字体';
	@override String get fontCodeDesc => '一切等宽处——代码块、终端、diff、ID 等。重启后生效。';
	@override String get fontBundled => '内置';
	@override String get fontSystem => '跟随系统';
	@override String get fontSans => '无衬线(内置)';
	@override String get fontSerif => '衬线';
	@override String get fontJetBrainsMono => 'JetBrains Mono';
	@override String get fontFiraCode => 'Fira Code';
	@override String get fontCascadia => 'Cascadia Code';
	@override String get fontSystemMono => '跟随系统等宽';
	@override String get fontRestartHint => '重启后生效';
	@override String get language => '语言';
	@override String get languageRow => '语言';
	@override String get languageDesc => '同时设定界面语言与当前工作区的 AI 输出语言';
	@override String get langSystem => '跟随系统';
	@override String get window => '窗口与启动';
	@override String get rememberWindow => '记住窗口大小与位置';
	@override String get rememberWindowDesc => '下次启动恢复上次的窗口几何';
	@override String get launchAtLogin => '开机自启';
	@override String get launchAtLoginDesc => '登录系统后自动启动 Anselm';
	@override String get updates => '更新';
	@override String get updateCheck => '自动检查更新';
	@override String get updateCheckDesc => '启动时向 GitHub Releases 查询新版本,不自动安装';
	@override String get resetToDefault => '重置为默认';
	@override String get patchFailed => '保存失败,已恢复原值';
	@override String get notifLevel => '通知级别';
	@override String get notifLevelDesc => '决定哪些事件弹出提醒;需要你处理的事项永远送达';
	@override String get levelAll => '全部';
	@override String get levelImportant => '仅需处理';
	@override String get levelSilent => '静音';
	@override String get notifOs => '系统通知';
	@override String get notifOsDesc => '窗口未聚焦时经系统通知中心送达';
	@override String get notifToast => '应用内提醒';
	@override String get notifToastDesc => '右上角浮出提醒;危险级错误不受此限';
	@override String get silentHint => '已静音,重要事项仍会进铃铛收件箱';
	@override String get autoStage => '右岛自动登台';
	@override String get autoStageDesc => '工具运行时右岛自动展示现场';
	@override String get stageNever => '从不';
	@override String get stageFirst => '每对话首次';
	@override String get stageAlways => '每次';
	@override String get sendKey => '发送键';
	@override String get sendKeyDesc => 'Shift+Enter 始终换行';
	@override String get sendEnter => 'Enter 发送';
	@override String get sendCmdEnter => '⌘Enter 发送';
	@override String get webFetch => '网页抓取模式';
	@override String get webFetchDesc => '本地抓取更私密;Jina 代理更能读动态页面';
	@override String get webLocal => '本地抓取';
	@override String get webJina => 'Jina 代理';
	@override String get defaultModelLink => '默认对话模型 → 模型与密钥';
	@override String get langEn => 'English';
	@override String get langZh => '简体中文';
	@override late final _Translations$settings$keys$zh_CN keys = _Translations$settings$keys$zh_CN._(_root);
	@override late final _Translations$settings$ws$zh_CN ws = _Translations$settings$ws$zh_CN._(_root);
	@override late final _Translations$settings$about$zh_CN about = _Translations$settings$about$zh_CN._(_root);
	@override late final _Translations$settings$mem$zh_CN mem = _Translations$settings$mem$zh_CN._(_root);
	@override late final _Translations$settings$mcp$zh_CN mcp = _Translations$settings$mcp$zh_CN._(_root);
	@override late final _Translations$settings$storage$zh_CN storage = _Translations$settings$storage$zh_CN._(_root);
	@override late final _Translations$settings$limits$zh_CN limits = _Translations$settings$limits$zh_CN._(_root);
	@override late final _Translations$settings$network$zh_CN network = _Translations$settings$network$zh_CN._(_root);
	@override late final _Translations$settings$sandbox$zh_CN sandbox = _Translations$settings$sandbox$zh_CN._(_root);
	@override late final _Translations$settings$shortcuts$zh_CN shortcuts = _Translations$settings$shortcuts$zh_CN._(_root);
}

// Path: markdown
class _Translations$markdown$zh_CN extends Translations$markdown$en {
	_Translations$markdown$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get imageNotLoaded => '图片未加载';
}

// Path: attach
class _Translations$attach$zh_CN extends Translations$attach$en {
	_Translations$attach$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get unavailable => '已不可用';
	@override String get retry => '点按重试';
	@override String get tapToLoad => '点按加载';
	@override String get uploading => 'Uploading…';
	@override String get failedRetry => 'Failed — tap to retry';
	@override String get failedUnreadable => '无法读取文件';
	@override String get remove => 'Remove';
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

// Path: chat.toc
class _Translations$chat$toc$zh_CN extends Translations$chat$toc$en {
	_Translations$chat$toc$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get button => '场次目录';
	@override String get gates => '待你决定';
	@override String toolCluster({required Object n}) => '${n} 项操作';
	@override String get compaction => '上下文已压缩';
	@override String get abnormal => '异常终止';
	@override String get empty => '还没有可跳转的场次';
}

// Path: chat.tool
class _Translations$chat$tool$zh_CN extends Translations$chat$tool$en {
	_Translations$chat$tool$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get calling => '正在调用';
	@override String get called => '已调用';
	@override String get awaitingConfirm => '等待确认';
	@override String get denied => '已拒绝执行';
	@override String get cancelled => '已中断';
	@override String elapsed({required Object s}) => '${s} 秒';
	@override String get intent => '意图';
	@override String get argsLabel => '参数';
	@override String get progressLabel => '进度';
	@override String get resultLabel => '结果';
	@override String get errorLabel => '错误';
	@override String get liveLabel => '实时';
	@override String truncatedNote({required Object chars}) => '已截断 · 完整内容 ${chars} 字符';
	@override String progressOmitted({required Object n}) => '…前 ${n} 行略';
	@override String get reading => '正在读取';
	@override String get read => '已读取';
	@override String get writing => '正在写入';
	@override String get wrote => '已写入';
	@override String get editing => '正在编辑';
	@override String get edited => '已编辑';
	@override String get globbing => '正在检索';
	@override String get globbed => '已检索';
	@override String get grepping => '正在搜索';
	@override String get grepped => '已搜索';
	@override String get listing => '正在列出';
	@override String get listed => '已列出';
	@override String get runningCmd => '正在执行命令';
	@override String get ranCmd => '已执行';
	@override String lines({required Object n}) => '${n} 行';
	@override String matches({required Object n}) => '${n} 处匹配';
	@override String files({required Object n}) => '${n} 个文件';
	@override String items({required Object n}) => '${n} 项';
	@override String get noMatches => '无匹配';
	@override String exit({required Object code}) => 'exit ${code}';
	@override String get timedOut => '超时';
	@override String creatingKind({required Object kind}) => '正在创建${kind}';
	@override String createdKind({required Object kind}) => '已创建${kind}';
	@override String updatingKind({required Object kind}) => '正在修改${kind}';
	@override String updatedKind({required Object kind}) => '已更新${kind}';
	@override String get envReady => 'env 就绪';
	@override String get envBuilding => 'env 构建中';
	@override String get envFailed => 'env 失败';
	@override String get restarted => '已重启';
	@override late final _Translations$chat$tool$kind$zh_CN kind = _Translations$chat$tool$kind$zh_CN._(_root);
	@override String get asking => '正在提问';
	@override String get answered => '已回答';
	@override String get skipped => '已跳过';
	@override String get emptyAnswer => '空答案';
	@override String get awaitingAnswer => '等待你回答';
	@override String get deciding => '正在裁决';
	@override String get approved => '已批准';
	@override String get rejected => '已否决';
	@override String get decided => '已裁决';
	@override String get approveVerdict => '批准';
	@override String get rejectVerdict => '否决';
	@override String get notParked => '该节点当前不在等待审批(可能已被决议、已超时或节点标识有误),本次裁决未生效。';
	@override String nodesShown({required Object shown, required Object total}) => '显示 ${shown}/${total} 个节点,全量见 flowrun';
	@override String get clearing => '正在清点审批收件箱';
	@override String get cleared => '已清点';
	@override String inboxCount({required Object n}) => '${n} 件待审';
	@override String get inboxEmpty => '无待审';
	@override String inboxMore({required Object n}) => '另有 ${n} 件';
	@override String get inboxRef => '审批';
	@override String get inboxSummary => '摘要';
	@override String get inboxWait => '等待';
	@override String get inboxRun => 'run';
	@override String get inboxEmptyState => '收件箱空——没有 run 在等审批';
	@override String get runtimeRunning => '运行中';
	@override String get runtimeStopped => '实例未运行';
	@override String get runtimeCrashed => '实例已崩溃';
	@override String envFixAttempt({required Object n}) => '尝试 ${n}';
	@override String get envFixTitle => '环境自愈';
	@override String get wfInactive => '未激活';
	@override String wfGraphCounts({required Object nodes, required Object edges}) => '节点 ${nodes} · 边 ${edges}';
	@override String get wfNodeUnit => '节点';
	@override String get wfEdgeUnit => '边';
	@override String get wfDeltaEmpty => '仅改元数据(图未变)';
	@override String get wfMorphNote => '增量变换(图整体见实体面板)';
	@override String get ctlOtherwise => '否则';
	@override String get ctlWhenTrue => '兜底';
	@override String get apfTimeoutNever => '永不超时';
	@override String get apfAllowReason => '可填备注';
	@override String get apfApprove => '批准';
	@override String get apfReject => '拒绝';
	@override String get apfPreviewHint => '审批人将看到';
	@override String get apfOnTimeout => '超时 →';
	@override String get memorizing => '正在记忆';
	@override String get memorized => '已记忆';
	@override String get recalling => '正在回忆';
	@override String get recalled => '已回忆';
	@override String get forgetting => '正在遗忘';
	@override String get forgot => '已遗忘';
	@override String get fetchingWeb => '正在抓取';
	@override String get fetchedWeb => '已抓取';
	@override String get searchingWeb => '正在搜索';
	@override String get searchedWeb => '已搜索';
	@override String get searchingTools => '正在检索工具';
	@override String get searchedTools => '已检索工具';
	@override String get memNotSaved => '未保存';
	@override String get memNotFound => '未找到';
	@override String get memAlreadyGone => '本就不存在';
	@override String get irreversible => '不可逆';
	@override String webHits({required Object n}) => '${n} 条';
	@override String webHitsPlus({required Object n}) => '${n}+ 条';
	@override String get webEmpty => '无结果';
	@override String get webEmptyBody => '没有找到结果';
	@override String get webNoBackend => '未配置搜索';
	@override String get webMisconfig => '搜索 key 配置有误';
	@override String get webProviderFail => '搜索失败';
	@override String fetchChars({required Object n}) => '${n} 字';
	@override String get fetchEmpty => '空页面';
	@override String get fetchRawFallback => '摘要不可用 · 附原文';
	@override String get fetchJsShell => 'JS 页面';
	@override String get fetchFailed => '抓取失败';
	@override String get fetchRefused => '已拒绝';
	@override String get fetchAsk => '问:';
	@override String toolsFound({required Object n}) => '${n} 工具';
	@override String get toolsNoMatch => '无匹配';
	@override String get toolSchema => '参数 schema';
	@override String get proseExpand => '展开全文';
	@override String get proseCollapse => '收起';
	@override String grepFilter({required Object p}) => '过滤 /${p}/';
	@override String get docAutoRenamed => '请求名被占,已自动改名';
	@override String get skillNoRevert => '整份覆盖 · 无版本可回退';
	@override String get skillPreauth => '激活后免危险确认(预授权)';
	@override String get skillInline => '内联';
	@override String get skillFork => '派生';
	@override String get docSoftFail => '未生效';
	@override String get trgNotListening => '未监听';
	@override String get trgHotUpdate => '热更新已生效';
	@override String get trgCreateNote => '创建不启动监听——active workflow 引用才开始听';
	@override String get trgSecret => '密钥';
	@override String trgEvery({required Object n}) => '每 ${n} 秒';
	@override String get trgCondition => '条件';
	@override String get trgOutput => '输出';
	@override String searchingKind({required Object kind}) => '正在搜索${kind}';
	@override String searchedKind({required Object kind}) => '已搜索${kind}';
	@override String listingKind({required Object kind}) => '正在列${kind}';
	@override String listedKind({required Object kind}) => '已列${kind}';
	@override String hits({required Object n}) => '${n} 个';
	@override String hitsOfTotal({required Object n, required Object total}) => '${n}·共${total}';
	@override String get emptyList => '空';
	@override String get hitCurrent => '当前';
	@override String cappedFooter({required Object n, required Object total}) => '前 ${n} · 共 ${total}';
	@override String serverTruncatedNote({required Object n, required Object total}) => '前 ${n} · 共 ${total}(服务端截断)';
	@override String get wfActive => '活跃';
	@override String refCount({required Object n}) => '${n} 处引用';
	@override String get trgListening => '监听中';
	@override String get rawResult => '原始返回';
	@override String get contentTruncated => '内容超长已截断——在实体面板看全文';
	@override String get noActiveVersion => '无活跃版本';
	@override String get kvDescription => '描述';
	@override String get kvPath => '路径';
	@override String get kvSignature => '签名';
	@override String get kvDeps => '依赖';
	@override String get kvUpdated => '更新';
	@override String get kvMethods => '方法';
	@override String get kvModel => '模型';
	@override String get kvConcurrency => '并发';
	@override String get kvGraph => '图';
	@override String get kvContext => '上下文';
	@override String get kvSource => '来源';
	@override String get apfTimeout => '超时';
	@override String get apfBehavior => '超时行为';
	@override String get envFailedShort => 'env failed';
	@override String get envPending => 'env pending';
	@override String get skillPreauthNote => 'allowedTools 激活后本次运行预授权免危险确认';
	@override String viewingKind({required Object kind}) => '正在查看${kind}';
	@override String viewedKind({required Object kind}) => '已查看${kind}';
	@override String get kvTags => '标签';
	@override String get attachTruncated => '已截断';
	@override String get readingDoc => '正在阅读文档';
	@override String get readDoc => '已阅读文档';
	@override String get readingAtt => '正在读取附件';
	@override String get readAtt => '已读取附件';
	@override String revertingKind({required Object kind}) => '正在回退${kind}';
	@override String revertedKind({required Object kind}) => '已回退${kind}';
	@override String deletingKind({required Object kind}) => '正在删除${kind}';
	@override String deletedKind2({required Object kind}) => '已删除${kind}';
	@override String get staging => '正在设为待命';
	@override String get staged => '已待命';
	@override String get activatingWf => '正在上线';
	@override String get activatedWf => '已上线';
	@override String get deactivatingWf => '正在下线';
	@override String get deactivatedWf => '已停监听';
	@override String get killingWf => '正在急停';
	@override String get killedWf => '已急停';
	@override String get restarting => '正在重启';
	@override String get restartFailed => '重启后未运行';
	@override String get activatingSkill => '正在激活技能';
	@override String get activatedSkill => '已激活技能';
	@override String get movingDoc => '正在移动文档';
	@override String get movedDoc => '已移动文档';
	@override String get updatingMeta => '正在更新信息';
	@override String get updatedMeta => '已更新信息';
	@override String get renaming => '正在改名';
	@override String get renamed => '已改名';
	@override String get configuring => '正在配置';
	@override String get configured => '已配置';
	@override String rewind({required Object v}) => '↩ v${v}';
	@override String get deletedShort => '已删除';
	@override String depsAffected({required Object n}) => '${n} 处引用受影响';
	@override String docDescendants({required Object n}) => '已删除 · 含 ${n} 个后代';
	@override String movedTo({required Object path}) => '→ ${path}';
	@override String killedN({required Object n}) => '杀停 ${n} 个在途运行';
	@override String get noInflight => '无在途运行';
	@override String nKeys({required Object n}) => '${n} 键';
	@override String get staged2 => '候下一发真实触发';
	@override String get listening2 => '监听中';
	@override String get offline => '已下线';
	@override String get draining => '排空中';
	@override String moreHits({required Object n}) => '另有 ${n}';
	@override String get noteRevertFn => '仅还原代码/输入输出/依赖;名称·描述·标签不随版本';
	@override String get noteRevertHd => '已触发重启以运行新版本;内存态已清空——运行状态见 handler 面板';
	@override String get noteRestart => '内存态已清空';
	@override String get noteKill => '监听已停;被杀 run 状态=cancelled,可在 flowruns 里查';
	@override String get noteStage => '真实触发到来跑一次后自动解除';
	@override String get noteDeleteDocSoft => '软删除,可恢复';
	@override String get noteConfig => '已触发重启以生效;运行状态见 handler 面板';
	@override String get noteMetaHandler => '无新版本、无重启、内存态保全';
	@override String get kvName => '名称';
	@override String get noteDraining => '在途运行跑完即停;要立即中止用 kill_workflow';
	@override String get cvArchiving => '正在归档对话';
	@override String get cvArchived => '已归档对话';
	@override String get cvUnarchiving => '正在取消归档';
	@override String get cvUnarchived => '已取消归档';
	@override String get cvPinning => '正在置顶对话';
	@override String get cvPinned => '已置顶对话';
	@override String get cvUnpinning => '正在取消置顶';
	@override String get cvUnpinned => '已取消置顶';
	@override String get cvRenaming => '正在重命名对话';
	@override String get cvRenamed => '已重命名对话';
	@override String get cvManaging => '正在整理对话';
	@override String get cvManaged => '已整理对话';
	@override String get cvListing => '正在列出对话';
	@override String get cvListed => '已列出对话';
	@override String get cvSearching => '正在搜索对话';
	@override String get cvSearched => '已搜索对话';
	@override String cvCount({required Object n}) => '${n} 条';
	@override String cvCountMore({required Object n}) => '${n}+ 条';
	@override String get cvEmpty => '无对话';
	@override String cvHits({required Object n}) => '${n} 命中';
	@override String get cvNoMatch => '无匹配';
	@override String get cvMorePages => '还有更多页';
	@override String get cvArchivedBadge => '已归档';
	@override String cvChunks({required Object n}) => '×${n}';
	@override String cvShownOfTotal({required Object n, required Object total}) => '显示前 ${n} 条 · 共 ${total} 命中';
	@override String get cvStatusArchived => '归档';
	@override String get cvStatusPinned => '置顶';
	@override String get cvStatusTitle => '标题';
	@override String get cvAutoUnarchive => '再发消息会自动取消归档';
	@override String get bashBlocked => '已拦截';
	@override String get bashCancelled => '已取消';
	@override String get bashExitUnknown => 'exit 未知';
	@override String bashBackground({required Object id}) => '${id} · 后台';
	@override String get statusRunning => '运行中';
	@override String statusExited({required Object code}) => '退出 ${code}';
	@override String get statusKilled => '已终止';
	@override String get statusErrored => '出错';
	@override String get statusNotFound => '会话不存在';
	@override String get killFinished => '已自行结束';
	@override String get killNotFound => '会话不存在';
	@override String get polling => '正在读取输出';
	@override String get polled => '已读取输出';
	@override String get killing => '正在终止';
	@override String get killed3 => '已终止';
	@override String get backToLatest => '回到最新';
	@override String showEarlier({required Object n}) => '显示更早 ${n} 行';
	@override String get bashBgHint => '用 BashOutput 轮询新输出,或 KillShell 终止';
	@override String get bashHeadTruncated => '输出过长,已弃头保尾';
	@override String get bashNoOutput => '(无输出)';
	@override String get ranBg => '已转入后台';
	@override String get bashSessionGoneHint => '可能已被终止 / 已清理 / 后端已重启';
	@override String get bashNoNew => '(无新输出)';
	@override String bashDropped({required Object n}) => '丢弃 ${n} 字节(环缓冲溢出)';
	@override String get fsNotFound => '未找到';
	@override String get fsDenied => '无权限';
	@override String get fsReadFirst => '需先读';
	@override String get fsNoMatch => '未匹配';
	@override String fsAmbiguous({required Object n}) => '${n} 处歧义';
	@override String get fsModified => '文件已变';
	@override String get fsParentMissing => '父目录缺';
	@override String get fsBadPath => '路径无效';
	@override String get fsFailed => '出错';
	@override String readRange({required Object f, required Object l}) => '行 ${f}–${l}';
	@override String readFloor({required Object n}) => '${n}+ 行';
	@override String readRangeFloor({required Object f, required Object n}) => '行 ${f}–${n}+';
	@override String edited2({required Object n}) => '${n} 处替换';
	@override String get fsUnconfirmed => '结果未确认';
	@override String get emptyFile => '空文件';
	@override String replaceAllNote({required Object n}) => '${n} 处全部替换';
	@override String get mcpCalling => '正在调用 MCP 工具';
	@override String get mcpCalled => '已调用 MCP 工具';
	@override String get mcpError => 'MCP 错误';
	@override String get hdCalling => '正在调用方法';
	@override String get hdCalled => '已调用方法';
	@override String get hdResult => '返回';
	@override String get lsEmpty => '空目录';
	@override String globHeader({required Object pattern, required Object root}) => '${pattern} 于 ${root}';
	@override String get noReturn => '无返回值';
	@override String get execOk => '运行成功';
	@override String get execFailed => '运行失败';
	@override String execLogs({required Object n}) => '日志 · ${n} 行';
	@override String get runningFn => '正在运行函数';
	@override String get ranFn => '已运行函数';
	@override String get callingMethod => '正在调用方法';
	@override String get calledMethod => '已调用方法';
	@override String get firingTrigger => '正在触发';
	@override String get firedTrigger => '已触发';
	@override String get fireActivation => '活化';
	@override String get firePayloadNote => 'payload 恒为 {manual:true};扇出与处置见触发日志';
	@override String get replayingRun => '正在重放运行';
	@override String get replayedRun => '已重放运行';
	@override String get triggeringWf => '正在触发工作流';
	@override String get triggeredWf => '已触发工作流';
	@override String get invokingAgent => '正在调用智能体';
	@override String get invokedAgent => '已调用智能体';
	@override String agentSteps({required Object n}) => '${n} 步';
	@override String get agentTrajectoryNote => '轨迹已流经,重载后于执行档案回放';
	@override String get searchingFnExec => '正在翻查函数执行';
	@override String get searchedFnExec => '已翻查函数执行';
	@override String get searchingHdCalls => '正在翻查处理器调用';
	@override String get searchedHdCalls => '已翻查处理器调用';
	@override String get searchingAgentExec => '正在翻查智能体执行';
	@override String get searchedAgentExec => '已翻查智能体执行';
	@override String get searchingMcpCalls => '正在翻查 MCP 调用';
	@override String get searchedMcpCalls => '已翻查 MCP 调用';
	@override String aggRollup({required Object ok, required Object failed}) => '${ok} ✓ · ${failed} ✗';
	@override String get aggNote => '✗ 含取消/超时';
	@override String get logNoRecords => '无记录';
	@override String get logNoMatch => '无匹配';
	@override String get byChat => '对话';
	@override String get byAgent => '智能体';
	@override String get byWorkflow => '工作流';
	@override String get byManual => '手动';
	@override String get searchingFlowruns => '正在翻查运行';
	@override String get searchedFlowruns => '已翻查运行';
	@override String get searchingFirings => '正在翻查派发';
	@override String get searchedFirings => '已翻查派发';
	@override String get searchingActivations => '正在翻查活动';
	@override String get searchedActivations => '已翻查活动';
	@override String get firingPending => '等待';
	@override String get firingStarted => '已建 run';
	@override String get firingSkipped => '跳过';
	@override String get firingSuperseded => '被顶替';
	@override String get firingShed => '丢弃';
	@override String logCount({required Object n}) => '${n} 条';
	@override String logCountMore({required Object n}) => '${n}+ 条';
	@override String get parkRunCaption => 'park 在审批节点的 run,头仍为 running';
	@override String get actReturnValue => '返回值';
	@override String actFanout({required Object n}) => '扇出 ${n}';
	@override String get gettingFnExec => '正在调阅函数执行档案';
	@override String get gotFnExec => '已调阅函数执行档案';
	@override String get gettingHdCall => '正在调阅处理器调用档案';
	@override String get gotHdCall => '已调阅处理器调用档案';
	@override String get gettingMcpCall => '正在调阅 MCP 调用档案';
	@override String get gotMcpCall => '已调阅 MCP 调用档案';
	@override String get gettingActivation => '正在调阅活动档案';
	@override String get gotActivation => '已调阅活动档案';
	@override String get dossierStderr => 'server stderr(可能早于本次调用)';
	@override String logOmitted({required Object n}) => '…省略 ${n} 字符…';
	@override String get fireYes => '已 fire';
	@override String get fireNo => '未 fire';
	@override String get gettingFlowrun => '正在调阅运行';
	@override String get gotFlowrun => '已调阅运行';
	@override String get gettingAgentExec => '正在调阅智能体执行';
	@override String get gotAgentExec => '已调阅智能体执行';
	@override String transcriptSteps({required Object n}) => '轨迹 · ${n} 步';
	@override String get transcriptOpenFull => '查看完整轨迹';
	@override String get transcriptEmpty => '无轨迹记录';
	@override String transcriptCapped({required Object shown, required Object total}) => '显示 ${shown}/${total} 块';
	@override String get transcriptThought => '思考';
	@override String get transcriptReply => '回复';
	@override String get spawningSubagent => '正在派子代理';
	@override String get spawnedSubagent => '已派子代理';
	@override String get subagentTask => '任务';
	@override String get subagentAnswer => '回答';
	@override String get subagentTraceNote => '轨迹仅流不落盘——用 get_subagent_trace 回放';
	@override String get gettingSubTrace => '正在调阅子代理轨迹';
	@override String get gotSubTrace => '已调阅子代理轨迹';
	@override String subTraceRuns({required Object n}) => '${n} 个子代理运行';
	@override String get subTraceNoRuns => '本对话无子代理运行';
	@override String get todoWriting => '正在更新任务清单';
	@override String get todoWrote => '已更新任务清单';
	@override String get todoReading => '正在读取任务清单';
	@override String get todoRead => '已读取任务清单';
	@override String todoRollup({required Object total, required Object done}) => '${total} 项 · ${done} 完成';
	@override String get todoCleared => '清单已清空';
	@override String get gettingRelations => '正在查关系';
	@override String get gotRelations => '已查关系';
	@override String relCount({required Object n}) => '${n} 条关系';
	@override String get relNoEdges => '无关系';
	@override String get relArrow => '→';
	@override String get checkingCapability => '正在体检工作流';
	@override String get checkedCapability => '已体检工作流';
	@override String get capRunnable => '结构可运行';
	@override String capProblems({required Object n}) => '${n} 问题';
	@override String capWarnings({required Object n}) => '${n} 警示';
	@override String get capProblemsLabel => '问题';
	@override String get capWarningsLabel => '警示';
	@override String get capResolved => '依赖已解析';
	@override String get capStructural => '结构有效';
	@override String get installingMcp => '正在安装 MCP 服务器';
	@override String get installedMcp => '已安装 MCP 服务器';
	@override String get uninstallingMcp => '正在卸载 MCP 服务器';
	@override String get uninstalledMcp => '已卸载 MCP 服务器';
	@override String get reconnectingMcp => '正在重连 MCP';
	@override String get reconnectedMcp => '已重连 MCP';
	@override String get mcpConnected => '已连接';
	@override String get mcpDisconnected => '未连接';
	@override String mcpToolCount({required Object n}) => '${n} 工具';
	@override String mcpFailures({required Object n}) => '${n} 次连续失败';
	@override String get browsingMarket => '正在浏览市场';
	@override String get browsedMarket => '已浏览市场';
	@override String marketCount({required Object n}) => '${n} 个服务器';
	@override String mcpEnvRequired({required Object n}) => '${n} 必填 env';
	@override String get gettingModelConfig => '正在读模型配置';
	@override String get gotModelConfig => '已读模型配置';
	@override String get modelDefaults => '默认模型';
	@override String modelKeys({required Object n}) => '${n} 个密钥';
	@override String modelAvail({required Object n}) => '${n} 个可用模型';
	@override String get memSourceUser => '你';
	@override String get memSourceAi => 'AI';
	@override String get firingClaimed => '已认领';
}

// Path: chat.gate
class _Translations$chat$gate$zh_CN extends Translations$chat$gate$en {
	_Translations$chat$gate$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get dangerBadge => '危险';
	@override String get awaitingDanger => '等待你确认';
	@override String get awaitingAsk => '等待你回答';
	@override String get approve => '允许';
	@override String get approveAlways => '总是允许';
	@override String approveAlwaysHint({required Object tool}) => '本对话内不再询问 ${tool}(重启即忘)';
	@override String get deny => '拒绝';
	@override String get decline => '不回答';
	@override String get submit => '发送';
	@override String get answerPlaceholder => '输入你的回答…';
	@override String get decidedApproved => '已允许';
	@override String get decidedApprovedAlways => '已允许 · 本对话总是';
	@override String get decidedDenied => '已拒绝';
	@override String get decidedDeclined => '已跳过';
}

// Path: chat.stage
class _Translations$chat$stage$zh_CN extends Translations$chat$stage$en {
	_Translations$chat$stage$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '侧幕';
	@override String get island => '活动';
	@override String get tasks => '待办';
	@override String get expandAll => '展开全部';
	@override String get collapseAll => '收起全部';
	@override String glanceTouched({required Object n}) => '${n} 触点';
	@override String glanceExecuted({required Object n}) => '${n} 执行';
	@override String glanceNeedsYou({required Object n}) => '${n} 待你处理';
	@override String get groupJustNow => '刚刚';
	@override String get groupEarlierToday => '早些时候';
	@override String get groupEarlier => '更早';
	@override String get following => '跟随';
	@override String get pinned => '已锁定';
	@override String get live => '进行中';
	@override String get settled => '已落定';
	@override String get failed => '未保存';
	@override String get backToLive => '回到直播';
	@override late final _Translations$chat$stage$run$zh_CN run = _Translations$chat$stage$run$zh_CN._(_root);
	@override late final _Translations$chat$stage$a11y$zh_CN a11y = _Translations$chat$stage$a11y$zh_CN._(_root);
	@override late final _Translations$chat$stage$follow$zh_CN follow = _Translations$chat$stage$follow$zh_CN._(_root);
	@override String get castEmpty => '这场对话还没碰过什么';
	@override String get castEmptyHint => 'AI 创建、编辑或执行的东西会记在这里';
	@override String get beforeEdit => '改之前';
	@override String get proseUntouched => '本次未改动正文';
	@override String prefixKept({required Object n}) => '前 ${n} 字与旧版一致 · 已快进';
	@override String get fastForwarding => '与旧版一致 · 快进中…';
	@override String wholeReplace({required Object from, required Object to}) => '全量替换 · ${from} → ${to}';
	@override String get latestDiscriminant => '最新判别式';
	@override String basedOn({required Object n}) => '基于 v${n} 起改';
	@override String get elseFallback => '否则';
	@override String get passThrough => '透传';
	@override String get previewUnsent => '预览 · 尚未寄出';
	@override String get neverTimeout => '永不超时';
	@override String timeoutReject({required Object d}) => '${d} 后自动拒绝';
	@override String timeoutApprove({required Object d}) => '${d} 后自动通过';
	@override String timeoutFail({required Object d}) => '${d} 后置失败';
	@override String get allowReason => '审批者可附理由';
	@override String get listening => '监听中';
	@override String get notListening => '未监听';
	@override String nextFire({required Object t}) => '下次点火 · ${t}';
	@override String refCountWord({required Object n}) => '被 ${n} 条 workflow 引用';
	@override String get awaitingReceipt => '等待回执…';
	@override String get oldLadder => '改之前的梯';
	@override String get subagentUnnamed => '子代理';
	@override String get delegated => '委派';
	@override String get skillArgs => '参数';
	@override String get skillTools => '工具';
	@override String tokensInOut({required Object tin, required Object tout}) => '${tin} 入 · ${tout} 出';
	@override String stopReasonWord({required Object r}) => '止因 ${r}';
	@override String get ensembleTitle => '并行群像';
	@override String boardOf({required Object name}) => '${name} 的清单';
	@override String get humanOnly => '仅人可唤';
	@override String get toolsDiscovered => '个工具已发现';
	@override String get cfgReady => '配置就绪';
	@override String get cfgPending => '配置待建';
	@override String get rtRunning => '运行中';
	@override String get rtCrashed => '已崩溃';
	@override String get rtStopped => '已停止';
}

// Path: scheduler.overview
class _Translations$scheduler$overview$zh_CN extends Translations$scheduler$overview$en {
	_Translations$scheduler$overview$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get kpiRunning => '在跑';
	@override String kpiRunningA11y({required Object n}) => '在跑 ${n} 个。在「正在跑」列表中显示它们。';
	@override String get kpiWaiting => '等你';
	@override String kpiWaitingA11y({required Object n}) => '等你处理 ${n} 条。在「等你处理」列表中显示它们。';
	@override String get kpiFailed24h => '24h 失败';
	@override String kpiFailed24hA11y({required Object n}) => '近 24h 失败 ${n} 次。在失败 run 列表中显示它们。';
	@override String get kpiNextFire => '下次调度';
	@override String kpiNextFireA11y({required Object d}) => '下次调度在 ${d} 后。在调度轨上显示它。';
	@override String get kpiNone => '—';
	@override String fireIn({required Object d}) => '${d} 后';
	@override String deltaUp({required Object n}) => '▲${n}';
	@override String deltaDown({required Object n}) => '▼${n}';
	@override String deltaUpA11y({required Object n}) => '较前一个 24h 多 ${n}';
	@override String deltaDownA11y({required Object n}) => '较前一个 24h 少 ${n}';
	@override String get runningHead => '正在跑';
	@override String get runningEmpty => '现在没有正在运行的 run。';
	@override String get failuresSegmentHead => '失败';
	@override String get failed24hHead => '近 24 小时';
	@override String get trackTruncated => '此窗口内还有更多调度,轨道未能全部显示。';
	@override String get failuresHead => '连续失败 · 7d';
	@override String get failuresEmpty => '近 7 天没有连续失败的 workflow。';
	@override String streak({required Object n}) => '连败 ×${n}';
	@override String get openWorkflow => '打开 workflow →';
	@override String get waitingHead => '等你处理';
	@override String get waitingEmpty => '没有等你处理的审批。';
	@override String waitedFor({required Object d}) => '等 ${d}';
	@override String selectRow({required Object name}) => '选择 ${name}';
	@override String get alreadyHandled => '已被别处处理';
	@override String get alreadyFinished => 'run 已自行结束';
	@override String get cancelConfirmTitle => '取消这个 run?';
	@override String cancelConfirmBody({required Object name, required Object id}) => '将取消 ${name} · ${id};parked 审批一并收回。';
	@override String get cancelConfirmAction => '取消 run';
	@override String get cancelKeep => '先不取消';
	@override String cancelRunA11y({required Object id}) => '取消 run ${id}';
	@override String get batchApprove => '批量批准';
	@override String get batchReject => '批量拒绝';
	@override String get batchCancel => '批量取消';
	@override String batchRejectConfirm({required Object n}) => '拒绝 ${n} 条';
	@override String batchCancelTitle({required Object n}) => '将取消这 ${n} 个 run?';
	@override String batchCancelBody({required Object list}) => '以下 run 将被取消;parked 审批一并收回:\n${list}';
	@override String sumApproved({required Object n}) => '已批准 ${n}';
	@override String sumRejected({required Object n}) => '已拒绝 ${n}';
	@override String sumCancelled({required Object n}) => '已取消 ${n}';
	@override String sumLost({required Object n}) => '${n} 条已被别处处理';
	@override String sumEnded({required Object n}) => '${n} 条已自行结束';
	@override String sumFailed({required Object n}) => '${n} 条失败';
	@override String get firstUseTitle => '第一个自动化还没建';
	@override String get firstUseBody => '去 Entities 建一个 workflow 并挂上 cron;或者直接在对话里说「每天早上八点抓数据发我」。';
	@override String get firstUseEntities => '去 Entities';
	@override String get firstUseChat => '打开对话';
	@override String get errorTitle => '总览加载失败';
	@override String get errorHint => '后端没有应答,检查连接后重试。';
	@override String get scheduleHead => '调度';
	@override String get scheduleEmpty => '没有装备任何 cron 排程。';
	@override String get kpiMissed => '24h 错过';
	@override String kpiMissedA11y({required Object n}) => '24h 错过 ${n} 次。在时间轴上看它们。';
	@override String trackPastTruncated({required Object at}) => '早于 ${at} 的触发未显示——账目不止一页。';
	@override String trackNextIn({required Object d}) => '(${d} 后)';
	@override String trackCardHead({required Object at, required Object n}) => '${at} · 共 ${n} 次';
	@override String trackCardMissed({required Object at}) => '错过 ${at}';
	@override String trackCardMore({required Object n}) => '还有 ${n} 次';
	@override String get trackCardMoreOk => '全部成功';
	@override String trackCardMoreFailed({required Object m}) => '含 ${m} 次失败';
	@override String trackCardNext({required Object at, required Object schedule}) => '下一发 ${at} · ${schedule}';
	@override String trackCardNextBare({required Object at}) => '下一发 ${at}';
	@override String trackBinA11y({required Object hour, required Object n, required Object ok, required Object fail}) => '${hour} 时,${n} 次:${ok} 成 ${fail} 败';
	@override String trackBinMissedClause({required Object x}) => ',含 ${x} 次错过';
	@override String trackBinEmptyA11y({required Object hour}) => '${hour} 时,无运行';
	@override String trackFutureA11y({required Object at, required Object schedule}) => '下一发 ${at},${schedule}';
	@override String trackLaneSummaryA11y({required Object name, required Object n, required Object ok, required Object fail, required Object missed, required Object next}) => '${name},24 小时 ${n} 次运行:${ok} 成 ${fail} 败,错过 ${missed} 次;下一次 ${next}';
}

// Path: scheduler.status
class _Translations$scheduler$status$zh_CN extends Translations$scheduler$status$en {
	_Translations$scheduler$status$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get active => '生效';
	@override String get draining => '收尾中';
	@override String get inactive => '停用';
}

// Path: scheduler.home
class _Translations$scheduler$home$zh_CN extends Translations$scheduler$home$en {
	_Translations$scheduler$home$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get notFoundTitle => '找不到该 workflow';
	@override String get notFoundHint => '它可能已被删除。从左侧选择另一个 workflow。';
	@override String get moreA11y => '更多操作';
	@override String get runNow => '立即运行';
	@override String runNowStarted({required Object id}) => '已开跑 · ${id}';
	@override String get menuEdit => '去 Entities 编辑';
	@override String get menuKill => '终止 workflow…';
	@override String get killTitle => '终止这个 workflow';
	@override String killWarning({required Object n}) => '将取消 ${n} 个在途 run。';
	@override String get killBody => '停止监听、取消所有在途 run,并停用该 workflow。';
	@override String killHint({required Object name}) => '输入 ${name} 以确认';
	@override String get killConfirm => '终止 workflow';
	@override String get killed => 'workflow 已终止';
	@override String statsLine({required Object rate, required Object avg}) => '成功率 ${rate} · 均时 ${avg}';
	@override String get runsHead => '运行';
	@override String get runsError => '运行记录加载失败。';
	@override String get runsEmpty => '没有匹配此过滤的运行。';
	@override String get pagerPrev => '上一页';
	@override String get pagerNext => '下一页';
	@override String get pagerJump => '页码';
	@override String pagerPage({required Object n}) => '第 ${n} 页';
	@override String pagerJumpTo({required Object n}) => '跳转到第 ${n} 页';
	@override String get filterA11y => '按状态过滤运行';
	@override String get filterAll => '全部';
	@override String filterRunning({required Object n}) => '在跑 ${n}';
	@override String filterFailed({required Object n}) => '失败 ${n}';
	@override String filterWaiting({required Object n}) => '等人 ${n}';
	@override String get originAll => '全部来源';
	@override String get originManual => '手动';
	@override String get originChat => '对话';
	@override String get originCron => 'cron';
	@override String get originWebhook => 'webhook';
	@override String get originFsnotify => '文件监听';
	@override String get originSensor => '传感器';
	@override String newRuns({required Object n}) => '${n} 条新运行';
	@override String get srcManual => '手动';
	@override String get srcChat => '对话';
	@override String get srcCronBare => 'cron';
	@override String get srcWebhookBare => 'webhook';
	@override String srcWithName({required Object kind, required Object name}) => '${kind} · ${name}';
	@override String get srcUnknown => '未知来源';
	@override String get replayTitle => '重放这个 run?';
	@override String replayBody({required Object failed, required Object completed}) => '重跑 ${failed} 个失败节点 · 复用 ${completed} 个已完成结果。';
	@override String get replayBodyUnknown => '重跑失败节点;已完成结果按记忆化复用。';
	@override String get replayAction => '重放';
	@override String get replayed => '重放已开始';
	@override String get notReplayable => '该 run 已不可重放';
	@override String get batchReplay => '批量重放';
	@override String batchReplayTitle({required Object n}) => '重放 ${n} 个 run?';
	@override String batchReplayBody({required Object failed, required Object completed}) => '共重跑 ${failed} 个失败节点 · 复用 ${completed} 个已完成结果。';
	@override String sumReplayed({required Object n}) => '已重放 ${n}';
	@override String sumNotReplayable({required Object n}) => '${n} 个已不可重放';
	@override String get faceA11y => '速览卡视图';
	@override String get faceGantt => '甘特';
	@override String get faceGraph => '图';
	@override String get matrixTitle => '节点 × 运行';
	@override String get matrixView => '矩阵视图';
	@override String get matrixEmpty => '这段时间没有运行。';
	@override String get matrixNotReached => '未及';
	@override String get matrixRunning => '在跑';
	@override String matrixColA11y({required Object src, required Object status, required Object d}) => '运行 ${src},${status},${d}';
	@override String matrixRowA11y({required Object node}) => '节点 ${node},历史';
	@override String matrixCellA11y({required Object node, required Object status, required Object n}) => '${node},${status},${n} 轮';
	@override String get openRun => '打开 →';
	@override String get noGraph => '活跃版本没有图。';
	@override String get paneNoNodes => '还没有节点记录。';
	@override String get notRun => '未运行';
	@override String get paneError => '本次运行加载失败。';
	@override String get triggersHead => '触发器';
	@override String get triggersEmpty => '该 workflow 没有挂任何触发器。';
	@override String get paused => '已暂停';
	@override String get pause => '暂停';
	@override String get resume => '恢复';
	@override String pauseTitle({required Object name}) => '暂停「${name}」?';
	@override String get pauseBody => '暂停后不再产生新 firing;在途 run 不受影响。';
	@override String get pauseAction => '暂停';
	@override String nextFire({required Object d, required Object at}) => '下次 ${d} 后(${at})';
	@override String lastFired({required Object d}) => '上次 ${d} 前';
	@override String get neverFired => '从未触发';
	@override String editTriggerA11y({required Object name}) => '去 Entities 编辑触发器 ${name}';
	@override String matrixRowSummaryA11y({required Object node, required Object r, required Object total, required Object n, required Object failed}) => '${node},第 ${r} 行 共 ${total} 行,${n} 次运行抵达,${failed} 次失败';
	@override String matrixCoordA11y({required Object r, required Object rows, required Object c, required Object cols}) => '第 ${r} 行 共 ${rows} 行,第 ${c} 列 共 ${cols} 列';
	@override String get crumbRoot => '调度';
	@override String get rowCancel => '终止';
	@override String get rowRetry => '重试';
}

// Path: scheduler.run
class _Translations$scheduler$run$zh_CN extends Translations$scheduler$run$en {
	_Translations$scheduler$run$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get notFoundTitle => '找不到这次运行';
	@override String get notFoundHint => '它可能已被保留策略清理。从 workflow 里另选一次运行。';
	@override String get errorTitle => '这次运行加载失败';
	@override String get errorHint => '后端没有响应。检查连接后重试。';
	@override String get orphanBadge => '宿主已删除';
	@override String get pinnedVersion => '钉版';
	@override String get graphNotPinned => '取不到这次运行的钉版——下面这张图是 workflow 当前的图,可能与本次实际走过的不同。';
	@override String queuedFor({required Object d}) => '排队 ${d}';
	@override String execFor({required Object d}) => '执行 ${d}';
	@override String get queueWord => '排队';
	@override String get execWord => '执行';
	@override String get replay => '重放';
	@override String get cancel => '取消运行';
	@override String get triage => 'AI 诊断';
	@override String get triageFailed => '诊断对话没能打开';
	@override String get graphHead => '流转';
	@override String get graphHeadPinned => '流转(钉版)';
	@override String get graphEmpty => '取不到这次运行的拓扑——钉版读不出,workflow 也没有当前的图。';
	@override String get ganttHead => '甘特';
	@override String get ganttEmpty => '这次运行还没有可排上时间轴的节点。';
	@override String get ganttNoSpan => '所有节点落在同一毫秒内——条只表示顺序,不表示时长。';
	@override String get notRun => '未及';
	@override String get ledgerHead => '节点台账';
	@override String get ledgerEmpty => '还没有节点落定。';
	@override String get dossierTitle => '运行卷宗';
	@override String get kvStatus => '状态';
	@override String get inspectorTitle => '检查器';
	@override String glanceNextFire({required Object d}) => '下次点火 ${d} 后';
	@override String glanceSuccess({required Object pct}) => '近 7 天 ${pct}% 成功';
	@override String glanceStreak({required Object n}) => '连败 ${n}';
	@override String get payloadHead => '入口 payload';
	@override String get pinnedRefsHead => '钉住的引用';
	@override String get errorHead => '错误';
	@override String replayHistory({required Object n}) => '已重放 ×${n}';
	@override String get replayNever => '从未重放';
	@override String get iterationPick => '迭代';
	@override String get execLogHead => '执行日志';
	@override String execLogOpen({required Object id}) => '打开 ${id}';
	@override String get noSelection => '点一个节点来查看它。';
	@override String get nodeIn => '输入';
	@override String get nodeOut => '输出';
	@override String get nodeNoIo => '这个节点没有记录结果。';
	@override String get replayNode => '重放失败节点';
	@override String get relayResolving => '正在定位这次运行…';
	@override String get relayFailedTitle => '解析不出这次运行';
	@override String get relayFailedHint => '本工作区没有这个 id 的运行。检查 id,或从某个 workflow 里选一次运行。';
	@override String get closeA11y => '关闭本次运行页';
}

// Path: scheduler.range
class _Translations$scheduler$range$zh_CN extends Translations$scheduler$range$en {
	_Translations$scheduler$range$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get today => '今天';
	@override String get h24 => '近 24 小时';
	@override String get d7 => '近 7 天';
	@override String get d30 => '近 30 天';
	@override String get all => '全部';
	@override String get customTitle => '自定义范围';
	@override String get from => '从';
	@override String get to => '到';
	@override String get apply => '应用';
	@override String get endBeforeStart => '终点早于起点';
	@override String get weekdays => '一 二 三 四 五 六 日';
	@override String monthTitle({required Object y, required Object m}) => '${y} 年 ${m}';
	@override String get months => '1 月,2 月,3 月,4 月,5 月,6 月,7 月,8 月,9 月,10 月,11 月,12 月';
	@override String get prevMonth => '上个月';
	@override String get nextMonth => '下个月';
	@override String get backToPresets => '返回快捷范围';
	@override String get backToToday => '回到今天';
	@override String get preciseTime => '精确到时刻';
	@override String dayText({required Object m, required Object d}) => '${m} 月 ${d} 日';
	@override String dayTextYear({required Object y, required Object m, required Object d}) => '${y} 年 ${m} 月 ${d} 日';
	@override String get capsuleA11y => '时间范围';
	@override String get gridA11y => '日历';
}

// Path: feedback.batch
class _Translations$feedback$batch$zh_CN extends Translations$feedback$batch$en {
	_Translations$feedback$batch$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String selected({required Object n}) => '已选 ${n}';
	@override String get clear => '清除选择';
}

// Path: feedback.cast
class _Translations$feedback$cast$zh_CN extends Translations$feedback$cast$en {
	_Translations$feedback$cast$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get ribbonLive => '实时聆听中 · 落定以真相为准';
	@override String get ribbonGap => '实时流有缺口 · 以执行记录为准';
	@override String get ribbonFailed => '草稿未保存 · 真相仍是上一版';
	@override String get gatePill => 'AI 在等你决定 →';
	@override String livePill({required Object name}) => 'AI 正在编辑 ${name} →';
	@override String get tombstone => '已删除';
	@override String get goToEntity => '去实体页';
	@override String get jumpToScene => '跳到发生处';
	@override late final _Translations$feedback$cast$verb$zh_CN verb = _Translations$feedback$cast$verb$zh_CN._(_root);
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

// Path: notifications.kind
class _Translations$notifications$kind$zh_CN extends Translations$notifications$kind$en {
	_Translations$notifications$kind$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get memory => '记忆';
	@override String get sandbox => '环境';
	@override String get relation => '依赖';
}

// Path: notifications.verb
class _Translations$notifications$verb$zh_CN extends Translations$notifications$verb$en {
	_Translations$notifications$verb$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get created => '已创建';
	@override String get edited => '已编辑';
	@override String get reverted => '已回滚';
	@override String get updated => '已更新';
	@override String get deleted => '已删除';
	@override String get envRebuilt => '环境已重建';
	@override String get configUpdated => '配置已更新';
	@override String get configCleared => '配置已清空';
	@override String get installed => '已安装';
	@override String get removed => '已移除';
	@override String get reconnected => '已重连';
	@override String get reconnectFailed => '重连失败';
	@override String get crashed => '崩溃了';
	@override String get restartFailed => '重启失败';
	@override String get runFailed => '运行失败';
	@override String get needsAttention => '需要关注';
	@override String get recovered => '已恢复';
	@override String get waitingApproval => '等待审批';
	@override String get envReady => '环境就绪';
	@override String get envFailed => '环境构建失败';
}

// Path: graph.kind
class _Translations$graph$kind$zh_CN extends Translations$graph$kind$en {
	_Translations$graph$kind$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get trigger => '触发';
	@override String get action => '动作';
	@override String get agent => '智能体';
	@override String get control => '分支';
	@override String get approval => '审批';
	@override String get unknown => '未知';
}

// Path: entities.detail
class _Translations$entities$detail$zh_CN extends Translations$entities$detail$en {
	_Translations$entities$detail$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get crumbRoot => '实体';
	@override late final _Translations$entities$detail$tab$zh_CN tab = _Translations$entities$detail$tab$zh_CN._(_root);
	@override late final _Translations$entities$detail$verb$zh_CN verb = _Translations$entities$detail$verb$zh_CN._(_root);
	@override late final _Translations$entities$detail$hero$zh_CN hero = _Translations$entities$detail$hero$zh_CN._(_root);
	@override late final _Translations$entities$detail$gate$zh_CN gate = _Translations$entities$detail$gate$zh_CN._(_root);
	@override late final _Translations$entities$detail$codeToggle$zh_CN codeToggle = _Translations$entities$detail$codeToggle$zh_CN._(_root);
	@override late final _Translations$entities$detail$sec$zh_CN sec = _Translations$entities$detail$sec$zh_CN._(_root);
	@override late final _Translations$entities$detail$card$zh_CN card = _Translations$entities$detail$card$zh_CN._(_root);
	@override late final _Translations$entities$detail$graph$zh_CN graph = _Translations$entities$detail$graph$zh_CN._(_root);
	@override late final _Translations$entities$detail$cockpit$zh_CN cockpit = _Translations$entities$detail$cockpit$zh_CN._(_root);
	@override late final _Translations$entities$detail$kv$zh_CN kv = _Translations$entities$detail$kv$zh_CN._(_root);
	@override late final _Translations$entities$detail$val$zh_CN val = _Translations$entities$detail$val$zh_CN._(_root);
	@override late final _Translations$entities$detail$mounts$zh_CN mounts = _Translations$entities$detail$mounts$zh_CN._(_root);
	@override late final _Translations$entities$detail$trigger$zh_CN trigger = _Translations$entities$detail$trigger$zh_CN._(_root);
	@override String get addTag => '添加标签';
	@override late final _Translations$entities$detail$state$zh_CN state = _Translations$entities$detail$state$zh_CN._(_root);
	@override late final _Translations$entities$detail$editor$zh_CN editor = _Translations$entities$detail$editor$zh_CN._(_root);
}

// Path: entities.run
class _Translations$entities$run$zh_CN extends Translations$entities$run$en {
	_Translations$entities$run$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get method => '方法';
	@override String get streaming => '流式';
	@override String get example => '示例';
	@override String get payloadInvalid => '载荷必须是合法 JSON。';
	@override String get payloadObject => '载荷必须是 JSON 对象。';
	@override String get cancel => '取消';
	@override String get close => '关闭运行终端';
	@override String get cancelled => '已取消';
	@override String glanceToday({required Object n}) => '今天 ${n} 次执行';
	@override String get glanceLastOk => '上次成功';
	@override String get glanceLastFailed => '上次失败';
	@override String get glanceLastCancelled => '上次取消';
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
	@override String get errorHeading => '错误';
	@override late final _Translations$entities$run$danger$zh_CN danger = _Translations$entities$run$danger$zh_CN._(_root);
	@override String get inboxEmpty => '没有待审批';
	@override String get inboxEmptyHint => '等待决断的审批会出现在这里。';
	@override String get source => '来源';
	@override String get sourceManual => '手动';
	@override String get openFlowrun => '打开 run →';
	@override String get openRunPage => '在运行页打开 →';
	@override String recentCount({required Object n}) => '最近执行 · ${n}';
	@override String get reproduce => '用这份输入';
	@override String get inputHeading => '输入';
	@override late final _Translations$entities$run$origin$zh_CN origin = _Translations$entities$run$origin$zh_CN._(_root);
}

// Path: entities.val
class _Translations$entities$val$zh_CN extends Translations$entities$val$en {
	_Translations$entities$val$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get yes => '是';
	@override String get no => '否';
}

// Path: entities.overview
class _Translations$entities$overview$zh_CN extends Translations$entities$overview$en {
	_Translations$entities$overview$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '总览';
	@override String get accessory => '配件';
	@override String get graphHead => '关系图';
	@override String get recentHead => '最近更新';
}

// Path: entities.graph
class _Translations$entities$graph$zh_CN extends Translations$entities$graph$en {
	_Translations$entities$graph$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get showProvenance => '显示溯源';
	@override String get openDetail => '打开详情';
	@override String get groupEquips => '装备了';
	@override String get groupReferencedBy => '被引用';
	@override String get groupLinks => '链接';
	@override String get legend => '类型';
	@override String get back => '返回总览';
	@override String get selectHint => '选择一个节点查看其关系。';
	@override late final _Translations$entities$graph$verb$zh_CN verb = _Translations$entities$graph$verb$zh_CN._(_root);
}

// Path: documents.props
class _Translations$documents$props$zh_CN extends Translations$documents$props$en {
	_Translations$documents$props$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '属性';
	@override String get name => '名称';
	@override String get description => '描述';
	@override String get tags => '标签';
	@override String get addTag => '添加标签';
	@override String get path => '路径';
	@override String get size => '大小';
	@override String get modified => '修改时间';
	@override String get context => '上下文';
	@override String get contextInline => '内联';
	@override String get contextFork => '分叉';
	@override String get agent => 'Agent';
	@override String get agentHint => '要派发的子 agent 类型——分叉技能必填。';
	@override String get tools => '允许的工具';
	@override String get addTool => '添加工具';
	@override String get arguments => '参数';
	@override String get addArg => '添加参数';
	@override String get modelInvoke => '模型可调用';
	@override String get userInvoke => '用户可调用';
	@override String get on => '开';
	@override String get off => '关';
	@override String get empty => '未选中';
	@override String get emptyHint => '选一个页面或技能查看它的属性。';
	@override String get outline => '大纲';
	@override String get backlinks => '反向链接';
	@override String get noBacklinks => '还没有页面链接到这里。';
	@override String get expandAll => '展开全部';
	@override String get collapseAll => '收起全部';
	@override String glanceChars({required Object count}) => '${count} 字';
	@override String glanceBacklinks({required Object n}) => '${n} 反链';
	@override String glanceEdited({required Object rel}) => '${rel}编辑';
	@override late final _Translations$documents$props$time$zh_CN time = _Translations$documents$props$time$zh_CN._(_root);
}

// Path: documents.slash
class _Translations$documents$slash$zh_CN extends Translations$documents$slash$en {
	_Translations$documents$slash$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get text => '正文';
	@override String get h1 => '标题 1';
	@override String get h2 => '标题 2';
	@override String get h3 => '标题 3';
	@override String get bulleted => '无序列表';
	@override String get numbered => '有序列表';
	@override String get quote => '引用';
	@override String get code => '代码块';
	@override String get table => '表格';
	@override String get divider => '分隔线';
	@override String get todo => '待办';
}

// Path: documents.table
class _Translations$documents$table$zh_CN extends Translations$documents$table$en {
	_Translations$documents$table$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get insertRowAbove => '在上方插入行';
	@override String get insertRowBelow => '在下方插入行';
	@override String get deleteRow => '删除行';
	@override String get insertColLeft => '在左侧插入列';
	@override String get insertColRight => '在右侧插入列';
	@override String get deleteCol => '删除列';
	@override String get deleteTable => '删除表格';
}

// Path: settings.scope
class _Translations$settings$scope$zh_CN extends Translations$settings$scope$en {
	_Translations$settings$scope$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get device => '本机';
	@override String get workspace => '工作区';
	@override String get machine => '全机';
}

// Path: settings.sections
class _Translations$settings$sections$zh_CN extends Translations$settings$sections$en {
	_Translations$settings$sections$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get prefs => '偏好';
	@override String get resources => '资源';
	@override String get system => '系统';
}

// Path: settings.panels
class _Translations$settings$panels$zh_CN extends Translations$settings$panels$en {
	_Translations$settings$panels$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get general => '通用';
	@override String get notifications => '通知';
	@override String get chat => '对话';
	@override String get modelsKeys => '模型与密钥';
	@override String get mcp => 'MCP 服务器';
	@override String get memory => '记忆';
	@override String get sandbox => '沙箱';
	@override String get workspaces => '工作区';
	@override String get storage => '存储与日志';
	@override String get limits => '高级限额';
	@override String get network => '网络';
	@override String get shortcuts => '快捷键';
	@override String get about => '关于';
}

// Path: settings.keys
class _Translations$settings$keys$zh_CN extends Translations$settings$keys$en {
	_Translations$settings$keys$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get freeTier => '免费档';
	@override String get freeTierName => 'Anselm Free · deepseek-v4-flash';
	@override String freeUsage({required Object used, required Object limit, required Object reset}) => '${used} / ${limit} · ${reset} 重置';
	@override String get freeUnavailable => '网关今日预算已满,明日恢复';
	@override String get freeEnable => '启用免费档';
	@override String get freeEnableHint => '将向 Anselm 网关注册本机匿名指纹以分配额度';
	@override String get freeProvisioning => '正在开通…';
	@override String get freeRefresh => '刷新';
	@override String get freeFailed => '开通未完成(离线或网关不可达),稍后可重试';
	@override String get keysSection => 'API 密钥';
	@override String get addKey => '添加密钥';
	@override String get testKey => '测试';
	@override String get editKey => '编辑';
	@override String get deleteKey => '删除';
	@override String get statusOk => '可用';
	@override String get statusPending => '待测';
	@override String get statusError => '失败';
	@override String get managedBadge => '受管';
	@override String get provider => '提供方';
	@override String get displayNameLabel => '名称';
	@override String get secretLabel => '密钥';
	@override String get baseUrlLabel => 'Base URL';
	@override String get apiFormatLabel => 'API 方言';
	@override String get saveKey => '保存并测试';
	@override String get cancel => '取消';
	@override String get reveal => '显示';
	@override String get conceal => '隐藏';
	@override String get rotateWarn => '替换即生效,原密钥不可恢复';
	@override String get rotatePlaceholder => '留空则不更换密钥';
	@override String get inUseTitle => '此密钥仍被引用';
	@override String get inUseHint => '先在以下位置解除引用:';
	@override String get deleteKeyTitle => '删除密钥';
	@override String deleteKeyBody({required Object name}) => '将删除「${name}」,不可恢复。';
	@override String get confirmDelete => '删除';
	@override String get defaults => '场景默认模型';
	@override String get scenarioDialogue => '对话';
	@override String get scenarioUtility => '工具';
	@override String get scenarioAgent => 'Agent';
	@override String get scenarioDialogueDesc => '聊天回复所用模型;Auto 依赖它,不可清除';
	@override String get scenarioUtilityDesc => '自动命名、上下文压缩等轻任务';
	@override String get scenarioAgentDesc => 'invoke_agent 执行所用';
	@override String get noDefault => '未配置';
	@override String get clearDefault => '清除';
	@override String get notConfiguredWarn => '未设默认对话模型,对话将无法开始';
	@override String get searchDefault => '默认搜索密钥';
	@override String get searchDefaultDesc => 'WebSearch 工具所用(category=search 的可用密钥)';
	@override String get keyOpFailed => '操作失败';
	@override String get refreshModels => '刷新模型列表';
	@override String get pickProvider => '选择提供商';
	@override String get changeProvider => '重新选择';
	@override String get baseUrlRequiredHint => '自托管服务必填服务地址';
	@override String get savingProbe => '正在保存并探测…';
	@override String get stageCredential => '凭证';
	@override String get stageModel => '模型';
	@override String get stageKnobs => '参数';
	@override String get pickerApply => '应用';
	@override String get pickerChange => '修改';
	@override String get pickerClose => '收起';
	@override String get visionBadge => '视觉';
	@override String get docsBadge => '文档';
	@override String get noCapsGuide => '还没有可用模型——先添加一把探测通过的密钥';
	@override String get searchSection => '搜索';
}

// Path: settings.ws
class _Translations$settings$ws$zh_CN extends Translations$settings$ws$en {
	_Translations$settings$ws$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get section => '工作区';
	@override String get current => '当前';
	@override String get newWorkspace => '新建工作区';
	@override String get name => '名称';
	@override String get color => '颜色';
	@override String get create => '创建';
	@override String get save => '保存';
	@override String get edit => '编辑';
	@override String get switchTo => '切换';
	@override String get dangerTitle => '删除此工作区';
	@override String dangerBody({required Object name, required Object conversations, required Object entities, required Object documents, required Object blob}) => '将永久删除「${name}」的全部内容:${conversations} 对话 · ${entities} 实体 · ${documents} 文档 · ${blob} 附件。';
	@override String runningWarn({required Object n}) => '有 ${n} 个执行进行中,删除将立即终止它们';
	@override String generatingWarn({required Object n}) => '有 ${n} 个对话正在生成回复,删除将立即打断';
	@override String typeNameHint({required Object name}) => '输入「${name}」以确认';
	@override String get confirmDelete => '永久删除';
	@override String get lastOne => '唯一的工作区不可删除';
	@override String get deleteFailed => '删除失败';
	@override String get blobUnknown => '体积未知';
	@override String get statsLoading => '正在盘点内容…';
}

// Path: settings.about
class _Translations$settings$about$zh_CN extends Translations$settings$about$en {
	_Translations$settings$about$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get appVersion => '应用版本';
	@override String get backendVersion => '引擎版本';
	@override String get versions => '版本';
	@override String get checkUpdates => '检查更新';
	@override String get checking => '检查中…';
	@override String upToDate({required Object v}) => '已是最新(${v})';
	@override String updateAvailable({required Object v}) => '新版本 ${v} 可用';
	@override String get download => '前往下载';
	@override String get cantCheck => '无法检查更新(离线或尚未发布)';
	@override String get diagnostics => '诊断';
	@override String get copyDiagnostics => '复制诊断信息';
	@override String get copied => '已复制';
	@override String get diagDesc => '复制版本与环境信息,便于报告问题';
	@override String get fonts => '字体';
	@override String get fontsCredit => '随包字体:Inter、MiSans、JetBrains Mono、思源宋 SC、Fira Code、Cascadia Code、Newsreader。MiSans © 小米公司,依 MiSans 字体许可协议使用;其余依 SIL 开放字体许可(OFL)。';
}

// Path: settings.mem
class _Translations$settings$mem$zh_CN extends Translations$settings$mem$en {
	_Translations$settings$mem$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get section => '记忆';
	@override String get filterAll => '全部';
	@override String get filterPinned => '已固定';
	@override String get newMemory => '新建记忆';
	@override String get name => '名称';
	@override String get nameHint => '小写字母开头,可用 a-z 0-9 - _';
	@override String get nameLocked => '名称即文件名,不可改';
	@override String get invalidName => '名称须以小写字母开头,仅含 a-z 0-9 - _(≤64)';
	@override String get description => '描述';
	@override String get content => '内容';
	@override String get save => '保存';
	@override String get pinTip => '固定的记忆常驻每次对话上下文';
	@override String get pinned => '已固定';
	@override String get deleteTitle => '删除记忆';
	@override String deleteBody({required Object name}) => '将物理删除「${name}」的记忆文件,无法撤销。';
	@override String get confirmDelete => '删除';
	@override String get empty => '还没有记忆';
	@override String get dirtyTitle => '放弃未保存的修改?';
	@override String get dirtyBody => '内容有改动尚未保存。';
	@override String get discard => '放弃';
	@override String get keepEditing => '继续编辑';
	@override String get sourceUser => '用户';
	@override String get sourceAi => 'AI';
	@override String get searchHint => '搜索记忆…';
}

// Path: settings.mcp
class _Translations$settings$mcp$zh_CN extends Translations$settings$mcp$en {
	_Translations$settings$mcp$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get browse => '浏览市场';
	@override String get manualAdd => '手动添加';
	@override String get importJson => '导入 mcp.json';
	@override String get empty => '还没有 MCP 服务器';
	@override String get reconnect => '重连';
	@override String get detail => '详情';
	@override String get deleteServer => '删除';
	@override String get deleteTitle => '删除 MCP 服务器';
	@override String deleteBody({required Object name}) => '将移除「${name}」及其配置(软删)。';
	@override String get confirmDelete => '删除';
	@override String tools({required Object n}) => '${n} 工具';
	@override String calls({required Object n}) => '${n} 次调用';
	@override String get statusReady => '就绪';
	@override String get statusFailed => '失败';
	@override String get statusDegraded => '降级';
	@override String get statusConnecting => '连接中';
	@override String get statusDisconnected => '未连接';
	@override String get name => '名称';
	@override String get transport => '传输';
	@override String get runtime => '运行时';
	@override String get command => '命令';
	@override String get args => '参数(每行一个)';
	@override String get url => 'URL';
	@override String get envKv => '环境变量(KEY=VALUE,每行一个)';
	@override String get headersKv => '请求头(KEY=VALUE,每行一个)';
	@override String get add => '添加';
	@override String get addFailedHonest => '连接失败也会落盘为 failed,可稍后重连';
	@override String get importTitle => '导入 mcp.json';
	@override String get importHint => '粘贴 Claude Desktop 的 mcpServers 片段';
	@override String get overwrite => '覆盖同名';
	@override String get doImport => '导入';
	@override String importResult({required Object n, required Object m}) => '导入 ${n} · 跳过 ${m}';
	@override String get importInvalid => 'JSON 无法解析';
	@override String get market => '市场';
	@override String get searchMarket => '搜索市场…';
	@override String get installed => '已安装';
	@override String get install => '安装';
	@override String get installing => '安装中…';
	@override String get prerequisite => '前置';
	@override String get requiredMark => '必填';
	@override String get oauthConnect => '连接并授权';
	@override String get oauthWaiting => '等待浏览器授权…(最长 120 秒)';
	@override String get tabTools => '工具';
	@override String get tabCalls => '调用历史';
	@override String get tabStderr => 'stderr';
	@override String get lastError => '最近错误';
	@override String get consecutiveFailures => '连续失败';
	@override String get noTools => '无工具';
	@override String get noCalls => '暂无调用';
	@override String get noStderr => '暂无输出';
	@override String callsAgg({required Object ok, required Object failed}) => '✓ ${ok} · ✗ ${failed}';
	@override String statCount({required Object n}) => '${n} 台';
	@override String statReady({required Object n}) => '就绪 ${n}';
	@override String statFailed({required Object n}) => '失败 ${n}';
	@override String get cardMenu => '更多操作';
}

// Path: settings.storage
class _Translations$settings$storage$zh_CN extends Translations$settings$storage$en {
	_Translations$settings$storage$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get dataDir => '数据目录';
	@override String get revealFinder => '在访达中显示';
	@override String get diskUsage => '磁盘占用';
	@override String get diskSandbox => '沙箱运行时与环境';
	@override String get openLogs => '打开日志文件夹';
	@override String get retention => 'Run 历史保留';
	@override String get retentionDesc => '超过保留线的 run 记录将被清理,统计与失败聚合不受影响。';
	@override String get retention30 => '30 天';
	@override String get retention90 => '90 天';
	@override String get retention180 => '180 天';
	@override String get retentionForever => '永久保留';
	@override String get retentionSaved => '保留策略已更新';
	@override String get database => '数据库';
	@override String dbFootprint({required Object size, required Object dead}) => '${size},其中 ${dead} 可回收';
	@override String get compact => '压缩数据库';
	@override String get compacting => '压缩中…';
	@override String compacted({required Object mb}) => '已回收 ${mb}';
	@override String get resetPrefs => '重置本地偏好';
	@override String get resetPrefsDesc => '只清除本机的界面偏好(主题/窗口/缩放等),不碰任何工作区数据将重启应用以生效。';
	@override String get resetPrefsTitle => '重置本地偏好?';
	@override String get factoryTitle => '恢复出厂设置';
	@override String get factoryWarn => '将停止引擎、永久删除整个数据目录(所有工作区/对话/实体/文档/密钥)并重启应用。';
	@override String get factoryHint => '输入「Anselm」以确认';
	@override String get factoryConfirm => '抹掉一切并重启';
}

// Path: settings.limits
class _Translations$settings$limits$zh_CN extends Translations$settings$limits$en {
	_Translations$settings$limits$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get scopeNote => '全机生效——任一工作区修改的都是这台机器的同一份上限';
	@override String get resetAll => '全部恢复默认';
	@override String get resetAllTitle => '恢复全部默认限额?';
	@override String get patchFailed => '保存失败';
	@override String get modified => '已修改';
	@override String get errorTitle => '限额加载失败';
	@override String get retry => '重试';
	@override String get errorHint => '无法从引擎读取限额配置';
}

// Path: settings.network
class _Translations$settings$network$zh_CN extends Translations$settings$network$en {
	_Translations$settings$network$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get section => '网络';
	@override String get proxyHint => '出站代理——AI 请求经它到达 LLM / MCP / 搜索服务';
	@override String get httpProxy => 'HTTP 代理';
	@override String get httpsProxy => 'HTTPS 代理';
	@override String get noProxy => '绕过代理(逗号分隔)';
	@override String get proxyPlaceholder => 'http://127.0.0.1:7890';
	@override String get save => '保存';
	@override String get saved => '已保存,重启引擎后完整生效';
	@override String get restartNote => '代理配置在重启引擎后完整生效';
	@override String get empty => '留空=直连';
}

// Path: settings.sandbox
class _Translations$settings$sandbox$zh_CN extends Translations$settings$sandbox$en {
	_Translations$settings$sandbox$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get bootstrapFail => '沙箱引导失败';
	@override String get retry => '重试';
	@override String get runtimes => '运行时';
	@override String get install => '安装';
	@override String get installing => '安装中…';
	@override String get installTitle => '安装运行时';
	@override String get kind => '类型';
	@override String get version => '版本';
	@override String get versionHint => '如 22 / 3.12';
	@override String get add => '安装';
	@override String get delete => '删除';
	@override String get deleteRtTitle => '删除运行时';
	@override String deleteRtBody({required Object kind, required Object version}) => '将删除「${kind} ${version}」;仍被环境引用会被拒。';
	@override String get confirmDelete => '删除';
	@override String get inUse => '仍有环境引用此运行时,先清理环境';
	@override String get envs => '环境';
	@override String get envRebuild => '下次执行时自动重建';
	@override String get deleteEnvTitle => '删除环境';
	@override String get deleteEnvBody => '将删除此环境。';
	@override String get ownerFunction => '函数';
	@override String get ownerHandler => '处理器';
	@override String get ownerMcp => 'MCP';
	@override String get ownerSkill => '技能';
	@override String get ownerConversation => '对话';
	@override String get noRuntimes => '还没有运行时';
	@override String get noEnvs => '暂无环境';
	@override String get disk => '磁盘占用';
	@override String get gc => '回收空闲环境';
	@override String get gcDays => '回收超过 N 天未用的环境';
	@override String get gcRun => '回收';
	@override String gcDone({required Object n}) => '已回收 ${n} 个';
	@override String get gcAllTitle => '立即回收全部空闲环境?';
	@override String get gcAll => '立即全部回收';
	@override String get running => '运行中';
	@override String get statusReady => '就绪';
	@override String get statusFailed => '失败';
}

// Path: settings.shortcuts
class _Translations$settings$shortcuts$zh_CN extends Translations$settings$shortcuts$en {
	_Translations$settings$shortcuts$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get section => '快捷键';
	@override String get scope => '本机';
	@override String get resetAll => '全部恢复默认';
	@override String get reset => '恢复默认';
	@override String get rebind => '改绑';
	@override String get recording => '按下新组合键…';
	@override String conflict({required Object cmd}) => '与「${cmd}」冲突';
	@override String get cmdToggleLeft => '折叠/展开左岛';
	@override String get cmdToggleRight => '折叠/展开右岛';
	@override String get cmdOpenSettings => '打开设置';
	@override String get cmdZoomIn => '放大界面';
	@override String get cmdZoomOut => '缩小界面';
	@override String get cmdZoomReset => '重置缩放';
	@override String get hintModifier => '组合键须含 ⌘/Ctrl 等修饰键';
}

// Path: chat.tool.kind
class _Translations$chat$tool$kind$zh_CN extends Translations$chat$tool$kind$en {
	_Translations$chat$tool$kind$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get function => '函数';
	@override String get handler => '处理器';
	@override String get agent => '智能体';
	@override String get workflow => '工作流';
	@override String get control => '控制';
	@override String get approval => '审批';
	@override String get document => '文档';
	@override String get skill => '技能';
	@override String get trigger => '触发器';
	@override String get blocks => '块';
	@override String get attachment => '附件';
	@override String get conversation => '对话';
}

// Path: chat.stage.run
class _Translations$chat$stage$run$zh_CN extends Translations$chat$stage$run$en {
	_Translations$chat$stage$run$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get queued => '已入队 · 聆听节点回报…';
	@override String get done => '运行完成';
	@override String get failed => '运行失败';
	@override String get cancelled => '运行已取消';
	@override String get parked => '等待审批';
}

// Path: chat.stage.a11y
class _Translations$chat$stage$a11y$zh_CN extends Translations$chat$stage$a11y$en {
	_Translations$chat$stage$a11y$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String staged({required Object name}) => '${name} 登台';
	@override String get gate => 'AI 在等你决定';
	@override String get failed => '操作失败,舞台驻留';
	@override String settled({required Object name}) => '${name} 已落定';
}

// Path: chat.stage.follow
class _Translations$chat$stage$follow$zh_CN extends Translations$chat$stage$follow$en {
	_Translations$chat$stage$follow$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '自动登台';
	@override String get always => '每次都跟';
	@override String get first => '每会话首次';
	@override String get never => '从不';
}

// Path: feedback.cast.verb
class _Translations$feedback$cast$verb$zh_CN extends Translations$feedback$cast$verb$en {
	_Translations$feedback$cast$verb$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get mentioned => '提及';
	@override String get created => '创建';
	@override String get edited => '编辑';
	@override String get viewed => '查看';
	@override String get executed => '执行';
	@override String get attached => '附上';
	@override String get deleted => '删除';
	@override String get unknown => '触碰';
}

// Path: entities.detail.tab
class _Translations$entities$detail$tab$zh_CN extends Translations$entities$detail$tab$en {
	_Translations$entities$detail$tab$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get overview => '概览';
	@override String get versions => '版本';
	@override String get logs => '日志';
	@override String get runs => '运行';
	@override String get activity => '活动';
	@override String get dispatch => '派发';
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

// Path: entities.detail.hero
class _Translations$entities$detail$hero$zh_CN extends Translations$entities$detail$hero$en {
	_Translations$entities$detail$hero$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String envStatus({required Object status}) => 'env ${status}';
	@override String get noInputs => '无入参';
	@override String methods({required Object n}) => '${n} 个方法';
	@override String deps({required Object n}) => '${n} 依赖';
}

// Path: entities.detail.gate
class _Translations$entities$detail$gate$zh_CN extends Translations$entities$detail$gate$en {
	_Translations$entities$detail$gate$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get config => 'config';
	@override String get env => 'env';
	@override String get instance => 'instance';
}

// Path: entities.detail.codeToggle
class _Translations$entities$detail$codeToggle$zh_CN extends Translations$entities$detail$codeToggle$en {
	_Translations$entities$detail$codeToggle$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String expand({required Object n}) => '展开全部 (${n} 行)';
	@override String get collapse => '收起';
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
	@override String get branches => '路由分支';
	@override String get template => '审批模板';
	@override String get decisionRules => '决策规则';
	@override String get config => '配置';
	@override String get listener => '监听';
	@override String get firePayload => 'Fire 载荷';
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
	@override String get unparseable => '编排图无法解析';
}

// Path: entities.detail.cockpit
class _Translations$entities$detail$cockpit$zh_CN extends Translations$entities$detail$cockpit$en {
	_Translations$entities$detail$cockpit$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get runs => '运行';
	@override String runsCount({required Object n}) => '运行 · ${n} 次';
	@override String get nodeGantt => '节点甘特';
	@override String get notRun => '未运行';
	@override String get waitingApproval => '等待审批';
	@override String get noRuns => '尚无运行';
	@override String get noRunsHint => '触发此工作流后这里会列出每次运行';
	@override String get runGraph => '运行图';
	@override String nodeDetail({required Object id}) => '节点 · ${id}';
	@override String get replay => '重跑';
	@override String get kill => '终止';
	@override String get runInfo => '运行信息';
	@override String iteration({required Object n}) => '轮次 ${n}';
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
	@override String get allowReason => '允许备注';
	@override String get timeout => '超时';
	@override String get timeoutBehavior => '超时行为';
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
	@override String get passthrough => '透传';
	@override String get never => '永不超时';
	@override String get yes => '是';
	@override String get no => '否';
	@override String get stopped => '已停';
	@override String get noAlerts => '无告警';
	@override String get needsAttention => '需注意';
	@override String get required => '必填';
	@override String get optional => '可选';
	@override String get sensitive => '敏感';
	@override String timeoutMs({required Object ms}) => '超时 ${ms} ms';
	@override String get defaultPrefix => '默认';
	@override String get generator => '生成器';
	@override String get modelDefault => '工作区默认';
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

// Path: entities.detail.trigger
class _Translations$entities$detail$trigger$zh_CN extends Translations$entities$detail$trigger$en {
	_Translations$entities$detail$trigger$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get fire => '催发';
	@override String get listening => '监听中';
	@override String get idle => '空闲';
	@override String get source => '源';
	@override String get refCount => '监听者';
	@override String get lastFired => '最近触发';
	@override String get nextFire => '下次触发';
	@override String get signatureAlgo => '签名';
	@override String get signatureHeader => '签名头';
	@override String get events => '事件';
	@override String get pattern => '匹配';
	@override String get target => '目标';
	@override String get interval => '间隔';
	@override String get fired => '已触发';
	@override String get notFired => '未触发';
	@override String fanout({required Object n}) => '扇出 ${n}';
	@override String get fanoutLabel => '扇出';
	@override String get returnValue => '返回值';
	@override String get payload => '载荷';
	@override String get detail => '详情';
	@override String get activation => '活动';
	@override String get allActivity => '全部活动';
	@override String get firedOnly => '仅已触发';
	@override String get allDispatch => '全部派发';
	@override String firedToast({required Object id}) => '已催发 · ${id}';
	@override String get fireFailed => '催发失败';
}

// Path: entities.detail.state
class _Translations$entities$detail$state$zh_CN extends Translations$entities$detail$state$en {
	_Translations$entities$detail$state$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get setActive => '设为活跃版本';
	@override String get setActiveFailed => '设为活跃版本失败';
	@override String get retry => '重试';
	@override String get noVersions => '暂无版本';
	@override String get noLogs => '暂无运行记录';
	@override String get noLogsHint => '执行该实体后,记录会出现在这里。';
	@override String get noActivations => '暂无活动';
	@override String get noActivationsHint => '该触发器每次动作(触发与否)都会在此留一行。';
	@override String get noFirings => '无派发';
	@override String get noFiringsHint => '一次触发扇给 workflow 后,其处置显示在此。';
	@override String get noActiveVersion => '无活动版本';
	@override String get errorTitle => '无法加载该实体';
	@override String get errorHint => '本地引擎没有返回它。';
	@override String get loadMore => '加载更多';
	@override String get loadFailed => '加载失败,点此重试';
	@override String get earliest => '最早版本';
}

// Path: entities.detail.editor
class _Translations$entities$detail$editor$zh_CN extends Translations$entities$detail$editor$en {
	_Translations$entities$detail$editor$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '图编辑器';
	@override String get back => '返回';
	@override String get addNode => '添加节点';
	@override String get autoLayout => '自动布局';
	@override String get dirLR => '横向';
	@override String get dirTB => '纵向';
	@override String get save => '保存';
	@override String get discard => '放弃更改';
	@override String get discardConfirmTitle => '丢弃未保存的更改?';
	@override String get discardConfirmMessage => '画布上有尚未保存的编辑,现在离开将丢弃它们。';
	@override String get discardConfirmAction => '丢弃并离开';
	@override String get saved => '已保存新版本';
	@override String get unsaved => '未保存更改';
	@override String get inspectorEmpty => '选中节点或连线进行编辑';
	@override String get nodeRef => '引用';
	@override String get nodeKind => '类型';
	@override String get nodeInput => '输入映射';
	@override String get nodeRetry => '重试';
	@override String get edgePort => '端口';
	@override String get deleteNode => '删除节点';
	@override String get deleteEdge => '删除连线';
	@override String get portHint => 'control 端口须匹配分支名;approval 为 yes/no';
	@override String get portPick => '选择分支端口';
	@override String get branches => '路由分支';
	@override String get branchDefault => '兜底(其余情况)';
	@override String get branchEmit => 'emit';
	@override String get field => '字段';
	@override String get retryEnable => '启用重试';
	@override String get maxAttempts => '最大次数';
	@override String get errSelfLoop => '不支持自环:节点不能连自身';
	@override String get errDuplicateEdge => '该连线已存在';
	@override String get errBackEdgeSource => '回边仅可从 control / approval 发出';
	@override String get errApprovalPortsFull => 'approval 仅有 yes / no 两个出口';
	@override String get on => '开';
	@override String get off => '关';
	@override String get inspectorTitle => '检查器';
	@override String get inspectorEmptyHint => '在画布上选一个节点或边来编辑。';
	@override String get edge => '边';
	@override String get removeField => '移除字段';
	@override String get refPickFamily => '选择类别…';
	@override String get refFamilyFunction => '函数';
	@override String get refFamilyHandler => '处理器';
	@override String get refFamilyMcp => 'MCP';
	@override String get refPickTarget => '选择…';
	@override String get refPickMethod => '选择方法…';
	@override String get refPickTool => '选择工具…';
}

// Path: entities.run.danger
class _Translations$entities$run$danger$zh_CN extends Translations$entities$run$danger$en {
	_Translations$entities$run$danger$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get cautious => '谨慎';
	@override String get dangerous => '危险';
}

// Path: entities.run.origin
class _Translations$entities$run$origin$zh_CN extends Translations$entities$run$origin$en {
	_Translations$entities$run$origin$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get manual => '手动';
	@override String get chat => '对话';
	@override String get agent => '智能体';
	@override String get workflow => '工作流';
	@override String get cron => '调度';
	@override String get webhook => 'Webhook';
	@override String get fsnotify => '文件变更';
	@override String get sensor => '传感器';
}

// Path: entities.graph.verb
class _Translations$entities$graph$verb$zh_CN extends Translations$entities$graph$verb$en {
	_Translations$entities$graph$verb$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get equip => '装备了';
	@override String get link => '链接了';
	@override String get create => '创建了';
	@override String get edit => '编辑了';
}

// Path: documents.props.time
class _Translations$documents$props$time$zh_CN extends Translations$documents$props$time$en {
	_Translations$documents$props$time$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get today => '今天';
	@override String get yesterday => '昨天';
	@override String daysAgo({required Object n}) => '${n} 天前';
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
			'chat.errorTitle' => '对话列表加载失败',
			'chat.errorHint' => '本地引擎没有返回对话列表。',
			'chat.retry' => '重试',
			'chat.sortLabel' => '排序',
			'chat.sortActivity' => '最近活跃',
			'chat.sortCreated' => '最近创建',
			'chat.sortName' => '按名称',
			'chat.displayLabel' => '显示',
			'chat.showArchived' => '显示已归档',
			'chat.showCount' => '显示分组计数',
			'chat.showTime' => '显示时间',
			'chat.rename' => '重命名',
			'chat.pin' => '置顶',
			'chat.unpin' => '取消置顶',
			'chat.archive' => '归档',
			'chat.unarchive' => '取消归档',
			'chat.deleteTitle' => '删除这个对话？',
			'chat.deleteBody' => ({required Object title}) => '「${title}」将被移除。',
			'chat.deleteConfirm' => '删除',
			'chat.actionFailed' => '操作失败',
			'chat.time.justNow' => '刚刚',
			'chat.time.minutesAgo' => ({required Object n}) => '${n} 分钟前',
			'chat.time.hoursAgo' => ({required Object n}) => '${n} 小时前',
			'chat.time.yesterday' => '昨天',
			'chat.time.daysAgo' => ({required Object n}) => '${n} 天前',
			'chat.bucket.pinned' => '置顶',
			'chat.bucket.recents' => '最近',
			'chat.placeholder' => 'Ask anything…',
			'chat.send' => '发送',
			'chat.stop' => '停止生成',
			'chat.thinking' => 'thinking',
			'chat.thought' => 'thought',
			'chat.sendFailed' => 'Couldn\'t send',
			'chat.attachmentsFailedDropped' => ({required Object n}) => '${n} 个附件上传失败,未随消息发送',
			'chat.retrySend' => 'Retry',
			'chat.discard' => 'Discard',
			'chat.stoppedCancelled' => 'Stopped',
			'chat.stoppedError' => 'Something went wrong',
			'chat.repickModel' => '重选模型',
			'chat.stoppedMaxSteps' => 'Paused — step limit reached',
			'chat.stoppedBudget' => 'Paused — context window is full',
			'chat.stoppedMaxTokens' => 'Reached the output limit',
			'chat.transcriptErrorTitle' => 'Couldn\'t load this conversation',
			'chat.transcriptErrorHint' => 'The local engine didn’t return the messages.',
			'chat.backToPresent' => '回到现场',
			'chat.toc.button' => '场次目录',
			'chat.toc.gates' => '待你决定',
			'chat.toc.toolCluster' => ({required Object n}) => '${n} 项操作',
			'chat.toc.compaction' => '上下文已压缩',
			'chat.toc.abnormal' => '异常终止',
			'chat.toc.empty' => '还没有可跳转的场次',
			'chat.landingGreeting' => 'What should we dig into?',
			'chat.modelAuto' => 'Auto',
			'chat.mentionEntity' => 'Mention an entity',
			'chat.attachFile' => 'Attach files',
			'chat.dropToAttach' => 'Drop files to attach',
			'chat.tool.calling' => '正在调用',
			'chat.tool.called' => '已调用',
			'chat.tool.awaitingConfirm' => '等待确认',
			'chat.tool.denied' => '已拒绝执行',
			'chat.tool.cancelled' => '已中断',
			'chat.tool.elapsed' => ({required Object s}) => '${s} 秒',
			'chat.tool.intent' => '意图',
			'chat.tool.argsLabel' => '参数',
			'chat.tool.progressLabel' => '进度',
			'chat.tool.resultLabel' => '结果',
			'chat.tool.errorLabel' => '错误',
			'chat.tool.liveLabel' => '实时',
			'chat.tool.truncatedNote' => ({required Object chars}) => '已截断 · 完整内容 ${chars} 字符',
			'chat.tool.progressOmitted' => ({required Object n}) => '…前 ${n} 行略',
			'chat.tool.reading' => '正在读取',
			'chat.tool.read' => '已读取',
			'chat.tool.writing' => '正在写入',
			'chat.tool.wrote' => '已写入',
			'chat.tool.editing' => '正在编辑',
			'chat.tool.edited' => '已编辑',
			'chat.tool.globbing' => '正在检索',
			'chat.tool.globbed' => '已检索',
			'chat.tool.grepping' => '正在搜索',
			'chat.tool.grepped' => '已搜索',
			'chat.tool.listing' => '正在列出',
			'chat.tool.listed' => '已列出',
			'chat.tool.runningCmd' => '正在执行命令',
			'chat.tool.ranCmd' => '已执行',
			'chat.tool.lines' => ({required Object n}) => '${n} 行',
			'chat.tool.matches' => ({required Object n}) => '${n} 处匹配',
			'chat.tool.files' => ({required Object n}) => '${n} 个文件',
			'chat.tool.items' => ({required Object n}) => '${n} 项',
			'chat.tool.noMatches' => '无匹配',
			'chat.tool.exit' => ({required Object code}) => 'exit ${code}',
			'chat.tool.timedOut' => '超时',
			'chat.tool.creatingKind' => ({required Object kind}) => '正在创建${kind}',
			'chat.tool.createdKind' => ({required Object kind}) => '已创建${kind}',
			'chat.tool.updatingKind' => ({required Object kind}) => '正在修改${kind}',
			'chat.tool.updatedKind' => ({required Object kind}) => '已更新${kind}',
			'chat.tool.envReady' => 'env 就绪',
			'chat.tool.envBuilding' => 'env 构建中',
			'chat.tool.envFailed' => 'env 失败',
			'chat.tool.restarted' => '已重启',
			'chat.tool.kind.function' => '函数',
			'chat.tool.kind.handler' => '处理器',
			'chat.tool.kind.agent' => '智能体',
			'chat.tool.kind.workflow' => '工作流',
			'chat.tool.kind.control' => '控制',
			'chat.tool.kind.approval' => '审批',
			'chat.tool.kind.document' => '文档',
			'chat.tool.kind.skill' => '技能',
			'chat.tool.kind.trigger' => '触发器',
			'chat.tool.kind.blocks' => '块',
			'chat.tool.kind.attachment' => '附件',
			'chat.tool.kind.conversation' => '对话',
			'chat.tool.asking' => '正在提问',
			'chat.tool.answered' => '已回答',
			'chat.tool.skipped' => '已跳过',
			'chat.tool.emptyAnswer' => '空答案',
			'chat.tool.awaitingAnswer' => '等待你回答',
			'chat.tool.deciding' => '正在裁决',
			'chat.tool.approved' => '已批准',
			'chat.tool.rejected' => '已否决',
			'chat.tool.decided' => '已裁决',
			'chat.tool.approveVerdict' => '批准',
			'chat.tool.rejectVerdict' => '否决',
			'chat.tool.notParked' => '该节点当前不在等待审批(可能已被决议、已超时或节点标识有误),本次裁决未生效。',
			'chat.tool.nodesShown' => ({required Object shown, required Object total}) => '显示 ${shown}/${total} 个节点,全量见 flowrun',
			'chat.tool.clearing' => '正在清点审批收件箱',
			'chat.tool.cleared' => '已清点',
			'chat.tool.inboxCount' => ({required Object n}) => '${n} 件待审',
			'chat.tool.inboxEmpty' => '无待审',
			'chat.tool.inboxMore' => ({required Object n}) => '另有 ${n} 件',
			'chat.tool.inboxRef' => '审批',
			'chat.tool.inboxSummary' => '摘要',
			'chat.tool.inboxWait' => '等待',
			'chat.tool.inboxRun' => 'run',
			'chat.tool.inboxEmptyState' => '收件箱空——没有 run 在等审批',
			'chat.tool.runtimeRunning' => '运行中',
			'chat.tool.runtimeStopped' => '实例未运行',
			'chat.tool.runtimeCrashed' => '实例已崩溃',
			'chat.tool.envFixAttempt' => ({required Object n}) => '尝试 ${n}',
			'chat.tool.envFixTitle' => '环境自愈',
			'chat.tool.wfInactive' => '未激活',
			'chat.tool.wfGraphCounts' => ({required Object nodes, required Object edges}) => '节点 ${nodes} · 边 ${edges}',
			'chat.tool.wfNodeUnit' => '节点',
			'chat.tool.wfEdgeUnit' => '边',
			'chat.tool.wfDeltaEmpty' => '仅改元数据(图未变)',
			'chat.tool.wfMorphNote' => '增量变换(图整体见实体面板)',
			'chat.tool.ctlOtherwise' => '否则',
			'chat.tool.ctlWhenTrue' => '兜底',
			'chat.tool.apfTimeoutNever' => '永不超时',
			'chat.tool.apfAllowReason' => '可填备注',
			'chat.tool.apfApprove' => '批准',
			'chat.tool.apfReject' => '拒绝',
			'chat.tool.apfPreviewHint' => '审批人将看到',
			'chat.tool.apfOnTimeout' => '超时 →',
			'chat.tool.memorizing' => '正在记忆',
			'chat.tool.memorized' => '已记忆',
			'chat.tool.recalling' => '正在回忆',
			'chat.tool.recalled' => '已回忆',
			'chat.tool.forgetting' => '正在遗忘',
			'chat.tool.forgot' => '已遗忘',
			'chat.tool.fetchingWeb' => '正在抓取',
			'chat.tool.fetchedWeb' => '已抓取',
			'chat.tool.searchingWeb' => '正在搜索',
			'chat.tool.searchedWeb' => '已搜索',
			'chat.tool.searchingTools' => '正在检索工具',
			'chat.tool.searchedTools' => '已检索工具',
			'chat.tool.memNotSaved' => '未保存',
			'chat.tool.memNotFound' => '未找到',
			'chat.tool.memAlreadyGone' => '本就不存在',
			'chat.tool.irreversible' => '不可逆',
			'chat.tool.webHits' => ({required Object n}) => '${n} 条',
			'chat.tool.webHitsPlus' => ({required Object n}) => '${n}+ 条',
			'chat.tool.webEmpty' => '无结果',
			'chat.tool.webEmptyBody' => '没有找到结果',
			'chat.tool.webNoBackend' => '未配置搜索',
			'chat.tool.webMisconfig' => '搜索 key 配置有误',
			'chat.tool.webProviderFail' => '搜索失败',
			'chat.tool.fetchChars' => ({required Object n}) => '${n} 字',
			'chat.tool.fetchEmpty' => '空页面',
			'chat.tool.fetchRawFallback' => '摘要不可用 · 附原文',
			'chat.tool.fetchJsShell' => 'JS 页面',
			'chat.tool.fetchFailed' => '抓取失败',
			'chat.tool.fetchRefused' => '已拒绝',
			'chat.tool.fetchAsk' => '问:',
			'chat.tool.toolsFound' => ({required Object n}) => '${n} 工具',
			'chat.tool.toolsNoMatch' => '无匹配',
			'chat.tool.toolSchema' => '参数 schema',
			'chat.tool.proseExpand' => '展开全文',
			'chat.tool.proseCollapse' => '收起',
			'chat.tool.grepFilter' => ({required Object p}) => '过滤 /${p}/',
			'chat.tool.docAutoRenamed' => '请求名被占,已自动改名',
			'chat.tool.skillNoRevert' => '整份覆盖 · 无版本可回退',
			'chat.tool.skillPreauth' => '激活后免危险确认(预授权)',
			'chat.tool.skillInline' => '内联',
			'chat.tool.skillFork' => '派生',
			'chat.tool.docSoftFail' => '未生效',
			'chat.tool.trgNotListening' => '未监听',
			'chat.tool.trgHotUpdate' => '热更新已生效',
			'chat.tool.trgCreateNote' => '创建不启动监听——active workflow 引用才开始听',
			'chat.tool.trgSecret' => '密钥',
			'chat.tool.trgEvery' => ({required Object n}) => '每 ${n} 秒',
			'chat.tool.trgCondition' => '条件',
			'chat.tool.trgOutput' => '输出',
			'chat.tool.searchingKind' => ({required Object kind}) => '正在搜索${kind}',
			'chat.tool.searchedKind' => ({required Object kind}) => '已搜索${kind}',
			'chat.tool.listingKind' => ({required Object kind}) => '正在列${kind}',
			'chat.tool.listedKind' => ({required Object kind}) => '已列${kind}',
			'chat.tool.hits' => ({required Object n}) => '${n} 个',
			'chat.tool.hitsOfTotal' => ({required Object n, required Object total}) => '${n}·共${total}',
			'chat.tool.emptyList' => '空',
			'chat.tool.hitCurrent' => '当前',
			'chat.tool.cappedFooter' => ({required Object n, required Object total}) => '前 ${n} · 共 ${total}',
			'chat.tool.serverTruncatedNote' => ({required Object n, required Object total}) => '前 ${n} · 共 ${total}(服务端截断)',
			'chat.tool.wfActive' => '活跃',
			'chat.tool.refCount' => ({required Object n}) => '${n} 处引用',
			'chat.tool.trgListening' => '监听中',
			'chat.tool.rawResult' => '原始返回',
			'chat.tool.contentTruncated' => '内容超长已截断——在实体面板看全文',
			'chat.tool.noActiveVersion' => '无活跃版本',
			'chat.tool.kvDescription' => '描述',
			'chat.tool.kvPath' => '路径',
			'chat.tool.kvSignature' => '签名',
			'chat.tool.kvDeps' => '依赖',
			'chat.tool.kvUpdated' => '更新',
			'chat.tool.kvMethods' => '方法',
			'chat.tool.kvModel' => '模型',
			'chat.tool.kvConcurrency' => '并发',
			'chat.tool.kvGraph' => '图',
			'chat.tool.kvContext' => '上下文',
			'chat.tool.kvSource' => '来源',
			'chat.tool.apfTimeout' => '超时',
			'chat.tool.apfBehavior' => '超时行为',
			'chat.tool.envFailedShort' => 'env failed',
			'chat.tool.envPending' => 'env pending',
			'chat.tool.skillPreauthNote' => 'allowedTools 激活后本次运行预授权免危险确认',
			'chat.tool.viewingKind' => ({required Object kind}) => '正在查看${kind}',
			'chat.tool.viewedKind' => ({required Object kind}) => '已查看${kind}',
			'chat.tool.kvTags' => '标签',
			'chat.tool.attachTruncated' => '已截断',
			'chat.tool.readingDoc' => '正在阅读文档',
			'chat.tool.readDoc' => '已阅读文档',
			'chat.tool.readingAtt' => '正在读取附件',
			'chat.tool.readAtt' => '已读取附件',
			'chat.tool.revertingKind' => ({required Object kind}) => '正在回退${kind}',
			'chat.tool.revertedKind' => ({required Object kind}) => '已回退${kind}',
			'chat.tool.deletingKind' => ({required Object kind}) => '正在删除${kind}',
			'chat.tool.deletedKind2' => ({required Object kind}) => '已删除${kind}',
			'chat.tool.staging' => '正在设为待命',
			'chat.tool.staged' => '已待命',
			'chat.tool.activatingWf' => '正在上线',
			'chat.tool.activatedWf' => '已上线',
			'chat.tool.deactivatingWf' => '正在下线',
			'chat.tool.deactivatedWf' => '已停监听',
			'chat.tool.killingWf' => '正在急停',
			'chat.tool.killedWf' => '已急停',
			'chat.tool.restarting' => '正在重启',
			'chat.tool.restartFailed' => '重启后未运行',
			'chat.tool.activatingSkill' => '正在激活技能',
			'chat.tool.activatedSkill' => '已激活技能',
			'chat.tool.movingDoc' => '正在移动文档',
			'chat.tool.movedDoc' => '已移动文档',
			'chat.tool.updatingMeta' => '正在更新信息',
			'chat.tool.updatedMeta' => '已更新信息',
			'chat.tool.renaming' => '正在改名',
			'chat.tool.renamed' => '已改名',
			'chat.tool.configuring' => '正在配置',
			'chat.tool.configured' => '已配置',
			'chat.tool.rewind' => ({required Object v}) => '↩ v${v}',
			'chat.tool.deletedShort' => '已删除',
			'chat.tool.depsAffected' => ({required Object n}) => '${n} 处引用受影响',
			'chat.tool.docDescendants' => ({required Object n}) => '已删除 · 含 ${n} 个后代',
			'chat.tool.movedTo' => ({required Object path}) => '→ ${path}',
			'chat.tool.killedN' => ({required Object n}) => '杀停 ${n} 个在途运行',
			'chat.tool.noInflight' => '无在途运行',
			'chat.tool.nKeys' => ({required Object n}) => '${n} 键',
			'chat.tool.staged2' => '候下一发真实触发',
			'chat.tool.listening2' => '监听中',
			'chat.tool.offline' => '已下线',
			'chat.tool.draining' => '排空中',
			'chat.tool.moreHits' => ({required Object n}) => '另有 ${n}',
			'chat.tool.noteRevertFn' => '仅还原代码/输入输出/依赖;名称·描述·标签不随版本',
			'chat.tool.noteRevertHd' => '已触发重启以运行新版本;内存态已清空——运行状态见 handler 面板',
			'chat.tool.noteRestart' => '内存态已清空',
			'chat.tool.noteKill' => '监听已停;被杀 run 状态=cancelled,可在 flowruns 里查',
			'chat.tool.noteStage' => '真实触发到来跑一次后自动解除',
			'chat.tool.noteDeleteDocSoft' => '软删除,可恢复',
			'chat.tool.noteConfig' => '已触发重启以生效;运行状态见 handler 面板',
			'chat.tool.noteMetaHandler' => '无新版本、无重启、内存态保全',
			'chat.tool.kvName' => '名称',
			'chat.tool.noteDraining' => '在途运行跑完即停;要立即中止用 kill_workflow',
			'chat.tool.cvArchiving' => '正在归档对话',
			'chat.tool.cvArchived' => '已归档对话',
			'chat.tool.cvUnarchiving' => '正在取消归档',
			'chat.tool.cvUnarchived' => '已取消归档',
			'chat.tool.cvPinning' => '正在置顶对话',
			'chat.tool.cvPinned' => '已置顶对话',
			'chat.tool.cvUnpinning' => '正在取消置顶',
			'chat.tool.cvUnpinned' => '已取消置顶',
			'chat.tool.cvRenaming' => '正在重命名对话',
			'chat.tool.cvRenamed' => '已重命名对话',
			'chat.tool.cvManaging' => '正在整理对话',
			'chat.tool.cvManaged' => '已整理对话',
			'chat.tool.cvListing' => '正在列出对话',
			'chat.tool.cvListed' => '已列出对话',
			'chat.tool.cvSearching' => '正在搜索对话',
			'chat.tool.cvSearched' => '已搜索对话',
			'chat.tool.cvCount' => ({required Object n}) => '${n} 条',
			'chat.tool.cvCountMore' => ({required Object n}) => '${n}+ 条',
			'chat.tool.cvEmpty' => '无对话',
			'chat.tool.cvHits' => ({required Object n}) => '${n} 命中',
			'chat.tool.cvNoMatch' => '无匹配',
			'chat.tool.cvMorePages' => '还有更多页',
			'chat.tool.cvArchivedBadge' => '已归档',
			'chat.tool.cvChunks' => ({required Object n}) => '×${n}',
			'chat.tool.cvShownOfTotal' => ({required Object n, required Object total}) => '显示前 ${n} 条 · 共 ${total} 命中',
			'chat.tool.cvStatusArchived' => '归档',
			'chat.tool.cvStatusPinned' => '置顶',
			'chat.tool.cvStatusTitle' => '标题',
			'chat.tool.cvAutoUnarchive' => '再发消息会自动取消归档',
			'chat.tool.bashBlocked' => '已拦截',
			'chat.tool.bashCancelled' => '已取消',
			'chat.tool.bashExitUnknown' => 'exit 未知',
			'chat.tool.bashBackground' => ({required Object id}) => '${id} · 后台',
			'chat.tool.statusRunning' => '运行中',
			'chat.tool.statusExited' => ({required Object code}) => '退出 ${code}',
			'chat.tool.statusKilled' => '已终止',
			'chat.tool.statusErrored' => '出错',
			'chat.tool.statusNotFound' => '会话不存在',
			'chat.tool.killFinished' => '已自行结束',
			'chat.tool.killNotFound' => '会话不存在',
			'chat.tool.polling' => '正在读取输出',
			'chat.tool.polled' => '已读取输出',
			'chat.tool.killing' => '正在终止',
			'chat.tool.killed3' => '已终止',
			'chat.tool.backToLatest' => '回到最新',
			'chat.tool.showEarlier' => ({required Object n}) => '显示更早 ${n} 行',
			'chat.tool.bashBgHint' => '用 BashOutput 轮询新输出,或 KillShell 终止',
			'chat.tool.bashHeadTruncated' => '输出过长,已弃头保尾',
			'chat.tool.bashNoOutput' => '(无输出)',
			'chat.tool.ranBg' => '已转入后台',
			'chat.tool.bashSessionGoneHint' => '可能已被终止 / 已清理 / 后端已重启',
			'chat.tool.bashNoNew' => '(无新输出)',
			'chat.tool.bashDropped' => ({required Object n}) => '丢弃 ${n} 字节(环缓冲溢出)',
			'chat.tool.fsNotFound' => '未找到',
			'chat.tool.fsDenied' => '无权限',
			'chat.tool.fsReadFirst' => '需先读',
			'chat.tool.fsNoMatch' => '未匹配',
			'chat.tool.fsAmbiguous' => ({required Object n}) => '${n} 处歧义',
			'chat.tool.fsModified' => '文件已变',
			'chat.tool.fsParentMissing' => '父目录缺',
			'chat.tool.fsBadPath' => '路径无效',
			'chat.tool.fsFailed' => '出错',
			'chat.tool.readRange' => ({required Object f, required Object l}) => '行 ${f}–${l}',
			'chat.tool.readFloor' => ({required Object n}) => '${n}+ 行',
			'chat.tool.readRangeFloor' => ({required Object f, required Object n}) => '行 ${f}–${n}+',
			'chat.tool.edited2' => ({required Object n}) => '${n} 处替换',
			'chat.tool.fsUnconfirmed' => '结果未确认',
			'chat.tool.emptyFile' => '空文件',
			'chat.tool.replaceAllNote' => ({required Object n}) => '${n} 处全部替换',
			'chat.tool.mcpCalling' => '正在调用 MCP 工具',
			'chat.tool.mcpCalled' => '已调用 MCP 工具',
			'chat.tool.mcpError' => 'MCP 错误',
			'chat.tool.hdCalling' => '正在调用方法',
			'chat.tool.hdCalled' => '已调用方法',
			'chat.tool.hdResult' => '返回',
			'chat.tool.lsEmpty' => '空目录',
			'chat.tool.globHeader' => ({required Object pattern, required Object root}) => '${pattern} 于 ${root}',
			'chat.tool.noReturn' => '无返回值',
			'chat.tool.execOk' => '运行成功',
			'chat.tool.execFailed' => '运行失败',
			'chat.tool.execLogs' => ({required Object n}) => '日志 · ${n} 行',
			'chat.tool.runningFn' => '正在运行函数',
			'chat.tool.ranFn' => '已运行函数',
			'chat.tool.callingMethod' => '正在调用方法',
			'chat.tool.calledMethod' => '已调用方法',
			'chat.tool.firingTrigger' => '正在触发',
			'chat.tool.firedTrigger' => '已触发',
			'chat.tool.fireActivation' => '活化',
			'chat.tool.firePayloadNote' => 'payload 恒为 {manual:true};扇出与处置见触发日志',
			'chat.tool.replayingRun' => '正在重放运行',
			'chat.tool.replayedRun' => '已重放运行',
			'chat.tool.triggeringWf' => '正在触发工作流',
			'chat.tool.triggeredWf' => '已触发工作流',
			'chat.tool.invokingAgent' => '正在调用智能体',
			'chat.tool.invokedAgent' => '已调用智能体',
			'chat.tool.agentSteps' => ({required Object n}) => '${n} 步',
			'chat.tool.agentTrajectoryNote' => '轨迹已流经,重载后于执行档案回放',
			'chat.tool.searchingFnExec' => '正在翻查函数执行',
			'chat.tool.searchedFnExec' => '已翻查函数执行',
			'chat.tool.searchingHdCalls' => '正在翻查处理器调用',
			'chat.tool.searchedHdCalls' => '已翻查处理器调用',
			'chat.tool.searchingAgentExec' => '正在翻查智能体执行',
			'chat.tool.searchedAgentExec' => '已翻查智能体执行',
			'chat.tool.searchingMcpCalls' => '正在翻查 MCP 调用',
			'chat.tool.searchedMcpCalls' => '已翻查 MCP 调用',
			'chat.tool.aggRollup' => ({required Object ok, required Object failed}) => '${ok} ✓ · ${failed} ✗',
			'chat.tool.aggNote' => '✗ 含取消/超时',
			'chat.tool.logNoRecords' => '无记录',
			'chat.tool.logNoMatch' => '无匹配',
			'chat.tool.byChat' => '对话',
			'chat.tool.byAgent' => '智能体',
			'chat.tool.byWorkflow' => '工作流',
			'chat.tool.byManual' => '手动',
			'chat.tool.searchingFlowruns' => '正在翻查运行',
			'chat.tool.searchedFlowruns' => '已翻查运行',
			'chat.tool.searchingFirings' => '正在翻查派发',
			'chat.tool.searchedFirings' => '已翻查派发',
			'chat.tool.searchingActivations' => '正在翻查活动',
			'chat.tool.searchedActivations' => '已翻查活动',
			'chat.tool.firingPending' => '等待',
			'chat.tool.firingStarted' => '已建 run',
			'chat.tool.firingSkipped' => '跳过',
			'chat.tool.firingSuperseded' => '被顶替',
			'chat.tool.firingShed' => '丢弃',
			'chat.tool.logCount' => ({required Object n}) => '${n} 条',
			'chat.tool.logCountMore' => ({required Object n}) => '${n}+ 条',
			'chat.tool.parkRunCaption' => 'park 在审批节点的 run,头仍为 running',
			'chat.tool.actReturnValue' => '返回值',
			'chat.tool.actFanout' => ({required Object n}) => '扇出 ${n}',
			'chat.tool.gettingFnExec' => '正在调阅函数执行档案',
			'chat.tool.gotFnExec' => '已调阅函数执行档案',
			'chat.tool.gettingHdCall' => '正在调阅处理器调用档案',
			'chat.tool.gotHdCall' => '已调阅处理器调用档案',
			'chat.tool.gettingMcpCall' => '正在调阅 MCP 调用档案',
			'chat.tool.gotMcpCall' => '已调阅 MCP 调用档案',
			'chat.tool.gettingActivation' => '正在调阅活动档案',
			'chat.tool.gotActivation' => '已调阅活动档案',
			'chat.tool.dossierStderr' => 'server stderr(可能早于本次调用)',
			'chat.tool.logOmitted' => ({required Object n}) => '…省略 ${n} 字符…',
			'chat.tool.fireYes' => '已 fire',
			'chat.tool.fireNo' => '未 fire',
			'chat.tool.gettingFlowrun' => '正在调阅运行',
			'chat.tool.gotFlowrun' => '已调阅运行',
			'chat.tool.gettingAgentExec' => '正在调阅智能体执行',
			'chat.tool.gotAgentExec' => '已调阅智能体执行',
			'chat.tool.transcriptSteps' => ({required Object n}) => '轨迹 · ${n} 步',
			'chat.tool.transcriptOpenFull' => '查看完整轨迹',
			'chat.tool.transcriptEmpty' => '无轨迹记录',
			'chat.tool.transcriptCapped' => ({required Object shown, required Object total}) => '显示 ${shown}/${total} 块',
			'chat.tool.transcriptThought' => '思考',
			'chat.tool.transcriptReply' => '回复',
			'chat.tool.spawningSubagent' => '正在派子代理',
			'chat.tool.spawnedSubagent' => '已派子代理',
			'chat.tool.subagentTask' => '任务',
			'chat.tool.subagentAnswer' => '回答',
			'chat.tool.subagentTraceNote' => '轨迹仅流不落盘——用 get_subagent_trace 回放',
			'chat.tool.gettingSubTrace' => '正在调阅子代理轨迹',
			'chat.tool.gotSubTrace' => '已调阅子代理轨迹',
			'chat.tool.subTraceRuns' => ({required Object n}) => '${n} 个子代理运行',
			'chat.tool.subTraceNoRuns' => '本对话无子代理运行',
			'chat.tool.todoWriting' => '正在更新任务清单',
			'chat.tool.todoWrote' => '已更新任务清单',
			'chat.tool.todoReading' => '正在读取任务清单',
			'chat.tool.todoRead' => '已读取任务清单',
			'chat.tool.todoRollup' => ({required Object total, required Object done}) => '${total} 项 · ${done} 完成',
			'chat.tool.todoCleared' => '清单已清空',
			'chat.tool.gettingRelations' => '正在查关系',
			'chat.tool.gotRelations' => '已查关系',
			'chat.tool.relCount' => ({required Object n}) => '${n} 条关系',
			'chat.tool.relNoEdges' => '无关系',
			'chat.tool.relArrow' => '→',
			'chat.tool.checkingCapability' => '正在体检工作流',
			'chat.tool.checkedCapability' => '已体检工作流',
			'chat.tool.capRunnable' => '结构可运行',
			'chat.tool.capProblems' => ({required Object n}) => '${n} 问题',
			'chat.tool.capWarnings' => ({required Object n}) => '${n} 警示',
			'chat.tool.capProblemsLabel' => '问题',
			'chat.tool.capWarningsLabel' => '警示',
			'chat.tool.capResolved' => '依赖已解析',
			'chat.tool.capStructural' => '结构有效',
			'chat.tool.installingMcp' => '正在安装 MCP 服务器',
			'chat.tool.installedMcp' => '已安装 MCP 服务器',
			'chat.tool.uninstallingMcp' => '正在卸载 MCP 服务器',
			'chat.tool.uninstalledMcp' => '已卸载 MCP 服务器',
			'chat.tool.reconnectingMcp' => '正在重连 MCP',
			'chat.tool.reconnectedMcp' => '已重连 MCP',
			'chat.tool.mcpConnected' => '已连接',
			'chat.tool.mcpDisconnected' => '未连接',
			'chat.tool.mcpToolCount' => ({required Object n}) => '${n} 工具',
			'chat.tool.mcpFailures' => ({required Object n}) => '${n} 次连续失败',
			'chat.tool.browsingMarket' => '正在浏览市场',
			'chat.tool.browsedMarket' => '已浏览市场',
			'chat.tool.marketCount' => ({required Object n}) => '${n} 个服务器',
			'chat.tool.mcpEnvRequired' => ({required Object n}) => '${n} 必填 env',
			'chat.tool.gettingModelConfig' => '正在读模型配置',
			'chat.tool.gotModelConfig' => '已读模型配置',
			'chat.tool.modelDefaults' => '默认模型',
			'chat.tool.modelKeys' => ({required Object n}) => '${n} 个密钥',
			'chat.tool.modelAvail' => ({required Object n}) => '${n} 个可用模型',
			'chat.tool.memSourceUser' => '你',
			'chat.tool.memSourceAi' => 'AI',
			'chat.tool.firingClaimed' => '已认领',
			'chat.gate.dangerBadge' => '危险',
			'chat.gate.awaitingDanger' => '等待你确认',
			'chat.gate.awaitingAsk' => '等待你回答',
			'chat.gate.approve' => '允许',
			'chat.gate.approveAlways' => '总是允许',
			'chat.gate.approveAlwaysHint' => ({required Object tool}) => '本对话内不再询问 ${tool}(重启即忘)',
			'chat.gate.deny' => '拒绝',
			'chat.gate.decline' => '不回答',
			'chat.gate.submit' => '发送',
			'chat.gate.answerPlaceholder' => '输入你的回答…',
			'chat.gate.decidedApproved' => '已允许',
			'chat.gate.decidedApprovedAlways' => '已允许 · 本对话总是',
			'chat.gate.decidedDenied' => '已拒绝',
			'chat.gate.decidedDeclined' => '已跳过',
			'chat.contextCompacted' => '上下文已压缩',
			'chat.contextCompactedCount' => ({required Object n}) => '上下文已压缩 · ${n} 条更早消息已折叠进摘要',
			'chat.stage.title' => '侧幕',
			'chat.stage.island' => '活动',
			'chat.stage.tasks' => '待办',
			_ => null,
		} ?? switch (path) {
			'chat.stage.expandAll' => '展开全部',
			'chat.stage.collapseAll' => '收起全部',
			'chat.stage.glanceTouched' => ({required Object n}) => '${n} 触点',
			'chat.stage.glanceExecuted' => ({required Object n}) => '${n} 执行',
			'chat.stage.glanceNeedsYou' => ({required Object n}) => '${n} 待你处理',
			'chat.stage.groupJustNow' => '刚刚',
			'chat.stage.groupEarlierToday' => '早些时候',
			'chat.stage.groupEarlier' => '更早',
			'chat.stage.following' => '跟随',
			'chat.stage.pinned' => '已锁定',
			'chat.stage.live' => '进行中',
			'chat.stage.settled' => '已落定',
			'chat.stage.failed' => '未保存',
			'chat.stage.backToLive' => '回到直播',
			'chat.stage.run.queued' => '已入队 · 聆听节点回报…',
			'chat.stage.run.done' => '运行完成',
			'chat.stage.run.failed' => '运行失败',
			'chat.stage.run.cancelled' => '运行已取消',
			'chat.stage.run.parked' => '等待审批',
			'chat.stage.a11y.staged' => ({required Object name}) => '${name} 登台',
			'chat.stage.a11y.gate' => 'AI 在等你决定',
			'chat.stage.a11y.failed' => '操作失败,舞台驻留',
			'chat.stage.a11y.settled' => ({required Object name}) => '${name} 已落定',
			'chat.stage.follow.label' => '自动登台',
			'chat.stage.follow.always' => '每次都跟',
			'chat.stage.follow.first' => '每会话首次',
			'chat.stage.follow.never' => '从不',
			'chat.stage.castEmpty' => '这场对话还没碰过什么',
			'chat.stage.castEmptyHint' => 'AI 创建、编辑或执行的东西会记在这里',
			'chat.stage.beforeEdit' => '改之前',
			'chat.stage.proseUntouched' => '本次未改动正文',
			'chat.stage.prefixKept' => ({required Object n}) => '前 ${n} 字与旧版一致 · 已快进',
			'chat.stage.fastForwarding' => '与旧版一致 · 快进中…',
			'chat.stage.wholeReplace' => ({required Object from, required Object to}) => '全量替换 · ${from} → ${to}',
			'chat.stage.latestDiscriminant' => '最新判别式',
			'chat.stage.basedOn' => ({required Object n}) => '基于 v${n} 起改',
			'chat.stage.elseFallback' => '否则',
			'chat.stage.passThrough' => '透传',
			'chat.stage.previewUnsent' => '预览 · 尚未寄出',
			'chat.stage.neverTimeout' => '永不超时',
			'chat.stage.timeoutReject' => ({required Object d}) => '${d} 后自动拒绝',
			'chat.stage.timeoutApprove' => ({required Object d}) => '${d} 后自动通过',
			'chat.stage.timeoutFail' => ({required Object d}) => '${d} 后置失败',
			'chat.stage.allowReason' => '审批者可附理由',
			'chat.stage.listening' => '监听中',
			'chat.stage.notListening' => '未监听',
			'chat.stage.nextFire' => ({required Object t}) => '下次点火 · ${t}',
			'chat.stage.refCountWord' => ({required Object n}) => '被 ${n} 条 workflow 引用',
			'chat.stage.awaitingReceipt' => '等待回执…',
			'chat.stage.oldLadder' => '改之前的梯',
			'chat.stage.subagentUnnamed' => '子代理',
			'chat.stage.delegated' => '委派',
			'chat.stage.skillArgs' => '参数',
			'chat.stage.skillTools' => '工具',
			'chat.stage.tokensInOut' => ({required Object tin, required Object tout}) => '${tin} 入 · ${tout} 出',
			'chat.stage.stopReasonWord' => ({required Object r}) => '止因 ${r}',
			'chat.stage.ensembleTitle' => '并行群像',
			'chat.stage.boardOf' => ({required Object name}) => '${name} 的清单',
			'chat.stage.humanOnly' => '仅人可唤',
			'chat.stage.toolsDiscovered' => '个工具已发现',
			'chat.stage.cfgReady' => '配置就绪',
			'chat.stage.cfgPending' => '配置待建',
			'chat.stage.rtRunning' => '运行中',
			'chat.stage.rtCrashed' => '已崩溃',
			'chat.stage.rtStopped' => '已停止',
			'appName' => 'Anselm',
			'status.idle' => '空闲',
			'status.run' => '运行中',
			'status.wait' => '等待',
			'status.err' => '失败',
			'status.done' => '完成',
			'run.runCompleted' => '完成',
			'run.failed' => '失败',
			'run.agentTimeout' => '超时',
			'run.runCancelled' => '已取消',
			'run.runStillFailed' => '仍失败',
			'run.runAwaitApproval' => '等待审批',
			'run.runStatusRunning' => '运行中',
			'run.replayPinNote' => '用原 pin 版本重跑,事后修的代码不生效',
			'run.replayTimes' => ({required Object n}) => '第 ${n} 次重放',
			'run.flowShown' => ({required Object shown, required Object total}) => '显示 ${shown}/${total} 节点',
			'run.nodeCount' => ({required Object n}) => '${n} 节点',
			'run.nodeWait' => '等待',
			'run.beadPageScope' => '本页',
			'run.provConversation' => '对话',
			'run.provTrigger' => '触发器',
			'run.provFlowrun' => '运行',
			'run.provMessage' => '消息',
			'run.provFiring' => '派发',
			'run.provNode' => '节点',
			'run.emptyPayload' => '空 payload',
			'run.triggerStartedNote' => '已启动运行——用 get_flowrun 看进展',
			'run.ioInput' => '输入',
			'run.ioOutput' => '输出',
			'run.countdownLeft' => ({required Object d}) => '剩 ${d}',
			'run.countdownOverdue' => '已超时',
			'run.approvalTitle' => '等待审批',
			'run.approve' => '通过',
			'run.reject' => '驳回',
			'run.approvalHint' => 'first-wins:先到的决断生效。',
			'run.reasonHint' => '备注(可选)',
			'run.addReason' => '+ 理由',
			'run.inferredRunning' => '推测执行中',
			'run.approveAll' => '全部批准',
			'run.rejectAll' => '全部拒绝',
			'run.batchApproveTitle' => ({required Object n}) => '批准全部 ${n} 项?',
			'run.batchRejectTitle' => ({required Object n}) => '拒绝全部 ${n} 项?',
			'run.batchDecideBody' => ({required Object list}) => '以下审批将被处理(先到的决断生效):\n${list}',
			'run.sumApproved' => ({required Object n}) => '已批准 ${n} 项',
			'run.sumRejected' => ({required Object n}) => '已拒绝 ${n} 项',
			'run.sumLost' => ({required Object n}) => '${n} 项已被别处处理',
			'run.sumFailed' => ({required Object n}) => '${n} 项失败',
			'scheduler.railErrorTitle' => 'workflow 加载失败',
			'scheduler.railErrorHint' => '后端没有应答,检查连接后重试。',
			'scheduler.retry' => '重试',
			'scheduler.overviewTitle' => '总览',
			'scheduler.underConstruction' => 'Scheduler 指挥中心建设中(S1–S5)。',
			'scheduler.runningFor' => ({required Object d}) => '运行中 · ${d}',
			'scheduler.nextFireIn' => ({required Object d}) => '${d} 后',
			'scheduler.agoMeta' => ({required Object d}) => '${d} 前',
			'scheduler.neverRan' => '—',
			'scheduler.sectionNeverRan' => '未运行',
			'scheduler.sectionInactive' => '停用',
			'scheduler.filterPlaceholder' => '搜索…',
			'scheduler.sortLabel' => '排序',
			'scheduler.sortActivity' => '最近活动',
			'scheduler.sortName' => '名称',
			'scheduler.displayLabel' => '显示',
			'scheduler.showNextFire' => '显示下次触发',
			'scheduler.showLastRun' => '显示上次运行',
			'scheduler.showInactive' => '显示停用',
			'scheduler.overview.kpiRunning' => '在跑',
			'scheduler.overview.kpiRunningA11y' => ({required Object n}) => '在跑 ${n} 个。在「正在跑」列表中显示它们。',
			'scheduler.overview.kpiWaiting' => '等你',
			'scheduler.overview.kpiWaitingA11y' => ({required Object n}) => '等你处理 ${n} 条。在「等你处理」列表中显示它们。',
			'scheduler.overview.kpiFailed24h' => '24h 失败',
			'scheduler.overview.kpiFailed24hA11y' => ({required Object n}) => '近 24h 失败 ${n} 次。在失败 run 列表中显示它们。',
			'scheduler.overview.kpiNextFire' => '下次调度',
			'scheduler.overview.kpiNextFireA11y' => ({required Object d}) => '下次调度在 ${d} 后。在调度轨上显示它。',
			'scheduler.overview.kpiNone' => '—',
			'scheduler.overview.fireIn' => ({required Object d}) => '${d} 后',
			'scheduler.overview.deltaUp' => ({required Object n}) => '▲${n}',
			'scheduler.overview.deltaDown' => ({required Object n}) => '▼${n}',
			'scheduler.overview.deltaUpA11y' => ({required Object n}) => '较前一个 24h 多 ${n}',
			'scheduler.overview.deltaDownA11y' => ({required Object n}) => '较前一个 24h 少 ${n}',
			'scheduler.overview.runningHead' => '正在跑',
			'scheduler.overview.runningEmpty' => '现在没有正在运行的 run。',
			'scheduler.overview.failuresSegmentHead' => '失败',
			'scheduler.overview.failed24hHead' => '近 24 小时',
			'scheduler.overview.trackTruncated' => '此窗口内还有更多调度,轨道未能全部显示。',
			'scheduler.overview.failuresHead' => '连续失败 · 7d',
			'scheduler.overview.failuresEmpty' => '近 7 天没有连续失败的 workflow。',
			'scheduler.overview.streak' => ({required Object n}) => '连败 ×${n}',
			'scheduler.overview.openWorkflow' => '打开 workflow →',
			'scheduler.overview.waitingHead' => '等你处理',
			'scheduler.overview.waitingEmpty' => '没有等你处理的审批。',
			'scheduler.overview.waitedFor' => ({required Object d}) => '等 ${d}',
			'scheduler.overview.selectRow' => ({required Object name}) => '选择 ${name}',
			'scheduler.overview.alreadyHandled' => '已被别处处理',
			'scheduler.overview.alreadyFinished' => 'run 已自行结束',
			'scheduler.overview.cancelConfirmTitle' => '取消这个 run?',
			'scheduler.overview.cancelConfirmBody' => ({required Object name, required Object id}) => '将取消 ${name} · ${id};parked 审批一并收回。',
			'scheduler.overview.cancelConfirmAction' => '取消 run',
			'scheduler.overview.cancelKeep' => '先不取消',
			'scheduler.overview.cancelRunA11y' => ({required Object id}) => '取消 run ${id}',
			'scheduler.overview.batchApprove' => '批量批准',
			'scheduler.overview.batchReject' => '批量拒绝',
			'scheduler.overview.batchCancel' => '批量取消',
			'scheduler.overview.batchRejectConfirm' => ({required Object n}) => '拒绝 ${n} 条',
			'scheduler.overview.batchCancelTitle' => ({required Object n}) => '将取消这 ${n} 个 run?',
			'scheduler.overview.batchCancelBody' => ({required Object list}) => '以下 run 将被取消;parked 审批一并收回:\n${list}',
			'scheduler.overview.sumApproved' => ({required Object n}) => '已批准 ${n}',
			'scheduler.overview.sumRejected' => ({required Object n}) => '已拒绝 ${n}',
			'scheduler.overview.sumCancelled' => ({required Object n}) => '已取消 ${n}',
			'scheduler.overview.sumLost' => ({required Object n}) => '${n} 条已被别处处理',
			'scheduler.overview.sumEnded' => ({required Object n}) => '${n} 条已自行结束',
			'scheduler.overview.sumFailed' => ({required Object n}) => '${n} 条失败',
			'scheduler.overview.firstUseTitle' => '第一个自动化还没建',
			'scheduler.overview.firstUseBody' => '去 Entities 建一个 workflow 并挂上 cron;或者直接在对话里说「每天早上八点抓数据发我」。',
			'scheduler.overview.firstUseEntities' => '去 Entities',
			'scheduler.overview.firstUseChat' => '打开对话',
			'scheduler.overview.errorTitle' => '总览加载失败',
			'scheduler.overview.errorHint' => '后端没有应答,检查连接后重试。',
			'scheduler.overview.scheduleHead' => '调度',
			'scheduler.overview.scheduleEmpty' => '没有装备任何 cron 排程。',
			'scheduler.overview.kpiMissed' => '24h 错过',
			'scheduler.overview.kpiMissedA11y' => ({required Object n}) => '24h 错过 ${n} 次。在时间轴上看它们。',
			'scheduler.overview.trackPastTruncated' => ({required Object at}) => '早于 ${at} 的触发未显示——账目不止一页。',
			'scheduler.overview.trackNextIn' => ({required Object d}) => '(${d} 后)',
			'scheduler.overview.trackCardHead' => ({required Object at, required Object n}) => '${at} · 共 ${n} 次',
			'scheduler.overview.trackCardMissed' => ({required Object at}) => '错过 ${at}',
			'scheduler.overview.trackCardMore' => ({required Object n}) => '还有 ${n} 次',
			'scheduler.overview.trackCardMoreOk' => '全部成功',
			'scheduler.overview.trackCardMoreFailed' => ({required Object m}) => '含 ${m} 次失败',
			'scheduler.overview.trackCardNext' => ({required Object at, required Object schedule}) => '下一发 ${at} · ${schedule}',
			'scheduler.overview.trackCardNextBare' => ({required Object at}) => '下一发 ${at}',
			'scheduler.overview.trackBinA11y' => ({required Object hour, required Object n, required Object ok, required Object fail}) => '${hour} 时,${n} 次:${ok} 成 ${fail} 败',
			'scheduler.overview.trackBinMissedClause' => ({required Object x}) => ',含 ${x} 次错过',
			'scheduler.overview.trackBinEmptyA11y' => ({required Object hour}) => '${hour} 时,无运行',
			'scheduler.overview.trackFutureA11y' => ({required Object at, required Object schedule}) => '下一发 ${at},${schedule}',
			'scheduler.overview.trackLaneSummaryA11y' => ({required Object name, required Object n, required Object ok, required Object fail, required Object missed, required Object next}) => '${name},24 小时 ${n} 次运行:${ok} 成 ${fail} 败,错过 ${missed} 次;下一次 ${next}',
			'scheduler.status.active' => '生效',
			'scheduler.status.draining' => '收尾中',
			'scheduler.status.inactive' => '停用',
			'scheduler.home.notFoundTitle' => '找不到该 workflow',
			'scheduler.home.notFoundHint' => '它可能已被删除。从左侧选择另一个 workflow。',
			'scheduler.home.moreA11y' => '更多操作',
			'scheduler.home.runNow' => '立即运行',
			'scheduler.home.runNowStarted' => ({required Object id}) => '已开跑 · ${id}',
			'scheduler.home.menuEdit' => '去 Entities 编辑',
			'scheduler.home.menuKill' => '终止 workflow…',
			'scheduler.home.killTitle' => '终止这个 workflow',
			'scheduler.home.killWarning' => ({required Object n}) => '将取消 ${n} 个在途 run。',
			'scheduler.home.killBody' => '停止监听、取消所有在途 run,并停用该 workflow。',
			'scheduler.home.killHint' => ({required Object name}) => '输入 ${name} 以确认',
			'scheduler.home.killConfirm' => '终止 workflow',
			'scheduler.home.killed' => 'workflow 已终止',
			'scheduler.home.statsLine' => ({required Object rate, required Object avg}) => '成功率 ${rate} · 均时 ${avg}',
			'scheduler.home.runsHead' => '运行',
			'scheduler.home.runsError' => '运行记录加载失败。',
			'scheduler.home.runsEmpty' => '没有匹配此过滤的运行。',
			'scheduler.home.pagerPrev' => '上一页',
			'scheduler.home.pagerNext' => '下一页',
			'scheduler.home.pagerJump' => '页码',
			'scheduler.home.pagerPage' => ({required Object n}) => '第 ${n} 页',
			'scheduler.home.pagerJumpTo' => ({required Object n}) => '跳转到第 ${n} 页',
			'scheduler.home.filterA11y' => '按状态过滤运行',
			'scheduler.home.filterAll' => '全部',
			'scheduler.home.filterRunning' => ({required Object n}) => '在跑 ${n}',
			'scheduler.home.filterFailed' => ({required Object n}) => '失败 ${n}',
			'scheduler.home.filterWaiting' => ({required Object n}) => '等人 ${n}',
			'scheduler.home.originAll' => '全部来源',
			'scheduler.home.originManual' => '手动',
			'scheduler.home.originChat' => '对话',
			'scheduler.home.originCron' => 'cron',
			'scheduler.home.originWebhook' => 'webhook',
			'scheduler.home.originFsnotify' => '文件监听',
			'scheduler.home.originSensor' => '传感器',
			'scheduler.home.newRuns' => ({required Object n}) => '${n} 条新运行',
			'scheduler.home.srcManual' => '手动',
			'scheduler.home.srcChat' => '对话',
			'scheduler.home.srcCronBare' => 'cron',
			'scheduler.home.srcWebhookBare' => 'webhook',
			'scheduler.home.srcWithName' => ({required Object kind, required Object name}) => '${kind} · ${name}',
			'scheduler.home.srcUnknown' => '未知来源',
			'scheduler.home.replayTitle' => '重放这个 run?',
			'scheduler.home.replayBody' => ({required Object failed, required Object completed}) => '重跑 ${failed} 个失败节点 · 复用 ${completed} 个已完成结果。',
			'scheduler.home.replayBodyUnknown' => '重跑失败节点;已完成结果按记忆化复用。',
			'scheduler.home.replayAction' => '重放',
			'scheduler.home.replayed' => '重放已开始',
			'scheduler.home.notReplayable' => '该 run 已不可重放',
			'scheduler.home.batchReplay' => '批量重放',
			'scheduler.home.batchReplayTitle' => ({required Object n}) => '重放 ${n} 个 run?',
			'scheduler.home.batchReplayBody' => ({required Object failed, required Object completed}) => '共重跑 ${failed} 个失败节点 · 复用 ${completed} 个已完成结果。',
			'scheduler.home.sumReplayed' => ({required Object n}) => '已重放 ${n}',
			'scheduler.home.sumNotReplayable' => ({required Object n}) => '${n} 个已不可重放',
			'scheduler.home.faceA11y' => '速览卡视图',
			'scheduler.home.faceGantt' => '甘特',
			'scheduler.home.faceGraph' => '图',
			'scheduler.home.matrixTitle' => '节点 × 运行',
			'scheduler.home.matrixView' => '矩阵视图',
			'scheduler.home.matrixEmpty' => '这段时间没有运行。',
			'scheduler.home.matrixNotReached' => '未及',
			'scheduler.home.matrixRunning' => '在跑',
			'scheduler.home.matrixColA11y' => ({required Object src, required Object status, required Object d}) => '运行 ${src},${status},${d}',
			'scheduler.home.matrixRowA11y' => ({required Object node}) => '节点 ${node},历史',
			'scheduler.home.matrixCellA11y' => ({required Object node, required Object status, required Object n}) => '${node},${status},${n} 轮',
			'scheduler.home.openRun' => '打开 →',
			'scheduler.home.noGraph' => '活跃版本没有图。',
			'scheduler.home.paneNoNodes' => '还没有节点记录。',
			'scheduler.home.notRun' => '未运行',
			'scheduler.home.paneError' => '本次运行加载失败。',
			'scheduler.home.triggersHead' => '触发器',
			'scheduler.home.triggersEmpty' => '该 workflow 没有挂任何触发器。',
			'scheduler.home.paused' => '已暂停',
			'scheduler.home.pause' => '暂停',
			'scheduler.home.resume' => '恢复',
			'scheduler.home.pauseTitle' => ({required Object name}) => '暂停「${name}」?',
			'scheduler.home.pauseBody' => '暂停后不再产生新 firing;在途 run 不受影响。',
			'scheduler.home.pauseAction' => '暂停',
			'scheduler.home.nextFire' => ({required Object d, required Object at}) => '下次 ${d} 后(${at})',
			'scheduler.home.lastFired' => ({required Object d}) => '上次 ${d} 前',
			'scheduler.home.neverFired' => '从未触发',
			'scheduler.home.editTriggerA11y' => ({required Object name}) => '去 Entities 编辑触发器 ${name}',
			'scheduler.home.matrixRowSummaryA11y' => ({required Object node, required Object r, required Object total, required Object n, required Object failed}) => '${node},第 ${r} 行 共 ${total} 行,${n} 次运行抵达,${failed} 次失败',
			'scheduler.home.matrixCoordA11y' => ({required Object r, required Object rows, required Object c, required Object cols}) => '第 ${r} 行 共 ${rows} 行,第 ${c} 列 共 ${cols} 列',
			'scheduler.home.crumbRoot' => '调度',
			'scheduler.home.rowCancel' => '终止',
			'scheduler.home.rowRetry' => '重试',
			'scheduler.run.notFoundTitle' => '找不到这次运行',
			'scheduler.run.notFoundHint' => '它可能已被保留策略清理。从 workflow 里另选一次运行。',
			'scheduler.run.errorTitle' => '这次运行加载失败',
			'scheduler.run.errorHint' => '后端没有响应。检查连接后重试。',
			'scheduler.run.orphanBadge' => '宿主已删除',
			'scheduler.run.pinnedVersion' => '钉版',
			'scheduler.run.graphNotPinned' => '取不到这次运行的钉版——下面这张图是 workflow 当前的图,可能与本次实际走过的不同。',
			'scheduler.run.queuedFor' => ({required Object d}) => '排队 ${d}',
			'scheduler.run.execFor' => ({required Object d}) => '执行 ${d}',
			'scheduler.run.queueWord' => '排队',
			'scheduler.run.execWord' => '执行',
			'scheduler.run.replay' => '重放',
			'scheduler.run.cancel' => '取消运行',
			'scheduler.run.triage' => 'AI 诊断',
			'scheduler.run.triageFailed' => '诊断对话没能打开',
			'scheduler.run.graphHead' => '流转',
			'scheduler.run.graphHeadPinned' => '流转(钉版)',
			'scheduler.run.graphEmpty' => '取不到这次运行的拓扑——钉版读不出,workflow 也没有当前的图。',
			'scheduler.run.ganttHead' => '甘特',
			'scheduler.run.ganttEmpty' => '这次运行还没有可排上时间轴的节点。',
			'scheduler.run.ganttNoSpan' => '所有节点落在同一毫秒内——条只表示顺序,不表示时长。',
			'scheduler.run.notRun' => '未及',
			'scheduler.run.ledgerHead' => '节点台账',
			'scheduler.run.ledgerEmpty' => '还没有节点落定。',
			'scheduler.run.dossierTitle' => '运行卷宗',
			'scheduler.run.kvStatus' => '状态',
			'scheduler.run.inspectorTitle' => '检查器',
			'scheduler.run.glanceNextFire' => ({required Object d}) => '下次点火 ${d} 后',
			'scheduler.run.glanceSuccess' => ({required Object pct}) => '近 7 天 ${pct}% 成功',
			'scheduler.run.glanceStreak' => ({required Object n}) => '连败 ${n}',
			'scheduler.run.payloadHead' => '入口 payload',
			'scheduler.run.pinnedRefsHead' => '钉住的引用',
			'scheduler.run.errorHead' => '错误',
			'scheduler.run.replayHistory' => ({required Object n}) => '已重放 ×${n}',
			'scheduler.run.replayNever' => '从未重放',
			'scheduler.run.iterationPick' => '迭代',
			'scheduler.run.execLogHead' => '执行日志',
			'scheduler.run.execLogOpen' => ({required Object id}) => '打开 ${id}',
			'scheduler.run.noSelection' => '点一个节点来查看它。',
			'scheduler.run.nodeIn' => '输入',
			'scheduler.run.nodeOut' => '输出',
			'scheduler.run.nodeNoIo' => '这个节点没有记录结果。',
			'scheduler.run.replayNode' => '重放失败节点',
			'scheduler.run.relayResolving' => '正在定位这次运行…',
			'scheduler.run.relayFailedTitle' => '解析不出这次运行',
			'scheduler.run.relayFailedHint' => '本工作区没有这个 id 的运行。检查 id,或从某个 workflow 里选一次运行。',
			'scheduler.run.closeA11y' => '关闭本次运行页',
			'scheduler.range.today' => '今天',
			'scheduler.range.h24' => '近 24 小时',
			'scheduler.range.d7' => '近 7 天',
			'scheduler.range.d30' => '近 30 天',
			'scheduler.range.all' => '全部',
			'scheduler.range.customTitle' => '自定义范围',
			'scheduler.range.from' => '从',
			'scheduler.range.to' => '到',
			'scheduler.range.apply' => '应用',
			'scheduler.range.endBeforeStart' => '终点早于起点',
			'scheduler.range.weekdays' => '一 二 三 四 五 六 日',
			'scheduler.range.monthTitle' => ({required Object y, required Object m}) => '${y} 年 ${m}',
			'scheduler.range.months' => '1 月,2 月,3 月,4 月,5 月,6 月,7 月,8 月,9 月,10 月,11 月,12 月',
			'scheduler.range.prevMonth' => '上个月',
			'scheduler.range.nextMonth' => '下个月',
			'scheduler.range.backToPresets' => '返回快捷范围',
			'scheduler.range.backToToday' => '回到今天',
			'scheduler.range.preciseTime' => '精确到时刻',
			'scheduler.range.dayText' => ({required Object m, required Object d}) => '${m} 月 ${d} 日',
			'scheduler.range.dayTextYear' => ({required Object y, required Object m, required Object d}) => '${y} 年 ${m} 月 ${d} 日',
			'scheduler.range.capsuleA11y' => '时间范围',
			'scheduler.range.gridA11y' => '日历',
			'action.edit' => '编辑',
			'action.cancel' => '取消',
			'action.save' => '保存',
			'action.copy' => '复制',
			'action.expand' => '展开',
			'action.collapse' => '收起',
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
			'feedback.showAll' => ({required Object n}) => '展开其余 ${n} 个',
			'feedback.copyFailed' => '复制失败',
			'feedback.batch.selected' => ({required Object n}) => '已选 ${n}',
			'feedback.batch.clear' => '清除选择',
			'feedback.retry' => '重试',
			'feedback.cast.ribbonLive' => '实时聆听中 · 落定以真相为准',
			'feedback.cast.ribbonGap' => '实时流有缺口 · 以执行记录为准',
			'feedback.cast.ribbonFailed' => '草稿未保存 · 真相仍是上一版',
			'feedback.cast.gatePill' => 'AI 在等你决定 →',
			'feedback.cast.livePill' => ({required Object name}) => 'AI 正在编辑 ${name} →',
			'feedback.cast.tombstone' => '已删除',
			'feedback.cast.goToEntity' => '去实体页',
			'feedback.cast.jumpToScene' => '跳到发生处',
			'feedback.cast.verb.mentioned' => '提及',
			'feedback.cast.verb.created' => '创建',
			'feedback.cast.verb.edited' => '编辑',
			'feedback.cast.verb.viewed' => '查看',
			'feedback.cast.verb.executed' => '执行',
			'feedback.cast.verb.attached' => '附上',
			'feedback.cast.verb.deleted' => '删除',
			'feedback.cast.verb.unknown' => '触碰',
			'shell.collapseSidebar' => '收起侧栏',
			'shell.expandSidebar' => '展开侧栏',
			'shell.togglePanel' => '切换面板',
			'shell.ocean.chat' => '对话',
			'shell.ocean.entities' => '实体',
			'shell.ocean.scheduler' => '调度',
			'shell.ocean.documents' => '文档',
			'shell.comingSoonTitle' => '即将推出',
			'shell.comingSoonHint' => '该海洋尚未构建。',
			'shell.settings' => '设置',
			'shell.notifications' => '通知',
			'shell.workspaceFallback' => '工作区',
			'shell.newWorkspace' => '新建工作区',
			'shell.workspaceSettings' => '工作区设置',
			'notifications.title' => '通知',
			'notifications.needsYou' => '待你处理',
			'notifications.feed' => '通知',
			'notifications.markAllRead' => '全部已读',
			'notifications.markAllUnread' => '全部未读',
			'notifications.markRead' => '标为已读',
			'notifications.searchPlaceholder' => '搜索通知…',
			'notifications.unreadOnly' => '仅显示未读',
			'notifications.displayOptions' => '显示',
			'notifications.today' => '今天',
			'notifications.yesterday' => '昨天',
			'notifications.earlier' => '更早',
			'notifications.unknown' => '有新动态',
			'notifications.kind.memory' => '记忆',
			'notifications.kind.sandbox' => '环境',
			'notifications.kind.relation' => '依赖',
			'notifications.verb.created' => '已创建',
			'notifications.verb.edited' => '已编辑',
			'notifications.verb.reverted' => '已回滚',
			'notifications.verb.updated' => '已更新',
			'notifications.verb.deleted' => '已删除',
			'notifications.verb.envRebuilt' => '环境已重建',
			'notifications.verb.configUpdated' => '配置已更新',
			'notifications.verb.configCleared' => '配置已清空',
			'notifications.verb.installed' => '已安装',
			'notifications.verb.removed' => '已移除',
			'notifications.verb.reconnected' => '已重连',
			'notifications.verb.reconnectFailed' => '重连失败',
			'notifications.verb.crashed' => '崩溃了',
			'notifications.verb.restartFailed' => '重启失败',
			'notifications.verb.runFailed' => '运行失败',
			'notifications.verb.needsAttention' => '需要关注',
			'notifications.verb.recovered' => '已恢复',
			'notifications.verb.waitingApproval' => '等待审批',
			'notifications.verb.envReady' => '环境就绪',
			'notifications.verb.envFailed' => '环境构建失败',
			'notifications.depBrokenOne' => '删除后留下 1 处悬空引用',
			'notifications.depBrokenMany' => ({required Object n}) => '删除后留下 ${n} 处悬空引用',
			'notifications.view' => '查看',
			'notifications.errorTitle' => '通知加载失败',
			'notifications.errorHint' => '本地引擎没有返回通知列表。',
			'notifications.retry' => '重试',
			'notifications.nameQuoted' => ({required Object name}) => '「${name}」',
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
			'graph.kind.trigger' => '触发',
			'graph.kind.action' => '动作',
			'graph.kind.agent' => '智能体',
			'graph.kind.control' => '分支',
			'graph.kind.approval' => '审批',
			'graph.kind.unknown' => '未知',
			'a11y.flagYes' => '是',
			'a11y.flagNo' => '否',
			'a11y.editingField' => ({required Object field}) => '正在编辑 ${field}',
			'a11y.editField' => ({required Object field}) => '编辑 ${field}',
			'a11y.addTagTo' => ({required Object field}) => '添加标签:${field}',
			'a11y.displayOptions' => '显示选项',
			'a11y.moreActions' => '更多操作',
			'a11y.newSubpage' => '新建子页面',
			'a11y.graphZoomIn' => '放大',
			'a11y.graphZoomOut' => '缩小',
			'a11y.graphFit' => '适应画布',
			'a11y.graphNode' => ({required Object id, required Object kind, required Object ref}) => '节点 ${id},${kind},${ref}',
			'a11y.codeBlock' => ({required Object lang, required Object lines}) => '代码块,${lang},${lines} 行',
			'a11y.codeBlockPlain' => ({required Object lines}) => '代码块,${lines} 行',
			'a11y.jsonTree' => ({required Object count}) => 'JSON 树,${count} 项',
			'a11y.diff' => ({required Object added, required Object removed}) => '差异,新增 ${added},删除 ${removed}',
			'a11y.loading' => '加载中',
			'a11y.timeoutBudget' => '时限',
			'a11y.fmtBold' => '加粗',
			'a11y.fmtItalic' => '斜体',
			'a11y.fmtStrike' => '删除线',
			'a11y.fmtCode' => '行内代码',
			'a11y.fmtLink' => '链接',
			'a11y.relationSummary' => ({required Object nodes, required Object edges}) => '关系图。${nodes} 个实体，${edges} 条关系。',
			'a11y.relationNode' => ({required Object name, required Object kind, required Object count}) => '${name}，${kind}，被 ${count} 个实体引用',
			'a11y.relationExpand' => '展开关系图',
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
			_ => null,
		} ?? switch (path) {
			'entities.filter' => '搜索实体…',
			'entities.errorTitle' => '无法加载实体',
			'entities.errorHint' => '本地引擎没有返回实体列表。',
			'entities.retry' => '重试',
			'entities.selectTitle' => '选择一个实体',
			'entities.selectHint' => '从左侧选择一个函数、处理器、智能体或工作流。',
			'entities.sortLabel' => '排序',
			'entities.sortRecent' => '最近活跃',
			'entities.sortCreated' => '最近创建',
			'entities.sortName' => '名称',
			'entities.displayLabel' => '显示',
			'entities.showCount' => '显示分组计数',
			'entities.detail.crumbRoot' => '实体',
			'entities.detail.tab.overview' => '概览',
			'entities.detail.tab.versions' => '版本',
			'entities.detail.tab.logs' => '日志',
			'entities.detail.tab.runs' => '运行',
			'entities.detail.tab.activity' => '活动',
			'entities.detail.tab.dispatch' => '派发',
			'entities.detail.verb.run' => '运行',
			'entities.detail.verb.call' => '调用',
			'entities.detail.verb.invoke' => '唤起',
			'entities.detail.verb.trigger' => '触发',
			'entities.detail.hero.envStatus' => ({required Object status}) => 'env ${status}',
			'entities.detail.hero.noInputs' => '无入参',
			'entities.detail.hero.methods' => ({required Object n}) => '${n} 个方法',
			'entities.detail.hero.deps' => ({required Object n}) => '${n} 依赖',
			'entities.detail.gate.config' => 'config',
			'entities.detail.gate.env' => 'env',
			'entities.detail.gate.instance' => 'instance',
			'entities.detail.codeToggle.expand' => ({required Object n}) => '展开全部 (${n} 行)',
			'entities.detail.codeToggle.collapse' => '收起',
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
			'entities.detail.sec.branches' => '路由分支',
			'entities.detail.sec.template' => '审批模板',
			'entities.detail.sec.decisionRules' => '决策规则',
			'entities.detail.sec.config' => '配置',
			'entities.detail.sec.listener' => '监听',
			'entities.detail.sec.firePayload' => 'Fire 载荷',
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
			'entities.detail.graph.unparseable' => '编排图无法解析',
			'entities.detail.cockpit.runs' => '运行',
			'entities.detail.cockpit.runsCount' => ({required Object n}) => '运行 · ${n} 次',
			'entities.detail.cockpit.nodeGantt' => '节点甘特',
			'entities.detail.cockpit.notRun' => '未运行',
			'entities.detail.cockpit.waitingApproval' => '等待审批',
			'entities.detail.cockpit.noRuns' => '尚无运行',
			'entities.detail.cockpit.noRunsHint' => '触发此工作流后这里会列出每次运行',
			'entities.detail.cockpit.runGraph' => '运行图',
			'entities.detail.cockpit.nodeDetail' => ({required Object id}) => '节点 · ${id}',
			'entities.detail.cockpit.replay' => '重跑',
			'entities.detail.cockpit.kill' => '终止',
			'entities.detail.cockpit.runInfo' => '运行信息',
			'entities.detail.cockpit.iteration' => ({required Object n}) => '轮次 ${n}',
			'entities.detail.kv.name' => '名称',
			'entities.detail.kv.tags' => '标签',
			'entities.detail.kv.id' => 'ID',
			'entities.detail.kv.activeVersion' => '活动版本',
			'entities.detail.kv.currentVersion' => '当前版本',
			'entities.detail.kv.python' => 'Python',
			'entities.detail.kv.updated' => '更新',
			'entities.detail.kv.desc' => '说明',
			'entities.detail.kv.allowReason' => '允许备注',
			'entities.detail.kv.timeout' => '超时',
			'entities.detail.kv.timeoutBehavior' => '超时行为',
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
			'entities.detail.val.passthrough' => '透传',
			'entities.detail.val.never' => '永不超时',
			'entities.detail.val.yes' => '是',
			'entities.detail.val.no' => '否',
			'entities.detail.val.stopped' => '已停',
			'entities.detail.val.noAlerts' => '无告警',
			'entities.detail.val.needsAttention' => '需注意',
			'entities.detail.val.required' => '必填',
			'entities.detail.val.optional' => '可选',
			'entities.detail.val.sensitive' => '敏感',
			'entities.detail.val.timeoutMs' => ({required Object ms}) => '超时 ${ms} ms',
			'entities.detail.val.defaultPrefix' => '默认',
			'entities.detail.val.generator' => '生成器',
			'entities.detail.val.modelDefault' => '工作区默认',
			'entities.detail.val.none' => '—',
			'entities.detail.mounts.healthy' => '挂载正常',
			'entities.detail.mounts.unhealthy' => ({required Object count}) => '${count} 项异常',
			'entities.detail.trigger.fire' => '催发',
			'entities.detail.trigger.listening' => '监听中',
			'entities.detail.trigger.idle' => '空闲',
			'entities.detail.trigger.source' => '源',
			'entities.detail.trigger.refCount' => '监听者',
			'entities.detail.trigger.lastFired' => '最近触发',
			'entities.detail.trigger.nextFire' => '下次触发',
			'entities.detail.trigger.signatureAlgo' => '签名',
			'entities.detail.trigger.signatureHeader' => '签名头',
			'entities.detail.trigger.events' => '事件',
			'entities.detail.trigger.pattern' => '匹配',
			'entities.detail.trigger.target' => '目标',
			'entities.detail.trigger.interval' => '间隔',
			'entities.detail.trigger.fired' => '已触发',
			'entities.detail.trigger.notFired' => '未触发',
			'entities.detail.trigger.fanout' => ({required Object n}) => '扇出 ${n}',
			'entities.detail.trigger.fanoutLabel' => '扇出',
			'entities.detail.trigger.returnValue' => '返回值',
			'entities.detail.trigger.payload' => '载荷',
			'entities.detail.trigger.detail' => '详情',
			'entities.detail.trigger.activation' => '活动',
			'entities.detail.trigger.allActivity' => '全部活动',
			'entities.detail.trigger.firedOnly' => '仅已触发',
			'entities.detail.trigger.allDispatch' => '全部派发',
			'entities.detail.trigger.firedToast' => ({required Object id}) => '已催发 · ${id}',
			'entities.detail.trigger.fireFailed' => '催发失败',
			'entities.detail.addTag' => '添加标签',
			'entities.detail.state.setActive' => '设为活跃版本',
			'entities.detail.state.setActiveFailed' => '设为活跃版本失败',
			'entities.detail.state.retry' => '重试',
			'entities.detail.state.noVersions' => '暂无版本',
			'entities.detail.state.noLogs' => '暂无运行记录',
			'entities.detail.state.noLogsHint' => '执行该实体后,记录会出现在这里。',
			'entities.detail.state.noActivations' => '暂无活动',
			'entities.detail.state.noActivationsHint' => '该触发器每次动作(触发与否)都会在此留一行。',
			'entities.detail.state.noFirings' => '无派发',
			'entities.detail.state.noFiringsHint' => '一次触发扇给 workflow 后,其处置显示在此。',
			'entities.detail.state.noActiveVersion' => '无活动版本',
			'entities.detail.state.errorTitle' => '无法加载该实体',
			'entities.detail.state.errorHint' => '本地引擎没有返回它。',
			'entities.detail.state.loadMore' => '加载更多',
			'entities.detail.state.loadFailed' => '加载失败,点此重试',
			'entities.detail.state.earliest' => '最早版本',
			'entities.detail.editor.title' => '图编辑器',
			'entities.detail.editor.back' => '返回',
			'entities.detail.editor.addNode' => '添加节点',
			'entities.detail.editor.autoLayout' => '自动布局',
			'entities.detail.editor.dirLR' => '横向',
			'entities.detail.editor.dirTB' => '纵向',
			'entities.detail.editor.save' => '保存',
			'entities.detail.editor.discard' => '放弃更改',
			'entities.detail.editor.discardConfirmTitle' => '丢弃未保存的更改?',
			'entities.detail.editor.discardConfirmMessage' => '画布上有尚未保存的编辑,现在离开将丢弃它们。',
			'entities.detail.editor.discardConfirmAction' => '丢弃并离开',
			'entities.detail.editor.saved' => '已保存新版本',
			'entities.detail.editor.unsaved' => '未保存更改',
			'entities.detail.editor.inspectorEmpty' => '选中节点或连线进行编辑',
			'entities.detail.editor.nodeRef' => '引用',
			'entities.detail.editor.nodeKind' => '类型',
			'entities.detail.editor.nodeInput' => '输入映射',
			'entities.detail.editor.nodeRetry' => '重试',
			'entities.detail.editor.edgePort' => '端口',
			'entities.detail.editor.deleteNode' => '删除节点',
			'entities.detail.editor.deleteEdge' => '删除连线',
			'entities.detail.editor.portHint' => 'control 端口须匹配分支名;approval 为 yes/no',
			'entities.detail.editor.portPick' => '选择分支端口',
			'entities.detail.editor.branches' => '路由分支',
			'entities.detail.editor.branchDefault' => '兜底(其余情况)',
			'entities.detail.editor.branchEmit' => 'emit',
			'entities.detail.editor.field' => '字段',
			'entities.detail.editor.retryEnable' => '启用重试',
			'entities.detail.editor.maxAttempts' => '最大次数',
			'entities.detail.editor.errSelfLoop' => '不支持自环:节点不能连自身',
			'entities.detail.editor.errDuplicateEdge' => '该连线已存在',
			'entities.detail.editor.errBackEdgeSource' => '回边仅可从 control / approval 发出',
			'entities.detail.editor.errApprovalPortsFull' => 'approval 仅有 yes / no 两个出口',
			'entities.detail.editor.on' => '开',
			'entities.detail.editor.off' => '关',
			'entities.detail.editor.inspectorTitle' => '检查器',
			'entities.detail.editor.inspectorEmptyHint' => '在画布上选一个节点或边来编辑。',
			'entities.detail.editor.edge' => '边',
			'entities.detail.editor.removeField' => '移除字段',
			'entities.detail.editor.refPickFamily' => '选择类别…',
			'entities.detail.editor.refFamilyFunction' => '函数',
			'entities.detail.editor.refFamilyHandler' => '处理器',
			'entities.detail.editor.refFamilyMcp' => 'MCP',
			'entities.detail.editor.refPickTarget' => '选择…',
			'entities.detail.editor.refPickMethod' => '选择方法…',
			'entities.detail.editor.refPickTool' => '选择工具…',
			'entities.run.method' => '方法',
			'entities.run.streaming' => '流式',
			'entities.run.example' => '示例',
			'entities.run.payloadInvalid' => '载荷必须是合法 JSON。',
			'entities.run.payloadObject' => '载荷必须是 JSON 对象。',
			'entities.run.cancel' => '取消',
			'entities.run.close' => '关闭运行终端',
			'entities.run.cancelled' => '已取消',
			'entities.run.glanceToday' => ({required Object n}) => '今天 ${n} 次执行',
			'entities.run.glanceLastOk' => '上次成功',
			'entities.run.glanceLastFailed' => '上次失败',
			'entities.run.glanceLastCancelled' => '上次取消',
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
			'entities.run.errorHeading' => '错误',
			'entities.run.danger.cautious' => '谨慎',
			'entities.run.danger.dangerous' => '危险',
			'entities.run.inboxEmpty' => '没有待审批',
			'entities.run.inboxEmptyHint' => '等待决断的审批会出现在这里。',
			'entities.run.source' => '来源',
			'entities.run.sourceManual' => '手动',
			'entities.run.openFlowrun' => '打开 run →',
			'entities.run.openRunPage' => '在运行页打开 →',
			'entities.run.recentCount' => ({required Object n}) => '最近执行 · ${n}',
			'entities.run.reproduce' => '用这份输入',
			'entities.run.inputHeading' => '输入',
			'entities.run.origin.manual' => '手动',
			'entities.run.origin.chat' => '对话',
			'entities.run.origin.agent' => '智能体',
			'entities.run.origin.workflow' => '工作流',
			'entities.run.origin.cron' => '调度',
			'entities.run.origin.webhook' => 'Webhook',
			'entities.run.origin.fsnotify' => '文件变更',
			'entities.run.origin.sensor' => '传感器',
			'entities.val.yes' => '是',
			'entities.val.no' => '否',
			'entities.overview.title' => '总览',
			'entities.overview.accessory' => '配件',
			'entities.overview.graphHead' => '关系图',
			'entities.overview.recentHead' => '最近更新',
			'entities.graph.showProvenance' => '显示溯源',
			'entities.graph.openDetail' => '打开详情',
			'entities.graph.groupEquips' => '装备了',
			'entities.graph.groupReferencedBy' => '被引用',
			'entities.graph.groupLinks' => '链接',
			'entities.graph.legend' => '类型',
			'entities.graph.back' => '返回总览',
			'entities.graph.selectHint' => '选择一个节点查看其关系。',
			'entities.graph.verb.equip' => '装备了',
			'entities.graph.verb.link' => '链接了',
			'entities.graph.verb.create' => '创建了',
			'entities.graph.verb.edit' => '编辑了',
			'coldStart.connecting' => '正在准备工作区…',
			'coldStart.errorTitle' => '无法准备工作区',
			'coldStart.errorHint' => '本地引擎已连通,但工作区未就绪。',
			'coldStart.defaultWorkspace' => '个人',
			'documents.documents' => '文档',
			'documents.skills' => '技能',
			'documents.untitled' => '未命名',
			'documents.editorHint' => '输入正文,按 / 唤起命令',
			'documents.addDescription' => '添加简介…',
			'documents.addTag' => '添加标签',
			'documents.filter' => '搜索文档…',
			'documents.kNew' => '新建页面',
			'documents.errorTitle' => '无法加载知识库',
			'documents.errorHint' => '本地引擎没有返回它。',
			'documents.retry' => '重试',
			'documents.pickTitle' => '选一篇文档',
			'documents.pickHint' => '在左侧选一篇文档或技能来阅读或编辑。',
			'documents.loadFailed' => '打不开这个',
			'documents.rename' => '改名',
			'documents.duplicate' => '创建副本',
			'documents.deleteDocTitle' => '删除这个页面?',
			'documents.deleteDocBody' => ({required Object name}) => '“${name}”及其下嵌套的所有内容都会被删除。',
			'documents.deleteSkillTitle' => '删除这个技能?',
			'documents.deleteSkillBody' => ({required Object name}) => '技能“${name}”会被删除。',
			'documents.actionFailed' => '操作失败',
			'documents.props.title' => '属性',
			'documents.props.name' => '名称',
			'documents.props.description' => '描述',
			'documents.props.tags' => '标签',
			'documents.props.addTag' => '添加标签',
			'documents.props.path' => '路径',
			'documents.props.size' => '大小',
			'documents.props.modified' => '修改时间',
			'documents.props.context' => '上下文',
			'documents.props.contextInline' => '内联',
			'documents.props.contextFork' => '分叉',
			'documents.props.agent' => 'Agent',
			'documents.props.agentHint' => '要派发的子 agent 类型——分叉技能必填。',
			'documents.props.tools' => '允许的工具',
			'documents.props.addTool' => '添加工具',
			'documents.props.arguments' => '参数',
			'documents.props.addArg' => '添加参数',
			'documents.props.modelInvoke' => '模型可调用',
			'documents.props.userInvoke' => '用户可调用',
			'documents.props.on' => '开',
			'documents.props.off' => '关',
			'documents.props.empty' => '未选中',
			'documents.props.emptyHint' => '选一个页面或技能查看它的属性。',
			'documents.props.outline' => '大纲',
			'documents.props.backlinks' => '反向链接',
			'documents.props.noBacklinks' => '还没有页面链接到这里。',
			'documents.props.expandAll' => '展开全部',
			'documents.props.collapseAll' => '收起全部',
			'documents.props.glanceChars' => ({required Object count}) => '${count} 字',
			'documents.props.glanceBacklinks' => ({required Object n}) => '${n} 反链',
			'documents.props.glanceEdited' => ({required Object rel}) => '${rel}编辑',
			'documents.props.time.today' => '今天',
			'documents.props.time.yesterday' => '昨天',
			'documents.props.time.daysAgo' => ({required Object n}) => '${n} 天前',
			'documents.slash.text' => '正文',
			'documents.slash.h1' => '标题 1',
			'documents.slash.h2' => '标题 2',
			'documents.slash.h3' => '标题 3',
			'documents.slash.bulleted' => '无序列表',
			'documents.slash.numbered' => '有序列表',
			'documents.slash.quote' => '引用',
			'documents.slash.code' => '代码块',
			'documents.slash.table' => '表格',
			'documents.slash.divider' => '分隔线',
			'documents.slash.todo' => '待办',
			'documents.linkHint' => '输入或粘贴链接,回车确定',
			'documents.table.insertRowAbove' => '在上方插入行',
			'documents.table.insertRowBelow' => '在下方插入行',
			'documents.table.deleteRow' => '删除行',
			'documents.table.insertColLeft' => '在左侧插入列',
			'documents.table.insertColRight' => '在右侧插入列',
			'documents.table.deleteCol' => '删除列',
			'documents.table.deleteTable' => '删除表格',
			'settings.title' => '设置',
			'settings.scope.device' => '本机',
			'settings.scope.workspace' => '工作区',
			'settings.scope.machine' => '全机',
			'settings.sections.prefs' => '偏好',
			'settings.sections.resources' => '资源',
			'settings.sections.system' => '系统',
			'settings.panels.general' => '通用',
			'settings.panels.notifications' => '通知',
			'settings.panels.chat' => '对话',
			'settings.panels.modelsKeys' => '模型与密钥',
			'settings.panels.mcp' => 'MCP 服务器',
			'settings.panels.memory' => '记忆',
			'settings.panels.sandbox' => '沙箱',
			'settings.panels.workspaces' => '工作区',
			'settings.panels.storage' => '存储与日志',
			'settings.panels.limits' => '高级限额',
			'settings.panels.network' => '网络',
			'settings.panels.shortcuts' => '快捷键',
			'settings.panels.about' => '关于',
			'settings.filter' => '搜索设置…',
			'settings.searchNoMatch' => '无匹配的设置',
			'settings.building' => '面板建设中',
			'settings.buildingHint' => '此面板随建造切片逐步点亮。',
			'settings.appearance' => '外观',
			'settings.theme' => '主题',
			'settings.themeLight' => '浅色',
			'settings.themeDark' => '深色',
			'settings.themeSystem' => '跟随系统',
			'settings.themeDesc' => '跟随系统将随 macOS 外观自动切换',
			'settings.zoom' => '界面缩放',
			'settings.zoomDesc' => '整体缩放界面,与 ⌘+ / ⌘− / ⌘0 同步',
			'settings.fonts' => '字体',
			'settings.fontUi' => '界面字体',
			'settings.fontUiDesc' => '整个界面。内置=Inter+MiSans(双语,各机一致);跟随系统=操作系统字体(macOS San Francisco · Windows Segoe UI)。重启后生效。',
			'settings.fontContent' => '内容字体',
			'settings.fontContentDesc' => '仅 chat 消息与文档正文。衬线=思源宋 SC(拉丁+简体中文)。即时生效。',
			'settings.fontCode' => '代码字体',
			'settings.fontCodeDesc' => '一切等宽处——代码块、终端、diff、ID 等。重启后生效。',
			'settings.fontBundled' => '内置',
			'settings.fontSystem' => '跟随系统',
			'settings.fontSans' => '无衬线(内置)',
			'settings.fontSerif' => '衬线',
			'settings.fontJetBrainsMono' => 'JetBrains Mono',
			'settings.fontFiraCode' => 'Fira Code',
			'settings.fontCascadia' => 'Cascadia Code',
			'settings.fontSystemMono' => '跟随系统等宽',
			'settings.fontRestartHint' => '重启后生效',
			'settings.language' => '语言',
			'settings.languageRow' => '语言',
			'settings.languageDesc' => '同时设定界面语言与当前工作区的 AI 输出语言',
			'settings.langSystem' => '跟随系统',
			'settings.window' => '窗口与启动',
			'settings.rememberWindow' => '记住窗口大小与位置',
			'settings.rememberWindowDesc' => '下次启动恢复上次的窗口几何',
			'settings.launchAtLogin' => '开机自启',
			'settings.launchAtLoginDesc' => '登录系统后自动启动 Anselm',
			'settings.updates' => '更新',
			'settings.updateCheck' => '自动检查更新',
			'settings.updateCheckDesc' => '启动时向 GitHub Releases 查询新版本,不自动安装',
			'settings.resetToDefault' => '重置为默认',
			'settings.patchFailed' => '保存失败,已恢复原值',
			'settings.notifLevel' => '通知级别',
			'settings.notifLevelDesc' => '决定哪些事件弹出提醒;需要你处理的事项永远送达',
			'settings.levelAll' => '全部',
			'settings.levelImportant' => '仅需处理',
			'settings.levelSilent' => '静音',
			'settings.notifOs' => '系统通知',
			'settings.notifOsDesc' => '窗口未聚焦时经系统通知中心送达',
			'settings.notifToast' => '应用内提醒',
			'settings.notifToastDesc' => '右上角浮出提醒;危险级错误不受此限',
			'settings.silentHint' => '已静音,重要事项仍会进铃铛收件箱',
			'settings.autoStage' => '右岛自动登台',
			'settings.autoStageDesc' => '工具运行时右岛自动展示现场',
			'settings.stageNever' => '从不',
			'settings.stageFirst' => '每对话首次',
			'settings.stageAlways' => '每次',
			'settings.sendKey' => '发送键',
			'settings.sendKeyDesc' => 'Shift+Enter 始终换行',
			'settings.sendEnter' => 'Enter 发送',
			'settings.sendCmdEnter' => '⌘Enter 发送',
			'settings.webFetch' => '网页抓取模式',
			'settings.webFetchDesc' => '本地抓取更私密;Jina 代理更能读动态页面',
			'settings.webLocal' => '本地抓取',
			'settings.webJina' => 'Jina 代理',
			'settings.defaultModelLink' => '默认对话模型 → 模型与密钥',
			'settings.langEn' => 'English',
			'settings.langZh' => '简体中文',
			'settings.keys.freeTier' => '免费档',
			'settings.keys.freeTierName' => 'Anselm Free · deepseek-v4-flash',
			'settings.keys.freeUsage' => ({required Object used, required Object limit, required Object reset}) => '${used} / ${limit} · ${reset} 重置',
			'settings.keys.freeUnavailable' => '网关今日预算已满,明日恢复',
			'settings.keys.freeEnable' => '启用免费档',
			'settings.keys.freeEnableHint' => '将向 Anselm 网关注册本机匿名指纹以分配额度',
			'settings.keys.freeProvisioning' => '正在开通…',
			'settings.keys.freeRefresh' => '刷新',
			'settings.keys.freeFailed' => '开通未完成(离线或网关不可达),稍后可重试',
			'settings.keys.keysSection' => 'API 密钥',
			'settings.keys.addKey' => '添加密钥',
			'settings.keys.testKey' => '测试',
			'settings.keys.editKey' => '编辑',
			'settings.keys.deleteKey' => '删除',
			'settings.keys.statusOk' => '可用',
			'settings.keys.statusPending' => '待测',
			'settings.keys.statusError' => '失败',
			'settings.keys.managedBadge' => '受管',
			'settings.keys.provider' => '提供方',
			'settings.keys.displayNameLabel' => '名称',
			'settings.keys.secretLabel' => '密钥',
			'settings.keys.baseUrlLabel' => 'Base URL',
			'settings.keys.apiFormatLabel' => 'API 方言',
			'settings.keys.saveKey' => '保存并测试',
			'settings.keys.cancel' => '取消',
			'settings.keys.reveal' => '显示',
			'settings.keys.conceal' => '隐藏',
			'settings.keys.rotateWarn' => '替换即生效,原密钥不可恢复',
			'settings.keys.rotatePlaceholder' => '留空则不更换密钥',
			'settings.keys.inUseTitle' => '此密钥仍被引用',
			'settings.keys.inUseHint' => '先在以下位置解除引用:',
			'settings.keys.deleteKeyTitle' => '删除密钥',
			'settings.keys.deleteKeyBody' => ({required Object name}) => '将删除「${name}」,不可恢复。',
			'settings.keys.confirmDelete' => '删除',
			'settings.keys.defaults' => '场景默认模型',
			'settings.keys.scenarioDialogue' => '对话',
			'settings.keys.scenarioUtility' => '工具',
			'settings.keys.scenarioAgent' => 'Agent',
			'settings.keys.scenarioDialogueDesc' => '聊天回复所用模型;Auto 依赖它,不可清除',
			'settings.keys.scenarioUtilityDesc' => '自动命名、上下文压缩等轻任务',
			'settings.keys.scenarioAgentDesc' => 'invoke_agent 执行所用',
			'settings.keys.noDefault' => '未配置',
			'settings.keys.clearDefault' => '清除',
			'settings.keys.notConfiguredWarn' => '未设默认对话模型,对话将无法开始',
			'settings.keys.searchDefault' => '默认搜索密钥',
			'settings.keys.searchDefaultDesc' => 'WebSearch 工具所用(category=search 的可用密钥)',
			'settings.keys.keyOpFailed' => '操作失败',
			'settings.keys.refreshModels' => '刷新模型列表',
			'settings.keys.pickProvider' => '选择提供商',
			'settings.keys.changeProvider' => '重新选择',
			'settings.keys.baseUrlRequiredHint' => '自托管服务必填服务地址',
			'settings.keys.savingProbe' => '正在保存并探测…',
			'settings.keys.stageCredential' => '凭证',
			'settings.keys.stageModel' => '模型',
			'settings.keys.stageKnobs' => '参数',
			'settings.keys.pickerApply' => '应用',
			'settings.keys.pickerChange' => '修改',
			'settings.keys.pickerClose' => '收起',
			'settings.keys.visionBadge' => '视觉',
			'settings.keys.docsBadge' => '文档',
			'settings.keys.noCapsGuide' => '还没有可用模型——先添加一把探测通过的密钥',
			'settings.keys.searchSection' => '搜索',
			_ => null,
		} ?? switch (path) {
			'settings.ws.section' => '工作区',
			'settings.ws.current' => '当前',
			'settings.ws.newWorkspace' => '新建工作区',
			'settings.ws.name' => '名称',
			'settings.ws.color' => '颜色',
			'settings.ws.create' => '创建',
			'settings.ws.save' => '保存',
			'settings.ws.edit' => '编辑',
			'settings.ws.switchTo' => '切换',
			'settings.ws.dangerTitle' => '删除此工作区',
			'settings.ws.dangerBody' => ({required Object name, required Object conversations, required Object entities, required Object documents, required Object blob}) => '将永久删除「${name}」的全部内容:${conversations} 对话 · ${entities} 实体 · ${documents} 文档 · ${blob} 附件。',
			'settings.ws.runningWarn' => ({required Object n}) => '有 ${n} 个执行进行中,删除将立即终止它们',
			'settings.ws.generatingWarn' => ({required Object n}) => '有 ${n} 个对话正在生成回复,删除将立即打断',
			'settings.ws.typeNameHint' => ({required Object name}) => '输入「${name}」以确认',
			'settings.ws.confirmDelete' => '永久删除',
			'settings.ws.lastOne' => '唯一的工作区不可删除',
			'settings.ws.deleteFailed' => '删除失败',
			'settings.ws.blobUnknown' => '体积未知',
			'settings.ws.statsLoading' => '正在盘点内容…',
			'settings.about.appVersion' => '应用版本',
			'settings.about.backendVersion' => '引擎版本',
			'settings.about.versions' => '版本',
			'settings.about.checkUpdates' => '检查更新',
			'settings.about.checking' => '检查中…',
			'settings.about.upToDate' => ({required Object v}) => '已是最新(${v})',
			'settings.about.updateAvailable' => ({required Object v}) => '新版本 ${v} 可用',
			'settings.about.download' => '前往下载',
			'settings.about.cantCheck' => '无法检查更新(离线或尚未发布)',
			'settings.about.diagnostics' => '诊断',
			'settings.about.copyDiagnostics' => '复制诊断信息',
			'settings.about.copied' => '已复制',
			'settings.about.diagDesc' => '复制版本与环境信息,便于报告问题',
			'settings.about.fonts' => '字体',
			'settings.about.fontsCredit' => '随包字体:Inter、MiSans、JetBrains Mono、思源宋 SC、Fira Code、Cascadia Code、Newsreader。MiSans © 小米公司,依 MiSans 字体许可协议使用;其余依 SIL 开放字体许可(OFL)。',
			'settings.mem.section' => '记忆',
			'settings.mem.filterAll' => '全部',
			'settings.mem.filterPinned' => '已固定',
			'settings.mem.newMemory' => '新建记忆',
			'settings.mem.name' => '名称',
			'settings.mem.nameHint' => '小写字母开头,可用 a-z 0-9 - _',
			'settings.mem.nameLocked' => '名称即文件名,不可改',
			'settings.mem.invalidName' => '名称须以小写字母开头,仅含 a-z 0-9 - _(≤64)',
			'settings.mem.description' => '描述',
			'settings.mem.content' => '内容',
			'settings.mem.save' => '保存',
			'settings.mem.pinTip' => '固定的记忆常驻每次对话上下文',
			'settings.mem.pinned' => '已固定',
			'settings.mem.deleteTitle' => '删除记忆',
			'settings.mem.deleteBody' => ({required Object name}) => '将物理删除「${name}」的记忆文件,无法撤销。',
			'settings.mem.confirmDelete' => '删除',
			'settings.mem.empty' => '还没有记忆',
			'settings.mem.dirtyTitle' => '放弃未保存的修改?',
			'settings.mem.dirtyBody' => '内容有改动尚未保存。',
			'settings.mem.discard' => '放弃',
			'settings.mem.keepEditing' => '继续编辑',
			'settings.mem.sourceUser' => '用户',
			'settings.mem.sourceAi' => 'AI',
			'settings.mem.searchHint' => '搜索记忆…',
			'settings.mcp.browse' => '浏览市场',
			'settings.mcp.manualAdd' => '手动添加',
			'settings.mcp.importJson' => '导入 mcp.json',
			'settings.mcp.empty' => '还没有 MCP 服务器',
			'settings.mcp.reconnect' => '重连',
			'settings.mcp.detail' => '详情',
			'settings.mcp.deleteServer' => '删除',
			'settings.mcp.deleteTitle' => '删除 MCP 服务器',
			'settings.mcp.deleteBody' => ({required Object name}) => '将移除「${name}」及其配置(软删)。',
			'settings.mcp.confirmDelete' => '删除',
			'settings.mcp.tools' => ({required Object n}) => '${n} 工具',
			'settings.mcp.calls' => ({required Object n}) => '${n} 次调用',
			'settings.mcp.statusReady' => '就绪',
			'settings.mcp.statusFailed' => '失败',
			'settings.mcp.statusDegraded' => '降级',
			'settings.mcp.statusConnecting' => '连接中',
			'settings.mcp.statusDisconnected' => '未连接',
			'settings.mcp.name' => '名称',
			'settings.mcp.transport' => '传输',
			'settings.mcp.runtime' => '运行时',
			'settings.mcp.command' => '命令',
			'settings.mcp.args' => '参数(每行一个)',
			'settings.mcp.url' => 'URL',
			'settings.mcp.envKv' => '环境变量(KEY=VALUE,每行一个)',
			'settings.mcp.headersKv' => '请求头(KEY=VALUE,每行一个)',
			'settings.mcp.add' => '添加',
			'settings.mcp.addFailedHonest' => '连接失败也会落盘为 failed,可稍后重连',
			'settings.mcp.importTitle' => '导入 mcp.json',
			'settings.mcp.importHint' => '粘贴 Claude Desktop 的 mcpServers 片段',
			'settings.mcp.overwrite' => '覆盖同名',
			'settings.mcp.doImport' => '导入',
			'settings.mcp.importResult' => ({required Object n, required Object m}) => '导入 ${n} · 跳过 ${m}',
			'settings.mcp.importInvalid' => 'JSON 无法解析',
			'settings.mcp.market' => '市场',
			'settings.mcp.searchMarket' => '搜索市场…',
			'settings.mcp.installed' => '已安装',
			'settings.mcp.install' => '安装',
			'settings.mcp.installing' => '安装中…',
			'settings.mcp.prerequisite' => '前置',
			'settings.mcp.requiredMark' => '必填',
			'settings.mcp.oauthConnect' => '连接并授权',
			'settings.mcp.oauthWaiting' => '等待浏览器授权…(最长 120 秒)',
			'settings.mcp.tabTools' => '工具',
			'settings.mcp.tabCalls' => '调用历史',
			'settings.mcp.tabStderr' => 'stderr',
			'settings.mcp.lastError' => '最近错误',
			'settings.mcp.consecutiveFailures' => '连续失败',
			'settings.mcp.noTools' => '无工具',
			'settings.mcp.noCalls' => '暂无调用',
			'settings.mcp.noStderr' => '暂无输出',
			'settings.mcp.callsAgg' => ({required Object ok, required Object failed}) => '✓ ${ok} · ✗ ${failed}',
			'settings.mcp.statCount' => ({required Object n}) => '${n} 台',
			'settings.mcp.statReady' => ({required Object n}) => '就绪 ${n}',
			'settings.mcp.statFailed' => ({required Object n}) => '失败 ${n}',
			'settings.mcp.cardMenu' => '更多操作',
			'settings.storage.dataDir' => '数据目录',
			'settings.storage.revealFinder' => '在访达中显示',
			'settings.storage.diskUsage' => '磁盘占用',
			'settings.storage.diskSandbox' => '沙箱运行时与环境',
			'settings.storage.openLogs' => '打开日志文件夹',
			'settings.storage.retention' => 'Run 历史保留',
			'settings.storage.retentionDesc' => '超过保留线的 run 记录将被清理,统计与失败聚合不受影响。',
			'settings.storage.retention30' => '30 天',
			'settings.storage.retention90' => '90 天',
			'settings.storage.retention180' => '180 天',
			'settings.storage.retentionForever' => '永久保留',
			'settings.storage.retentionSaved' => '保留策略已更新',
			'settings.storage.database' => '数据库',
			'settings.storage.dbFootprint' => ({required Object size, required Object dead}) => '${size},其中 ${dead} 可回收',
			'settings.storage.compact' => '压缩数据库',
			'settings.storage.compacting' => '压缩中…',
			'settings.storage.compacted' => ({required Object mb}) => '已回收 ${mb}',
			'settings.storage.resetPrefs' => '重置本地偏好',
			'settings.storage.resetPrefsDesc' => '只清除本机的界面偏好(主题/窗口/缩放等),不碰任何工作区数据将重启应用以生效。',
			'settings.storage.resetPrefsTitle' => '重置本地偏好?',
			'settings.storage.factoryTitle' => '恢复出厂设置',
			'settings.storage.factoryWarn' => '将停止引擎、永久删除整个数据目录(所有工作区/对话/实体/文档/密钥)并重启应用。',
			'settings.storage.factoryHint' => '输入「Anselm」以确认',
			'settings.storage.factoryConfirm' => '抹掉一切并重启',
			'settings.limits.scopeNote' => '全机生效——任一工作区修改的都是这台机器的同一份上限',
			'settings.limits.resetAll' => '全部恢复默认',
			'settings.limits.resetAllTitle' => '恢复全部默认限额?',
			'settings.limits.patchFailed' => '保存失败',
			'settings.limits.modified' => '已修改',
			'settings.limits.errorTitle' => '限额加载失败',
			'settings.limits.retry' => '重试',
			'settings.limits.errorHint' => '无法从引擎读取限额配置',
			'settings.network.section' => '网络',
			'settings.network.proxyHint' => '出站代理——AI 请求经它到达 LLM / MCP / 搜索服务',
			'settings.network.httpProxy' => 'HTTP 代理',
			'settings.network.httpsProxy' => 'HTTPS 代理',
			'settings.network.noProxy' => '绕过代理(逗号分隔)',
			'settings.network.proxyPlaceholder' => 'http://127.0.0.1:7890',
			'settings.network.save' => '保存',
			'settings.network.saved' => '已保存,重启引擎后完整生效',
			'settings.network.restartNote' => '代理配置在重启引擎后完整生效',
			'settings.network.empty' => '留空=直连',
			'settings.sandbox.bootstrapFail' => '沙箱引导失败',
			'settings.sandbox.retry' => '重试',
			'settings.sandbox.runtimes' => '运行时',
			'settings.sandbox.install' => '安装',
			'settings.sandbox.installing' => '安装中…',
			'settings.sandbox.installTitle' => '安装运行时',
			'settings.sandbox.kind' => '类型',
			'settings.sandbox.version' => '版本',
			'settings.sandbox.versionHint' => '如 22 / 3.12',
			'settings.sandbox.add' => '安装',
			'settings.sandbox.delete' => '删除',
			'settings.sandbox.deleteRtTitle' => '删除运行时',
			'settings.sandbox.deleteRtBody' => ({required Object kind, required Object version}) => '将删除「${kind} ${version}」;仍被环境引用会被拒。',
			'settings.sandbox.confirmDelete' => '删除',
			'settings.sandbox.inUse' => '仍有环境引用此运行时,先清理环境',
			'settings.sandbox.envs' => '环境',
			'settings.sandbox.envRebuild' => '下次执行时自动重建',
			'settings.sandbox.deleteEnvTitle' => '删除环境',
			'settings.sandbox.deleteEnvBody' => '将删除此环境。',
			'settings.sandbox.ownerFunction' => '函数',
			'settings.sandbox.ownerHandler' => '处理器',
			'settings.sandbox.ownerMcp' => 'MCP',
			'settings.sandbox.ownerSkill' => '技能',
			'settings.sandbox.ownerConversation' => '对话',
			'settings.sandbox.noRuntimes' => '还没有运行时',
			'settings.sandbox.noEnvs' => '暂无环境',
			'settings.sandbox.disk' => '磁盘占用',
			'settings.sandbox.gc' => '回收空闲环境',
			'settings.sandbox.gcDays' => '回收超过 N 天未用的环境',
			'settings.sandbox.gcRun' => '回收',
			'settings.sandbox.gcDone' => ({required Object n}) => '已回收 ${n} 个',
			'settings.sandbox.gcAllTitle' => '立即回收全部空闲环境?',
			'settings.sandbox.gcAll' => '立即全部回收',
			'settings.sandbox.running' => '运行中',
			'settings.sandbox.statusReady' => '就绪',
			'settings.sandbox.statusFailed' => '失败',
			'settings.shortcuts.section' => '快捷键',
			'settings.shortcuts.scope' => '本机',
			'settings.shortcuts.resetAll' => '全部恢复默认',
			'settings.shortcuts.reset' => '恢复默认',
			'settings.shortcuts.rebind' => '改绑',
			'settings.shortcuts.recording' => '按下新组合键…',
			'settings.shortcuts.conflict' => ({required Object cmd}) => '与「${cmd}」冲突',
			'settings.shortcuts.cmdToggleLeft' => '折叠/展开左岛',
			'settings.shortcuts.cmdToggleRight' => '折叠/展开右岛',
			'settings.shortcuts.cmdOpenSettings' => '打开设置',
			'settings.shortcuts.cmdZoomIn' => '放大界面',
			'settings.shortcuts.cmdZoomOut' => '缩小界面',
			'settings.shortcuts.cmdZoomReset' => '重置缩放',
			'settings.shortcuts.hintModifier' => '组合键须含 ⌘/Ctrl 等修饰键',
			'markdown.imageNotLoaded' => '图片未加载',
			'attach.unavailable' => '已不可用',
			'attach.retry' => '点按重试',
			'attach.tapToLoad' => '点按加载',
			'attach.uploading' => 'Uploading…',
			'attach.failedRetry' => 'Failed — tap to retry',
			'attach.failedUnreadable' => '无法读取文件',
			'attach.remove' => 'Remove',
			_ => null,
		};
	}
}
