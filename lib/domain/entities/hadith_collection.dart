import 'package:meta/meta.dart';

import 'enums.dart';

/// A hadith collection (book) available to read.
///
/// Everything here is bibliographic metadata about the book plus provenance for
/// its text. It never contains hadith text itself.
@immutable
class HadithCollection {
  const HadithCollection({
    required this.id,
    required this.slug,
    required this.titleEnglish,
    required this.titleArabic,
    required this.compiler,
    required this.description,
    required this.totalHadith,
    required this.source,
    required this.verification,
    this.compilerArabic,
    this.isInstalled = false,
    this.isAvailable = false,
  });

  /// Stable identifier used as a foreign key by progress and preferences.
  final String id;

  /// URL/asset-friendly identifier.
  final String slug;

  final String titleEnglish;

  /// Native title, e.g. `رياض الصالحين`. Empty when unknown.
  final String titleArabic;

  final String compiler;
  final String? compilerArabic;
  final String description;

  /// Number of hadith the complete collection contains.
  final int totalHadith;

  /// Where the text came from. Displayed as attribution.
  final ContentSource source;

  /// Whether the text is verified content or a development fixture.
  final ContentVerification verification;

  /// True once the collection's text is present in local storage and readable
  /// offline.
  final bool isInstalled;

  /// True when the content source can supply this collection's text — either it
  /// is already installed, or importing it would succeed. Catalog entries whose
  /// dataset has not been added yet report `false` and surface a
  /// "dataset not installed" state rather than an error.
  final bool isAvailable;

  bool get isFixture => verification.isFixture;

  /// Whether the reader can open this book right now (or after a quick,
  /// automatic first-open import).
  bool get isReadable => isInstalled || isAvailable;

  HadithCollection copyWith({
    bool? isInstalled,
    bool? isAvailable,
    int? totalHadith,
  }) {
    return HadithCollection(
      id: id,
      slug: slug,
      titleEnglish: titleEnglish,
      titleArabic: titleArabic,
      compiler: compiler,
      compilerArabic: compilerArabic,
      description: description,
      totalHadith: totalHadith ?? this.totalHadith,
      source: source,
      verification: verification,
      isInstalled: isInstalled ?? this.isInstalled,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HadithCollection &&
      other.id == id &&
      other.totalHadith == totalHadith &&
      other.isInstalled == isInstalled &&
      other.isAvailable == isAvailable;

  @override
  int get hashCode => Object.hash(id, totalHadith, isInstalled, isAvailable);
}

/// Attribution for a collection's text. Stored with every collection so the
/// app can always say where its content came from.
@immutable
class ContentSource {
  const ContentSource({
    required this.name,
    this.url,
    this.translator,
    this.licence,
    this.retrievedAt,
  });

  /// Human-readable name of the dataset or publisher.
  final String name;

  /// Canonical link to the dataset or publisher.
  final String? url;

  /// Credited translator of the English text, when known.
  final String? translator;

  /// Licence the dataset is distributed under, when known.
  final String? licence;

  /// When the dataset snapshot was taken.
  final DateTime? retrievedAt;

  @override
  bool operator ==(Object other) =>
      other is ContentSource && other.name == name && other.url == url;

  @override
  int get hashCode => Object.hash(name, url);
}
