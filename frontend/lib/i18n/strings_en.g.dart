///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations

	/// en: 'Anselm'
	String get appName => 'Anselm';

	late final Translations$status$en status = Translations$status$en.internal(_root);
	late final Translations$action$en action = Translations$action$en.internal(_root);
	late final Translations$feedback$en feedback = Translations$feedback$en.internal(_root);
	late final Translations$shell$en shell = Translations$shell$en.internal(_root);
	late final Translations$ref$en ref = Translations$ref$en.internal(_root);
	late final Translations$a11y$en a11y = Translations$a11y$en.internal(_root);
	late final Translations$diff$en diff = Translations$diff$en.internal(_root);
	late final Translations$tree$en tree = Translations$tree$en.internal(_root);
	late final Translations$startup$en startup = Translations$startup$en.internal(_root);
	late final Translations$entities$en entities = Translations$entities$en.internal(_root);
	late final Translations$coldStart$en coldStart = Translations$coldStart$en.internal(_root);
}

// Path: status
class Translations$status$en {
	Translations$status$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Idle'
	String get idle => 'Idle';

	/// en: 'Running'
	String get run => 'Running';

	/// en: 'Waiting'
	String get wait => 'Waiting';

	/// en: 'Failed'
	String get err => 'Failed';

	/// en: 'Done'
	String get done => 'Done';
}

// Path: action
class Translations$action$en {
	Translations$action$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Copy'
	String get copy => 'Copy';

	/// en: 'Wrap'
	String get wrap => 'Wrap';

	/// en: 'Delete'
	String get delete => 'Delete';
}

// Path: feedback
class Translations$feedback$en {
	Translations$feedback$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Info'
	String get info => 'Info';

	/// en: 'Success'
	String get success => 'Success';

	/// en: 'Warning'
	String get warning => 'Warning';

	/// en: 'Error'
	String get error => 'Error';

	/// en: 'Dismiss'
	String get dismiss => 'Dismiss';

	/// en: 'Confirm deletion'
	String get confirmDelete => 'Confirm deletion';

	/// en: 'Dismiss dialog'
	String get dialogBarrier => 'Dismiss dialog';

	/// en: 'Loading'
	String get loading => 'Loading';

	/// en: 'Step $n of $m'
	String stepOf({required Object n, required Object m}) => 'Step ${n} of ${m}';

	/// en: 'Go to step $n'
	String goToStep({required Object n}) => 'Go to step ${n}';

	/// en: 'Remove $name'
	String removeTag({required Object name}) => 'Remove ${name}';

	/// en: 'Add tag'
	String get addTag => 'Add tag';

	/// en: 'Copied'
	String get copied => 'Copied';

	/// en: 'Copy failed'
	String get copyFailed => 'Copy failed';
}

// Path: shell
class Translations$shell$en {
	Translations$shell$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Collapse sidebar'
	String get collapseSidebar => 'Collapse sidebar';

	/// en: 'Expand sidebar'
	String get expandSidebar => 'Expand sidebar';

	/// en: 'Toggle panel'
	String get togglePanel => 'Toggle panel';

	/// en: 'Back to top'
	String get backToTop => 'Back to top';

	late final Translations$shell$ocean$en ocean = Translations$shell$ocean$en.internal(_root);

	/// en: 'Coming soon'
	String get comingSoonTitle => 'Coming soon';

	/// en: 'This ocean isn't built yet.'
	String get comingSoonHint => 'This ocean isn\'t built yet.';

	/// en: 'Settings'
	String get settings => 'Settings';

	/// en: 'Notifications'
	String get notifications => 'Notifications';

	/// en: 'You're all caught up.'
	String get notificationsHint => 'You\'re all caught up.';

	/// en: 'Workspace'
	String get workspaceFallback => 'Workspace';

	/// en: 'New workspace'
	String get newWorkspace => 'New workspace';

	/// en: 'Workspace settings'
	String get workspaceSettings => 'Workspace settings';
}

// Path: ref
class Translations$ref$en {
	Translations$ref$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Function'
	String get function => 'Function';

