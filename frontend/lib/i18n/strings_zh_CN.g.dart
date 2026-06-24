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
	@override String get appName => 'Anselm';
	@override late final _Translations$status$zh_CN status = _Translations$status$zh_CN._(_root);
	@override late final _Translations$action$zh_CN action = _Translations$action$zh_CN._(_root);
	@override late final _Translations$feedback$zh_CN feedback = _Translations$feedback$zh_CN._(_root);
	@override late final _Translations$ref$zh_CN ref = _Translations$ref$zh_CN._(_root);
	@override late final _Translations$a11y$zh_CN a11y = _Translations$a11y$zh_CN._(_root);
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
	@override String get loading => '加载中';
	@override String stepOf({required Object n, required Object m}) => '第 ${n} 步 / 共 ${m} 步';
	@override String goToStep({required Object n}) => '跳到第 ${n} 步';
	@override String removeTag({required Object name}) => '移除 ${name}';
	@override String get addTag => '添加标签';
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
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZhCn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appName' => 'Anselm',
			'status.idle' => '空闲',
			'status.run' => '运行中',
			'status.wait' => '等待',
			'status.err' => '失败',
			'status.done' => '完成',
			'action.edit' => '编辑',
			'action.cancel' => '取消',
			'action.save' => '保存',
			'feedback.info' => '提示',
			'feedback.success' => '成功',
			'feedback.warning' => '警告',
			'feedback.error' => '错误',
			'feedback.dismiss' => '关闭',
			'feedback.loading' => '加载中',
			'feedback.stepOf' => ({required Object n, required Object m}) => '第 ${n} 步 / 共 ${m} 步',
			'feedback.goToStep' => ({required Object n}) => '跳到第 ${n} 步',
			'feedback.removeTag' => ({required Object name}) => '移除 ${name}',
			'feedback.addTag' => '添加标签',
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
			_ => null,
		};
	}
}
