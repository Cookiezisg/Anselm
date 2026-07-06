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
	late final Translations$chat$en chat = Translations$chat$en.internal(_root);

	/// en: 'Anselm'
	String get appName => 'Anselm';

	late final Translations$status$en status = Translations$status$en.internal(_root);
	late final Translations$action$en action = Translations$action$en.internal(_root);
	late final Translations$feedback$en feedback = Translations$feedback$en.internal(_root);
	late final Translations$shell$en shell = Translations$shell$en.internal(_root);
	late final Translations$notifications$en notifications = Translations$notifications$en.internal(_root);
	late final Translations$ref$en ref = Translations$ref$en.internal(_root);
	late final Translations$graph$en graph = Translations$graph$en.internal(_root);
	late final Translations$a11y$en a11y = Translations$a11y$en.internal(_root);
	late final Translations$diff$en diff = Translations$diff$en.internal(_root);
	late final Translations$tree$en tree = Translations$tree$en.internal(_root);
	late final Translations$startup$en startup = Translations$startup$en.internal(_root);
	late final Translations$entities$en entities = Translations$entities$en.internal(_root);
	late final Translations$coldStart$en coldStart = Translations$coldStart$en.internal(_root);
	late final Translations$documents$en documents = Translations$documents$en.internal(_root);
	late final Translations$markdown$en markdown = Translations$markdown$en.internal(_root);
	late final Translations$attach$en attach = Translations$attach$en.internal(_root);
}

// Path: chat
class Translations$chat$en {
	Translations$chat$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New chat'
	String get kNew => 'New chat';

	/// en: 'Search conversations…'
	String get filter => 'Search conversations…';

	/// en: 'No conversations yet'
	String get emptyTitle => 'No conversations yet';

	/// en: 'Start a new chat to begin.'
	String get emptyHint => 'Start a new chat to begin.';

	/// en: 'Couldn't load conversations'
	String get errorTitle => 'Couldn\'t load conversations';

	/// en: 'The local engine didn't return the conversation list.'
	String get errorHint => 'The local engine didn\'t return the conversation list.';

	/// en: 'Try again'
	String get retry => 'Try again';

	/// en: 'Sort'
	String get sortLabel => 'Sort';

	/// en: 'Recently active'
	String get sortActivity => 'Recently active';

	/// en: 'Recently created'
	String get sortCreated => 'Recently created';

	/// en: 'Name'
	String get sortName => 'Name';

	/// en: 'Display'
	String get displayLabel => 'Display';

	/// en: 'Show archived'
	String get showArchived => 'Show archived';

	/// en: 'Show counts'
	String get showCount => 'Show counts';

	/// en: 'Show time'
	String get showTime => 'Show time';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Pin'
	String get pin => 'Pin';

	/// en: 'Unpin'
	String get unpin => 'Unpin';

	/// en: 'Archive'
	String get archive => 'Archive';

	/// en: 'Unarchive'
	String get unarchive => 'Unarchive';

	/// en: 'Delete this conversation?'
	String get deleteTitle => 'Delete this conversation?';

	/// en: '“$title” will be removed.'
	String deleteBody({required Object title}) => '“${title}” will be removed.';

	/// en: 'Delete'
	String get deleteConfirm => 'Delete';

	/// en: 'Action failed'
	String get actionFailed => 'Action failed';

	late final Translations$chat$time$en time = Translations$chat$time$en.internal(_root);
	late final Translations$chat$bucket$en bucket = Translations$chat$bucket$en.internal(_root);

	/// en: 'Ask anything…'
	String get placeholder => 'Ask anything…';

	/// en: 'Send message'
	String get send => 'Send message';

	/// en: 'Stop generating'
	String get stop => 'Stop generating';

	/// en: 'thinking'
	String get thinking => 'thinking';

	/// en: 'thought'
	String get thought => 'thought';

	/// en: 'Couldn't send'
	String get sendFailed => 'Couldn\'t send';

	/// en: 'Retry'
	String get retrySend => 'Retry';

	/// en: 'Discard'
	String get discard => 'Discard';

	/// en: 'Stopped'
	String get stoppedCancelled => 'Stopped';

	/// en: 'Something went wrong'
	String get stoppedError => 'Something went wrong';

	/// en: 'Paused — step limit reached'
	String get stoppedMaxSteps => 'Paused — step limit reached';

	/// en: 'Paused — context window is full'
	String get stoppedBudget => 'Paused — context window is full';

	/// en: 'Couldn't load this conversation'
	String get transcriptErrorTitle => 'Couldn\'t load this conversation';

	/// en: 'The local engine didn’t return the messages.'
	String get transcriptErrorHint => 'The local engine didn’t return the messages.';

	/// en: 'What should we dig into?'
	String get landingGreeting => 'What should we dig into?';

	/// en: 'Auto'
	String get modelAuto => 'Auto';

	/// en: 'Mention an entity'
	String get mentionEntity => 'Mention an entity';

	/// en: 'Attach files'
	String get attachFile => 'Attach files';

	/// en: 'Drop files to attach'
	String get dropToAttach => 'Drop files to attach';

	late final Translations$chat$tool$en tool = Translations$chat$tool$en.internal(_root);
	late final Translations$chat$gate$en gate = Translations$chat$gate$en.internal(_root);

	/// en: 'Context compacted'
	String get contextCompacted => 'Context compacted';

	/// en: 'Context compacted · $n earlier messages folded into the summary'
	String contextCompactedCount({required Object n}) => 'Context compacted · ${n} earlier messages folded into the summary';
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

// Path: notifications
class Translations$notifications$en {
	Translations$notifications$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Notifications'
	String get title => 'Notifications';

	/// en: 'Needs you'
	String get needsYou => 'Needs you';

	/// en: 'Notifications'
	String get feed => 'Notifications';

	/// en: 'Mark all read'
	String get markAllRead => 'Mark all read';

	/// en: 'Mark read'
	String get markRead => 'Mark read';

	/// en: 'You're all caught up'
	String get emptyTitle => 'You\'re all caught up';

	/// en: 'New activity shows up here.'
	String get emptyHint => 'New activity shows up here.';

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';

	/// en: 'Earlier'
	String get earlier => 'Earlier';

	/// en: '(unnamed)'
	String get unnamed => '(unnamed)';

	/// en: 'New activity'
	String get unknown => 'New activity';

	late final Translations$notifications$kind$en kind = Translations$notifications$kind$en.internal(_root);
	late final Translations$notifications$verb$en verb = Translations$notifications$verb$en.internal(_root);

	/// en: 'left 1 reference dangling'
	String get depBrokenOne => 'left 1 reference dangling';

	/// en: 'left $n references dangling'
	String depBrokenMany({required Object n}) => 'left ${n} references dangling';

	/// en: 'View'
	String get view => 'View';
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

// Path: graph
class Translations$graph$en {
	Translations$graph$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$graph$kind$en kind = Translations$graph$kind$en.internal(_root);
}

// Path: a11y
class Translations$a11y$en {
	Translations$a11y$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Editing $field'
	String editingField({required Object field}) => 'Editing ${field}';

	/// en: 'Edit $field'
	String editField({required Object field}) => 'Edit ${field}';

	/// en: 'Add tag: $field'
	String addTagTo({required Object field}) => 'Add tag: ${field}';

	/// en: 'Display options'
	String get displayOptions => 'Display options';

	/// en: 'More actions'
	String get moreActions => 'More actions';

	/// en: 'Zoom in'
	String get graphZoomIn => 'Zoom in';

	/// en: 'Zoom out'
	String get graphZoomOut => 'Zoom out';

	/// en: 'Fit to view'
	String get graphFit => 'Fit to view';

	/// en: 'Node $id, $kind, $ref'
	String graphNode({required Object id, required Object kind, required Object ref}) => 'Node ${id}, ${kind}, ${ref}';

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

	/// en: 'Recently active'
	String get sortRecent => 'Recently active';

	/// en: 'Recently created'
	String get sortCreated => 'Recently created';

	/// en: 'Name'
	String get sortName => 'Name';

	/// en: 'Display'
	String get displayLabel => 'Display';

	/// en: 'Show counts'
	String get showCount => 'Show counts';

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

// Path: documents
class Translations$documents$en {
	Translations$documents$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Documents'
	String get documents => 'Documents';

	/// en: 'Skills'
	String get skills => 'Skills';

	/// en: 'Untitled'
	String get untitled => 'Untitled';

	/// en: 'Filter'
	String get filter => 'Filter';

	/// en: 'New'
	String get kNew => 'New';

	/// en: 'Couldn't load your library'
	String get errorTitle => 'Couldn\'t load your library';

	/// en: 'The local engine didn't return it.'
	String get errorHint => 'The local engine didn\'t return it.';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Nothing here yet'
	String get emptyTitle => 'Nothing here yet';

	/// en: 'Create a document or a skill to get started.'
	String get emptyHint => 'Create a document or a skill to get started.';

	/// en: 'Pick a document'
	String get pickTitle => 'Pick a document';

	/// en: 'Choose a document or skill on the left to read or edit it.'
	String get pickHint => 'Choose a document or skill on the left to read or edit it.';

	/// en: 'Couldn't open this'
	String get loadFailed => 'Couldn\'t open this';

	/// en: 'This document is empty.'
	String get emptyDoc => 'This document is empty.';

	/// en: 'New skill'
	String get newSkill => 'New skill';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Duplicate'
	String get duplicate => 'Duplicate';

	/// en: 'Delete this page?'
	String get deleteDocTitle => 'Delete this page?';

	/// en: '“$name” and everything nested inside it will be removed.'
	String deleteDocBody({required Object name}) => '“${name}” and everything nested inside it will be removed.';

	/// en: 'Delete this skill?'
	String get deleteSkillTitle => 'Delete this skill?';

	/// en: 'The “$name” skill will be removed.'
	String deleteSkillBody({required Object name}) => 'The “${name}” skill will be removed.';

	/// en: 'Action failed'
	String get actionFailed => 'Action failed';

	late final Translations$documents$props$en props = Translations$documents$props$en.internal(_root);
	late final Translations$documents$slash$en slash = Translations$documents$slash$en.internal(_root);

	/// en: '$n tools'
	String toolCount({required Object n}) => '${n} tools';
}

// Path: markdown
class Translations$markdown$en {
	Translations$markdown$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'image not loaded'
	String get imageNotLoaded => 'image not loaded';
}

// Path: attach
class Translations$attach$en {
	Translations$attach$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Unavailable'
	String get unavailable => 'Unavailable';

	/// en: 'Tap to retry'
	String get retry => 'Tap to retry';

	/// en: 'Tap to load'
	String get tapToLoad => 'Tap to load';

	/// en: 'Uploading…'
	String get uploading => 'Uploading…';

	/// en: 'Failed — tap to retry'
	String get failedRetry => 'Failed — tap to retry';

	/// en: 'Couldn't read file'
	String get failedUnreadable => 'Couldn\'t read file';

	/// en: 'Remove'
	String get remove => 'Remove';
}

// Path: chat.time
class Translations$chat$time$en {
	Translations$chat$time$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Just now'
	String get justNow => 'Just now';

	/// en: '$n min ago'
	String minutesAgo({required Object n}) => '${n} min ago';

	/// en: '$n hr ago'
	String hoursAgo({required Object n}) => '${n} hr ago';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';

	/// en: '$n days ago'
	String daysAgo({required Object n}) => '${n} days ago';
}

// Path: chat.bucket
class Translations$chat$bucket$en {
	Translations$chat$bucket$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Pinned'
	String get pinned => 'Pinned';

	/// en: 'Recents'
	String get recents => 'Recents';
}

// Path: chat.tool
class Translations$chat$tool$en {
	Translations$chat$tool$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Calling'
	String get calling => 'Calling';

	/// en: 'Called'
	String get called => 'Called';

	/// en: 'Awaiting confirmation'
	String get awaitingConfirm => 'Awaiting confirmation';

	/// en: 'failed'
	String get failed => 'failed';

	/// en: 'Denied'
	String get denied => 'Denied';

	/// en: 'Interrupted'
	String get cancelled => 'Interrupted';

	/// en: '$s s'
	String elapsed({required Object s}) => '${s} s';

	/// en: 'Intent'
	String get intent => 'Intent';

	/// en: 'Arguments'
	String get argsLabel => 'Arguments';

	/// en: 'Progress'
	String get progressLabel => 'Progress';

	/// en: 'Result'
	String get resultLabel => 'Result';

	/// en: 'Error'
	String get errorLabel => 'Error';

	/// en: 'live'
	String get liveLabel => 'live';

	/// en: 'Truncated · full content $chars chars'
	String truncatedNote({required Object chars}) => 'Truncated · full content ${chars} chars';

	/// en: '…$n earlier lines omitted'
	String progressOmitted({required Object n}) => '…${n} earlier lines omitted';

	/// en: 'Reading'
	String get reading => 'Reading';

	/// en: 'Read'
	String get read => 'Read';

	/// en: 'Writing'
	String get writing => 'Writing';

	/// en: 'Wrote'
	String get wrote => 'Wrote';

	/// en: 'Editing'
	String get editing => 'Editing';

	/// en: 'Edited'
	String get edited => 'Edited';

	/// en: 'Globbing'
	String get globbing => 'Globbing';

	/// en: 'Globbed'
	String get globbed => 'Globbed';

	/// en: 'Searching'
	String get grepping => 'Searching';

	/// en: 'Searched'
	String get grepped => 'Searched';

	/// en: 'Listing'
	String get listing => 'Listing';

	/// en: 'Listed'
	String get listed => 'Listed';

	/// en: 'Running command'
	String get runningCmd => 'Running command';

	/// en: 'Ran'
	String get ranCmd => 'Ran';

	/// en: '$n lines'
	String lines({required Object n}) => '${n} lines';

	/// en: 'first $n lines (truncated)'
	String linesTruncated({required Object n}) => 'first ${n} lines (truncated)';

	/// en: '$n matches'
	String matches({required Object n}) => '${n} matches';

	/// en: '$n files'
	String files({required Object n}) => '${n} files';

	/// en: '$n items'
	String items({required Object n}) => '${n} items';

	/// en: 'no matches'
	String get noMatches => 'no matches';

	/// en: 'exit $code'
	String exit({required Object code}) => 'exit ${code}';

	/// en: 'timed out'
	String get timedOut => 'timed out';

	/// en: '$n bytes'
	String wroteBytes({required Object n}) => '${n} bytes';

	/// en: 'Creating $kind'
	String creatingKind({required Object kind}) => 'Creating ${kind}';

	/// en: 'Created $kind'
	String createdKind({required Object kind}) => 'Created ${kind}';

	/// en: 'Updating $kind'
	String updatingKind({required Object kind}) => 'Updating ${kind}';

	/// en: 'Updated $kind'
	String updatedKind({required Object kind}) => 'Updated ${kind}';

	/// en: 'env ready'
	String get envReady => 'env ready';

	/// en: 'env building'
	String get envBuilding => 'env building';

