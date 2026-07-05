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
	@override late final _Translations$graph$zh_CN graph = _Translations$graph$zh_CN._(_root);
	@override late final _Translations$a11y$zh_CN a11y = _Translations$a11y$zh_CN._(_root);
	@override late final _Translations$diff$zh_CN diff = _Translations$diff$zh_CN._(_root);
	@override late final _Translations$tree$zh_CN tree = _Translations$tree$zh_CN._(_root);
	@override late final _Translations$startup$zh_CN startup = _Translations$startup$zh_CN._(_root);
	@override late final _Translations$entities$zh_CN entities = _Translations$entities$zh_CN._(_root);
	@override late final _Translations$coldStart$zh_CN coldStart = _Translations$coldStart$zh_CN._(_root);
	@override late final _Translations$documents$zh_CN documents = _Translations$documents$zh_CN._(_root);
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
	@override String get emptyTitle => '还没有对话';
	@override String get emptyHint => '开始一个新对话吧。';
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
	@override String get retrySend => 'Retry';
	@override String get discard => 'Discard';
	@override String get stoppedCancelled => 'Stopped';
	@override String get stoppedError => 'Something went wrong';
	@override String get stoppedMaxSteps => 'Paused — step limit reached';
	@override String get stoppedBudget => 'Paused — context window is full';
	@override String get transcriptErrorTitle => 'Couldn\'t load this conversation';
	@override String get transcriptErrorHint => 'The local engine didn’t return the messages.';
	@override String get landingGreeting => 'What should we dig into?';
	@override String get modelAuto => 'Auto';
	@override String get mentionEntity => 'Mention an entity';
	@override String get attachFile => 'Attach files';
	@override String get dropToAttach => 'Drop files to attach';
	@override late final _Translations$chat$tool$zh_CN tool = _Translations$chat$tool$zh_CN._(_root);
	@override late final _Translations$chat$gate$zh_CN gate = _Translations$chat$gate$zh_CN._(_root);
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
	@override String editingField({required Object field}) => '正在编辑 ${field}';
	@override String editField({required Object field}) => '编辑 ${field}';
	@override String addTagTo({required Object field}) => '添加标签:${field}';
	@override String get displayOptions => '显示选项';
	@override String get moreActions => '更多操作';
	@override String get graphZoomIn => '放大';
	@override String get graphZoomOut => '缩小';
	@override String get graphFit => '适应画布';
	@override String graphNode({required Object id, required Object kind, required Object ref}) => '节点 ${id},${kind},${ref}';
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
	@override String get sortRecent => '最近活跃';
	@override String get sortCreated => '最近创建';
	@override String get sortName => '名称';
	@override String get displayLabel => '显示';
	@override String get showCount => '显示分组计数';
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

