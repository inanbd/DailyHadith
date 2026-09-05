# Hadith data sources

This file documents where the app's hadith text comes from, what shape it must
be in, and what to check before importing a dataset.

## The rule this project holds to

Hadith text is never generated, paraphrased, completed, corrected or reformatted
by this application or by any tool in this repository. It is copied verbatim
from a dataset you choose, and it always travels with an attribution record.

If a dataset has no Arabic for an entry, the app shows no Arabic for that entry.
If it has no grading, no grading is shown. Gaps in a source stay gaps.

## What ships in this repository

| Collection | Status |
|---|---|
| `dev_sample` — "Development Sample" | **Development fixture. Not hadith.** Placeholder prose written for this repository to exercise layout, typography and RTL rendering. |
| `riyad_as_salihin`, `nawawi40`, `adab_al_mufrad`, `shamail_muhammadiyyah`, `bulugh_al_maram`, `bukhari`, `muslim` | Bibliographic metadata only. No text. Each shows a "Dataset not installed" state until imported. |

The fixture is marked `"verification": "development_fixture"` in the catalog.
The app surfaces that on the Today screen, on the collection screen, on the
library card and under **Settings → Hadith sources**. `flutter test
test/data/bundled_assets_test.dart` fails if that labelling is ever lost, or if a
collection ships text without real attribution.

No third-party hadith dataset is vendored here. That is deliberate: choosing a
dataset means accepting its accuracy and its licence, and that is a decision for
whoever ships the app, not a default baked into it.

## Choosing a dataset

Before importing, check that the dataset:

1. **Names its provenance.** Which printed edition or publisher is it based on?
   Who produced the translation?
2. **Has a licence you can comply with.** Many hadith datasets circulating on
   code-hosting sites carry no licence file at all, which means no permission to
   redistribute. Redistributing text inside a shipped app is redistribution.
3. **Numbers entries consistently.** Numbering differs between editions and
   between sites. The app treats reading order (`ordinal`) and the published
   number (`hadithNumber`) as separate things for exactly this reason, but a
   dataset that mixes numbering schemes will produce confusing references.
4. **Keeps Arabic and translation aligned.** Spot-check entries at the start,
   middle and end after importing.
5. **Reports grading honestly**, where it reports grading at all. The app shows
   the grading string verbatim and never infers one.

Publishers and translators generally need to be credited by name. Record them
with `--source-name` and `--translator` so the app can show them.

## The data contract

Two files, both plain JSON. This is the whole contract — anything that can emit
these shapes can back the app.

### `assets/data/catalog.json`

```jsonc
{
  "schemaVersion": 1,
  "collections": [
    {
      "id": "riyad_as_salihin",      // stable key; progress is stored against it
      "slug": "riyad_as_salihin",    // file name under assets/data/collections/
      "titleEnglish": "Riyad as-Salihin",
      "titleArabic": "رياض الصالحين",
      "compiler": "Imam an-Nawawi",
      "compilerArabic": "الإمام النووي",
      "description": "…",
      "totalHadith": 1896,
      "verification": "verified",    // or "development_fixture"
      "source": {
        "name": "…",                 // required; shown as attribution
        "url": "https://…",
        "translator": "…",
        "licence": "…",
        "retrievedAt": "2026-02-01T00:00:00Z"
      }
    }
  ]
}
```

A collection is readable when `assets/data/collections/<slug>.json` exists.
Catalog entries without one are listed but not startable.

### `assets/data/collections/<slug>.json`

```jsonc
{
  "schemaVersion": 1,
  "collectionId": "riyad_as_salihin",
  "verification": "verified",
  "source": { "name": "…" },
  "chapters": [
    {
      "chapterNumber": 1,
      "bookNumber": 1,
      "titleEnglish": "Sincerity",
      "titleArabic": "الإخلاص",
      "hadithCount": 20
    }
  ],
  "hadith": [
    {
      "hadithNumber": "1",           // as published; may be non-numeric ("1a")
      "bookNumber": 1,
      "chapterNumber": 1,
      "chapterEnglish": "Sincerity",
      "chapterArabic": "الإخلاص",
      "arabic": "…",                 // verbatim
      "english": "…",                // verbatim
      "narrator": "…",
      "grade": "…",                  // verbatim, never inferred
      "reference": "Riyad as-Salihin 1"
    }
  ]
}
```

Notes:

- **Array order is reading order.** The app assigns `ordinal` 1..N from the
  array position; `hadithNumber` is only for display and citation.
- **Every entry needs at least one of `arabic` or `english`.** Entries with
  neither are skipped by the importer and reported.
- **Whitespace-only strings are treated as absent**, so a source that uses `""`
  for missing fields does not produce empty blocks in the reader.
- `chapters` may be empty. Chapter browsing is not in the MVP UI, but the
  metadata is preserved so it can be added without touching the data layer.

## Importing

```bash
dart run tool/import_hadith.dart \
  --input path/to/dataset.json \
  --collection riyad_as_salihin \
  --source-name "…" \
  --source-url https://… \
  --translator "…" \
  --licence "…" \
  --array-path hadiths \
  --map number=idInBook \
  --map arabic=arabic \
  --map english=english.text \
  --map narrator=english.narrator \
  --map chapter=chapterId
```

The tool writes the collection file, updates the catalog's `totalHadith`,
`verification` and `source`, and derives the chapter list from whatever chapter
metadata the entries carry. `--fixture` marks an import as development data
instead of verified content.

After importing:

```bash
flutter test test/data/bundled_assets_test.dart   # structure and labelling
flutter run                                        # spot-check the text
```

Spot-check entries at the beginning, middle and end, with the language set to
**English + Arabic**, and confirm the reference line matches the numbering you
expect.

## Replacing the content layer entirely

Bundled assets are only the default. The seam is
[`HadithContentSource`](lib/domain/repositories/hadith_content_source.dart) —
four methods. Implement it against an API, a downloadable content pack or a
publisher SDK, then override one provider:

```dart
ProviderScope(
  overrides: [
    hadithContentSourceProvider.overrideWith((ref) => MyApiContentSource()),
  ],
  child: const DailyHadithApp(),
);
```

Everything above that line — repositories, progress, reminders, every screen —
is unchanged. Content is still copied into local storage on first open, so
reading stays offline-capable regardless of where the text came from.