	/// en: 'Handler'
	String get handler => 'Handler';

	/// en: 'Workflow'
	String get workflow => 'Workflow';

	/// en: 'Agent'
	String get agent => 'Agent';

	/// en: 'Document'
	String get document => 'Document';

	/// en: 'Conversation'
	String get conversation => 'Conversation';

	/// en: 'Skill'
	String get skill => 'Skill';

	/// en: 'MCP'
	String get mcp => 'MCP';

	/// en: 'Trigger'
	String get trigger => 'Trigger';

	/// en: 'Control'
	String get control => 'Control';

	/// en: 'Approval'
	String get approval => 'Approval';
}

// Path: a11y
class Translations$a11y$en {
	Translations$a11y$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Editing $field'
	String editingField({required Object field}) => 'Editing ${field}';

	/// en: 'Display options'
	String get displayOptions => 'Display options';

	/// en: 'Code block, $lang, $lines lines'
	String codeBlock({required Object lang, required Object lines}) => 'Code block, ${lang}, ${lines} lines';

	/// en: 'Code block, $lines lines'
	String codeBlockPlain({required Object lines}) => 'Code block, ${lines} lines';

	/// en: 'JSON tree, $count items'
	String jsonTree({required Object count}) => 'JSON tree, ${count} items';

	/// en: 'Diff, $added added, $removed removed'
	String diff({required Object added, required Object removed}) => 'Diff, ${added} added, ${removed} removed';
}

// Path: diff
class Translations$diff$en {
	Translations$diff$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Added'
	String get added => 'Added';

	/// en: 'Removed'
	String get removed => 'Removed';
}

// Path: tree
class Translations$tree$en {
	Translations$tree$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Invalid JSON'
	String get invalidJson => 'Invalid JSON';

	/// en: '[Circular]'
	String get circular => '[Circular]';

	/// en: '$count more (truncated)'
	String moreItems({required Object count}) => '${count} more (truncated)';
}

// Path: startup
class Translations$startup$en {
	Translations$startup$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Connecting to the local engine…'
	String get connecting => 'Connecting to the local engine…';

	/// en: 'Can't reach the local engine'
	String get crashedTitle => 'Can\'t reach the local engine';

	/// en: 'The backend didn't start. For development, set ANSELM_BACKEND_URL to an already-running server (make server).'
	String get crashedHint => 'The backend didn\'t start. For development, set ANSELM_BACKEND_URL to an already-running server (make server).';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Something went wrong'
	String get errorTitle => 'Something went wrong';

	/// en: 'An unexpected error occurred while rendering this view.'
	String get errorHint => 'An unexpected error occurred while rendering this view.';
}

// Path: entities
class Translations$entities$en {
	Translations$entities$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New'
	String get kNew => 'New';

	/// en: 'Filter…'
	String get filter => 'Filter…';

	/// en: 'No entities yet'
	String get emptyTitle => 'No entities yet';

	/// en: 'Create a function, handler, agent, or workflow to get started.'
	String get emptyHint => 'Create a function, handler, agent, or workflow to get started.';

	/// en: 'Couldn't load entities'
	String get errorTitle => 'Couldn\'t load entities';

	/// en: 'The local engine didn't return the entity list.'
	String get errorHint => 'The local engine didn\'t return the entity list.';

	/// en: 'Try again'
	String get retry => 'Try again';

	/// en: 'Select an entity'
	String get selectTitle => 'Select an entity';

	/// en: 'Choose a function, handler, agent, or workflow from the rail.'
	String get selectHint => 'Choose a function, handler, agent, or workflow from the rail.';

	/// en: 'Sort'
	String get sortLabel => 'Sort';

	/// en: 'Recently updated'
	String get sortRecent => 'Recently updated';

	/// en: 'Name'
	String get sortName => 'Name';

	late final Translations$entities$detail$en detail = Translations$entities$detail$en.internal(_root);
	late final Translations$entities$run$en run = Translations$entities$run$en.internal(_root);
}