	/// en: 'env failed'
	String get envFailed => 'env failed';

	/// en: 'restarted'
	String get restarted => 'restarted';

	late final Translations$chat$tool$kind$en kind = Translations$chat$tool$kind$en.internal(_root);

	/// en: 'Asking'
	String get asking => 'Asking';

	/// en: 'Asked'
	String get asked => 'Asked';

	/// en: 'Answered'
	String get answered => 'Answered';

	/// en: 'Skipped'
	String get skipped => 'Skipped';

	/// en: 'Empty answer'
	String get emptyAnswer => 'Empty answer';

	/// en: 'Awaiting your answer'
	String get awaitingAnswer => 'Awaiting your answer';

	/// en: 'Deciding'
	String get deciding => 'Deciding';

	/// en: 'Approved'
	String get approved => 'Approved';

	/// en: 'Rejected'
	String get rejected => 'Rejected';

	/// en: 'Decided'
	String get decided => 'Decided';

	/// en: 'Approve'
	String get approveVerdict => 'Approve';

	/// en: 'Reject'
	String get rejectVerdict => 'Reject';

	/// en: 'This node isn't awaiting a decision (already decided, timed out, or a wrong node id) — this decision had no effect.'
	String get notParked => 'This node isn\'t awaiting a decision (already decided, timed out, or a wrong node id) — this decision had no effect.';

	/// en: 'showing $shown/$total nodes, full set in the flowrun'
	String nodesShown({required Object shown, required Object total}) => 'showing ${shown}/${total} nodes, full set in the flowrun';

	/// en: 'Checking the approval inbox'
	String get clearing => 'Checking the approval inbox';

	/// en: 'Checked'
	String get cleared => 'Checked';

	/// en: '$n awaiting'
	String inboxCount({required Object n}) => '${n} awaiting';

	/// en: 'None awaiting'
	String get inboxEmpty => 'None awaiting';

	/// en: '$n more'
	String inboxMore({required Object n}) => '${n} more';

	/// en: 'Approval'
	String get inboxRef => 'Approval';

	/// en: 'Summary'
	String get inboxSummary => 'Summary';

	/// en: 'Waiting'
	String get inboxWait => 'Waiting';

	/// en: 'run'
	String get inboxRun => 'run';

	/// en: 'Inbox empty — no run is awaiting approval'
	String get inboxEmptyState => 'Inbox empty — no run is awaiting approval';

	/// en: 'Running'
	String get runtimeRunning => 'Running';

	/// en: 'Instance not running'
	String get runtimeStopped => 'Instance not running';

	/// en: 'Instance crashed'
	String get runtimeCrashed => 'Instance crashed';

	/// en: 'attempt $n'
	String envFixAttempt({required Object n}) => 'attempt ${n}';

	/// en: 'revised deps, retried'
	String get envFixHealing => 'revised deps, retried';

	/// en: 'Environment self-heal'
	String get envFixTitle => 'Environment self-heal';

	/// en: 'Not activated'
	String get wfInactive => 'Not activated';

	/// en: '$nodes nodes · $edges edges'
	String wfGraphCounts({required Object nodes, required Object edges}) => '${nodes} nodes · ${edges} edges';

	/// en: 'activate_workflow to go live · trigger_workflow to test'
	String get wfActivateHint => 'activate_workflow to go live · trigger_workflow to test';

	/// en: 'Composing'
	String get wfGrowing => 'Composing';

	/// en: 'nodes'
	String get wfNodeUnit => 'nodes';

	/// en: 'edges'
	String get wfEdgeUnit => 'edges';

	/// en: 'metadata only (graph unchanged)'
	String get wfDeltaEmpty => 'metadata only (graph unchanged)';

	/// en: 'incremental change (full graph in the entity panel)'
	String get wfMorphNote => 'incremental change (full graph in the entity panel)';

	/// en: 'otherwise'
	String get ctlOtherwise => 'otherwise';

	/// en: 'catch-all'
	String get ctlWhenTrue => 'catch-all';

	/// en: 'emit'
	String get ctlEmit => 'emit';

	/// en: 'no catch-all: last must be when:"true"'
	String get ctlNoCatchall => 'no catch-all: last must be when:"true"';

	/// en: 'never times out'
	String get apfTimeoutNever => 'never times out';

	/// en: 'note allowed'
	String get apfAllowReason => 'note allowed';

	/// en: 'Approve'
	String get apfApprove => 'Approve';

	/// en: 'Reject'
	String get apfReject => 'Reject';

	/// en: 'the approver will see'
	String get apfPreviewHint => 'the approver will see';

	/// en: 'on timeout →'
	String get apfOnTimeout => 'on timeout →';

	/// en: 'Show all'
	String get proseExpand => 'Show all';

	/// en: 'Collapse'
	String get proseCollapse => 'Collapse';

	/// en: 'requested name was taken, auto-renamed'
	String get docAutoRenamed => 'requested name was taken, auto-renamed';

	/// en: 'whole overwrite · no version to revert to'
	String get skillNoRevert => 'whole overwrite · no version to revert to';

	/// en: 'pre-authorized after activation (no confirm)'
	String get skillPreauth => 'pre-authorized after activation (no confirm)';

	/// en: 'inline'
	String get skillInline => 'inline';

	/// en: 'fork'
	String get skillFork => 'fork';

	/// en: 'did not take effect'
	String get docSoftFail => 'did not take effect';

	/// en: 'not listening'
	String get trgNotListening => 'not listening';

	/// en: 'hot-updated live'
	String get trgHotUpdate => 'hot-updated live';

	/// en: 'created but not listening — an active workflow reference starts it'
	String get trgCreateNote => 'created but not listening — an active workflow reference starts it';

	/// en: 'Copied'
	String get copyDone => 'Copied';

	/// en: 'secret'
	String get trgSecret => 'secret';

	/// en: 'every $n s'
	String trgEvery({required Object n}) => 'every ${n} s';

	/// en: 'when'
	String get trgCondition => 'when';

	/// en: 'emit'
	String get trgOutput => 'emit';

	/// en: 'Searching $kind'
	String searchingKind({required Object kind}) => 'Searching ${kind}';

	/// en: 'Searched $kind'
	String searchedKind({required Object kind}) => 'Searched ${kind}';

	/// en: 'Listing $kind'
	String listingKind({required Object kind}) => 'Listing ${kind}';

	/// en: 'Listed $kind'
	String listedKind({required Object kind}) => 'Listed ${kind}';

	/// en: '$n found'
	String hits({required Object n}) => '${n} found';

	/// en: '$n of $total'
	String hitsOfTotal({required Object n, required Object total}) => '${n} of ${total}';

	/// en: 'empty'
	String get emptyList => 'empty';

	/// en: 'current'
	String get hitCurrent => 'current';

	/// en: 'first $n of $total'
	String cappedFooter({required Object n, required Object total}) => 'first ${n} of ${total}';

	/// en: 'first $n of $total (server-truncated)'
	String serverTruncatedNote({required Object n, required Object total}) => 'first ${n} of ${total} (server-truncated)';

	/// en: 'active'
	String get wfActive => 'active';

	/// en: '$n refs'
	String refCount({required Object n}) => '${n} refs';

	/// en: 'listening'
	String get trgListening => 'listening';

	/// en: 'raw result'
	String get rawResult => 'raw result';

	/// en: 'content truncated — see the full text in the entity panel'
	String get contentTruncated => 'content truncated — see the full text in the entity panel';

	/// en: 'no active version'
	String get noActiveVersion => 'no active version';

	/// en: 'description'
	String get kvDescription => 'description';

	/// en: 'signature'
	String get kvSignature => 'signature';

	/// en: 'deps'
	String get kvDeps => 'deps';

	/// en: 'updated'
	String get kvUpdated => 'updated';

	/// en: 'methods'
	String get kvMethods => 'methods';

	/// en: 'model'
	String get kvModel => 'model';

	/// en: 'concurrency'
	String get kvConcurrency => 'concurrency';

	/// en: 'graph'
	String get kvGraph => 'graph';

	/// en: 'context'
	String get kvContext => 'context';

	/// en: 'source'
	String get kvSource => 'source';

	/// en: 'timeout'
	String get apfTimeout => 'timeout';

	/// en: 'on timeout'
	String get apfBehavior => 'on timeout';

	/// en: 'env failed'
	String get envFailedShort => 'env failed';

	/// en: 'env pending'
	String get envPending => 'env pending';

	/// en: 'allowedTools are pre-authorized (no danger confirm) for this run when active'
	String get skillPreauthNote => 'allowedTools are pre-authorized (no danger confirm) for this run when active';

	/// en: 'Viewing $kind'
	String viewingKind({required Object kind}) => 'Viewing ${kind}';

	/// en: 'Viewed $kind'
	String viewedKind({required Object kind}) => 'Viewed ${kind}';

	/// en: 'tags'
	String get kvTags => 'tags';

	/// en: 'truncated'
	String get attachTruncated => 'truncated';

	/// en: 'Reading document'
	String get readingDoc => 'Reading document';

	/// en: 'Read document'
	String get readDoc => 'Read document';

	/// en: 'Reading attachment'
	String get readingAtt => 'Reading attachment';

	/// en: 'Read attachment'
	String get readAtt => 'Read attachment';

	/// en: 'Reverting $kind'
	String revertingKind({required Object kind}) => 'Reverting ${kind}';

	/// en: 'Reverted $kind'
	String revertedKind({required Object kind}) => 'Reverted ${kind}';

	/// en: 'Deleting $kind'
	String deletingKind({required Object kind}) => 'Deleting ${kind}';

	/// en: 'Deleted $kind'
	String deletedKind2({required Object kind}) => 'Deleted ${kind}';

	/// en: 'Staging'
	String get staging => 'Staging';

	/// en: 'Staged'
	String get staged => 'Staged';

	/// en: 'Activating'
	String get activatingWf => 'Activating';

	/// en: 'Activated'
	String get activatedWf => 'Activated';

	/// en: 'Deactivating'
	String get deactivatingWf => 'Deactivating';

	/// en: 'Stopped listening'
	String get deactivatedWf => 'Stopped listening';

	/// en: 'Killing'
	String get killingWf => 'Killing';

	/// en: 'Killed'
	String get killedWf => 'Killed';

	/// en: 'Restarting'
	String get restarting => 'Restarting';

	/// en: 'not running after restart'
	String get restartFailed => 'not running after restart';

	/// en: 'Activating skill'
	String get activatingSkill => 'Activating skill';

	/// en: 'Activated skill'
	String get activatedSkill => 'Activated skill';

	/// en: 'Moving document'
	String get movingDoc => 'Moving document';

	/// en: 'Moved document'
	String get movedDoc => 'Moved document';

	/// en: 'Updating info'
	String get updatingMeta => 'Updating info';

	/// en: 'Updated info'
	String get updatedMeta => 'Updated info';

	/// en: 'Renaming'
	String get renaming => 'Renaming';

	/// en: 'Renamed'
	String get renamed => 'Renamed';

	/// en: 'Configuring'
	String get configuring => 'Configuring';

	/// en: 'Configured'
	String get configured => 'Configured';

	/// en: '↩ v$v'
	String rewind({required Object v}) => '↩ v${v}';

	/// en: 'deleted'
	String get deletedShort => 'deleted';

	/// en: '$n refs affected'
	String depsAffected({required Object n}) => '${n} refs affected';

	/// en: 'deleted · $n descendants'
	String docDescendants({required Object n}) => 'deleted · ${n} descendants';

	/// en: '→ $path'
	String movedTo({required Object path}) => '→ ${path}';

	/// en: 'killed $n in-flight'
	String killedN({required Object n}) => 'killed ${n} in-flight';

	/// en: 'no in-flight runs'
	String get noInflight => 'no in-flight runs';

	/// en: '$n keys'
	String nKeys({required Object n}) => '${n} keys';

	/// en: 'awaiting next real trigger'
	String get staged2 => 'awaiting next real trigger';

	/// en: 'listening'
	String get listening2 => 'listening';

	/// en: 'offline'
	String get offline => 'offline';

	/// en: 'draining'
	String get draining => 'draining';

	/// en: '+$n more'
	String moreHits({required Object n}) => '+${n} more';

	/// en: 'restores code/IO/deps only; name·desc·tags do not follow versions'
	String get noteRevertFn => 'restores code/IO/deps only; name·desc·tags do not follow versions';

	/// en: 'restart triggered to run the new version; memory state cleared — see the handler panel'
	String get noteRevertHd => 'restart triggered to run the new version; memory state cleared — see the handler panel';

	/// en: 'memory state cleared'
	String get noteRestart => 'memory state cleared';

	/// en: 'listening stopped; killed runs are cancelled — see flowruns'
	String get noteKill => 'listening stopped; killed runs are cancelled — see flowruns';

	/// en: 'runs once on the next real trigger, then auto-unstages'
	String get noteStage => 'runs once on the next real trigger, then auto-unstages';

	/// en: 'to abort in-flight now, use kill_workflow'
	String get noteDeactivateDrain => 'to abort in-flight now, use kill_workflow';

	/// en: 'soft-deleted, recoverable'
	String get noteDeleteDocSoft => 'soft-deleted, recoverable';

	/// en: 'listening released'
	String get noteTriggerRemoved => 'listening released';

	/// en: 'restart triggered to take effect; see the handler panel'
	String get noteConfig => 'restart triggered to take effect; see the handler panel';

	/// en: 'no new version, no restart, memory state preserved'
	String get noteMetaHandler => 'no new version, no restart, memory state preserved';

	/// en: 'name'
	String get kvName => 'name';

	/// en: 'in-flight runs finish then stop; to abort now use kill_workflow'
	String get noteDraining => 'in-flight runs finish then stop; to abort now use kill_workflow';

	/// en: 'Archiving conversation'
	String get cvArchiving => 'Archiving conversation';

	/// en: 'Archived conversation'
	String get cvArchived => 'Archived conversation';

	/// en: 'Unarchiving'
	String get cvUnarchiving => 'Unarchiving';

	/// en: 'Unarchived'
	String get cvUnarchived => 'Unarchived';

	/// en: 'Pinning conversation'
	String get cvPinning => 'Pinning conversation';

	/// en: 'Pinned conversation'
	String get cvPinned => 'Pinned conversation';

	/// en: 'Unpinning'
	String get cvUnpinning => 'Unpinning';

	/// en: 'Unpinned'
	String get cvUnpinned => 'Unpinned';

	/// en: 'Renaming conversation'
	String get cvRenaming => 'Renaming conversation';

	/// en: 'Renamed conversation'
	String get cvRenamed => 'Renamed conversation';

	/// en: 'Managing conversation'
	String get cvManaging => 'Managing conversation';

	/// en: 'Managed conversation'
	String get cvManaged => 'Managed conversation';

	/// en: 'Listing conversations'
	String get cvListing => 'Listing conversations';

	/// en: 'Listed conversations'
	String get cvListed => 'Listed conversations';

