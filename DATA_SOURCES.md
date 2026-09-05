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

## Recipe: the `hadith-json` dataset

[`AhmedBaset/hadith-json`](https://github.com/AhmedBaset/hadith-json) is the
best-known open dataset for this purpose: 50,884 hadith across 17 books, Arabic
and English, scraped from [Sunnah.com](https://sunnah.com/). Seven of its books
match collections in this app's catalog.

**Read this before shipping it.** The dataset publishes **no LICENSE file**,
which means it grants no explicit permission to redistribute. Importing it to
read locally is one thing; putting it inside an app you publish is
redistribution, and so is committing it to a public repository. Check
Sunnah.com's terms and the dataset's, and satisfy yourself that you may
distribute the text, before releasing a build that contains it.

### One command

```bash
./tool/fetch_hadith_json.sh riyad_as_salihin   # or: all
```

That clones the dataset at its pinned tag into `.dart_tool/hadith-json`
(git-ignored, cached between runs) and imports it. Available collections:

| Collection | Entries | Dataset file |
|---|--:|---|
| `riyad_as_salihin` | 1,896 | `other_books/riyad_assalihin.json` |
| `nawawi40` | 42 | `forties/nawawi40.json` |
| `adab_al_mufrad` | 1,326 | `other_books/aladab_almufrad.json` |
| `shamail_muhammadiyyah` | 402 | `other_books/shamail_muhammadiyah.json` |
| `bulugh_al_maram` | 1,767 | `other_books/bulugh_almaram.json` |
| `bukhari` | 7,277 | `the_9_books/bukhari.json` |
| `muslim` | 7,459 | `the_9_books/muslim.json` |

Then:

```bash
flutter test test/data/bundled_assets_test.dart   # structure and labelling
flutter run
```

### The same thing by hand

The script is a thin wrapper. The underlying call, for Riyad as-Salihin:

```bash
dart run tool/import_hadith.dart \
  --input .dart_tool/hadith-json/db/by_book/other_books/riyad_assalihin.json \
  --collection riyad_as_salihin \
  --source-name "hadith-json (AhmedBaset), scraped from Sunnah.com" \
  --source-url "https://github.com/AhmedBaset/hadith-json/tree/v1.2.0" \
  --translator "Sunnah.com translation" \
  --array-path hadiths \
  --chapters-path chapters \
  --reference-template "Riyad as-Salihin {number}" \
  --map number=idInBook \
  --map arabic=arabic \
  --map english=english.text \
  --map narrator=english.narrator \
  --map chapter=chapterId \
  --map book=bookId \
  --chapter-map id=id \
  --chapter-map english=english \
  --chapter-map arabic=arabic \
  --chapter-map book=bookId
```

Two flags earn their keep on this dataset:

- `--chapters-path chapters` — the dataset stores chapter titles once in a
  top-level array and references them from each hadith by `chapterId`. This
  joins them, so the reader sees "Chapter: The Book of Good Manners" rather
  than nothing.
- `--reference-template` — the dataset carries no citation string. The template
  builds one from the collection's own name and the number the source
  published. It assembles a *reference*, never text.

Grading is not a separate field in this dataset; where a grading exists it is
part of the Arabic text (for example `(متفق عليه)`). The app therefore shows no
separate grading line for these imports, which is correct — it never infers one.

### Entry counts differ from the catalog's placeholders

The catalog shipped with rounded, edition-dependent totals. The dataset's real
counts differ for several books — Bulugh al-Maram is 1,767 here, not 1,568;
Sahih al-Bukhari is 7,277, not 7,563. **This is expected**: numbering varies
between printed editions and between sites. The importer overwrites
`totalHadith` with the count it actually imported, and at runtime the app trusts
the number of entries in local storage over anything the catalog claims, so
progress can never be measured against a total it does not have.

### If you decide to commit the imported data

Imported files land in `assets/data/collections/` and are **not** git-ignored,
so they are yours to commit once you are satisfied about the licence. Riyad
as-Salihin alone is about 2.6 MB. If you would rather keep them out of version
control and have each developer run the script, add this to `.gitignore`:

```gitignore
# Imported hadith datasets — fetched with tool/fetch_hadith_json.sh
/assets/data/collections/*.json
!/assets/data/collections/dev_sample.json
```

Either way the app builds: without an import it falls back to the development
fixture and shows a "Dataset not installed" state for everything else.

## Importing by hand (any dataset)

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
