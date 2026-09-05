// Imports a hadith dataset into the app's asset format.
//
// The app reads collections from `assets/data/collections/<slug>.json`, in the
// shape documented in `lib/data/content/content_schema.dart`. This tool
// converts a third-party dataset into that shape and records where it came
// from, so attribution travels with the text.
//
// It never invents, rewrites or reformats hadith text. Every field is copied
// verbatim from the input; entries with no text at all are reported and
// skipped rather than filled in.
//
// Usage:
//
//   dart run tool/import_hadith.dart \
//     --input path/to/source.json \
//     --collection riyad_as_salihin \
//     --source-name "Name of the dataset" \
//     --source-url https://example.org/dataset \
//     --licence "CC BY 4.0" \
//     --translator "Translator name" \
//     --array-path hadiths \
//     --map number=idInBook --map arabic=arabic --map english=english.text \
//     --map narrator=english.narrator --map chapter=chapterId
//
// Run with --help for the full list of options.

import 'dart:convert';
import 'dart:io';

const JsonEncoder _json = JsonEncoder.withIndent('  ');

const String _catalogPath = 'assets/data/catalog.json';
const String _collectionsDir = 'assets/data/collections';

/// Fields the app understands, and the input keys they default to.
const Map<String, String> _defaultMapping = <String, String>{
  'number': 'hadithNumber',
  'arabic': 'arabic',
  'english': 'english',
  'narrator': 'narrator',
  'grade': 'grade',
  'reference': 'reference',
  'chapter': 'chapterNumber',
  'chapterEnglish': 'chapterEnglish',
  'chapterArabic': 'chapterArabic',
  'book': 'bookNumber',
};

/// Fields of a separate chapter list, and the input keys they default to.
///
/// Many datasets keep chapter titles in one array and reference them from each
/// hadith by id, rather than repeating the title on every entry.
const Map<String, String> _defaultChapterMapping = <String, String>{
  'id': 'chapterNumber',
  'english': 'titleEnglish',
  'arabic': 'titleArabic',
  'book': 'bookNumber',
};

Future<int> main(List<String> arguments) async {
  final _Options options;
  try {
    options = _Options.parse(arguments);
  } on _UsageError catch (error) {
    stderr.writeln('Error: ${error.message}\n');
    stderr.writeln(_usage);
    return 64;
  }

  if (options.showHelp) {
    stdout.writeln(_usage);
    return 0;
  }

  final File input = File(options.inputPath);
  if (!input.existsSync()) {
    stderr.writeln('Error: input file not found: ${options.inputPath}');
    return 66;
  }

  final Object? decoded = jsonDecode(await input.readAsString());
  final List<Object?> entries = _locateArray(decoded, options.arrayPath);
  if (entries.isEmpty) {
    stderr.writeln('Error: no entries found in ${options.inputPath}.');
    if (options.arrayPath == null) {
      stderr.writeln('Hint: pass --array-path if the hadith live under a key.');
    }
    return 65;
  }

  // A separate chapter list, keyed by chapter id, joined onto each hadith below.
  final Map<int, _Chapter> chapterIndex = _readChapterIndex(decoded, options);
  if (options.chaptersPath != null && chapterIndex.isEmpty) {
    stderr.writeln(
      'Warning: --chapters-path "${options.chaptersPath}" matched no chapters.',
    );
  }

  final List<Map<String, Object?>> hadith = <Map<String, Object?>>[];
  int skipped = 0;
  int ordinal = 0;

  for (final Object? entry in entries) {
    if (entry is! Map<String, Object?>) {
      skipped++;
      continue;
    }
    ordinal++;

    final String? arabic = _readString(entry, options.mapping['arabic']);
    final String? english = _readString(entry, options.mapping['english']);

    if (arabic == null && english == null) {
      // An entry with no text is a gap in the source, not something to fill in.
      stderr.writeln('Skipping entry $ordinal: no Arabic or English text.');
      skipped++;
      ordinal--;
      continue;
    }

    final String number =
        _readString(entry, options.mapping['number']) ?? '$ordinal';
    final int? chapterNumber = _readInt(entry, options.mapping['chapter']);
    final int? bookNumber = _readInt(entry, options.mapping['book']);
    final _Chapter? chapter = chapterIndex[chapterNumber];

    hadith.add(<String, Object?>{
      'hadithNumber': number,
      'bookNumber': bookNumber ?? chapter?.bookNumber,
      'chapterNumber': chapterNumber,
      // Per-entry titles win; the joined chapter list fills the gaps.
      'chapterEnglish':
          _readString(entry, options.mapping['chapterEnglish']) ??
              chapter?.titleEnglish,
      'chapterArabic': _readString(entry, options.mapping['chapterArabic']) ??
          chapter?.titleArabic,
      'arabic': arabic,
      'english': english,
      'narrator': _readString(entry, options.mapping['narrator']),
      'grade': _readString(entry, options.mapping['grade']),
      'reference': _readString(entry, options.mapping['reference']) ??
          _buildReference(options.referenceTemplate, number, chapterNumber),
    }..removeWhere((String key, Object? value) => value == null));
  }

  if (hadith.isEmpty) {
    stderr.writeln('Error: every entry was skipped; nothing to write.');
    return 65;
  }

  final Map<String, Object?> source = <String, Object?>{
    'name': options.sourceName,
    if (options.sourceUrl != null) 'url': options.sourceUrl,
    if (options.translator != null) 'translator': options.translator,
    if (options.licence != null) 'licence': options.licence,
    'retrievedAt': DateTime.now().toUtc().toIso8601String(),
  };

  final Map<String, Object?> payload = <String, Object?>{
    'schemaVersion': 1,
    'collectionId': options.collectionId,
    'verification': options.verification,
    'source': source,
    'chapters': _deriveChapters(hadith),
    'hadith': hadith,
  };

  final String slug = await _updateCatalog(options, hadith.length, source);
  final File output = File('$_collectionsDir/$slug.json');
  await output.parent.create(recursive: true);
  await output.writeAsString('${_json.convert(payload)}\n');

  stdout.writeln('Imported ${hadith.length} entries into ${output.path}');
  if (skipped > 0) stdout.writeln('Skipped $skipped entries without text.');
  stdout.writeln('Updated $_catalogPath (totalHadith and source).');
  stdout.writeln(
    'Run `flutter pub get && flutter run` to pick up the new collection.',
  );
  return 0;
}