	/// en: 'Searching conversations'
	String get cvSearching => 'Searching conversations';

	/// en: 'Searched conversations'
	String get cvSearched => 'Searched conversations';

	/// en: '$n'
	String cvCount({required Object n}) => '${n}';

	/// en: '$n+'
	String cvCountMore({required Object n}) => '${n}+';

	/// en: 'no conversations'
	String get cvEmpty => 'no conversations';

	/// en: '$n hits'
	String cvHits({required Object n}) => '${n} hits';

	/// en: 'no matches'
	String get cvNoMatch => 'no matches';

	/// en: 'incl. archived'
	String get cvInclArchived => 'incl. archived';

	/// en: 'next page'
	String get cvNextPage => 'next page';

	/// en: 'more pages'
	String get cvMorePages => 'more pages';

	/// en: 'archived'
	String get cvArchivedBadge => 'archived';

	/// en: 'pinned'
	String get cvPinnedBadge => 'pinned';

	/// en: '×$n'
	String cvChunks({required Object n}) => '×${n}';

	/// en: 'first $n of $total hits'
	String cvShownOfTotal({required Object n, required Object total}) => 'first ${n} of ${total} hits';

	/// en: 'archived'
	String get cvStatusArchived => 'archived';

	/// en: 'pinned'
	String get cvStatusPinned => 'pinned';

	/// en: 'title'
	String get cvStatusTitle => 'title';

	/// en: 'sending a message auto-unarchives'
	String get cvAutoUnarchive => 'sending a message auto-unarchives';

	/// en: 'blocked'
	String get bashBlocked => 'blocked';

	/// en: 'cancelled'
	String get bashCancelled => 'cancelled';

	/// en: 'exit unknown'
	String get bashExitUnknown => 'exit unknown';

	/// en: '$id · bg'
	String bashBackground({required Object id}) => '${id} · bg';

	/// en: 'running'
	String get statusRunning => 'running';

	/// en: 'exit $code'
	String statusExited({required Object code}) => 'exit ${code}';

	/// en: 'killed'
	String get statusKilled => 'killed';

	/// en: 'errored'
	String get statusErrored => 'errored';

	/// en: 'session not found'
	String get statusNotFound => 'session not found';

	/// en: 'already finished'
	String get killFinished => 'already finished';

	/// en: 'session not found'
	String get killNotFound => 'session not found';

	/// en: 'Reading output'
	String get polling => 'Reading output';

	/// en: 'Read output'
	String get polled => 'Read output';

	/// en: 'Terminating'
	String get killing => 'Terminating';

	/// en: 'Terminated'
	String get killed3 => 'Terminated';

	/// en: 'latest'
	String get backToLatest => 'latest';

	/// en: 'show $n earlier lines'
	String showEarlier({required Object n}) => 'show ${n} earlier lines';

	/// en: 'poll with BashOutput, or KillShell to terminate'
	String get bashBgHint => 'poll with BashOutput, or KillShell to terminate';

	/// en: 'output too long — head dropped, tail kept'
	String get bashHeadTruncated => 'output too long — head dropped, tail kept';

	/// en: '(no output)'
	String get bashNoOutput => '(no output)';

	/// en: 'moved to background'
	String get ranBg => 'moved to background';

	/// en: 'may have been terminated / cleaned up / backend restarted'
	String get bashSessionGoneHint => 'may have been terminated / cleaned up / backend restarted';

	/// en: '(no new output)'
	String get bashNoNew => '(no new output)';

	/// en: '$n bytes dropped (ring overflow)'
	String bashDropped({required Object n}) => '${n} bytes dropped (ring overflow)';

	/// en: 'not found'
	String get fsNotFound => 'not found';

	/// en: 'denied'
	String get fsDenied => 'denied';

	/// en: 'read first'
	String get fsReadFirst => 'read first';

	/// en: 'no match'
	String get fsNoMatch => 'no match';

	/// en: '$n matches'
	String fsAmbiguous({required Object n}) => '${n} matches';

	/// en: 'file changed'
	String get fsModified => 'file changed';

	/// en: 'no parent dir'
	String get fsParentMissing => 'no parent dir';

	/// en: 'bad path'
	String get fsBadPath => 'bad path';

	/// en: 'failed'
	String get fsFailed => 'failed';

	/// en: 'lines $f–$l'
	String readRange({required Object f, required Object l}) => 'lines ${f}–${l}';

	/// en: '$n+ lines'
	String readFloor({required Object n}) => '${n}+ lines';

	/// en: 'lines $f–$n+'
	String readRangeFloor({required Object f, required Object n}) => 'lines ${f}–${n}+';

	/// en: '$n replaced'
	String edited2({required Object n}) => '${n} replaced';

	/// en: 'result unconfirmed'
	String get fsUnconfirmed => 'result unconfirmed';

	/// en: 'empty file'
	String get emptyFile => 'empty file';

	/// en: 'replaced all $n'
	String replaceAllNote({required Object n}) => 'replaced all ${n}';

	/// en: 'Calling MCP tool'
	String get mcpCalling => 'Calling MCP tool';

	/// en: 'Called MCP tool'
	String get mcpCalled => 'Called MCP tool';

	/// en: 'MCP error'
	String get mcpError => 'MCP error';

	/// en: 'Calling method'
	String get hdCalling => 'Calling method';

	/// en: 'Called method'
	String get hdCalled => 'Called method';

	/// en: 'result'
	String get hdResult => 'result';

	/// en: '(empty)'
	String get lsEmpty => '(empty)';

	/// en: '$pattern in $root'
	String globHeader({required Object pattern, required Object root}) => '${pattern} in ${root}';

	/// en: 'no return value'
	String get noReturn => 'no return value';

	/// en: 'ok'
	String get execOk => 'ok';

	/// en: 'failed'
	String get execFailed => 'failed';

	/// en: 'input'
	String get ioInput => 'input';

	/// en: 'output'
	String get ioOutput => 'output';

	/// en: 'logs · $n lines'
	String execLogs({required Object n}) => 'logs · ${n} lines';

	/// en: 'Running function'
	String get runningFn => 'Running function';

	/// en: 'Ran function'
	String get ranFn => 'Ran function';

	/// en: 'Calling method'
	String get callingMethod => 'Calling method';

	/// en: 'Called method'
	String get calledMethod => 'Called method';

	/// en: 'Firing trigger'
	String get firingTrigger => 'Firing trigger';

	/// en: 'Fired trigger'
	String get firedTrigger => 'Fired trigger';

	/// en: 'Activation'
	String get fireActivation => 'Activation';

	/// en: 'Payload is always {manual:true}; see the trigger log for fan-out and disposition'
	String get firePayloadNote => 'Payload is always {manual:true}; see the trigger log for fan-out and disposition';

	/// en: 'Replaying run'
	String get replayingRun => 'Replaying run';

	/// en: 'Replayed run'
	String get replayedRun => 'Replayed run';

	/// en: 'Completed'
	String get runCompleted => 'Completed';

	/// en: 'Still failed'
	String get runStillFailed => 'Still failed';

	/// en: 'Cancelled'
	String get runCancelled => 'Cancelled';

	/// en: 'Awaiting approval'
	String get runAwaitApproval => 'Awaiting approval';

	/// en: '$n nodes'
	String nodeCount({required Object n}) => '${n} nodes';

	/// en: 'Re-run under the originally pinned versions; edits made after the failure do not take effect'
	String get replayPinNote => 'Re-run under the originally pinned versions; edits made after the failure do not take effect';

	/// en: 'Replay #$n'
	String replayTimes({required Object n}) => 'Replay #${n}';

	/// en: 'Showing $shown/$total nodes'
	String flowShown({required Object shown, required Object total}) => 'Showing ${shown}/${total} nodes';

	/// en: 'Show remaining $n'
	String flowExpandAll({required Object n}) => 'Show remaining ${n}';

	/// en: 'waiting'
	String get nodeWait => 'waiting';

	/// en: 'Triggering workflow'
	String get triggeringWf => 'Triggering workflow';

	/// en: 'Triggered workflow'
	String get triggeredWf => 'Triggered workflow';

	/// en: 'empty payload'
	String get emptyPayload => 'empty payload';

	/// en: 'Run started — inspect with get_flowrun'
	String get triggerStartedNote => 'Run started — inspect with get_flowrun';

	/// en: 'Invoking agent'
	String get invokingAgent => 'Invoking agent';

	/// en: 'Invoked agent'
	String get invokedAgent => 'Invoked agent';

	/// en: '$n steps'
	String agentSteps({required Object n}) => '${n} steps';

	/// en: 'Timed out'
	String get agentTimeout => 'Timed out';

	/// en: 'The trajectory streamed live; replay it from the execution record'
	String get agentTrajectoryNote => 'The trajectory streamed live; replay it from the execution record';

	/// en: 'this page'
	String get beadPageScope => 'this page';

	/// en: 'Searching function runs'
	String get searchingFnExec => 'Searching function runs';

	/// en: 'Searched function runs'
	String get searchedFnExec => 'Searched function runs';

	/// en: 'Searching handler calls'
	String get searchingHdCalls => 'Searching handler calls';

	/// en: 'Searched handler calls'
	String get searchedHdCalls => 'Searched handler calls';

	/// en: 'Searching agent runs'
	String get searchingAgentExec => 'Searching agent runs';

	/// en: 'Searched agent runs'
	String get searchedAgentExec => 'Searched agent runs';

	/// en: 'Searching MCP calls'
	String get searchingMcpCalls => 'Searching MCP calls';

	/// en: 'Searched MCP calls'
	String get searchedMcpCalls => 'Searched MCP calls';

	/// en: '$ok ✓ · $failed ✗'
	String aggRollup({required Object ok, required Object failed}) => '${ok} ✓ · ${failed} ✗';

	/// en: '✗ incl. cancelled/timeout'
	String get aggNote => '✗ incl. cancelled/timeout';

	/// en: 'No records'
	String get logNoRecords => 'No records';

	/// en: 'No matches'
	String get logNoMatch => 'No matches';

	/// en: 'chat'
	String get byChat => 'chat';

	/// en: 'agent'
	String get byAgent => 'agent';

	/// en: 'workflow'
	String get byWorkflow => 'workflow';

	/// en: 'manual'
	String get byManual => 'manual';

	/// en: 'Searching runs'
	String get searchingFlowruns => 'Searching runs';

	/// en: 'Searched runs'
	String get searchedFlowruns => 'Searched runs';

	/// en: 'Searching firings'
	String get searchingFirings => 'Searching firings';

	/// en: 'Searched firings'
	String get searchedFirings => 'Searched firings';

	/// en: 'Searching activations'
	String get searchingActivations => 'Searching activations';

	/// en: 'Searched activations'
	String get searchedActivations => 'Searched activations';

	/// en: 'pending'
	String get firingPending => 'pending';

	/// en: 'run started'
	String get firingStarted => 'run started';

	/// en: 'skipped'
	String get firingSkipped => 'skipped';

	/// en: 'superseded'
	String get firingSuperseded => 'superseded';

	/// en: 'shed'
	String get firingShed => 'shed';

	/// en: '$n'
	String logCount({required Object n}) => '${n}';

	/// en: '$n+'
	String logCountMore({required Object n}) => '${n}+';

	/// en: 'a run parked on an approval node stays running at the header'
	String get parkRunCaption => 'a run parked on an approval node stays running at the header';

	/// en: 'Return value'
	String get actReturnValue => 'Return value';

	/// en: 'fan-out $n'
	String actFanout({required Object n}) => 'fan-out ${n}';

	/// en: 'Opening function-run record'
	String get gettingFnExec => 'Opening function-run record';

	/// en: 'Opened function-run record'
	String get gotFnExec => 'Opened function-run record';

	/// en: 'Opening handler-call record'
	String get gettingHdCall => 'Opening handler-call record';

	/// en: 'Opened handler-call record'
	String get gotHdCall => 'Opened handler-call record';

	/// en: 'Opening MCP-call record'
	String get gettingMcpCall => 'Opening MCP-call record';

	/// en: 'Opened MCP-call record'
	String get gotMcpCall => 'Opened MCP-call record';

	/// en: 'Opening activation record'
	String get gettingActivation => 'Opening activation record';

	/// en: 'Opened activation record'
	String get gotActivation => 'Opened activation record';

	/// en: 'Logs'
	String get dossierLogs => 'Logs';

	/// en: 'server stderr (may predate this call)'
	String get dossierStderr => 'server stderr (may predate this call)';

	/// en: '… $n chars omitted …'
	String logOmitted({required Object n}) => '… ${n} chars omitted …';

	/// en: 'conversation'
	String get provConversation => 'conversation';

	/// en: 'message'
	String get provMessage => 'message';

	/// en: 'run'
	String get provFlowrun => 'run';

	/// en: 'trigger'
	String get provTrigger => 'trigger';

	/// en: 'firing'
	String get provFiring => 'firing';

	/// en: 'node'
	String get provNode => 'node';

	/// en: 'fired'
	String get fireYes => 'fired';

	/// en: 'not fired'
	String get fireNo => 'not fired';

	/// en: 'Opening run'
	String get gettingFlowrun => 'Opening run';

	/// en: 'Opened run'
	String get gotFlowrun => 'Opened run';

	/// en: 'Running'
	String get runStatusRunning => 'Running';

	/// en: 'Opening agent run'
	String get gettingAgentExec => 'Opening agent run';

	/// en: 'Opened agent run'
	String get gotAgentExec => 'Opened agent run';

	/// en: 'Trajectory · $n steps'
	String transcriptSteps({required Object n}) => 'Trajectory · ${n} steps';

	/// en: 'View full trajectory'
	String get transcriptOpenFull => 'View full trajectory';

	/// en: 'No trajectory recorded'
	String get transcriptEmpty => 'No trajectory recorded';

	/// en: 'showing $shown/$total blocks'
	String transcriptCapped({required Object shown, required Object total}) => 'showing ${shown}/${total} blocks';

	/// en: 'thought'
	String get transcriptThought => 'thought';

	/// en: 'reply'
	String get transcriptReply => 'reply';

	/// en: 'Spawning subagent'
	String get spawningSubagent => 'Spawning subagent';

	/// en: 'Spawned subagent'
	String get spawnedSubagent => 'Spawned subagent';

	/// en: 'Task'
	String get subagentTask => 'Task';

	/// en: 'Answer'
	String get subagentAnswer => 'Answer';

	/// en: 'The trajectory streamed live only — replay it with get_subagent_trace'
	String get subagentTraceNote => 'The trajectory streamed live only — replay it with get_subagent_trace';

	/// en: 'Opening subagent trace'
	String get gettingSubTrace => 'Opening subagent trace';

	/// en: 'Opened subagent trace'
	String get gotSubTrace => 'Opened subagent trace';

	/// en: '$n subagent runs'
	String subTraceRuns({required Object n}) => '${n} subagent runs';

	/// en: 'No subagent runs in this conversation'
	String get subTraceNoRuns => 'No subagent runs in this conversation';

