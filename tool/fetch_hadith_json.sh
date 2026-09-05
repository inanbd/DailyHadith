#!/usr/bin/env bash
#
# Imports a collection from the `hadith-json` dataset
# (https://github.com/AhmedBaset/hadith-json), which is scraped from
# Sunnah.com and covers 17 books in Arabic and English.
#
#   ./tool/fetch_hadith_json.sh riyad_as_salihin
#   ./tool/fetch_hadith_json.sh all
#
# BEFORE YOU RUN THIS: the dataset publishes no LICENSE file, so it grants no
# explicit permission to redistribute. Importing it for local use is one thing;
# shipping it inside a published app is redistribution. Check the terms of
# Sunnah.com and of the dataset, and satisfy yourself that you may distribute
# the text, before releasing a build that contains it.
#
# The dataset is pinned to a tag: its README warns that the format may change
# on `main`.

set -euo pipefail

DATASET_TAG="v1.2.0"
DATASET_REPO="https://github.com/AhmedBaset/hadith-json.git"
CACHE_DIR="${HADITH_JSON_CACHE:-.dart_tool/hadith-json}"

# collection-id | path within db/by_book | English title used for citations
CATALOG="
riyad_as_salihin|other_books/riyad_assalihin.json|Riyad as-Salihin
nawawi40|forties/nawawi40.json|Forty Hadith of Imam an-Nawawi
adab_al_mufrad|other_books/aladab_almufrad.json|Al-Adab Al-Mufrad
shamail_muhammadiyyah|other_books/shamail_muhammadiyah.json|Ash-Shama'il Al-Muhammadiyyah
bulugh_al_maram|other_books/bulugh_almaram.json|Bulugh al-Maram
bukhari|the_9_books/bukhari.json|Sahih al-Bukhari
muslim|the_9_books/muslim.json|Sahih Muslim
"

usage() {
  echo "Usage: $0 <collection-id|all>"
  echo
  echo "Collections:"
  while IFS='|' read -r id _ title; do
    if [ -n "$id" ]; then
      printf '  %-24s %s\n' "$id" "$title"
    fi
  done <<< "$CATALOG"
  echo
  echo "  all                      import every collection above"
  return 0
}

if [ $# -ne 1 ]; then usage; exit 64; fi
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then usage; exit 0; fi

if [ ! -d "$CACHE_DIR/.git" ]; then
  echo "Fetching $DATASET_REPO at $DATASET_TAG ..."
  mkdir -p "$(dirname "$CACHE_DIR")"
  git -c advice.detachedHead=false clone --quiet --depth 1 \
    --branch "$DATASET_TAG" --filter=blob:none --sparse \
    "$DATASET_REPO" "$CACHE_DIR"
  git -C "$CACHE_DIR" sparse-checkout set db/by_book
else
  echo "Using cached dataset in $CACHE_DIR"
fi

import_one() {
  local id="$1" path="$2" title="$3"
  local input="$CACHE_DIR/db/by_book/$path"

  if [ ! -f "$input" ]; then
    echo "Error: $input not found in the dataset." >&2
    return 66
  fi

  echo "Importing $title ..."
  dart run tool/import_hadith.dart \
    --input "$input" \
    --collection "$id" \
    --source-name "hadith-json (AhmedBaset), scraped from Sunnah.com" \
    --source-url "https://github.com/AhmedBaset/hadith-json/tree/$DATASET_TAG" \
    --translator "Sunnah.com translation" \
    --array-path hadiths \
    --chapters-path chapters \
    --reference-template "$title {number}" \
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
}

if [ "$1" != "all" ] && ! grep -q "^$1|" <<< "$CATALOG"; then
  echo "Error: unknown collection \"$1\"." >&2
  usage >&2
  exit 64
fi

# A here-string rather than a pipe, so this runs in the current shell and a
# failing import aborts the script instead of being swallowed by a subshell.
while IFS='|' read -r id path title; do
  if [ -z "$id" ]; then
    continue
  fi
  if [ "$1" = "all" ] || [ "$1" = "$id" ]; then
    import_one "$id" "$path" "$title"
  fi
done <<< "$CATALOG"

echo
echo "Done. Verify with:"
echo "  flutter test test/data/bundled_assets_test.dart"
echo "  flutter run"