/// Rewrites the catalog entry for this collection, and returns its slug.
Future<String> _updateCatalog(
  _Options options,
  int total,
  Map<String, Object?> source,
) async {
  final File catalogFile = File(_catalogPath);
  if (!catalogFile.existsSync()) {
    throw StateError('Catalog not found at $_catalogPath.');
  }

  final Map<String, Object?> catalog =
      jsonDecode(await catalogFile.readAsString()) as Map<String, Object?>;
  final List<Object?> collections =
      (catalog['collections'] as List<Object?>?) ?? <Object?>[];

  Map<String, Object?>? entry;
  for (final Object? candidate in collections) {
    if (candidate is Map<String, Object?> &&
        candidate['id'] == options.collectionId) {
      entry = candidate;
      break;
    }
  }

  if (entry == null) {
    // A collection the catalog has never heard of is added with what we know;
    // the title and description can be filled in by hand afterwards.
    entry = <String, Object?>{
      'id': options.collectionId,
      'slug': options.collectionId,
      'titleEnglish': options.collectionId,
      'titleArabic': '',
      'compiler': '',
      'description': '',
    };
    collections.add(entry);
    catalog['collections'] = collections;
    stdout.writeln(
      'Note: "${options.collectionId}" was not in the catalog and has been '
      'added. Fill in its title, compiler and description.',
    );
  }

  entry['totalHadith'] = total;
  entry['verification'] = options.verification;
  entry['source'] = source;

  await catalogFile.writeAsString('${_json.convert(catalog)}\n');

  return (entry['slug'] as String?) ?? options.collectionId;
}

/// One entry of a dataset's separate chapter list.
class _Chapter {
  const _Chapter({this.titleEnglish, this.titleArabic, this.bookNumber});

  final String? titleEnglish;
  final String? titleArabic;
  final int? bookNumber;
}