// Path: documents
class _Translations$documents$zh_CN extends Translations$documents$en {
	_Translations$documents$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get documents => '文档';
	@override String get skills => '技能';
	@override String get untitled => '未命名';
	@override String get filter => '过滤';
	@override String get kNew => '新建';
	@override String get errorTitle => '无法加载知识库';
	@override String get errorHint => '本地引擎没有返回它。';
	@override String get retry => '重试';
	@override String get emptyTitle => '这里还什么都没有';
	@override String get emptyHint => '新建一篇文档或一个技能开始。';
	@override String get pickTitle => '选一篇文档';
	@override String get pickHint => '在左侧选一篇文档或技能来阅读或编辑。';
	@override String get loadFailed => '打不开这个';
	@override String get emptyDoc => '这篇文档是空的。';
	@override String get newSkill => '新建技能';
	@override String get rename => '改名';
	@override String get duplicate => '创建副本';
	@override String get deleteDocTitle => '删除这个页面?';
	@override String deleteDocBody({required Object name}) => '“${name}”及其下嵌套的所有内容都会被删除。';
	@override String get deleteSkillTitle => '删除这个技能?';
	@override String deleteSkillBody({required Object name}) => '技能“${name}”会被删除。';
	@override String get actionFailed => '操作失败';
	@override late final _Translations$documents$props$zh_CN props = _Translations$documents$props$zh_CN._(_root);
	@override late final _Translations$documents$slash$zh_CN slash = _Translations$documents$slash$zh_CN._(_root);
	@override String toolCount({required Object n}) => '${n} 个工具';
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

// Path: chat.tool
class _Translations$chat$tool$zh_CN extends Translations$chat$tool$en {
	_Translations$chat$tool$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get calling => '正在调用';
	@override String get called => '已调用';
	@override String get awaitingConfirm => '等待确认';
	@override String get failed => '失败';
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
	@override String linesTruncated({required Object n}) => '前 ${n} 行(截断)';
	@override String matches({required Object n}) => '${n} 处匹配';
	@override String files({required Object n}) => '${n} 个文件';
	@override String items({required Object n}) => '${n} 项';
	@override String get noMatches => '无匹配';
	@override String exit({required Object code}) => 'exit ${code}';
	@override String get timedOut => '超时';
	@override String wroteBytes({required Object n}) => '${n} 字节';
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
	@override String get asked => '已提问';
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
	@override String get envFixHealing => '改依赖重试';
	@override String get envFixTitle => '环境自愈';
	@override String get wfInactive => '未激活';
	@override String wfGraphCounts({required Object nodes, required Object edges}) => '节点 ${nodes} · 边 ${edges}';
	@override String get wfActivateHint => 'activate_workflow 上线 · trigger_workflow 试跑';
	@override String get wfGrowing => '正在编排';
	@override String get wfNodeUnit => '节点';
	@override String get wfEdgeUnit => '边';
	@override String get wfDeltaEmpty => '仅改元数据(图未变)';
	@override String get wfMorphNote => '增量变换(图整体见实体面板)';
	@override String get ctlOtherwise => '否则';
	@override String get ctlWhenTrue => '兜底';
	@override String get ctlEmit => 'emit';
	@override String get ctlNoCatchall => '缺兜底:末条须 when:"true"';
	@override String get apfTimeoutNever => '永不超时';
	@override String get apfAllowReason => '可填备注';
	@override String get apfApprove => '批准';
	@override String get apfReject => '拒绝';
	@override String get apfPreviewHint => '审批人将看到';
	@override String get apfOnTimeout => '超时 →';
}

// Path: chat.gate
class _Translations$chat$gate$zh_CN extends Translations$chat$gate$en {
	_Translations$chat$gate$zh_CN._(TranslationsZhCn root) : this._root = root, super.internal(root);