// Path: coldStart
class Translations$coldStart$en {
	Translations$coldStart$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Setting up your workspace…'
	String get connecting => 'Setting up your workspace…';

	/// en: 'Couldn't set up the workspace'
	String get errorTitle => 'Couldn\'t set up the workspace';

	/// en: 'The local engine is reachable but the workspace didn't resolve.'
	String get errorHint => 'The local engine is reachable but the workspace didn\'t resolve.';

	/// en: 'Personal'
	String get defaultWorkspace => 'Personal';
}

// Path: shell.ocean
class Translations$shell$ocean$en {
	Translations$shell$ocean$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Chat'
	String get chat => 'Chat';

	/// en: 'Entities'
	String get entities => 'Entities';

	/// en: 'Scheduler'
	String get scheduler => 'Scheduler';

	/// en: 'Documents'
	String get documents => 'Documents';
}

// Path: entities.detail
class Translations$entities$detail$en {
	Translations$entities$detail$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Entities'
	String get crumbRoot => 'Entities';

	/// en: 'More actions'
	String get moreActions => 'More actions';

	late final Translations$entities$detail$tab$en tab = Translations$entities$detail$tab$en.internal(_root);
	late final Translations$entities$detail$verb$en verb = Translations$entities$detail$verb$en.internal(_root);
	late final Translations$entities$detail$sec$en sec = Translations$entities$detail$sec$en.internal(_root);
	late final Translations$entities$detail$card$en card = Translations$entities$detail$card$en.internal(_root);
	late final Translations$entities$detail$graph$en graph = Translations$entities$detail$graph$en.internal(_root);
	late final Translations$entities$detail$kv$en kv = Translations$entities$detail$kv$en.internal(_root);
	late final Translations$entities$detail$val$en val = Translations$entities$detail$val$en.internal(_root);
	late final Translations$entities$detail$mounts$en mounts = Translations$entities$detail$mounts$en.internal(_root);
	late final Translations$entities$detail$state$en state = Translations$entities$detail$state$en.internal(_root);
}

// Path: entities.run
class Translations$entities$run$en {
	Translations$entities$run$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Method'
	String get method => 'Method';

	/// en: 'streaming'
	String get streaming => 'streaming';

	/// en: 'No inputs — run with no arguments.'
	String get noInputs => 'No inputs — run with no arguments.';

	/// en: 'Payload (JSON, optional)'
	String get payload => 'Payload (JSON, optional)';

	/// en: 'Payload must be valid JSON.'
	String get payloadInvalid => 'Payload must be valid JSON.';

	/// en: 'Payload must be a JSON object.'
	String get payloadObject => 'Payload must be a JSON object.';

	/// en: '$name must be valid JSON.'
	String fieldInvalid({required Object name}) => '${name} must be valid JSON.';

	/// en: 'true'
	String get boolTrue => 'true';

	/// en: 'false'
	String get boolFalse => 'false';

	/// en: 'Run again'
	String get runAgain => 'Run again';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Close run terminal'
	String get close => 'Close run terminal';

	/// en: 'Ready to run'
	String get idleTitle => 'Ready to run';

	/// en: 'Fill in the inputs, then run.'
	String get idleHint => 'Fill in the inputs, then run.';

	/// en: 'Cancelled'
	String get cancelled => 'Cancelled';

	/// en: 'Output'
	String get outputHeading => 'Output';

	/// en: 'Result'
	String get resultHeading => 'Result';

	/// en: 'Logs'
	String get logsHeading => 'Logs';

	/// en: 'Trace'
	String get traceHeading => 'Trace';

	/// en: 'Reasoning'
	String get reasoning => 'Reasoning';

	/// en: 'Tool call'
	String get toolCall => 'Tool call';

	/// en: 'Nodes'
	String get nodesHeading => 'Nodes';

	/// en: 'Waiting for output…'
	String get noTrace => 'Waiting for output…';

	/// en: '$n steps'
	String steps({required Object n}) => '${n} steps';

	/// en: '$inT in · $outT out'
	String tokens({required Object inT, required Object outT}) => '${inT} in · ${outT} out';