/// Reads the dataset's chapter list into a lookup keyed by chapter id.
///
/// Returns an empty map when no --chapters-path was given, in which case
/// chapter titles come from the hadith entries themselves.
Map<int, _Chapter> _readChapterIndex(Object? document, _Options options) {
  final String? path = options.chaptersPath;
  if (path == null) return const <int, _Chapter>{};

  final Map<int, _Chapter> index = <int, _Chapter>{};
  for (final Object? entry in _locateArray(document, path)) {
    if (entry is! Map<String, Object?>) continue;
    final int? id = _readInt(entry, options.chapterMapping['id']);
    if (id == null) continue;
    index[id] = _Chapter(
      titleEnglish: _readString(entry, options.chapterMapping['english']),
      titleArabic: _readString(entry, options.chapterMapping['arabic']),
      bookNumber: _readInt(entry, options.chapterMapping['book']),
    );
  }
  return index;
}

/// Builds a citation like "Riyad as-Salihin 24" from a template.
///
/// This is a reference, not hadith text: it is assembled only from the
/// collection's own name and the number the source published.
String? _buildReference(String? template, String number, int? chapter) {
  if (template == null || template.isEmpty) return null;
  return template
      .replaceAll('{number}', number)
      .replaceAll('{chapter}', chapter?.toString() ?? '');
}

/// Builds the chapter list from whatever chapter metadata the entries carry.
List<Map<String, Object?>> _deriveChapters(List<Map<String, Object?>> hadith) {
  final Map<int, Map<String, Object?>> chapters = <int, Map<String, Object?>>{};
  for (final Map<String, Object?> entry in hadith) {
    final Object? number = entry['chapterNumber'];
    if (number is! int) continue;
    final Map<String, Object?> chapter = chapters.putIfAbsent(
      number,
      () => <String, Object?>{
        'chapterNumber': number,
        'bookNumber': entry['bookNumber'],
        'titleEnglish': entry['chapterEnglish'] ?? '',
        'titleArabic': entry['chapterArabic'] ?? '',
        'hadithCount': 0,
      },
    );
    chapter['hadithCount'] = (chapter['hadithCount']! as int) + 1;
  }
  final List<Map<String, Object?>> result = chapters.values.toList()
    ..sort(
      (Map<String, Object?> a, Map<String, Object?> b) =>
          (a['chapterNumber']! as int).compareTo(b['chapterNumber']! as int),
    );
  return result;
}

/// Finds the array of entries, either at the document root or under
/// [arrayPath] (dot-separated).
List<Object?> _locateArray(Object? document, String? arrayPath) {
  if (arrayPath == null) {
    if (document is List<Object?>) return document;
    if (document is Map<String, Object?>) {
      // Common shapes: {"hadiths": [...]} or {"hadith": [...]}.
      for (final String key in <String>['hadith', 'hadiths', 'data', 'items']) {
        final Object? value = document[key];
        if (value is List<Object?>) return value;
      }
    }
    return const <Object?>[];
  }

  Object? cursor = document;
  for (final String segment in arrayPath.split('.')) {
    if (cursor is! Map<String, Object?>) return const <Object?>[];
    cursor = cursor[segment];
  }
  return cursor is List<Object?> ? cursor : const <Object?>[];
}

/// Reads a possibly nested value, e.g. `english.text`.
Object? _readPath(Map<String, Object?> entry, String? path) {
  if (path == null || path.isEmpty) return null;
  Object? cursor = entry;
  for (final String segment in path.split('.')) {
    if (cursor is! Map<String, Object?>) return null;
    cursor = cursor[segment];
  }
  return cursor;
}

String? _readString(Map<String, Object?> entry, String? path) {
  final Object? value = _readPath(entry, path);
  if (value == null) return null;
  final String text = value is String ? value : value.toString();
  return text.trim().isEmpty ? null : text;
}