	/// en: 'Updating checklist'
	String get todoWriting => 'Updating checklist';

	/// en: 'Updated checklist'
	String get todoWrote => 'Updated checklist';

	/// en: 'Reading checklist'
	String get todoReading => 'Reading checklist';

	/// en: 'Read checklist'
	String get todoRead => 'Read checklist';

	/// en: '$total items · $done done'
	String todoRollup({required Object total, required Object done}) => '${total} items · ${done} done';

	/// en: 'Checklist cleared'
	String get todoCleared => 'Checklist cleared';

	/// en: '$n in progress'
	String todoActive({required Object n}) => '${n} in progress';

	/// en: 'Checking relations'
	String get gettingRelations => 'Checking relations';

	/// en: 'Checked relations'
	String get gotRelations => 'Checked relations';

	/// en: '$n edges'
	String relCount({required Object n}) => '${n} edges';

	/// en: 'No relations'
	String get relNoEdges => 'No relations';

	/// en: '→'
	String get relArrow => '→';

	/// en: 'Checking workflow'
	String get checkingCapability => 'Checking workflow';

	/// en: 'Checked workflow'
	String get checkedCapability => 'Checked workflow';

	/// en: 'structurally runnable'
	String get capRunnable => 'structurally runnable';

	/// en: '$n problems'
	String capProblems({required Object n}) => '${n} problems';

	/// en: '$n warnings'
	String capWarnings({required Object n}) => '${n} warnings';

	/// en: 'Problems'
	String get capProblemsLabel => 'Problems';

	/// en: 'Warnings'
	String get capWarningsLabel => 'Warnings';

	/// en: 'deps resolved'
	String get capResolved => 'deps resolved';

	/// en: 'structurally valid'
	String get capStructural => 'structurally valid';

	/// en: 'Installing MCP server'
	String get installingMcp => 'Installing MCP server';

	/// en: 'Installed MCP server'
	String get installedMcp => 'Installed MCP server';

	/// en: 'Uninstalling MCP server'
	String get uninstallingMcp => 'Uninstalling MCP server';

	/// en: 'Uninstalled MCP server'
	String get uninstalledMcp => 'Uninstalled MCP server';

	/// en: 'Reconnecting MCP'
	String get reconnectingMcp => 'Reconnecting MCP';

	/// en: 'Reconnected MCP'
	String get reconnectedMcp => 'Reconnected MCP';

	/// en: 'connected'
	String get mcpConnected => 'connected';

	/// en: 'disconnected'
	String get mcpDisconnected => 'disconnected';

	/// en: '$n tools'
	String mcpToolCount({required Object n}) => '${n} tools';

	/// en: '$n consecutive failures'
	String mcpFailures({required Object n}) => '${n} consecutive failures';

	/// en: 'Browsing marketplace'
	String get browsingMarket => 'Browsing marketplace';

	/// en: 'Browsed marketplace'
	String get browsedMarket => 'Browsed marketplace';

	/// en: '$n servers'
	String marketCount({required Object n}) => '${n} servers';

	/// en: '$n required env'
	String mcpEnvRequired({required Object n}) => '${n} required env';

	/// en: 'Reading model config'
	String get gettingModelConfig => 'Reading model config';

	/// en: 'Read model config'
	String get gotModelConfig => 'Read model config';

	/// en: 'Default models'
	String get modelDefaults => 'Default models';

	/// en: '$n keys'
	String modelKeys({required Object n}) => '${n} keys';

	/// en: '$n available models'
	String modelAvail({required Object n}) => '${n} available models';
}

// Path: chat.gate
class Translations$chat$gate$en {
	Translations$chat$gate$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Dangerous'
	String get dangerBadge => 'Dangerous';

	/// en: 'Awaiting your approval'
	String get awaitingDanger => 'Awaiting your approval';

	/// en: 'Awaiting your answer'
	String get awaitingAsk => 'Awaiting your answer';

	/// en: 'Arguments'
	String get evidenceLabel => 'Arguments';

	/// en: 'Allow'
	String get approve => 'Allow';

	/// en: 'Always allow'
	String get approveAlways => 'Always allow';

	/// en: 'Don't ask again for $tool this conversation (forgotten on restart)'
	String approveAlwaysHint({required Object tool}) => 'Don\'t ask again for ${tool} this conversation (forgotten on restart)';

	/// en: 'Deny'
	String get deny => 'Deny';

	/// en: 'Don't answer'
	String get decline => 'Don\'t answer';

	/// en: 'Send'
	String get submit => 'Send';

	/// en: 'Type your answer…'
	String get answerPlaceholder => 'Type your answer…';

	/// en: 'Pick one, or type your own'
	String get optionsHint => 'Pick one, or type your own';

	/// en: 'Allowed'
	String get decidedApproved => 'Allowed';

	/// en: 'Allowed · always this conversation'
	String get decidedApprovedAlways => 'Allowed · always this conversation';

	/// en: 'Denied'
	String get decidedDenied => 'Denied';

	/// en: 'Skipped'
	String get decidedDeclined => 'Skipped';
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

// Path: notifications.kind
class Translations$notifications$kind$en {
	Translations$notifications$kind$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Memory'
	String get memory => 'Memory';

	/// en: 'Environment'
	String get sandbox => 'Environment';

	/// en: 'Dependency'
	String get relation => 'Dependency';
}

// Path: notifications.verb
class Translations$notifications$verb$en {
	Translations$notifications$verb$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'created'
	String get created => 'created';

	/// en: 'edited'
	String get edited => 'edited';

	/// en: 'reverted'
	String get reverted => 'reverted';

	/// en: 'updated'
	String get updated => 'updated';

	/// en: 'deleted'
	String get deleted => 'deleted';

	/// en: 'environment rebuilt'
	String get envRebuilt => 'environment rebuilt';

	/// en: 'config updated'
	String get configUpdated => 'config updated';

	/// en: 'config cleared'
	String get configCleared => 'config cleared';

	/// en: 'installed'
	String get installed => 'installed';

	/// en: 'removed'
	String get removed => 'removed';

	/// en: 'reconnected'
	String get reconnected => 'reconnected';

	/// en: 'reconnect failed'
	String get reconnectFailed => 'reconnect failed';

	/// en: 'crashed'
	String get crashed => 'crashed';

	/// en: 'restart failed'
	String get restartFailed => 'restart failed';

	/// en: 'run failed'
	String get runFailed => 'run failed';

	/// en: 'needs attention'
	String get needsAttention => 'needs attention';

	/// en: 'recovered'
	String get recovered => 'recovered';

	/// en: 'is waiting for approval'
	String get waitingApproval => 'is waiting for approval';

	/// en: 'environment ready'
	String get envReady => 'environment ready';

	/// en: 'environment build failed'
	String get envFailed => 'environment build failed';
}

// Path: graph.kind
class Translations$graph$kind$en {
	Translations$graph$kind$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Trigger'
	String get trigger => 'Trigger';

	/// en: 'Action'
	String get action => 'Action';

	/// en: 'Agent'
	String get agent => 'Agent';

	/// en: 'Branch'
	String get control => 'Branch';

	/// en: 'Approval'
	String get approval => 'Approval';

	/// en: 'Unknown'
	String get unknown => 'Unknown';
}

// Path: entities.detail
class Translations$entities$detail$en {
	Translations$entities$detail$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Entities'
	String get crumbRoot => 'Entities';

	late final Translations$entities$detail$tab$en tab = Translations$entities$detail$tab$en.internal(_root);
	late final Translations$entities$detail$verb$en verb = Translations$entities$detail$verb$en.internal(_root);
	late final Translations$entities$detail$hero$en hero = Translations$entities$detail$hero$en.internal(_root);
	late final Translations$entities$detail$gate$en gate = Translations$entities$detail$gate$en.internal(_root);
	late final Translations$entities$detail$codeToggle$en codeToggle = Translations$entities$detail$codeToggle$en.internal(_root);
	late final Translations$entities$detail$sec$en sec = Translations$entities$detail$sec$en.internal(_root);
	late final Translations$entities$detail$card$en card = Translations$entities$detail$card$en.internal(_root);
	late final Translations$entities$detail$graph$en graph = Translations$entities$detail$graph$en.internal(_root);
	late final Translations$entities$detail$cockpit$en cockpit = Translations$entities$detail$cockpit$en.internal(_root);
	late final Translations$entities$detail$kv$en kv = Translations$entities$detail$kv$en.internal(_root);
	late final Translations$entities$detail$val$en val = Translations$entities$detail$val$en.internal(_root);
	late final Translations$entities$detail$mounts$en mounts = Translations$entities$detail$mounts$en.internal(_root);
	late final Translations$entities$detail$trigger$en trigger = Translations$entities$detail$trigger$en.internal(_root);

	/// en: 'Add tag'
	String get addTag => 'Add tag';

	late final Translations$entities$detail$state$en state = Translations$entities$detail$state$en.internal(_root);
	late final Translations$entities$detail$editor$en editor = Translations$entities$detail$editor$en.internal(_root);
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

	/// en: 'Awaiting approval'
	String get approvalTitle => 'Awaiting approval';

	/// en: 'Approve'
	String get approve => 'Approve';

	/// en: 'Reject'
	String get reject => 'Reject';

	/// en: 'First decision wins.'
	String get approvalHint => 'First decision wins.';

	/// en: 'Reason (optional)'
	String get reasonHint => 'Reason (optional)';

	/// en: 'No pending approvals'
	String get inboxEmpty => 'No pending approvals';

	/// en: 'Approvals waiting for a decision will appear here.'
	String get inboxEmptyHint => 'Approvals waiting for a decision will appear here.';
}

// Path: documents.props
class Translations$documents$props$en {
	Translations$documents$props$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Properties'
	String get title => 'Properties';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'Description'
	String get description => 'Description';

	/// en: 'Tags'
	String get tags => 'Tags';

	/// en: 'Add a tag'
	String get addTag => 'Add a tag';

	/// en: 'Path'
	String get path => 'Path';

	/// en: 'Size'
	String get size => 'Size';

	/// en: 'Modified'
	String get modified => 'Modified';

	/// en: 'Context'
	String get context => 'Context';

	/// en: 'Inline'
	String get contextInline => 'Inline';

	/// en: 'Fork'
	String get contextFork => 'Fork';

	/// en: 'Agent'
	String get agent => 'Agent';

	/// en: 'Subagent type to dispatch — required for a fork skill.'
	String get agentHint => 'Subagent type to dispatch — required for a fork skill.';

	/// en: 'Allowed tools'
	String get tools => 'Allowed tools';

	/// en: 'Add a tool'
	String get addTool => 'Add a tool';

	/// en: 'Arguments'
	String get arguments => 'Arguments';

	/// en: 'Add an argument'
	String get addArg => 'Add an argument';

	/// en: 'Model can invoke'
	String get modelInvoke => 'Model can invoke';

	/// en: 'User-invocable'
	String get userInvoke => 'User-invocable';

	/// en: 'On'
	String get on => 'On';

	/// en: 'Off'
	String get off => 'Off';

	/// en: 'Nothing selected'
	String get empty => 'Nothing selected';

	/// en: 'Select a page or skill to see its properties.'
	String get emptyHint => 'Select a page or skill to see its properties.';

	/// en: 'Outline'
	String get outline => 'Outline';

	/// en: 'Backlinks'
	String get backlinks => 'Backlinks';

	/// en: 'No pages link here yet.'
	String get noBacklinks => 'No pages link here yet.';
}

// Path: documents.slash
class Translations$documents$slash$en {
	Translations$documents$slash$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Text'
	String get text => 'Text';

	/// en: 'Heading 1'
	String get h1 => 'Heading 1';

	/// en: 'Heading 2'
	String get h2 => 'Heading 2';

	/// en: 'Heading 3'
	String get h3 => 'Heading 3';

	/// en: 'Bulleted list'
	String get bulleted => 'Bulleted list';

	/// en: 'Numbered list'
	String get numbered => 'Numbered list';

	/// en: 'Quote'
	String get quote => 'Quote';

	/// en: 'Code block'
	String get code => 'Code block';

	/// en: 'Divider'
	String get divider => 'Divider';

	/// en: 'To-do'
	String get todo => 'To-do';
}

// Path: chat.tool.kind
class Translations$chat$tool$kind$en {
	Translations$chat$tool$kind$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'function'
	String get function => 'function';

	/// en: 'handler'
	String get handler => 'handler';

	/// en: 'agent'
	String get agent => 'agent';

	/// en: 'workflow'
	String get workflow => 'workflow';

	/// en: 'control'
	String get control => 'control';

	/// en: 'approval'
	String get approval => 'approval';

	/// en: 'document'
	String get document => 'document';

	/// en: 'skill'
	String get skill => 'skill';

	/// en: 'trigger'
	String get trigger => 'trigger';

	/// en: 'blocks'
	String get blocks => 'blocks';

	/// en: 'attachments'
	String get attachment => 'attachments';

	/// en: 'conversations'
	String get conversation => 'conversations';
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

	/// en: 'Runs'
	String get runs => 'Runs';

	/// en: 'Activity'
	String get activity => 'Activity';

	/// en: 'Dispatch'
	String get dispatch => 'Dispatch';
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

// Path: entities.detail.hero
class Translations$entities$detail$hero$en {
	Translations$entities$detail$hero$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'env $status'
	String envStatus({required Object status}) => 'env ${status}';

	/// en: 'no inputs'
	String get noInputs => 'no inputs';

	/// en: 'no outputs'
	String get noOutputs => 'no outputs';

	/// en: 'no config'
	String get noConfig => 'no config';

	/// en: 'no methods'
	String get noMethods => 'no methods';

	/// en: '$n methods'
	String methods({required Object n}) => '${n} methods';

	/// en: '$n deps'
	String deps({required Object n}) => '${n} deps';
}

// Path: entities.detail.gate
class Translations$entities$detail$gate$en {
	Translations$entities$detail$gate$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'config'
	String get config => 'config';

	/// en: 'env'
	String get env => 'env';

	/// en: 'instance'
	String get instance => 'instance';
}

// Path: entities.detail.codeToggle
class Translations$entities$detail$codeToggle$en {
	Translations$entities$detail$codeToggle$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Show all ($n lines)'
	String expand({required Object n}) => 'Show all (${n} lines)';

	/// en: 'Collapse'
	String get collapse => 'Collapse';
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

	/// en: 'Routing branches'
	String get branches => 'Routing branches';

	/// en: 'Approval template'
	String get template => 'Approval template';

	/// en: 'Decision rules'
	String get decisionRules => 'Decision rules';

	/// en: 'Configuration'
	String get config => 'Configuration';

	/// en: 'Listener'
	String get listener => 'Listener';

	/// en: 'Fire payload'
	String get firePayload => 'Fire payload';
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

	/// en: 'Orchestration graph unparseable'
	String get unparseable => 'Orchestration graph unparseable';
}

// Path: entities.detail.cockpit
class Translations$entities$detail$cockpit$en {
	Translations$entities$detail$cockpit$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Runs'
	String get runs => 'Runs';

