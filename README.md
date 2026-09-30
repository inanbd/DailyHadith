# Daily Hadith

A quiet reading app: one hadith at a time, gentle reminders, steady progress.

You choose a collection, choose when you want to be reminded, and read through
the book in order — or have a hadith chosen at random each time from books you
pick. Progress is saved per book, nothing is marked read unless you
read it, and the whole reading experience works offline. No account, no feed, no
streaks.

---

## Contents

- [Reading model](#reading-model)
- [Random mode](#random-mode)
- [Hadith content and source integrity](#hadith-content-and-source-integrity)
- [Getting started](#getting-started)
- [Importing a verified dataset](#importing-a-verified-dataset)
- [Project structure](#project-structure)
- [Architecture](#architecture)
- [Notifications](#notifications)
- [Testing](#testing)
- [Building for release](#building-for-release)
- [Accessibility](#accessibility)
- [Privacy](#privacy)
- [Licences](#licences)

---

## Reading model

The rule the whole app turns on:

> **Stay on what you read this period; otherwise move to the first hadith you
> have not read.**

That single rule produces the behaviour the product needs:

| Situation | What happens |
|---|---|
| First open | Hadith 1 |
| Read today, reopen tonight | The same hadith — no jumping ahead |
| Read yesterday, open after the reminder time | The next unread hadith |
| Missed a fortnight | The first hadith you never read, not the 14th |
| Skipped ahead to 50 and read it | Tomorrow returns to the hadith you skipped |
| Book finished | A completion state; no wrapping around |

A reminder **firing** never changes progress. Progress changes only when the
reader actually reads:

- pressing *Mark as read*,
- opening a hadith from a reminder tap,
- or **reading one through**: once the end of the hadith has been on screen for
  5 seconds (`TodayScreen.dwell`), it marks itself. A hadith scrolled past on
  the way to *Next* is not marked, and a reader who marks one back as unread is
  never overruled — auto-marking happens at most once per hadith.

Moving between hadith is browsing, not reading: the arrows, and a horizontal
swipe on the reading surface, change position without marking anything.

A "period" is the interval between reminders, so a weekly reader advances weekly
and a daily reader advances daily. A reader with several reminder times a day
(up to six) gets a new period, and so a new hadith, at each one. With reminders
switched off it falls back to a daily boundary at each configured time, so the
book still moves on.

The rule lives in
[`lib/domain/services/reading_scheduler.dart`](lib/domain/services/reading_scheduler.dart)
and is covered directly by
[`test/domain/reading_scheduler_test.dart`](test/domain/reading_scheduler_test.dart).

## Random mode

**Settings → Daily hadith** (or the shuffle button on Today) switches from
reading one book in order to a hadith chosen at random from books the reader
ticks. The same period rule applies:

- Each period gets **one** random hadith, which stays on screen until the next
  period. *Show another* draws a different one for the period.
- The draw is uniform over hadith, not over books, so a 40-hadith book is not
  exhausted in a few weeks next to a 7,000-hadith one.
- Hadith already read are skipped until everything in the chosen books is read;
  then the pool starts over.
- Reading at random marks the hadith read in its book, but never moves that
  book's in-order position or its reading period. Choosing *Start/Continue
  reading* on a book switches back to reading in order.

Each period's pick is stored (`random_picks` table), so a reminder that
previewed a hadith and the app opened from it always agree. The rules live in
[`RandomPicker`](lib/domain/services/random_picker.dart) (pure) and
[`RandomSelection`](lib/app/random_selection.dart).

## Hadith content and source integrity

The repository ships fifteen collections imported verbatim from the
[`hadith-json`](https://github.com/AhmedBaset/hadith-json) dataset (see
[DATA_SOURCES.md](DATA_SOURCES.md) — that dataset has no licence), plus one
development fixture, `dev_sample`, whose every field is placeholder prose
written to exercise layout, typography and right-to-left rendering. The fixture
is labelled as such in the catalog and on every screen that shows it, and is
hidden once any real collection is readable.

Nothing in this project generates, paraphrases, completes or corrects hadith
text. Hadith content must come from a dataset you choose and can vouch for. A
catalog entry without imported text shows a **Dataset not installed** state.
The one place text is shortened is a reminder preview, which shows the opening
of the hadith with an ellipsis and opens the full text when tapped.

Every collection carries a source record — name, URL, translator, licence and
retrieval date — which is shown on the collection screen and gathered under
**Settings → Hadith sources**.

See [DATA_SOURCES.md](DATA_SOURCES.md) for the data contract and what to check
before importing a dataset.

## Getting started

Requirements: Flutter **3.27+** (developed against 3.47.2 / Dart 3.13) and the
platform toolchains you intend to build for.

```bash
flutter pub get
flutter run
```

On first launch you get three onboarding steps — why, which book, when — and
then the Today screen. The Development Sample is selectable straight away, so
the app is fully usable before any dataset is imported.

## Importing a verified dataset

The quickest route is the open [`hadith-json`](https://github.com/AhmedBaset/hadith-json)
dataset (Arabic + English, scraped from Sunnah.com), which covers fifteen of the
collections in this app's catalog:

```bash
./tool/fetch_hadith_json.sh riyad_as_salihin   # or: all
flutter run
```

That dataset publishes **no licence**, so importing it for local use is fine but
shipping it in a published app is redistribution — read the note in
[DATA_SOURCES.md](DATA_SOURCES.md#recipe-the-hadith-json-dataset) before you
release a build containing it.

For any other dataset, `tool/import_hadith.dart` converts it into the app's
asset format and records its attribution. It copies text verbatim and skips
entries that have no text rather than filling gaps.

```bash
dart run tool/import_hadith.dart \
  --input path/to/riyad.json \
  --collection riyad_as_salihin \
  --source-name "Name of the dataset" \
  --source-url https://example.org/dataset \
  --translator "Translator name" \
  --licence "The dataset's licence" \
  --array-path hadiths \
  --map number=idInBook \
  --map arabic=arabic \
  --map english=english.text \
  --map narrator=english.narrator \
  --map chapter=chapterId
```

`--map field=path` points an app field at a key in your input; paths may be
nested with dots. `--chapters-path` joins a separate chapter list onto each
hadith, and `--reference-template` builds a citation for datasets that carry
none. Run `dart run tool/import_hadith.dart --help` for the full list.

The tool writes `assets/data/collections/<slug>.json` and updates
`assets/data/catalog.json` with the real entry count and source. Because the
pubspec declares the whole `assets/data/collections/` directory, the new
collection appears on the next build with **no code change** — that is the point
of the content layer.

To verify an import:

```bash
flutter test test/data/bundled_assets_test.dart
```

## Project structure

```
lib/
  app/          Providers, router, bootstrap, route table
  core/         Errors and formatting helpers
  data/
    content/    Asset-backed content source (the swappable seam)
    local/      SQLite database, DAOs, preferences store
    models/     JSON → entity parsing
    notifications/  flutter_local_notifications adapter, battery-optimisation
                    and system-settings channel
    repositories/   Repository implementations
  domain/
    entities/     Collections, hadith, progress, preferences
    repositories/ Abstract contracts
    services/     Reminder maths and the reading rule (pure Dart)
  features/
    onboarding/ library/ progress/ settings/ shell/ splash/
    today/      Reading surface, chapters sheet, auto-marking, swipe
  shared/
    theme/      Colours, typography, spacing, ThemeData
    widgets/    Reusable components
assets/
  data/         Collection catalog and per-collection JSON
  fonts/        Inter and Noto Naskh Arabic (OFL)
tool/
  import_hadith.dart
```

## Architecture

Four layers, each depending only on the one below:

**UI** (`features/`, `shared/`) → **State** (Riverpod controllers) →
**Repositories** (`domain/repositories` contracts, `data/repositories` impls) →
**Sources** (SQLite, shared preferences, content source, notification plugin).

Some deliberate choices:

- **The content source is one interface.**
  [`HadithContentSource`](lib/domain/repositories/hadith_content_source.dart)
  is the only thing that knows where hadith text comes from. The bundled
  implementation reads JSON assets; a network or publisher-backed one can
  replace it by overriding a single provider. Nothing in the UI changes.
- **Content is copied into SQLite on first open.** Reading, paging and progress
  then run entirely against local storage, which is what makes the app work
  offline and keeps a two-thousand-entry book cheap to page through.
- **Scheduling maths is pure Dart.**
  [`ReminderSchedule`](lib/domain/services/reminder_schedule.dart) and
  [`ReadingScheduler`](lib/domain/services/reading_scheduler.dart) have no
  Flutter or platform dependencies, so the tricky parts — weekday cadences,
  period boundaries, missed days — are tested directly.
- **Progress is one row per hadith actually read.** Nothing is ever inferred in
  bulk, which is what guarantees skipped hadith stay unread.
- **The clock is injectable** (`clockProvider`), so "the next morning" is a test
  assertion rather than a wait.

## Notifications

- **Permission is never requested at launch.** The OS prompts are raised at the
  end of onboarding, after the reader has picked a time — or when they turn
  reminders on in settings. Both go through
  [`ReminderPermissionFlow`](lib/features/settings/reminder_permission_flow.dart).
- **Three things have to be allowed**, tracked separately by
  [`ReminderReadiness`](lib/domain/entities/reminder_readiness.dart), because
  "arrives two hours late" and "never arrives" are different problems with
  different fixes:
  - *Notifications* — without it nothing arrives. Asked for with the OS's own
    dialog. Once refused, Android stops showing that dialog, so the settings
    screen offers a way into system settings instead.
  - *Exact timing* (`SCHEDULE_EXACT_ALARM`) — without it Android may hold a
    reminder until the device next wakes, which under Doze can be hours.
  - *Unrestricted battery use* — without it the phone can put the app to sleep
    and drop its pending alarms. Raised through the `MainActivity` method
    channel, which `flutter_local_notifications` does not cover.
- **Declining never breaks anything.** Reminders still switch on; they are armed
  as inexact alarms instead, and the *Delivery* section of notification settings
  keeps the fix on offer. Granting one later re-arms the reminders, so the more
  accurate mode actually takes effect.
- **Times are wall-clock.** 8:00 AM is resolved against the device's *current*
  timezone every time reminders are armed, so travel and daylight-saving
  changes are handled without the reader doing anything.
- **Several times a day.** Every cadence can carry up to six times; each is a
  reminder, and each starts a new reading period.
- **Plain invitations are armed as OS-level repeating notifications** for
  daily, weekly and selected-day cadences, one per time, so they survive a
  device restart and an app update without the app running. Every-other-day
  has no repeating equivalent, so a rolling window of occurrences is armed and
  topped up on each launch.
- **Reminders that show their hadith are concrete occurrences.** A repeating
  notification repeats its text, so these are planned by
  [`ReminderPlanner`](lib/app/reminder_planner.dart) as a rolling window of the
  next 60 reminders (under iOS's cap of 64 pending), re-planned on every launch
  and whenever a hadith is marked read or unread. A reader who does not open
  the app for the whole window stops getting reminders until they next do.
- **Reminders are re-armed on every launch** (`bootstrapProvider`), which also
  covers timezone changes and frequency edits.
- **Changing any setting cancels everything and re-arms**, so a stale reminder
  can never survive a frequency change.
- **Exact alarms where the OS allows them, inexact where it does not.** The mode
  is chosen at the moment reminders are armed, from what the platform reports it
  currently permits, and the exact path falls back rather than throwing if the
  permission is withdrawn in between.
- **What a reminder carries is the reader's choice.** By default it shows the
  opening of the hadith it is for (translation, or Arabic for Arabic-only
  readers), expanding to more of it on Android. In order, reminder *k* carries
  the *k*-th unread hadith after the one on screen; at random, the pick for the
  period it starts. **Notifications → Show the hadith in the reminder** turns
  this off, leaving a plain invitation to open the app.
- **Tapping a reminder opens exactly the hadith it showed** and marks it read;
  an invitation opens the reader's current position. Hadith skipped over stay
  unread either way.

Android needs core library desugaring for the notification plugin; it is already
configured in `android/app/build.gradle.kts`, along with ProGuard rules that
keep the plugin's models so reminders survive R8.

`flutter_local_notifications` stopped declaring its own broadcast receivers at
version 16, so `android/app/src/main/AndroidManifest.xml` declares them: without
`ScheduledNotificationReceiver` an alarm fires and nothing posts the
notification, and without `ScheduledNotificationBootReceiver` reminders do not
come back after a restart or an app update.

## Testing

```bash
flutter analyze     # lib, test and tool must be clean
flutter test
```

156 tests cover the reminder cadences (including several times a day) and
period boundaries, the reading rule, random mode's draw and its guard rails,
reminder previews and the hadith they carry, copying, the reading rule
(including missed days and skipping ahead), the SQLite progress layer, JSON
parsing and error states, the repository install path, the reading surface in
each language mode, reading aloud in both Arabic and English, auto-marking and
its guard rails, swipe navigation, chapter browsing (including books that have
no chapter data), notification scheduling and permission handling, and the full
first-run journey end to end.

`test/features/main_journey_test.dart` runs the exact scenario the product is
built around: install → Riyad as-Salihin → Arabic + English → daily at 8:00 AM →
hadith 1 → next morning's reminder → hadith 2 → `2 / 1,896`.

## Building for release

**Android**

```bash
flutter build appbundle --release   # Play Store
flutter build apk --release         # sideload / testing
```

Before publishing, replace the debug signing config in
`android/app/build.gradle.kts` with your own keystore.

**iOS**

```bash
flutter build ipa --release
```

Then open `ios/Runner.xcworkspace` in Xcode, set your team and bundle
identifier, and distribute. `ios/Runner/AppDelegate.swift` already sets the
`UNUserNotificationCenter` delegate, which is what lets a reminder show while
the app is in the foreground and lets taps reach Dart.

## Accessibility

- Reading text size is a preference that **multiplies** the platform's dynamic
  type rather than replacing it, so system accessibility settings keep working.
  Scaling is clamped to a range the reading layout can still honour.
- Arabic is laid out right-to-left with a generous line height, in Noto Naskh
  Arabic, with `locale` set so the correct glyphs are selected. Flutter does not
  currently expose a per-node screen-reader language, so the reader's system
  voice setting decides how Arabic is spoken.
- Progress bars announce a single sentence rather than three fragments; book
  cards announce title, compiler, size and progress as one label.
- All controls meet a 48dp minimum touch target, and the palette meets WCAG AA
  in both themes.

## Privacy

No account, no analytics, no advertising SDK, no location or contacts access.
Reading progress and preferences stay in local storage on the device. Reminders
that show their hadith can be read on the lock screen; turning previews off
keeps them to a plain invitation. Every
permission the app asks for serves reminders — notifications, exact alarms, and
an exemption from battery optimisation — and none is requested until the reader
has chosen a reminder time. Declining any of them costs punctuality, nothing
else.

## Licences

Application code in this repository is available for you to license as you see
fit. Bundled third-party assets:

- **Inter** — SIL Open Font License 1.1 (`assets/fonts/OFL-Inter.txt`)
- **Noto Naskh Arabic** — SIL Open Font License 1.1
  (`assets/fonts/OFL-NotoNaskhArabic.txt`)

Any hadith dataset you import carries its own licence and attribution; record
them with the importer's `--licence` and `--source-name` flags so they are shown
in the app.