int? _readInt(Map<String, Object?> entry, String? path) {
  final Object? value = _readPath(entry, path);
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class _UsageError implements Exception {
  _UsageError(this.message);

  final String message;
}

class _Options {
  _Options({
    required this.inputPath,
    required this.collectionId,
    required this.sourceName,
    required this.mapping,
    required this.chapterMapping,
    required this.verification,
    this.sourceUrl,
    this.translator,
    this.licence,
    this.arrayPath,
    this.chaptersPath,
    this.referenceTemplate,
    this.showHelp = false,
  });

  factory _Options.parse(List<String> arguments) {
    if (arguments.contains('--help') || arguments.contains('-h')) {
      return _Options(
        inputPath: '',
        collectionId: '',
        sourceName: '',
        mapping: _defaultMapping,
        chapterMapping: _defaultChapterMapping,
        verification: 'verified',
        showHelp: true,
      );
    }

    final Map<String, String> values = <String, String>{};
    final Map<String, String> mapping = Map<String, String>.of(_defaultMapping);
    final Map<String, String> chapterMapping =
        Map<String, String>.of(_defaultChapterMapping);
    bool fixture = false;

    for (int i = 0; i < arguments.length; i++) {
      final String argument = arguments[i];
      if (argument == '--fixture') {
        fixture = true;
        continue;
      }
      if (!argument.startsWith('--')) {
        throw _UsageError('Unexpected argument "$argument".');
      }
      final String name = argument.substring(2);
      if (i + 1 >= arguments.length) {
        throw _UsageError('Missing value for --$name.');
      }
      final String value = arguments[++i];

      if (name == 'map' || name == 'chapter-map') {
        final bool isChapter = name == 'chapter-map';
        final Map<String, String> target = isChapter ? chapterMapping : mapping;
        final Map<String, String> known =
            isChapter ? _defaultChapterMapping : _defaultMapping;

        final int split = value.indexOf('=');
        if (split <= 0) {
          throw _UsageError('--$name expects field=path, got "$value".');
        }
        final String field = value.substring(0, split);
        if (!known.containsKey(field)) {
          throw _UsageError(
            'Unknown --$name field "$field". Known fields: '
            '${known.keys.join(', ')}.',
          );
        }
        target[field] = value.substring(split + 1);
        continue;
      }
      values[name] = value;
    }

    for (final String required in <String>['input', 'collection', 'source-name']) {
      if ((values[required] ?? '').isEmpty) {
        throw _UsageError('--$required is required.');
      }
    }

    return _Options(
      inputPath: values['input']!,
      collectionId: values['collection']!,
      sourceName: values['source-name']!,
      sourceUrl: values['source-url'],
      translator: values['translator'],
      licence: values['licence'],
      arrayPath: values['array-path'],
      chaptersPath: values['chapters-path'],
      referenceTemplate: values['reference-template'],
      mapping: mapping,
      chapterMapping: chapterMapping,
      verification: fixture ? 'development_fixture' : 'verified',
    );
  }

  final String inputPath;
  final String collectionId;
  final String sourceName;
  final String? sourceUrl;
  final String? translator;
  final String? licence;
  final String? arrayPath;

  /// Dot path to a separate chapter list, when the dataset keeps one.
  final String? chaptersPath;

  /// Citation template, e.g. "Riyad as-Salihin {number}".
  final String? referenceTemplate;

  final Map<String, String> mapping;
  final Map<String, String> chapterMapping;
  final String verification;
  final bool showHelp;
}

const String _usage = '''
Import a hadith dataset into the app's asset format.

Required:
  --input <path>          JSON file to read.
  --collection <id>       Catalog id to import into, e.g. riyad_as_salihin.
  --source-name <name>    Attribution shown in the app. Never left blank.

Optional:
  --source-url <url>      Link to the dataset or publisher.
  --translator <name>     Credited translator of the English text.
  --licence <name>        Licence the dataset is distributed under.
  --array-path <path>     Dot path to the array of entries, e.g. "data.hadiths".
                          Omitted, the root array (or hadith/hadiths/data/items)
                          is used.
  --map <field>=<path>    Map an app field to an input path. Repeatable.
                          Paths may be nested, e.g. english=english.text.
  --chapters-path <path>  Dot path to a separate chapter list, for datasets
                          that store chapter titles once and reference them
                          from each hadith by id.
  --chapter-map <f>=<p>   Map a chapter field to an input path. Repeatable.
  --reference-template <t>
                          Citation to use when entries carry none, e.g.
                          "Riyad as-Salihin {number}". Placeholders: {number},
                          {chapter}. Built only from the collection's own name
                          and the source's published numbering.
  --fixture               Mark the import as development data rather than
                          verified content.
  -h, --help              Show this message.

App fields available to --map:
  number, arabic, english, narrator, grade, reference, chapter,
  chapterEnglish, chapterArabic, book

Chapter fields available to --chapter-map:
  id, english, arabic, book

Text is copied verbatim. Entries with neither Arabic nor English are reported
and skipped.
''';