	/// en: 'Runs · $n'
	String runsCount({required Object n}) => 'Runs · ${n}';

	/// en: 'Node timeline'
	String get nodeGantt => 'Node timeline';

	/// en: 'Not run'
	String get notRun => 'Not run';

	/// en: 'Awaiting approval'
	String get waitingApproval => 'Awaiting approval';

	/// en: 'No runs yet'
	String get noRuns => 'No runs yet';

	/// en: 'Each run appears here once the workflow is triggered'
	String get noRunsHint => 'Each run appears here once the workflow is triggered';

	/// en: 'Run graph'
	String get runGraph => 'Run graph';

	/// en: 'Node · $id'
	String nodeDetail({required Object id}) => 'Node · ${id}';

	/// en: 'Pick a node to see its execution detail'
	String get pickNode => 'Pick a node to see its execution detail';

	/// en: 'Replay'
	String get replay => 'Replay';

	/// en: 'Kill'
	String get kill => 'Kill';

	/// en: 'Run info'
	String get runInfo => 'Run info';

	/// en: 'Iteration $n'
	String iteration({required Object n}) => 'Iteration ${n}';
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

	/// en: 'Allow reason'
	String get allowReason => 'Allow reason';

	/// en: 'Timeout'
	String get timeout => 'Timeout';

	/// en: 'On timeout'
	String get timeoutBehavior => 'On timeout';

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

	/// en: 'passthrough'
	String get passthrough => 'passthrough';

	/// en: 'never'
	String get never => 'never';

	/// en: 'Yes'
	String get yes => 'Yes';

	/// en: 'No'
	String get no => 'No';

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

	/// en: 'timeout $ms ms'
	String timeoutMs({required Object ms}) => 'timeout ${ms} ms';

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

// Path: entities.detail.trigger
class Translations$entities$detail$trigger$en {
	Translations$entities$detail$trigger$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Fire'
	String get fire => 'Fire';

	/// en: 'Listening'
	String get listening => 'Listening';

	/// en: 'Idle'
	String get idle => 'Idle';

	/// en: 'Source'
	String get source => 'Source';

	/// en: 'Listeners'
	String get refCount => 'Listeners';

	/// en: 'Last fired'
	String get lastFired => 'Last fired';

	/// en: 'Next fire'
	String get nextFire => 'Next fire';

	/// en: 'Signature'
	String get signatureAlgo => 'Signature';

	/// en: 'Signature header'
	String get signatureHeader => 'Signature header';

	/// en: 'Events'
	String get events => 'Events';

	/// en: 'Pattern'
	String get pattern => 'Pattern';

	/// en: 'Target'
	String get target => 'Target';

	/// en: 'Interval'
	String get interval => 'Interval';

	/// en: 'Fired'
	String get fired => 'Fired';

	/// en: 'Didn't fire'
	String get notFired => 'Didn\'t fire';

	/// en: '$n fanned out'
	String fanout({required Object n}) => '${n} fanned out';

	/// en: 'Fan-out'
	String get fanoutLabel => 'Fan-out';

	/// en: 'Return value'
	String get returnValue => 'Return value';

	/// en: 'Payload'
	String get payload => 'Payload';

	/// en: 'Detail'
	String get detail => 'Detail';

	/// en: 'Activation'
	String get activation => 'Activation';

	/// en: 'All activity'
	String get allActivity => 'All activity';

	/// en: 'Fired only'
	String get firedOnly => 'Fired only';

	/// en: 'All dispatches'
	String get allDispatch => 'All dispatches';

	/// en: 'Fired · $id'
	String firedToast({required Object id}) => 'Fired · ${id}';

	/// en: 'Couldn't fire the trigger'
	String get fireFailed => 'Couldn\'t fire the trigger';
}

// Path: entities.detail.state
class Translations$entities$detail$state$en {
	Translations$entities$detail$state$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Set active'
	String get setActive => 'Set active';

	/// en: 'Couldn't set active version'
	String get setActiveFailed => 'Couldn\'t set active version';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'No versions'
	String get noVersions => 'No versions';

	/// en: 'No runs yet'
	String get noLogs => 'No runs yet';

	/// en: 'Runs will appear here once this entity is executed.'
	String get noLogsHint => 'Runs will appear here once this entity is executed.';

	/// en: 'No activity yet'
	String get noActivations => 'No activity yet';

	/// en: 'Every time this trigger acts — fired or not — a row appears here.'
	String get noActivationsHint => 'Every time this trigger acts — fired or not — a row appears here.';

	/// en: 'Nothing dispatched'
	String get noFirings => 'Nothing dispatched';

	/// en: 'When a fire fans out to a workflow, its disposition shows here.'
	String get noFiringsHint => 'When a fire fans out to a workflow, its disposition shows here.';

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

// Path: entities.detail.editor
class Translations$entities$detail$editor$en {
	Translations$entities$detail$editor$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Graph editor'
	String get title => 'Graph editor';

	/// en: 'Back'
	String get back => 'Back';

	/// en: 'Add node'
	String get addNode => 'Add node';

	/// en: 'Auto layout'
	String get autoLayout => 'Auto layout';

	/// en: 'Direction'
	String get direction => 'Direction';

	/// en: 'Horizontal'
	String get dirLR => 'Horizontal';

	/// en: 'Vertical'
	String get dirTB => 'Vertical';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Discard'
	String get discard => 'Discard';

	/// en: 'Discard unsaved changes?'
	String get discardConfirmTitle => 'Discard unsaved changes?';

	/// en: 'The graph has edits that haven't been saved. Leaving now discards them.'
	String get discardConfirmMessage => 'The graph has edits that haven\'t been saved. Leaving now discards them.';

	/// en: 'Discard and leave'
	String get discardConfirmAction => 'Discard and leave';

	/// en: 'New version saved'
	String get saved => 'New version saved';

	/// en: 'Unsaved changes'
	String get unsaved => 'Unsaved changes';

	/// en: 'Select a node or edge to edit'
	String get inspectorEmpty => 'Select a node or edge to edit';

	/// en: 'Ref'
	String get nodeRef => 'Ref';

	/// en: 'Kind'
	String get nodeKind => 'Kind';

	/// en: 'Input mapping'
	String get nodeInput => 'Input mapping';

	/// en: 'Retry'
	String get nodeRetry => 'Retry';

	/// en: 'Port'
	String get edgePort => 'Port';

	/// en: 'From'
	String get edgeFrom => 'From';

	/// en: 'To'
	String get edgeTo => 'To';

	/// en: 'Delete node'
	String get deleteNode => 'Delete node';

	/// en: 'Delete edge'
	String get deleteEdge => 'Delete edge';

	/// en: 'A control port must match a branch name; approval is yes/no'
	String get portHint => 'A control port must match a branch name; approval is yes/no';

	/// en: 'Select a branch port'
	String get portPick => 'Select a branch port';

	/// en: 'Routing branches'
	String get branches => 'Routing branches';

	/// en: 'default (all else)'
	String get branchDefault => 'default (all else)';

	/// en: 'emit'
	String get branchEmit => 'emit';

	/// en: 'Add field'
	String get addField => 'Add field';

	/// en: 'Field'
	String get field => 'Field';

	/// en: 'CEL expression'
	String get expr => 'CEL expression';

	/// en: 'Enable retry'
	String get retryEnable => 'Enable retry';

	/// en: 'Max attempts'
	String get maxAttempts => 'Max attempts';

	/// en: 'No self-loops: a node cannot connect to itself'
	String get errSelfLoop => 'No self-loops: a node cannot connect to itself';

	/// en: 'That edge already exists'
	String get errDuplicateEdge => 'That edge already exists';

	/// en: 'A back edge may only leave a control / approval node'
	String get errBackEdgeSource => 'A back edge may only leave a control / approval node';

	/// en: 'An approval has only yes / no outputs'
	String get errApprovalPortsFull => 'An approval has only yes / no outputs';

	/// en: 'On'
	String get on => 'On';

	/// en: 'Off'
	String get off => 'Off';

	/// en: 'Inspector'
	String get inspectorTitle => 'Inspector';

	/// en: 'Pick a node or edge on the canvas to edit it.'
	String get inspectorEmptyHint => 'Pick a node or edge on the canvas to edit it.';

	/// en: 'Edge'
	String get edge => 'Edge';

	/// en: 'Remove field'
	String get removeField => 'Remove field';

	/// en: 'Category…'
	String get refPickFamily => 'Category…';

	/// en: 'Function'
	String get refFamilyFunction => 'Function';

	/// en: 'Handler'
	String get refFamilyHandler => 'Handler';

	/// en: 'MCP'
	String get refFamilyMcp => 'MCP';

	/// en: 'Select…'
	String get refPickTarget => 'Select…';

	/// en: 'Method…'
	String get refPickMethod => 'Method…';