	/// en: '$ms ms'
	String ms({required Object ms}) => '${ms} ms';

	late final Translations$entities$run$danger$en danger = Translations$entities$run$danger$en.internal(_root);
}

// Path: entities.detail.tab
class Translations$entities$detail$tab$en {
	Translations$entities$detail$tab$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Overview'
	String get overview => 'Overview';

	/// en: 'Versions'
	String get versions => 'Versions';

	/// en: 'Logs'
	String get logs => 'Logs';
}

// Path: entities.detail.verb
class Translations$entities$detail$verb$en {
	Translations$entities$detail$verb$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Run'
	String get run => 'Run';

	/// en: 'Call'
	String get call => 'Call';

	/// en: 'Invoke'
	String get invoke => 'Invoke';

	/// en: 'Trigger'
	String get trigger => 'Trigger';
}

// Path: entities.detail.sec
class Translations$entities$detail$sec$en {
	Translations$entities$detail$sec$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Code'
	String get code => 'Code';

	/// en: 'Inputs'
	String get input => 'Inputs';

	/// en: 'Outputs'
	String get output => 'Outputs';

	/// en: 'Environment'
	String get env => 'Environment';

	/// en: 'Resident state'
	String get runtime => 'Resident state';

	/// en: 'Init args'
	String get initArgs => 'Init args';

	/// en: 'Methods'
	String get methods => 'Methods';

	/// en: 'Prompt'
	String get prompt => 'Prompt';

	/// en: 'Capabilities'
	String get capabilities => 'Capabilities';

	/// en: 'Mount health'
	String get mountHealth => 'Mount health';

	/// en: 'Run governance'
	String get governance => 'Run governance';

	/// en: 'Alerts'
	String get alerts => 'Alerts';

	/// en: 'Orchestration graph'
	String get graph => 'Orchestration graph';
}

// Path: entities.detail.card
class Translations$entities$detail$card$en {
	Translations$entities$detail$card$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Dependencies'
	String get deps => 'Dependencies';

	/// en: 'venv status'
	String get venv => 'venv status';

	/// en: 'Runtime'
	String get runtime => 'Runtime';

	/// en: 'Config readiness'
	String get config => 'Config readiness';

	/// en: 'Tool mounts'
	String get tools => 'Tool mounts';

	/// en: 'Skill'
	String get skill => 'Skill';

	/// en: 'Knowledge'
	String get knowledge => 'Knowledge';

	/// en: 'Model override'
	String get model => 'Model override';

	/// en: 'Lifecycle'
	String get lifecycle => 'Lifecycle';

	/// en: 'Concurrency'
	String get concurrency => 'Concurrency';
}

// Path: entities.detail.graph
class Translations$entities$detail$graph$en {
	Translations$entities$detail$graph$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Node'
	String get nodes => 'Node';

	/// en: 'Edge'
	String get edges => 'Edge';

	/// en: 'Path'
	String get path => 'Path';

	/// en: 'Open graph editor'
	String get openEditor => 'Open graph editor';
}

// Path: entities.detail.kv
class Translations$entities$detail$kv$en {
	Translations$entities$detail$kv$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'Tags'
	String get tags => 'Tags';

	/// en: 'ID'
	String get id => 'ID';

	/// en: 'Active version'
	String get activeVersion => 'Active version';

	/// en: 'Current version'
	String get currentVersion => 'Current version';

	/// en: 'Python'
	String get python => 'Python';

	/// en: 'Updated'
	String get updated => 'Updated';

	/// en: 'Description'
	String get desc => 'Description';

	/// en: 'env id'
	String get envId => 'env id';

	/// en: 'Status'
	String get status => 'Status';

	/// en: 'Last synced'
	String get syncedAt => 'Last synced';

	/// en: 'Error'
	String get error => 'Error';

	/// en: 'Model'
	String get model => 'Model';

	/// en: 'Provider'
	String get provider => 'Provider';

	/// en: 'Instance'
	String get instanceId => 'Instance';