	final TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get dangerBadge => '危险';
	@override String get awaitingDanger => '等待你确认';
	@override String get awaitingAsk => '等待你回答';
	@override String get evidenceLabel => '参数';
	@override String get approve => '允许';
	@override String get approveAlways => '总是允许';
	@override String approveAlwaysHint({required Object tool}) => '本对话内不再询问 ${tool}(重启即忘)';
	@override String get deny => '拒绝';
	@override String get decline => '不回答';
	@override String get submit => '发送';
	@override String get answerPlaceholder => '输入你的回答…';
	@override String get optionsHint => '选一项,或直接输入';
	@override String get decidedApproved => '已允许';
	@override String get decidedApprovedAlways => '已允许 · 本对话总是';
	@override String get decidedDenied => '已拒绝';
	@override String get decidedDeclined => '已跳过';
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
	@override String get approvalTitle => '等待审批';
	@override String get approve => '通过';
	@override String get reject => '驳回';
	@override String get approvalHint => 'first-wins:先到的决断生效。';
	@override String get reasonHint => '备注(可选)';
	@override String get inboxEmpty => '没有待审批';
	@override String get inboxEmptyHint => '等待决断的审批会出现在这里。';
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
	@override String get divider => '分隔线';
	@override String get todo => '待办';
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
	@override String get noOutputs => '无返回';
	@override String get noConfig => '无 config';
	@override String get noMethods => '无方法';
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
	@override String get pickNode => '选择一个节点查看执行详情';
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
	@override String get notFoundTitle => '未找到该实体';
	@override String get errorTitle => '无法加载该实体';
	@override String get errorHint => '本地引擎没有返回它。';
	@override String get loadMore => '加载更多';
	@override String get endOfList => '已到底';
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
	@override String get direction => '方向';
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
	@override String get edgeFrom => '从';
	@override String get edgeTo => '到';
	@override String get deleteNode => '删除节点';
	@override String get deleteEdge => '删除连线';
	@override String get portHint => 'control 端口须匹配分支名;approval 为 yes/no';
	@override String get portPick => '选择分支端口';
	@override String get branches => '路由分支';
	@override String get branchDefault => '兜底(其余情况)';
	@override String get branchEmit => 'emit';
	@override String get addField => '添加字段';
	@override String get field => '字段';
	@override String get expr => 'CEL 表达式';
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
			'chat.retrySend' => 'Retry',
			'chat.discard' => 'Discard',
			'chat.stoppedCancelled' => 'Stopped',
			'chat.stoppedError' => 'Something went wrong',
			'chat.stoppedMaxSteps' => 'Paused — step limit reached',
			'chat.stoppedBudget' => 'Paused — context window is full',
			'chat.transcriptErrorTitle' => 'Couldn\'t load this conversation',
			'chat.transcriptErrorHint' => 'The local engine didn’t return the messages.',
			'chat.landingGreeting' => 'What should we dig into?',
			'chat.modelAuto' => 'Auto',
			'chat.mentionEntity' => 'Mention an entity',
			'chat.attachFile' => 'Attach files',
			'chat.dropToAttach' => 'Drop files to attach',
			'chat.tool.calling' => '正在调用',
			'chat.tool.called' => '已调用',
			'chat.tool.awaitingConfirm' => '等待确认',
			'chat.tool.failed' => '失败',
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
			'chat.tool.linesTruncated' => ({required Object n}) => '前 ${n} 行(截断)',
			'chat.tool.matches' => ({required Object n}) => '${n} 处匹配',
			'chat.tool.files' => ({required Object n}) => '${n} 个文件',
			'chat.tool.items' => ({required Object n}) => '${n} 项',
			'chat.tool.noMatches' => '无匹配',
			'chat.tool.exit' => ({required Object code}) => 'exit ${code}',
			'chat.tool.timedOut' => '超时',
			'chat.tool.wroteBytes' => ({required Object n}) => '${n} 字节',
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
			'chat.tool.asking' => '正在提问',
			'chat.tool.asked' => '已提问',
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
			'chat.tool.envFixHealing' => '改依赖重试',
			'chat.tool.envFixTitle' => '环境自愈',
			'chat.tool.wfInactive' => '未激活',
			'chat.tool.wfGraphCounts' => ({required Object nodes, required Object edges}) => '节点 ${nodes} · 边 ${edges}',
			'chat.tool.wfActivateHint' => 'activate_workflow 上线 · trigger_workflow 试跑',
			'chat.tool.wfGrowing' => '正在编排',
			'chat.tool.wfNodeUnit' => '节点',
			'chat.tool.wfEdgeUnit' => '边',
			'chat.tool.wfDeltaEmpty' => '仅改元数据(图未变)',
			'chat.tool.wfMorphNote' => '增量变换(图整体见实体面板)',
			'chat.tool.ctlOtherwise' => '否则',
			'chat.tool.ctlWhenTrue' => '兜底',
			'chat.tool.ctlEmit' => 'emit',
			'chat.tool.ctlNoCatchall' => '缺兜底:末条须 when:"true"',
			'chat.tool.apfTimeoutNever' => '永不超时',
			'chat.tool.apfAllowReason' => '可填备注',
			'chat.tool.apfApprove' => '批准',
			'chat.tool.apfReject' => '拒绝',
			'chat.tool.apfPreviewHint' => '审批人将看到',
			'chat.tool.apfOnTimeout' => '超时 →',
			'chat.gate.dangerBadge' => '危险',
			'chat.gate.awaitingDanger' => '等待你确认',
			'chat.gate.awaitingAsk' => '等待你回答',
			'chat.gate.evidenceLabel' => '参数',
			'chat.gate.approve' => '允许',
			'chat.gate.approveAlways' => '总是允许',
			'chat.gate.approveAlwaysHint' => ({required Object tool}) => '本对话内不再询问 ${tool}(重启即忘)',
			'chat.gate.deny' => '拒绝',
			'chat.gate.decline' => '不回答',
			'chat.gate.submit' => '发送',
			'chat.gate.answerPlaceholder' => '输入你的回答…',
			'chat.gate.optionsHint' => '选一项,或直接输入',
			'chat.gate.decidedApproved' => '已允许',
			'chat.gate.decidedApprovedAlways' => '已允许 · 本对话总是',
			'chat.gate.decidedDenied' => '已拒绝',
			'chat.gate.decidedDeclined' => '已跳过',
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
			'graph.kind.trigger' => '触发',
			'graph.kind.action' => '动作',
			'graph.kind.agent' => '智能体',
			'graph.kind.control' => '分支',
			'graph.kind.approval' => '审批',
			'graph.kind.unknown' => '未知',
			'a11y.editingField' => ({required Object field}) => '正在编辑 ${field}',
			'a11y.editField' => ({required Object field}) => '编辑 ${field}',
			'a11y.addTagTo' => ({required Object field}) => '添加标签:${field}',
			'a11y.displayOptions' => '显示选项',
			'a11y.moreActions' => '更多操作',
			'a11y.graphZoomIn' => '放大',
			'a11y.graphZoomOut' => '缩小',
			'a11y.graphFit' => '适应画布',
			'a11y.graphNode' => ({required Object id, required Object kind, required Object ref}) => '节点 ${id},${kind},${ref}',
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
			'entities.detail.hero.noOutputs' => '无返回',
			'entities.detail.hero.noConfig' => '无 config',
			'entities.detail.hero.noMethods' => '无方法',
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
			'entities.detail.cockpit.pickNode' => '选择一个节点查看执行详情',
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
			'entities.detail.val.modelOverridden' => '已覆盖',
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
			'entities.detail.state.notFoundTitle' => '未找到该实体',
			'entities.detail.state.errorTitle' => '无法加载该实体',
			'entities.detail.state.errorHint' => '本地引擎没有返回它。',
			'entities.detail.state.loadMore' => '加载更多',
			'entities.detail.state.endOfList' => '已到底',
			'entities.detail.state.loadFailed' => '加载失败,点此重试',
			'entities.detail.state.earliest' => '最早版本',
			'entities.detail.editor.title' => '图编辑器',
			'entities.detail.editor.back' => '返回',
			'entities.detail.editor.addNode' => '添加节点',
			'entities.detail.editor.autoLayout' => '自动布局',
			'entities.detail.editor.direction' => '方向',
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
			'entities.detail.editor.edgeFrom' => '从',
			'entities.detail.editor.edgeTo' => '到',
			'entities.detail.editor.deleteNode' => '删除节点',
			'entities.detail.editor.deleteEdge' => '删除连线',
			'entities.detail.editor.portHint' => 'control 端口须匹配分支名;approval 为 yes/no',
			'entities.detail.editor.portPick' => '选择分支端口',
			'entities.detail.editor.branches' => '路由分支',
			'entities.detail.editor.branchDefault' => '兜底(其余情况)',
			'entities.detail.editor.branchEmit' => 'emit',
			'entities.detail.editor.addField' => '添加字段',
			'entities.detail.editor.field' => '字段',
			'entities.detail.editor.expr' => 'CEL 表达式',
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
			_ => null,
		} ?? switch (path) {
			'entities.run.nodesHeading' => '节点',
			'entities.run.noTrace' => '等待输出…',
			'entities.run.steps' => ({required Object n}) => '${n} 步',
			'entities.run.tokens' => ({required Object inT, required Object outT}) => '输入 ${inT} · 输出 ${outT}',
			'entities.run.ms' => ({required Object ms}) => '${ms} ms',
			'entities.run.danger.cautious' => '谨慎',
			'entities.run.danger.dangerous' => '危险',
			'entities.run.approvalTitle' => '等待审批',
			'entities.run.approve' => '通过',
			'entities.run.reject' => '驳回',
			'entities.run.approvalHint' => 'first-wins:先到的决断生效。',
			'entities.run.reasonHint' => '备注(可选)',
			'entities.run.inboxEmpty' => '没有待审批',
			'entities.run.inboxEmptyHint' => '等待决断的审批会出现在这里。',
			'coldStart.connecting' => '正在准备工作区…',
			'coldStart.errorTitle' => '无法准备工作区',
			'coldStart.errorHint' => '本地引擎已连通,但工作区未就绪。',
			'coldStart.defaultWorkspace' => '个人',
			'documents.documents' => '文档',
			'documents.skills' => '技能',
			'documents.untitled' => '未命名',
			'documents.filter' => '过滤',
			'documents.kNew' => '新建',
			'documents.errorTitle' => '无法加载知识库',
			'documents.errorHint' => '本地引擎没有返回它。',
			'documents.retry' => '重试',
			'documents.emptyTitle' => '这里还什么都没有',
			'documents.emptyHint' => '新建一篇文档或一个技能开始。',
			'documents.pickTitle' => '选一篇文档',
			'documents.pickHint' => '在左侧选一篇文档或技能来阅读或编辑。',
			'documents.loadFailed' => '打不开这个',
			'documents.emptyDoc' => '这篇文档是空的。',
			'documents.newSkill' => '新建技能',
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
			'documents.slash.text' => '正文',
			'documents.slash.h1' => '标题 1',
			'documents.slash.h2' => '标题 2',
			'documents.slash.h3' => '标题 3',
			'documents.slash.bulleted' => '无序列表',
			'documents.slash.numbered' => '有序列表',
			'documents.slash.quote' => '引用',
			'documents.slash.code' => '代码块',
			'documents.slash.divider' => '分隔线',
			'documents.slash.todo' => '待办',
			'documents.toolCount' => ({required Object n}) => '${n} 个工具',
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
