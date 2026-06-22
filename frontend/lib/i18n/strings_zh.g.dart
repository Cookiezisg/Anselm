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
class TranslationsZh extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZh({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zh,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsZh _root = this; // ignore: unused_field

	@override 
	TranslationsZh $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZh(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$zh app = _Translations$app$zh._(_root);
	@override late final _Translations$backend$zh backend = _Translations$backend$zh._(_root);
	@override late final _Translations$workspace$zh workspace = _Translations$workspace$zh._(_root);
	@override late final _Translations$nav$zh nav = _Translations$nav$zh._(_root);
}

// Path: app
class _Translations$app$zh extends Translations$app$en {
	_Translations$app$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get name => 'Anselm';
}

// Path: backend
class _Translations$backend$zh extends Translations$backend$en {
	_Translations$backend$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get starting => '正在启动 Anselm…';
	@override String get crashedTitle => '后端启动失败';
	@override String get retry => '重试';
}

// Path: workspace
class _Translations$workspace$zh extends Translations$workspace$en {
	_Translations$workspace$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get selectTitle => '选择一个工作区';
	@override String get none => '未选择工作区';
}

// Path: nav
class _Translations$nav$zh extends Translations$nav$en {
	_Translations$nav$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get chat => '对话';
	@override String get entities => '实体';
	@override String get scheduler => '调度';
	@override String get documents => '文档';
	@override String get search => '搜索';
	@override String get settings => '设置';
	@override String get notifications => '通知';
}

/// The flat map containing all translations for locale <zh>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZh {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.name' => 'Anselm',
			'backend.starting' => '正在启动 Anselm…',
			'backend.crashedTitle' => '后端启动失败',
			'backend.retry' => '重试',
			'workspace.selectTitle' => '选择一个工作区',
			'workspace.none' => '未选择工作区',
			'nav.chat' => '对话',
			'nav.entities' => '实体',
			'nav.scheduler' => '调度',
			'nav.documents' => '文档',
			'nav.search' => '搜索',
			'nav.settings' => '设置',
			'nav.notifications' => '通知',
			_ => null,
		};
	}
}