	/// en: 'Version'
	String get version => 'Version';

	/// en: 'Elapsed'
	String get elapsed => 'Elapsed';

	/// en: 'Time'
	String get time => 'Time';

	/// en: 'Replay'
	String get replay => 'Replay';

	/// en: 'Flowrun id'
	String get flowrunId => 'Flowrun id';

	/// en: 'Workflow'
	String get workflow => 'Workflow';

	/// en: 'Nodes'
	String get nodes => 'Nodes';

	/// en: 'Lifecycle'
	String get lifecycle => 'Lifecycle';

	/// en: 'Engaged'
	String get active => 'Engaged';

	/// en: 'Last action by'
	String get lastAction => 'Last action by';

	/// en: 'Concurrency'
	String get concurrency => 'Concurrency';

	/// en: 'Trigger'
	String get trigger => 'Trigger';

	/// en: 'Input'
	String get input => 'Input';

	/// en: 'Output'
	String get output => 'Output';

	/// en: 'Ref'
	String get ref => 'Ref';

	/// en: 'Healthy'
	String get healthy => 'Healthy';

	/// en: 'Method'
	String get method => 'Method';

	/// en: 'Started'
	String get startedAt => 'Started';

	/// en: 'Completed'
	String get completedAt => 'Completed';

	/// en: 'Triggered by'
	String get triggeredBy => 'Triggered by';
}

// Path: entities.detail.val
class Translations$entities$detail$val$en {
	Translations$entities$detail$val$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Listening'
	String get listening => 'Listening';

	/// en: 'Stopped'
	String get stopped => 'Stopped';

	/// en: 'No alerts'
	String get noAlerts => 'No alerts';

	/// en: 'Needs attention'
	String get needsAttention => 'Needs attention';

	/// en: 'required'
	String get required => 'required';

	/// en: 'optional'
	String get optional => 'optional';

	/// en: 'sensitive'
	String get sensitive => 'sensitive';

	/// en: 'default'
	String get defaultPrefix => 'default';

	/// en: 'generator'
	String get generator => 'generator';

	/// en: 'Workspace default'
	String get modelDefault => 'Workspace default';

	/// en: 'Overridden'
	String get modelOverridden => 'Overridden';

	/// en: '—'
	String get none => '—';
}

// Path: entities.detail.mounts
class Translations$entities$detail$mounts$en {
	Translations$entities$detail$mounts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'All mounts healthy'
	String get healthy => 'All mounts healthy';

	/// en: '$count unhealthy'
	String unhealthy({required Object count}) => '${count} unhealthy';
}

// Path: entities.detail.state
class Translations$entities$detail$state$en {
	Translations$entities$detail$state$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No versions'
	String get noVersions => 'No versions';

	/// en: 'No runs yet'
	String get noLogs => 'No runs yet';

	/// en: 'Runs will appear here once this entity is executed.'
	String get noLogsHint => 'Runs will appear here once this entity is executed.';

	/// en: 'No active version'
	String get noActiveVersion => 'No active version';

	/// en: 'Entity not found'
	String get notFoundTitle => 'Entity not found';

	/// en: 'Couldn't load this entity'
	String get errorTitle => 'Couldn\'t load this entity';

	/// en: 'The local engine didn't return it.'
	String get errorHint => 'The local engine didn\'t return it.';

	/// en: 'Load more'
	String get loadMore => 'Load more';

	/// en: 'End of list'
	String get endOfList => 'End of list';

	/// en: 'Load failed — tap to retry'
	String get loadFailed => 'Load failed — tap to retry';

	/// en: 'earliest version'
	String get earliest => 'earliest version';
}

// Path: entities.run.danger
class Translations$entities$run$danger$en {
	Translations$entities$run$danger$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Cautious'
	String get cautious => 'Cautious';