	/// en: 'Tool…'
	String get refPickTool => 'Tool…';
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
			'chat.kNew' => 'New chat',
			'chat.filter' => 'Search conversations…',
			'chat.emptyTitle' => 'No conversations yet',
			'chat.emptyHint' => 'Start a new chat to begin.',
			'chat.errorTitle' => 'Couldn\'t load conversations',
			'chat.errorHint' => 'The local engine didn\'t return the conversation list.',
			'chat.retry' => 'Try again',
			'chat.sortLabel' => 'Sort',
			'chat.sortActivity' => 'Recently active',
			'chat.sortCreated' => 'Recently created',
			'chat.sortName' => 'Name',
			'chat.displayLabel' => 'Display',
			'chat.showArchived' => 'Show archived',
			'chat.showCount' => 'Show counts',
			'chat.showTime' => 'Show time',
			'chat.rename' => 'Rename',
			'chat.pin' => 'Pin',
			'chat.unpin' => 'Unpin',
			'chat.archive' => 'Archive',
			'chat.unarchive' => 'Unarchive',
			'chat.deleteTitle' => 'Delete this conversation?',
			'chat.deleteBody' => ({required Object title}) => '“${title}” will be removed.',
			'chat.deleteConfirm' => 'Delete',
			'chat.actionFailed' => 'Action failed',
			'chat.time.justNow' => 'Just now',
			'chat.time.minutesAgo' => ({required Object n}) => '${n} min ago',
			'chat.time.hoursAgo' => ({required Object n}) => '${n} hr ago',
			'chat.time.yesterday' => 'Yesterday',
			'chat.time.daysAgo' => ({required Object n}) => '${n} days ago',
			'chat.bucket.pinned' => 'Pinned',
			'chat.bucket.recents' => 'Recents',
			'chat.placeholder' => 'Ask anything…',
			'chat.send' => 'Send message',
			'chat.stop' => 'Stop generating',
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
			'chat.tool.calling' => 'Calling',
			'chat.tool.called' => 'Called',
			'chat.tool.awaitingConfirm' => 'Awaiting confirmation',
			'chat.tool.failed' => 'failed',
			'chat.tool.denied' => 'Denied',
			'chat.tool.cancelled' => 'Interrupted',
			'chat.tool.elapsed' => ({required Object s}) => '${s} s',
			'chat.tool.intent' => 'Intent',
			'chat.tool.argsLabel' => 'Arguments',
			'chat.tool.progressLabel' => 'Progress',
			'chat.tool.resultLabel' => 'Result',
			'chat.tool.errorLabel' => 'Error',
			'chat.tool.liveLabel' => 'live',
			'chat.tool.truncatedNote' => ({required Object chars}) => 'Truncated · full content ${chars} chars',
			'chat.tool.progressOmitted' => ({required Object n}) => '…${n} earlier lines omitted',
			'chat.tool.reading' => 'Reading',
			'chat.tool.read' => 'Read',
			'chat.tool.writing' => 'Writing',
			'chat.tool.wrote' => 'Wrote',
			'chat.tool.editing' => 'Editing',
			'chat.tool.edited' => 'Edited',
			'chat.tool.globbing' => 'Globbing',
			'chat.tool.globbed' => 'Globbed',
			'chat.tool.grepping' => 'Searching',
			'chat.tool.grepped' => 'Searched',
			'chat.tool.listing' => 'Listing',
			'chat.tool.listed' => 'Listed',
			'chat.tool.runningCmd' => 'Running command',
			'chat.tool.ranCmd' => 'Ran',
			'chat.tool.lines' => ({required Object n}) => '${n} lines',
			'chat.tool.linesTruncated' => ({required Object n}) => 'first ${n} lines (truncated)',
			'chat.tool.matches' => ({required Object n}) => '${n} matches',
			'chat.tool.files' => ({required Object n}) => '${n} files',
			'chat.tool.items' => ({required Object n}) => '${n} items',
			'chat.tool.noMatches' => 'no matches',
			'chat.tool.exit' => ({required Object code}) => 'exit ${code}',
			'chat.tool.timedOut' => 'timed out',
			'chat.tool.wroteBytes' => ({required Object n}) => '${n} bytes',
			'chat.tool.creatingKind' => ({required Object kind}) => 'Creating ${kind}',
			'chat.tool.createdKind' => ({required Object kind}) => 'Created ${kind}',
			'chat.tool.updatingKind' => ({required Object kind}) => 'Updating ${kind}',
			'chat.tool.updatedKind' => ({required Object kind}) => 'Updated ${kind}',
			'chat.tool.envReady' => 'env ready',
			'chat.tool.envBuilding' => 'env building',
			'chat.tool.envFailed' => 'env failed',
			'chat.tool.restarted' => 'restarted',
			'chat.tool.kind.function' => 'function',
			'chat.tool.kind.handler' => 'handler',
			'chat.tool.kind.agent' => 'agent',
			'chat.tool.kind.workflow' => 'workflow',
			'chat.tool.kind.control' => 'control',
			'chat.tool.kind.approval' => 'approval',
			'chat.tool.kind.document' => 'document',
			'chat.tool.kind.skill' => 'skill',
			'chat.tool.kind.trigger' => 'trigger',
			'chat.tool.kind.blocks' => 'blocks',
			'chat.tool.kind.attachment' => 'attachments',
			'chat.tool.kind.conversation' => 'conversations',
			'chat.tool.asking' => 'Asking',
			'chat.tool.asked' => 'Asked',
			'chat.tool.answered' => 'Answered',
			'chat.tool.skipped' => 'Skipped',
			'chat.tool.emptyAnswer' => 'Empty answer',
			'chat.tool.awaitingAnswer' => 'Awaiting your answer',
			'chat.tool.deciding' => 'Deciding',
			'chat.tool.approved' => 'Approved',
			'chat.tool.rejected' => 'Rejected',
			'chat.tool.decided' => 'Decided',
			'chat.tool.approveVerdict' => 'Approve',
			'chat.tool.rejectVerdict' => 'Reject',
			'chat.tool.notParked' => 'This node isn\'t awaiting a decision (already decided, timed out, or a wrong node id) — this decision had no effect.',
			'chat.tool.nodesShown' => ({required Object shown, required Object total}) => 'showing ${shown}/${total} nodes, full set in the flowrun',
			'chat.tool.clearing' => 'Checking the approval inbox',
			'chat.tool.cleared' => 'Checked',
			'chat.tool.inboxCount' => ({required Object n}) => '${n} awaiting',
			'chat.tool.inboxEmpty' => 'None awaiting',
			'chat.tool.inboxMore' => ({required Object n}) => '${n} more',
			'chat.tool.inboxRef' => 'Approval',
			'chat.tool.inboxSummary' => 'Summary',
			'chat.tool.inboxWait' => 'Waiting',
			'chat.tool.inboxRun' => 'run',
			'chat.tool.inboxEmptyState' => 'Inbox empty — no run is awaiting approval',
			'chat.tool.runtimeRunning' => 'Running',
			'chat.tool.runtimeStopped' => 'Instance not running',
			'chat.tool.runtimeCrashed' => 'Instance crashed',
			'chat.tool.envFixAttempt' => ({required Object n}) => 'attempt ${n}',
			'chat.tool.envFixHealing' => 'revised deps, retried',
			'chat.tool.envFixTitle' => 'Environment self-heal',
			'chat.tool.wfInactive' => 'Not activated',
			'chat.tool.wfGraphCounts' => ({required Object nodes, required Object edges}) => '${nodes} nodes · ${edges} edges',
			'chat.tool.wfActivateHint' => 'activate_workflow to go live · trigger_workflow to test',
			'chat.tool.wfGrowing' => 'Composing',
			'chat.tool.wfNodeUnit' => 'nodes',
			'chat.tool.wfEdgeUnit' => 'edges',
			'chat.tool.wfDeltaEmpty' => 'metadata only (graph unchanged)',
			'chat.tool.wfMorphNote' => 'incremental change (full graph in the entity panel)',
			'chat.tool.ctlOtherwise' => 'otherwise',
			'chat.tool.ctlWhenTrue' => 'catch-all',
			'chat.tool.ctlEmit' => 'emit',
			'chat.tool.ctlNoCatchall' => 'no catch-all: last must be when:"true"',
			'chat.tool.apfTimeoutNever' => 'never times out',
			'chat.tool.apfAllowReason' => 'note allowed',
			'chat.tool.apfApprove' => 'Approve',
			'chat.tool.apfReject' => 'Reject',
			'chat.tool.apfPreviewHint' => 'the approver will see',
			'chat.tool.apfOnTimeout' => 'on timeout →',
			'chat.tool.proseExpand' => 'Show all',
			'chat.tool.proseCollapse' => 'Collapse',
			'chat.tool.docAutoRenamed' => 'requested name was taken, auto-renamed',
			'chat.tool.skillNoRevert' => 'whole overwrite · no version to revert to',
			'chat.tool.skillPreauth' => 'pre-authorized after activation (no confirm)',
			'chat.tool.skillInline' => 'inline',
			'chat.tool.skillFork' => 'fork',
			'chat.tool.docSoftFail' => 'did not take effect',
			'chat.tool.trgNotListening' => 'not listening',
			'chat.tool.trgHotUpdate' => 'hot-updated live',
			'chat.tool.trgCreateNote' => 'created but not listening — an active workflow reference starts it',
			'chat.tool.copyDone' => 'Copied',
			'chat.tool.trgSecret' => 'secret',
			'chat.tool.trgEvery' => ({required Object n}) => 'every ${n} s',
			'chat.tool.trgCondition' => 'when',
			'chat.tool.trgOutput' => 'emit',
			'chat.tool.searchingKind' => ({required Object kind}) => 'Searching ${kind}',
			'chat.tool.searchedKind' => ({required Object kind}) => 'Searched ${kind}',
			'chat.tool.listingKind' => ({required Object kind}) => 'Listing ${kind}',
			'chat.tool.listedKind' => ({required Object kind}) => 'Listed ${kind}',
			'chat.tool.hits' => ({required Object n}) => '${n} found',
			'chat.tool.hitsOfTotal' => ({required Object n, required Object total}) => '${n} of ${total}',
			'chat.tool.emptyList' => 'empty',
			'chat.tool.hitCurrent' => 'current',
			'chat.tool.cappedFooter' => ({required Object n, required Object total}) => 'first ${n} of ${total}',
			'chat.tool.serverTruncatedNote' => ({required Object n, required Object total}) => 'first ${n} of ${total} (server-truncated)',
			'chat.tool.wfActive' => 'active',
			'chat.tool.refCount' => ({required Object n}) => '${n} refs',
			'chat.tool.trgListening' => 'listening',
			'chat.tool.rawResult' => 'raw result',
			'chat.tool.contentTruncated' => 'content truncated — see the full text in the entity panel',
			'chat.tool.noActiveVersion' => 'no active version',
			'chat.tool.kvDescription' => 'description',
			'chat.tool.kvSignature' => 'signature',
			'chat.tool.kvDeps' => 'deps',
			'chat.tool.kvUpdated' => 'updated',
			'chat.tool.kvMethods' => 'methods',
			'chat.tool.kvModel' => 'model',
			'chat.tool.kvConcurrency' => 'concurrency',
			'chat.tool.kvGraph' => 'graph',
			'chat.tool.kvContext' => 'context',
			'chat.tool.kvSource' => 'source',
			'chat.tool.apfTimeout' => 'timeout',
			'chat.tool.apfBehavior' => 'on timeout',
			'chat.tool.envFailedShort' => 'env failed',
			'chat.tool.envPending' => 'env pending',
			'chat.tool.skillPreauthNote' => 'allowedTools are pre-authorized (no danger confirm) for this run when active',
			'chat.tool.viewingKind' => ({required Object kind}) => 'Viewing ${kind}',
			'chat.tool.viewedKind' => ({required Object kind}) => 'Viewed ${kind}',
			'chat.tool.kvTags' => 'tags',
			'chat.tool.attachTruncated' => 'truncated',
			'chat.tool.readingDoc' => 'Reading document',
			'chat.tool.readDoc' => 'Read document',
			'chat.tool.readingAtt' => 'Reading attachment',
			'chat.tool.readAtt' => 'Read attachment',
			'chat.tool.revertingKind' => ({required Object kind}) => 'Reverting ${kind}',
			'chat.tool.revertedKind' => ({required Object kind}) => 'Reverted ${kind}',
			'chat.tool.deletingKind' => ({required Object kind}) => 'Deleting ${kind}',
			'chat.tool.deletedKind2' => ({required Object kind}) => 'Deleted ${kind}',
			'chat.tool.staging' => 'Staging',
			'chat.tool.staged' => 'Staged',
			'chat.tool.activatingWf' => 'Activating',
			'chat.tool.activatedWf' => 'Activated',
			'chat.tool.deactivatingWf' => 'Deactivating',
			'chat.tool.deactivatedWf' => 'Stopped listening',
			'chat.tool.killingWf' => 'Killing',
			'chat.tool.killedWf' => 'Killed',
			'chat.tool.restarting' => 'Restarting',
			'chat.tool.restartFailed' => 'not running after restart',
			'chat.tool.activatingSkill' => 'Activating skill',
			'chat.tool.activatedSkill' => 'Activated skill',
			'chat.tool.movingDoc' => 'Moving document',
			'chat.tool.movedDoc' => 'Moved document',
			'chat.tool.updatingMeta' => 'Updating info',
			'chat.tool.updatedMeta' => 'Updated info',
			'chat.tool.renaming' => 'Renaming',
			'chat.tool.renamed' => 'Renamed',
			'chat.tool.configuring' => 'Configuring',
			'chat.tool.configured' => 'Configured',
			'chat.tool.rewind' => ({required Object v}) => '↩ v${v}',
			'chat.tool.deletedShort' => 'deleted',
			'chat.tool.depsAffected' => ({required Object n}) => '${n} refs affected',
			'chat.tool.docDescendants' => ({required Object n}) => 'deleted · ${n} descendants',
			'chat.tool.movedTo' => ({required Object path}) => '→ ${path}',
			'chat.tool.killedN' => ({required Object n}) => 'killed ${n} in-flight',
			'chat.tool.noInflight' => 'no in-flight runs',
			'chat.tool.nKeys' => ({required Object n}) => '${n} keys',
			'chat.tool.staged2' => 'awaiting next real trigger',
			'chat.tool.listening2' => 'listening',
			'chat.tool.offline' => 'offline',
			'chat.tool.draining' => 'draining',
			'chat.tool.moreHits' => ({required Object n}) => '+${n} more',
			'chat.tool.noteRevertFn' => 'restores code/IO/deps only; name·desc·tags do not follow versions',
			'chat.tool.noteRevertHd' => 'restart triggered to run the new version; memory state cleared — see the handler panel',
			'chat.tool.noteRestart' => 'memory state cleared',
			'chat.tool.noteKill' => 'listening stopped; killed runs are cancelled — see flowruns',
			'chat.tool.noteStage' => 'runs once on the next real trigger, then auto-unstages',
			'chat.tool.noteDeactivateDrain' => 'to abort in-flight now, use kill_workflow',
			'chat.tool.noteDeleteDocSoft' => 'soft-deleted, recoverable',
			'chat.tool.noteTriggerRemoved' => 'listening released',
			'chat.tool.noteConfig' => 'restart triggered to take effect; see the handler panel',
			'chat.tool.noteMetaHandler' => 'no new version, no restart, memory state preserved',
			'chat.tool.kvName' => 'name',
			'chat.tool.noteDraining' => 'in-flight runs finish then stop; to abort now use kill_workflow',
			'chat.tool.cvArchiving' => 'Archiving conversation',
			'chat.tool.cvArchived' => 'Archived conversation',
			'chat.tool.cvUnarchiving' => 'Unarchiving',
			'chat.tool.cvUnarchived' => 'Unarchived',
			'chat.tool.cvPinning' => 'Pinning conversation',
			'chat.tool.cvPinned' => 'Pinned conversation',
			'chat.tool.cvUnpinning' => 'Unpinning',
			'chat.tool.cvUnpinned' => 'Unpinned',
			'chat.tool.cvRenaming' => 'Renaming conversation',
			'chat.tool.cvRenamed' => 'Renamed conversation',
			'chat.tool.cvManaging' => 'Managing conversation',
			'chat.tool.cvManaged' => 'Managed conversation',
			'chat.tool.cvListing' => 'Listing conversations',
			'chat.tool.cvListed' => 'Listed conversations',
			'chat.tool.cvSearching' => 'Searching conversations',
			'chat.tool.cvSearched' => 'Searched conversations',
			'chat.tool.cvCount' => ({required Object n}) => '${n}',
			'chat.tool.cvCountMore' => ({required Object n}) => '${n}+',
			'chat.tool.cvEmpty' => 'no conversations',
			'chat.tool.cvHits' => ({required Object n}) => '${n} hits',
			'chat.tool.cvNoMatch' => 'no matches',
			'chat.tool.cvInclArchived' => 'incl. archived',
			'chat.tool.cvNextPage' => 'next page',
			'chat.tool.cvMorePages' => 'more pages',
			'chat.tool.cvArchivedBadge' => 'archived',
			'chat.tool.cvPinnedBadge' => 'pinned',
			'chat.tool.cvChunks' => ({required Object n}) => '×${n}',
			'chat.tool.cvShownOfTotal' => ({required Object n, required Object total}) => 'first ${n} of ${total} hits',
			'chat.tool.cvStatusArchived' => 'archived',
			'chat.tool.cvStatusPinned' => 'pinned',
			'chat.tool.cvStatusTitle' => 'title',
			'chat.tool.cvAutoUnarchive' => 'sending a message auto-unarchives',
			'chat.tool.bashBlocked' => 'blocked',
			'chat.tool.bashCancelled' => 'cancelled',
			'chat.tool.bashExitUnknown' => 'exit unknown',
			'chat.tool.bashBackground' => ({required Object id}) => '${id} · bg',
			'chat.tool.statusRunning' => 'running',
			'chat.tool.statusExited' => ({required Object code}) => 'exit ${code}',
			'chat.tool.statusKilled' => 'killed',
			'chat.tool.statusErrored' => 'errored',
			'chat.tool.statusNotFound' => 'session not found',
			'chat.tool.killFinished' => 'already finished',
			'chat.tool.killNotFound' => 'session not found',
			'chat.tool.polling' => 'Reading output',
			'chat.tool.polled' => 'Read output',
			'chat.tool.killing' => 'Terminating',
			'chat.tool.killed3' => 'Terminated',
			'chat.tool.backToLatest' => 'latest',
			'chat.tool.showEarlier' => ({required Object n}) => 'show ${n} earlier lines',
			'chat.tool.bashBgHint' => 'poll with BashOutput, or KillShell to terminate',
			'chat.tool.bashHeadTruncated' => 'output too long — head dropped, tail kept',
			'chat.tool.bashNoOutput' => '(no output)',
			'chat.tool.ranBg' => 'moved to background',
			'chat.tool.bashSessionGoneHint' => 'may have been terminated / cleaned up / backend restarted',
			'chat.tool.bashNoNew' => '(no new output)',
			'chat.tool.bashDropped' => ({required Object n}) => '${n} bytes dropped (ring overflow)',
			'chat.tool.fsNotFound' => 'not found',
			'chat.tool.fsDenied' => 'denied',
			'chat.tool.fsReadFirst' => 'read first',
			'chat.tool.fsNoMatch' => 'no match',
			'chat.tool.fsAmbiguous' => ({required Object n}) => '${n} matches',
			'chat.tool.fsModified' => 'file changed',
			'chat.tool.fsParentMissing' => 'no parent dir',
			'chat.tool.fsBadPath' => 'bad path',
			'chat.tool.fsFailed' => 'failed',
			'chat.tool.readRange' => ({required Object f, required Object l}) => 'lines ${f}–${l}',
			'chat.tool.readFloor' => ({required Object n}) => '${n}+ lines',
			'chat.tool.readRangeFloor' => ({required Object f, required Object n}) => 'lines ${f}–${n}+',
			'chat.tool.edited2' => ({required Object n}) => '${n} replaced',
			'chat.tool.fsUnconfirmed' => 'result unconfirmed',
			'chat.tool.emptyFile' => 'empty file',
			'chat.tool.replaceAllNote' => ({required Object n}) => 'replaced all ${n}',
			'chat.tool.mcpCalling' => 'Calling MCP tool',
			'chat.tool.mcpCalled' => 'Called MCP tool',
			'chat.tool.mcpError' => 'MCP error',
			'chat.tool.hdCalling' => 'Calling method',
			'chat.tool.hdCalled' => 'Called method',
			'chat.tool.hdResult' => 'result',
			'chat.tool.lsEmpty' => '(empty)',
			'chat.tool.globHeader' => ({required Object pattern, required Object root}) => '${pattern} in ${root}',
			'chat.tool.noReturn' => 'no return value',
			'chat.tool.execOk' => 'ok',
			'chat.tool.execFailed' => 'failed',
			'chat.tool.ioInput' => 'input',
			'chat.tool.ioOutput' => 'output',
			'chat.tool.execLogs' => ({required Object n}) => 'logs · ${n} lines',
			'chat.tool.runningFn' => 'Running function',
			'chat.tool.ranFn' => 'Ran function',
			'chat.tool.callingMethod' => 'Calling method',
			'chat.tool.calledMethod' => 'Called method',
			'chat.tool.firingTrigger' => 'Firing trigger',
			'chat.tool.firedTrigger' => 'Fired trigger',
			'chat.tool.fireActivation' => 'Activation',
			'chat.tool.firePayloadNote' => 'Payload is always {manual:true}; see the trigger log for fan-out and disposition',
			'chat.tool.replayingRun' => 'Replaying run',
			'chat.tool.replayedRun' => 'Replayed run',
			'chat.tool.runCompleted' => 'Completed',
			'chat.tool.runStillFailed' => 'Still failed',
			'chat.tool.runCancelled' => 'Cancelled',
			'chat.tool.runAwaitApproval' => 'Awaiting approval',
			'chat.tool.nodeCount' => ({required Object n}) => '${n} nodes',
			'chat.tool.replayPinNote' => 'Re-run under the originally pinned versions; edits made after the failure do not take effect',
			'chat.tool.replayTimes' => ({required Object n}) => 'Replay #${n}',
			'chat.tool.flowShown' => ({required Object shown, required Object total}) => 'Showing ${shown}/${total} nodes',
			'chat.tool.flowExpandAll' => ({required Object n}) => 'Show remaining ${n}',
			'chat.tool.nodeWait' => 'waiting',
			'chat.tool.triggeringWf' => 'Triggering workflow',
			'chat.tool.triggeredWf' => 'Triggered workflow',
			'chat.tool.emptyPayload' => 'empty payload',
			'chat.tool.triggerStartedNote' => 'Run started — inspect with get_flowrun',
			'chat.tool.invokingAgent' => 'Invoking agent',
			'chat.tool.invokedAgent' => 'Invoked agent',
			'chat.tool.agentSteps' => ({required Object n}) => '${n} steps',
			'chat.tool.agentTimeout' => 'Timed out',
			'chat.tool.agentTrajectoryNote' => 'The trajectory streamed live; replay it from the execution record',
			'chat.tool.beadPageScope' => 'this page',
			'chat.tool.searchingFnExec' => 'Searching function runs',
			'chat.tool.searchedFnExec' => 'Searched function runs',
			'chat.tool.searchingHdCalls' => 'Searching handler calls',
			'chat.tool.searchedHdCalls' => 'Searched handler calls',
			'chat.tool.searchingAgentExec' => 'Searching agent runs',
			'chat.tool.searchedAgentExec' => 'Searched agent runs',
			'chat.tool.searchingMcpCalls' => 'Searching MCP calls',
			'chat.tool.searchedMcpCalls' => 'Searched MCP calls',
			'chat.tool.aggRollup' => ({required Object ok, required Object failed}) => '${ok} ✓ · ${failed} ✗',
			'chat.tool.aggNote' => '✗ incl. cancelled/timeout',
			'chat.tool.logNoRecords' => 'No records',
			'chat.tool.logNoMatch' => 'No matches',
			'chat.tool.byChat' => 'chat',
			'chat.tool.byAgent' => 'agent',
			'chat.tool.byWorkflow' => 'workflow',
			'chat.tool.byManual' => 'manual',
			'chat.tool.searchingFlowruns' => 'Searching runs',
			'chat.tool.searchedFlowruns' => 'Searched runs',
			'chat.tool.searchingFirings' => 'Searching firings',
			'chat.tool.searchedFirings' => 'Searched firings',
			'chat.tool.searchingActivations' => 'Searching activations',
			'chat.tool.searchedActivations' => 'Searched activations',
			'chat.tool.firingPending' => 'pending',
			'chat.tool.firingStarted' => 'run started',
			'chat.tool.firingSkipped' => 'skipped',
			'chat.tool.firingSuperseded' => 'superseded',
			'chat.tool.firingShed' => 'shed',
			'chat.tool.logCount' => ({required Object n}) => '${n}',
			'chat.tool.logCountMore' => ({required Object n}) => '${n}+',
			'chat.tool.parkRunCaption' => 'a run parked on an approval node stays running at the header',
			'chat.tool.actReturnValue' => 'Return value',
			'chat.tool.actFanout' => ({required Object n}) => 'fan-out ${n}',
			'chat.tool.gettingFnExec' => 'Opening function-run record',
			'chat.tool.gotFnExec' => 'Opened function-run record',
			'chat.tool.gettingHdCall' => 'Opening handler-call record',
			'chat.tool.gotHdCall' => 'Opened handler-call record',
			'chat.tool.gettingMcpCall' => 'Opening MCP-call record',
			'chat.tool.gotMcpCall' => 'Opened MCP-call record',
			'chat.tool.gettingActivation' => 'Opening activation record',
			'chat.tool.gotActivation' => 'Opened activation record',
			'chat.tool.dossierLogs' => 'Logs',
			'chat.tool.dossierStderr' => 'server stderr (may predate this call)',
			'chat.tool.logOmitted' => ({required Object n}) => '… ${n} chars omitted …',
			'chat.tool.provConversation' => 'conversation',
			'chat.tool.provMessage' => 'message',
			'chat.tool.provFlowrun' => 'run',
			'chat.tool.provTrigger' => 'trigger',
			'chat.tool.provFiring' => 'firing',
			'chat.tool.provNode' => 'node',
			'chat.tool.fireYes' => 'fired',
			'chat.tool.fireNo' => 'not fired',
			'chat.tool.gettingFlowrun' => 'Opening run',
			'chat.tool.gotFlowrun' => 'Opened run',
			'chat.tool.runStatusRunning' => 'Running',
			'chat.tool.gettingAgentExec' => 'Opening agent run',
			'chat.tool.gotAgentExec' => 'Opened agent run',
			'chat.tool.transcriptSteps' => ({required Object n}) => 'Trajectory · ${n} steps',
			'chat.tool.transcriptOpenFull' => 'View full trajectory',
			'chat.tool.transcriptEmpty' => 'No trajectory recorded',
			'chat.tool.transcriptCapped' => ({required Object shown, required Object total}) => 'showing ${shown}/${total} blocks',
			'chat.tool.transcriptThought' => 'thought',
			'chat.tool.transcriptReply' => 'reply',
			'chat.tool.spawningSubagent' => 'Spawning subagent',
			'chat.tool.spawnedSubagent' => 'Spawned subagent',
			'chat.tool.subagentTask' => 'Task',
			'chat.tool.subagentAnswer' => 'Answer',
			'chat.tool.subagentTraceNote' => 'The trajectory streamed live only — replay it with get_subagent_trace',
			'chat.tool.gettingSubTrace' => 'Opening subagent trace',
			'chat.tool.gotSubTrace' => 'Opened subagent trace',
			'chat.tool.subTraceRuns' => ({required Object n}) => '${n} subagent runs',
			'chat.tool.subTraceNoRuns' => 'No subagent runs in this conversation',
			'chat.tool.todoWriting' => 'Updating checklist',
			'chat.tool.todoWrote' => 'Updated checklist',
			'chat.tool.todoReading' => 'Reading checklist',
			'chat.tool.todoRead' => 'Read checklist',
			'chat.tool.todoRollup' => ({required Object total, required Object done}) => '${total} items · ${done} done',
			'chat.tool.todoCleared' => 'Checklist cleared',
			'chat.tool.todoActive' => ({required Object n}) => '${n} in progress',
			'chat.tool.gettingRelations' => 'Checking relations',
			'chat.tool.gotRelations' => 'Checked relations',
			'chat.tool.relCount' => ({required Object n}) => '${n} edges',
			'chat.tool.relNoEdges' => 'No relations',
			'chat.tool.relArrow' => '→',
			'chat.tool.checkingCapability' => 'Checking workflow',
			'chat.tool.checkedCapability' => 'Checked workflow',
			'chat.tool.capRunnable' => 'structurally runnable',
			'chat.tool.capProblems' => ({required Object n}) => '${n} problems',
			'chat.tool.capWarnings' => ({required Object n}) => '${n} warnings',
			'chat.tool.capProblemsLabel' => 'Problems',
			'chat.tool.capWarningsLabel' => 'Warnings',
			'chat.tool.capResolved' => 'deps resolved',
			'chat.tool.capStructural' => 'structurally valid',
			'chat.tool.installingMcp' => 'Installing MCP server',
			'chat.tool.installedMcp' => 'Installed MCP server',
			'chat.tool.uninstallingMcp' => 'Uninstalling MCP server',
			'chat.tool.uninstalledMcp' => 'Uninstalled MCP server',
			'chat.tool.reconnectingMcp' => 'Reconnecting MCP',
			'chat.tool.reconnectedMcp' => 'Reconnected MCP',
			'chat.tool.mcpConnected' => 'connected',
			'chat.tool.mcpDisconnected' => 'disconnected',
			'chat.tool.mcpToolCount' => ({required Object n}) => '${n} tools',
			'chat.tool.mcpFailures' => ({required Object n}) => '${n} consecutive failures',
			'chat.tool.browsingMarket' => 'Browsing marketplace',
			'chat.tool.browsedMarket' => 'Browsed marketplace',
			'chat.tool.marketCount' => ({required Object n}) => '${n} servers',
			'chat.tool.mcpEnvRequired' => ({required Object n}) => '${n} required env',
			'chat.tool.gettingModelConfig' => 'Reading model config',
			'chat.tool.gotModelConfig' => 'Read model config',
			'chat.tool.modelDefaults' => 'Default models',
			'chat.tool.modelKeys' => ({required Object n}) => '${n} keys',
			'chat.tool.modelAvail' => ({required Object n}) => '${n} available models',
			'chat.gate.dangerBadge' => 'Dangerous',
			'chat.gate.awaitingDanger' => 'Awaiting your approval',
			'chat.gate.awaitingAsk' => 'Awaiting your answer',
			'chat.gate.evidenceLabel' => 'Arguments',
			'chat.gate.approve' => 'Allow',
			'chat.gate.approveAlways' => 'Always allow',
			'chat.gate.approveAlwaysHint' => ({required Object tool}) => 'Don\'t ask again for ${tool} this conversation (forgotten on restart)',
			'chat.gate.deny' => 'Deny',
			'chat.gate.decline' => 'Don\'t answer',
			'chat.gate.submit' => 'Send',
			'chat.gate.answerPlaceholder' => 'Type your answer…',
			'chat.gate.optionsHint' => 'Pick one, or type your own',
			'chat.gate.decidedApproved' => 'Allowed',
			'chat.gate.decidedApprovedAlways' => 'Allowed · always this conversation',
			'chat.gate.decidedDenied' => 'Denied',
			'chat.gate.decidedDeclined' => 'Skipped',
			'chat.contextCompacted' => 'Context compacted',
			'chat.contextCompactedCount' => ({required Object n}) => 'Context compacted · ${n} earlier messages folded into the summary',
			'appName' => 'Anselm',
			'status.idle' => 'Idle',
			'status.run' => 'Running',
			'status.wait' => 'Waiting',
			'status.err' => 'Failed',
			'status.done' => 'Done',
			'action.edit' => 'Edit',
			_ => null,
		} ?? switch (path) {
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
			'notifications.title' => 'Notifications',
			'notifications.needsYou' => 'Needs you',
			'notifications.feed' => 'Notifications',
			'notifications.markAllRead' => 'Mark all read',
			'notifications.markRead' => 'Mark read',
			'notifications.emptyTitle' => 'You\'re all caught up',
			'notifications.emptyHint' => 'New activity shows up here.',
			'notifications.today' => 'Today',
			'notifications.yesterday' => 'Yesterday',
			'notifications.earlier' => 'Earlier',
			'notifications.unnamed' => '(unnamed)',
			'notifications.unknown' => 'New activity',
			'notifications.kind.memory' => 'Memory',
			'notifications.kind.sandbox' => 'Environment',
			'notifications.kind.relation' => 'Dependency',
			'notifications.verb.created' => 'created',
			'notifications.verb.edited' => 'edited',
			'notifications.verb.reverted' => 'reverted',
			'notifications.verb.updated' => 'updated',
			'notifications.verb.deleted' => 'deleted',
			'notifications.verb.envRebuilt' => 'environment rebuilt',
			'notifications.verb.configUpdated' => 'config updated',
			'notifications.verb.configCleared' => 'config cleared',
			'notifications.verb.installed' => 'installed',
			'notifications.verb.removed' => 'removed',
			'notifications.verb.reconnected' => 'reconnected',
			'notifications.verb.reconnectFailed' => 'reconnect failed',
			'notifications.verb.crashed' => 'crashed',
			'notifications.verb.restartFailed' => 'restart failed',
			'notifications.verb.runFailed' => 'run failed',
			'notifications.verb.needsAttention' => 'needs attention',
			'notifications.verb.recovered' => 'recovered',
			'notifications.verb.waitingApproval' => 'is waiting for approval',
			'notifications.verb.envReady' => 'environment ready',
			'notifications.verb.envFailed' => 'environment build failed',
			'notifications.depBrokenOne' => 'left 1 reference dangling',
			'notifications.depBrokenMany' => ({required Object n}) => 'left ${n} references dangling',
			'notifications.view' => 'View',
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
			'graph.kind.trigger' => 'Trigger',
			'graph.kind.action' => 'Action',
			'graph.kind.agent' => 'Agent',
			'graph.kind.control' => 'Branch',
			'graph.kind.approval' => 'Approval',
			'graph.kind.unknown' => 'Unknown',
			'a11y.editingField' => ({required Object field}) => 'Editing ${field}',
			'a11y.editField' => ({required Object field}) => 'Edit ${field}',
			'a11y.addTagTo' => ({required Object field}) => 'Add tag: ${field}',
			'a11y.displayOptions' => 'Display options',
			'a11y.moreActions' => 'More actions',
			'a11y.graphZoomIn' => 'Zoom in',
			'a11y.graphZoomOut' => 'Zoom out',
			'a11y.graphFit' => 'Fit to view',
			'a11y.graphNode' => ({required Object id, required Object kind, required Object ref}) => 'Node ${id}, ${kind}, ${ref}',
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
			'entities.sortRecent' => 'Recently active',
			'entities.sortCreated' => 'Recently created',
			'entities.sortName' => 'Name',
			'entities.displayLabel' => 'Display',
			'entities.showCount' => 'Show counts',
			'entities.detail.crumbRoot' => 'Entities',
			'entities.detail.tab.overview' => 'Overview',
			'entities.detail.tab.versions' => 'Versions',
			'entities.detail.tab.logs' => 'Logs',
			'entities.detail.tab.runs' => 'Runs',
			'entities.detail.tab.activity' => 'Activity',
			'entities.detail.tab.dispatch' => 'Dispatch',
			'entities.detail.verb.run' => 'Run',
			'entities.detail.verb.call' => 'Call',
			'entities.detail.verb.invoke' => 'Invoke',
			'entities.detail.verb.trigger' => 'Trigger',
			'entities.detail.hero.envStatus' => ({required Object status}) => 'env ${status}',
			'entities.detail.hero.noInputs' => 'no inputs',
			'entities.detail.hero.noOutputs' => 'no outputs',
			'entities.detail.hero.noConfig' => 'no config',
			'entities.detail.hero.noMethods' => 'no methods',
			'entities.detail.hero.methods' => ({required Object n}) => '${n} methods',
			'entities.detail.hero.deps' => ({required Object n}) => '${n} deps',
			'entities.detail.gate.config' => 'config',
			'entities.detail.gate.env' => 'env',
			'entities.detail.gate.instance' => 'instance',
			'entities.detail.codeToggle.expand' => ({required Object n}) => 'Show all (${n} lines)',
			'entities.detail.codeToggle.collapse' => 'Collapse',
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
			'entities.detail.sec.branches' => 'Routing branches',
			'entities.detail.sec.template' => 'Approval template',
			'entities.detail.sec.decisionRules' => 'Decision rules',
			'entities.detail.sec.config' => 'Configuration',
			'entities.detail.sec.listener' => 'Listener',
			'entities.detail.sec.firePayload' => 'Fire payload',
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
			'entities.detail.graph.unparseable' => 'Orchestration graph unparseable',
			'entities.detail.cockpit.runs' => 'Runs',
			'entities.detail.cockpit.runsCount' => ({required Object n}) => 'Runs · ${n}',
			'entities.detail.cockpit.nodeGantt' => 'Node timeline',
			'entities.detail.cockpit.notRun' => 'Not run',
			'entities.detail.cockpit.waitingApproval' => 'Awaiting approval',
			'entities.detail.cockpit.noRuns' => 'No runs yet',
			'entities.detail.cockpit.noRunsHint' => 'Each run appears here once the workflow is triggered',
			'entities.detail.cockpit.runGraph' => 'Run graph',
			'entities.detail.cockpit.nodeDetail' => ({required Object id}) => 'Node · ${id}',
			'entities.detail.cockpit.pickNode' => 'Pick a node to see its execution detail',
			'entities.detail.cockpit.replay' => 'Replay',
			'entities.detail.cockpit.kill' => 'Kill',
			'entities.detail.cockpit.runInfo' => 'Run info',
			'entities.detail.cockpit.iteration' => ({required Object n}) => 'Iteration ${n}',
			'entities.detail.kv.name' => 'Name',
			'entities.detail.kv.tags' => 'Tags',
			'entities.detail.kv.id' => 'ID',
			'entities.detail.kv.activeVersion' => 'Active version',
			'entities.detail.kv.currentVersion' => 'Current version',
			'entities.detail.kv.python' => 'Python',
			'entities.detail.kv.updated' => 'Updated',
			'entities.detail.kv.desc' => 'Description',
			'entities.detail.kv.allowReason' => 'Allow reason',
			'entities.detail.kv.timeout' => 'Timeout',
			'entities.detail.kv.timeoutBehavior' => 'On timeout',
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
			'entities.detail.val.passthrough' => 'passthrough',
			'entities.detail.val.never' => 'never',
			'entities.detail.val.yes' => 'Yes',
			'entities.detail.val.no' => 'No',
			'entities.detail.val.stopped' => 'Stopped',
			'entities.detail.val.noAlerts' => 'No alerts',
			'entities.detail.val.needsAttention' => 'Needs attention',
			'entities.detail.val.required' => 'required',
			'entities.detail.val.optional' => 'optional',
			'entities.detail.val.sensitive' => 'sensitive',
			'entities.detail.val.timeoutMs' => ({required Object ms}) => 'timeout ${ms} ms',
			'entities.detail.val.defaultPrefix' => 'default',
			'entities.detail.val.generator' => 'generator',
			'entities.detail.val.modelDefault' => 'Workspace default',
			'entities.detail.val.modelOverridden' => 'Overridden',
			'entities.detail.val.none' => '—',
			'entities.detail.mounts.healthy' => 'All mounts healthy',
			'entities.detail.mounts.unhealthy' => ({required Object count}) => '${count} unhealthy',
			'entities.detail.trigger.fire' => 'Fire',
			'entities.detail.trigger.listening' => 'Listening',
			'entities.detail.trigger.idle' => 'Idle',
			'entities.detail.trigger.source' => 'Source',
			'entities.detail.trigger.refCount' => 'Listeners',
			'entities.detail.trigger.lastFired' => 'Last fired',
			'entities.detail.trigger.nextFire' => 'Next fire',
			'entities.detail.trigger.signatureAlgo' => 'Signature',
			'entities.detail.trigger.signatureHeader' => 'Signature header',
			'entities.detail.trigger.events' => 'Events',
			'entities.detail.trigger.pattern' => 'Pattern',
			'entities.detail.trigger.target' => 'Target',
			'entities.detail.trigger.interval' => 'Interval',
			'entities.detail.trigger.fired' => 'Fired',
			'entities.detail.trigger.notFired' => 'Didn\'t fire',
			'entities.detail.trigger.fanout' => ({required Object n}) => '${n} fanned out',
			'entities.detail.trigger.fanoutLabel' => 'Fan-out',
			'entities.detail.trigger.returnValue' => 'Return value',
			'entities.detail.trigger.payload' => 'Payload',
			'entities.detail.trigger.detail' => 'Detail',
			'entities.detail.trigger.activation' => 'Activation',
			'entities.detail.trigger.allActivity' => 'All activity',
			'entities.detail.trigger.firedOnly' => 'Fired only',
			'entities.detail.trigger.allDispatch' => 'All dispatches',
			'entities.detail.trigger.firedToast' => ({required Object id}) => 'Fired · ${id}',
			'entities.detail.trigger.fireFailed' => 'Couldn\'t fire the trigger',
			'entities.detail.addTag' => 'Add tag',
			'entities.detail.state.setActive' => 'Set active',
			'entities.detail.state.setActiveFailed' => 'Couldn\'t set active version',
			'entities.detail.state.retry' => 'Retry',
			'entities.detail.state.noVersions' => 'No versions',
			'entities.detail.state.noLogs' => 'No runs yet',
			'entities.detail.state.noLogsHint' => 'Runs will appear here once this entity is executed.',
			'entities.detail.state.noActivations' => 'No activity yet',
			'entities.detail.state.noActivationsHint' => 'Every time this trigger acts — fired or not — a row appears here.',
			'entities.detail.state.noFirings' => 'Nothing dispatched',
			'entities.detail.state.noFiringsHint' => 'When a fire fans out to a workflow, its disposition shows here.',
			'entities.detail.state.noActiveVersion' => 'No active version',
			'entities.detail.state.notFoundTitle' => 'Entity not found',
			'entities.detail.state.errorTitle' => 'Couldn\'t load this entity',
			'entities.detail.state.errorHint' => 'The local engine didn\'t return it.',
			'entities.detail.state.loadMore' => 'Load more',
			'entities.detail.state.endOfList' => 'End of list',
			'entities.detail.state.loadFailed' => 'Load failed — tap to retry',
			'entities.detail.state.earliest' => 'earliest version',
			'entities.detail.editor.title' => 'Graph editor',
			'entities.detail.editor.back' => 'Back',
			'entities.detail.editor.addNode' => 'Add node',
			'entities.detail.editor.autoLayout' => 'Auto layout',
			'entities.detail.editor.direction' => 'Direction',
			'entities.detail.editor.dirLR' => 'Horizontal',
			'entities.detail.editor.dirTB' => 'Vertical',
			'entities.detail.editor.save' => 'Save',
			'entities.detail.editor.discard' => 'Discard',
			'entities.detail.editor.discardConfirmTitle' => 'Discard unsaved changes?',
			'entities.detail.editor.discardConfirmMessage' => 'The graph has edits that haven\'t been saved. Leaving now discards them.',
			'entities.detail.editor.discardConfirmAction' => 'Discard and leave',
			'entities.detail.editor.saved' => 'New version saved',
			'entities.detail.editor.unsaved' => 'Unsaved changes',
			'entities.detail.editor.inspectorEmpty' => 'Select a node or edge to edit',
			'entities.detail.editor.nodeRef' => 'Ref',
			'entities.detail.editor.nodeKind' => 'Kind',
			'entities.detail.editor.nodeInput' => 'Input mapping',
			'entities.detail.editor.nodeRetry' => 'Retry',
			'entities.detail.editor.edgePort' => 'Port',
			'entities.detail.editor.edgeFrom' => 'From',
			'entities.detail.editor.edgeTo' => 'To',
			'entities.detail.editor.deleteNode' => 'Delete node',
			'entities.detail.editor.deleteEdge' => 'Delete edge',
			'entities.detail.editor.portHint' => 'A control port must match a branch name; approval is yes/no',
			'entities.detail.editor.portPick' => 'Select a branch port',
			'entities.detail.editor.branches' => 'Routing branches',
			'entities.detail.editor.branchDefault' => 'default (all else)',
			'entities.detail.editor.branchEmit' => 'emit',
			'entities.detail.editor.addField' => 'Add field',
			'entities.detail.editor.field' => 'Field',
			'entities.detail.editor.expr' => 'CEL expression',
			'entities.detail.editor.retryEnable' => 'Enable retry',
			'entities.detail.editor.maxAttempts' => 'Max attempts',
			'entities.detail.editor.errSelfLoop' => 'No self-loops: a node cannot connect to itself',
			'entities.detail.editor.errDuplicateEdge' => 'That edge already exists',
			'entities.detail.editor.errBackEdgeSource' => 'A back edge may only leave a control / approval node',
			'entities.detail.editor.errApprovalPortsFull' => 'An approval has only yes / no outputs',
			'entities.detail.editor.on' => 'On',
			'entities.detail.editor.off' => 'Off',
			'entities.detail.editor.inspectorTitle' => 'Inspector',
			'entities.detail.editor.inspectorEmptyHint' => 'Pick a node or edge on the canvas to edit it.',
			'entities.detail.editor.edge' => 'Edge',
			'entities.detail.editor.removeField' => 'Remove field',
			'entities.detail.editor.refPickFamily' => 'Category…',
			'entities.detail.editor.refFamilyFunction' => 'Function',
			'entities.detail.editor.refFamilyHandler' => 'Handler',
			'entities.detail.editor.refFamilyMcp' => 'MCP',
			'entities.detail.editor.refPickTarget' => 'Select…',
			'entities.detail.editor.refPickMethod' => 'Method…',
			'entities.detail.editor.refPickTool' => 'Tool…',
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
			'entities.run.approvalTitle' => 'Awaiting approval',
			'entities.run.approve' => 'Approve',
			'entities.run.reject' => 'Reject',
			'entities.run.approvalHint' => 'First decision wins.',
			'entities.run.reasonHint' => 'Reason (optional)',
			'entities.run.inboxEmpty' => 'No pending approvals',
			'entities.run.inboxEmptyHint' => 'Approvals waiting for a decision will appear here.',
			'coldStart.connecting' => 'Setting up your workspace…',
			'coldStart.errorTitle' => 'Couldn\'t set up the workspace',
			'coldStart.errorHint' => 'The local engine is reachable but the workspace didn\'t resolve.',
			'coldStart.defaultWorkspace' => 'Personal',
			'documents.documents' => 'Documents',
			'documents.skills' => 'Skills',
			'documents.untitled' => 'Untitled',
			'documents.filter' => 'Filter',
			'documents.kNew' => 'New',
			'documents.errorTitle' => 'Couldn\'t load your library',
			'documents.errorHint' => 'The local engine didn\'t return it.',
			'documents.retry' => 'Retry',
			'documents.emptyTitle' => 'Nothing here yet',
			'documents.emptyHint' => 'Create a document or a skill to get started.',
			'documents.pickTitle' => 'Pick a document',
			'documents.pickHint' => 'Choose a document or skill on the left to read or edit it.',
			'documents.loadFailed' => 'Couldn\'t open this',
			'documents.emptyDoc' => 'This document is empty.',
			'documents.newSkill' => 'New skill',
			'documents.rename' => 'Rename',
			'documents.duplicate' => 'Duplicate',
			'documents.deleteDocTitle' => 'Delete this page?',
			'documents.deleteDocBody' => ({required Object name}) => '“${name}” and everything nested inside it will be removed.',
			'documents.deleteSkillTitle' => 'Delete this skill?',
			'documents.deleteSkillBody' => ({required Object name}) => 'The “${name}” skill will be removed.',
			'documents.actionFailed' => 'Action failed',
			'documents.props.title' => 'Properties',
			'documents.props.name' => 'Name',
			'documents.props.description' => 'Description',
			'documents.props.tags' => 'Tags',
			'documents.props.addTag' => 'Add a tag',
			'documents.props.path' => 'Path',
			'documents.props.size' => 'Size',
			'documents.props.modified' => 'Modified',
			'documents.props.context' => 'Context',
			'documents.props.contextInline' => 'Inline',
			'documents.props.contextFork' => 'Fork',
			'documents.props.agent' => 'Agent',
			'documents.props.agentHint' => 'Subagent type to dispatch — required for a fork skill.',
			'documents.props.tools' => 'Allowed tools',
			'documents.props.addTool' => 'Add a tool',
			'documents.props.arguments' => 'Arguments',
			'documents.props.addArg' => 'Add an argument',
			'documents.props.modelInvoke' => 'Model can invoke',
			'documents.props.userInvoke' => 'User-invocable',
			'documents.props.on' => 'On',
			'documents.props.off' => 'Off',
			'documents.props.empty' => 'Nothing selected',
			'documents.props.emptyHint' => 'Select a page or skill to see its properties.',
			'documents.props.outline' => 'Outline',
			'documents.props.backlinks' => 'Backlinks',
			'documents.props.noBacklinks' => 'No pages link here yet.',
			'documents.slash.text' => 'Text',
			'documents.slash.h1' => 'Heading 1',
			'documents.slash.h2' => 'Heading 2',
			'documents.slash.h3' => 'Heading 3',
			'documents.slash.bulleted' => 'Bulleted list',
			'documents.slash.numbered' => 'Numbered list',
			'documents.slash.quote' => 'Quote',
			'documents.slash.code' => 'Code block',
			'documents.slash.divider' => 'Divider',
			'documents.slash.todo' => 'To-do',
			'documents.toolCount' => ({required Object n}) => '${n} tools',
			'markdown.imageNotLoaded' => 'image not loaded',
			'attach.unavailable' => 'Unavailable',
			'attach.retry' => 'Tap to retry',
			'attach.tapToLoad' => 'Tap to load',
			'attach.uploading' => 'Uploading…',
			'attach.failedRetry' => 'Failed — tap to retry',
			'attach.failedUnreadable' => 'Couldn\'t read file',
			'attach.remove' => 'Remove',
			_ => null,
		};
	}
}