	/// en: 'Dangerous'
	String get dangerous => 'Dangerous';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appName' => 'Anselm',
			'status.idle' => 'Idle',
			'status.run' => 'Running',
			'status.wait' => 'Waiting',
			'status.err' => 'Failed',
			'status.done' => 'Done',
			'action.edit' => 'Edit',
			'action.cancel' => 'Cancel',
			'action.save' => 'Save',
			'action.copy' => 'Copy',
			'action.wrap' => 'Wrap',
			'action.delete' => 'Delete',
			'feedback.info' => 'Info',
			'feedback.success' => 'Success',
			'feedback.warning' => 'Warning',
			'feedback.error' => 'Error',
			'feedback.dismiss' => 'Dismiss',
			'feedback.confirmDelete' => 'Confirm deletion',
			'feedback.dialogBarrier' => 'Dismiss dialog',
			'feedback.loading' => 'Loading',
			'feedback.stepOf' => ({required Object n, required Object m}) => 'Step ${n} of ${m}',
			'feedback.goToStep' => ({required Object n}) => 'Go to step ${n}',
			'feedback.removeTag' => ({required Object name}) => 'Remove ${name}',
			'feedback.addTag' => 'Add tag',
			'feedback.copied' => 'Copied',
			'feedback.copyFailed' => 'Copy failed',
			'shell.collapseSidebar' => 'Collapse sidebar',
			'shell.expandSidebar' => 'Expand sidebar',
			'shell.togglePanel' => 'Toggle panel',
			'shell.backToTop' => 'Back to top',
			'shell.ocean.chat' => 'Chat',
			'shell.ocean.entities' => 'Entities',
			'shell.ocean.scheduler' => 'Scheduler',
			'shell.ocean.documents' => 'Documents',
			'shell.comingSoonTitle' => 'Coming soon',
			'shell.comingSoonHint' => 'This ocean isn\'t built yet.',
			'shell.settings' => 'Settings',
			'shell.notifications' => 'Notifications',
			'shell.notificationsHint' => 'You\'re all caught up.',
			'shell.workspaceFallback' => 'Workspace',
			'shell.newWorkspace' => 'New workspace',
			'shell.workspaceSettings' => 'Workspace settings',
			'ref.function' => 'Function',
			'ref.handler' => 'Handler',
			'ref.workflow' => 'Workflow',
			'ref.agent' => 'Agent',
			'ref.document' => 'Document',
			'ref.conversation' => 'Conversation',
			'ref.skill' => 'Skill',
			'ref.mcp' => 'MCP',
			'ref.trigger' => 'Trigger',
			'ref.control' => 'Control',
			'ref.approval' => 'Approval',
			'a11y.editingField' => ({required Object field}) => 'Editing ${field}',
			'a11y.displayOptions' => 'Display options',
			'a11y.codeBlock' => ({required Object lang, required Object lines}) => 'Code block, ${lang}, ${lines} lines',
			'a11y.codeBlockPlain' => ({required Object lines}) => 'Code block, ${lines} lines',
			'a11y.jsonTree' => ({required Object count}) => 'JSON tree, ${count} items',
			'a11y.diff' => ({required Object added, required Object removed}) => 'Diff, ${added} added, ${removed} removed',
			'diff.added' => 'Added',
			'diff.removed' => 'Removed',
			'tree.invalidJson' => 'Invalid JSON',
			'tree.circular' => '[Circular]',
			'tree.moreItems' => ({required Object count}) => '${count} more (truncated)',
			'startup.connecting' => 'Connecting to the local engine…',
			'startup.crashedTitle' => 'Can\'t reach the local engine',
			'startup.crashedHint' => 'The backend didn\'t start. For development, set ANSELM_BACKEND_URL to an already-running server (make server).',
			'startup.retry' => 'Retry',
			'startup.errorTitle' => 'Something went wrong',
			'startup.errorHint' => 'An unexpected error occurred while rendering this view.',
			'entities.kNew' => 'New',
			'entities.filter' => 'Filter…',
			'entities.emptyTitle' => 'No entities yet',
			'entities.emptyHint' => 'Create a function, handler, agent, or workflow to get started.',
			'entities.errorTitle' => 'Couldn\'t load entities',
			'entities.errorHint' => 'The local engine didn\'t return the entity list.',
			'entities.retry' => 'Try again',
			'entities.selectTitle' => 'Select an entity',
			'entities.selectHint' => 'Choose a function, handler, agent, or workflow from the rail.',
			'entities.sortLabel' => 'Sort',
			'entities.sortRecent' => 'Recently updated',
			'entities.sortName' => 'Name',
			'entities.detail.crumbRoot' => 'Entities',
			'entities.detail.moreActions' => 'More actions',
			'entities.detail.tab.overview' => 'Overview',
			'entities.detail.tab.versions' => 'Versions',
			'entities.detail.tab.logs' => 'Logs',
			'entities.detail.verb.run' => 'Run',
			'entities.detail.verb.call' => 'Call',
			'entities.detail.verb.invoke' => 'Invoke',
			'entities.detail.verb.trigger' => 'Trigger',
			'entities.detail.sec.code' => 'Code',
			'entities.detail.sec.input' => 'Inputs',
			'entities.detail.sec.output' => 'Outputs',
			'entities.detail.sec.env' => 'Environment',
			'entities.detail.sec.runtime' => 'Resident state',
			'entities.detail.sec.initArgs' => 'Init args',
			'entities.detail.sec.methods' => 'Methods',
			'entities.detail.sec.prompt' => 'Prompt',
			'entities.detail.sec.capabilities' => 'Capabilities',
			'entities.detail.sec.mountHealth' => 'Mount health',
			'entities.detail.sec.governance' => 'Run governance',
			'entities.detail.sec.alerts' => 'Alerts',
			'entities.detail.sec.graph' => 'Orchestration graph',
			'entities.detail.card.deps' => 'Dependencies',
			'entities.detail.card.venv' => 'venv status',
			'entities.detail.card.runtime' => 'Runtime',
			'entities.detail.card.config' => 'Config readiness',
			'entities.detail.card.tools' => 'Tool mounts',
			'entities.detail.card.skill' => 'Skill',
			'entities.detail.card.knowledge' => 'Knowledge',
			'entities.detail.card.model' => 'Model override',
			'entities.detail.card.lifecycle' => 'Lifecycle',
			'entities.detail.card.concurrency' => 'Concurrency',
			'entities.detail.graph.nodes' => 'Node',
			'entities.detail.graph.edges' => 'Edge',
			'entities.detail.graph.path' => 'Path',
			'entities.detail.graph.openEditor' => 'Open graph editor',
			'entities.detail.kv.name' => 'Name',
			'entities.detail.kv.tags' => 'Tags',
			'entities.detail.kv.id' => 'ID',
			'entities.detail.kv.activeVersion' => 'Active version',
			'entities.detail.kv.currentVersion' => 'Current version',
			'entities.detail.kv.python' => 'Python',
			'entities.detail.kv.updated' => 'Updated',
			'entities.detail.kv.desc' => 'Description',
			'entities.detail.kv.envId' => 'env id',
			'entities.detail.kv.status' => 'Status',
			'entities.detail.kv.syncedAt' => 'Last synced',
			'entities.detail.kv.error' => 'Error',
			'entities.detail.kv.model' => 'Model',
			'entities.detail.kv.provider' => 'Provider',
			'entities.detail.kv.instanceId' => 'Instance',
			'entities.detail.kv.version' => 'Version',
			'entities.detail.kv.elapsed' => 'Elapsed',
			'entities.detail.kv.time' => 'Time',
			'entities.detail.kv.replay' => 'Replay',
			'entities.detail.kv.flowrunId' => 'Flowrun id',
			'entities.detail.kv.workflow' => 'Workflow',
			'entities.detail.kv.nodes' => 'Nodes',
			'entities.detail.kv.lifecycle' => 'Lifecycle',
			'entities.detail.kv.active' => 'Engaged',
			'entities.detail.kv.lastAction' => 'Last action by',
			'entities.detail.kv.concurrency' => 'Concurrency',
			'entities.detail.kv.trigger' => 'Trigger',
			'entities.detail.kv.input' => 'Input',
			'entities.detail.kv.output' => 'Output',
			'entities.detail.kv.ref' => 'Ref',
			'entities.detail.kv.healthy' => 'Healthy',
			'entities.detail.kv.method' => 'Method',
			'entities.detail.kv.startedAt' => 'Started',
			'entities.detail.kv.completedAt' => 'Completed',
			'entities.detail.kv.triggeredBy' => 'Triggered by',
			'entities.detail.val.listening' => 'Listening',
			'entities.detail.val.stopped' => 'Stopped',
			'entities.detail.val.noAlerts' => 'No alerts',
			'entities.detail.val.needsAttention' => 'Needs attention',
			'entities.detail.val.required' => 'required',
			'entities.detail.val.optional' => 'optional',
			'entities.detail.val.sensitive' => 'sensitive',
			'entities.detail.val.defaultPrefix' => 'default',
			'entities.detail.val.generator' => 'generator',
			'entities.detail.val.modelDefault' => 'Workspace default',
			'entities.detail.val.modelOverridden' => 'Overridden',
			'entities.detail.val.none' => '—',
			'entities.detail.mounts.healthy' => 'All mounts healthy',
			'entities.detail.mounts.unhealthy' => ({required Object count}) => '${count} unhealthy',
			'entities.detail.state.noVersions' => 'No versions',
			'entities.detail.state.noLogs' => 'No runs yet',
			'entities.detail.state.noLogsHint' => 'Runs will appear here once this entity is executed.',
			'entities.detail.state.noActiveVersion' => 'No active version',
			'entities.detail.state.notFoundTitle' => 'Entity not found',
			'entities.detail.state.errorTitle' => 'Couldn\'t load this entity',
			'entities.detail.state.errorHint' => 'The local engine didn\'t return it.',
			'entities.detail.state.loadMore' => 'Load more',
			'entities.detail.state.endOfList' => 'End of list',
			'entities.detail.state.loadFailed' => 'Load failed — tap to retry',
			'entities.detail.state.earliest' => 'earliest version',
			'entities.run.method' => 'Method',
			'entities.run.streaming' => 'streaming',
			'entities.run.noInputs' => 'No inputs — run with no arguments.',
			'entities.run.payload' => 'Payload (JSON, optional)',
			'entities.run.payloadInvalid' => 'Payload must be valid JSON.',
			'entities.run.payloadObject' => 'Payload must be a JSON object.',
			'entities.run.fieldInvalid' => ({required Object name}) => '${name} must be valid JSON.',
			'entities.run.boolTrue' => 'true',
			'entities.run.boolFalse' => 'false',
			'entities.run.runAgain' => 'Run again',
			'entities.run.cancel' => 'Cancel',
			'entities.run.close' => 'Close run terminal',
			'entities.run.idleTitle' => 'Ready to run',
			'entities.run.idleHint' => 'Fill in the inputs, then run.',
			'entities.run.cancelled' => 'Cancelled',
			'entities.run.outputHeading' => 'Output',
			'entities.run.resultHeading' => 'Result',
			'entities.run.logsHeading' => 'Logs',
			'entities.run.traceHeading' => 'Trace',
			'entities.run.reasoning' => 'Reasoning',
			'entities.run.toolCall' => 'Tool call',
			'entities.run.nodesHeading' => 'Nodes',
			'entities.run.noTrace' => 'Waiting for output…',
			'entities.run.steps' => ({required Object n}) => '${n} steps',
			'entities.run.tokens' => ({required Object inT, required Object outT}) => '${inT} in · ${outT} out',
			'entities.run.ms' => ({required Object ms}) => '${ms} ms',
			'entities.run.danger.cautious' => 'Cautious',
			'entities.run.danger.dangerous' => 'Dangerous',
			'coldStart.connecting' => 'Setting up your workspace…',
			'coldStart.errorTitle' => 'Couldn\'t set up the workspace',
			'coldStart.errorHint' => 'The local engine is reachable but the workspace didn\'t resolve.',
			'coldStart.defaultWorkspace' => 'Personal',
			_ => null,
		};
	}
}
