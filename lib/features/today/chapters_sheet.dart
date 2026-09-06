import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/collection_providers.dart';
import '../../app/providers.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/repositories/hadith_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import 'today_controller.dart';

/// Jumping to a chapter, for books whose dataset carried chapter metadata.
///
/// Deliberately behind an icon rather than on the reading screen: the app is
/// built around reading one hadith at a time in order, and a table of contents
/// on the page would invite skimming. It is here for the reader who wants it.
abstract final class ChaptersSheet {
  /// Opens the chapter list for [collectionId].
  static Future<void> open(
    BuildContext context,
    String collectionId,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (BuildContext context) => _ChaptersList(collectionId: collectionId),
    );
  }
}

class _ChaptersList extends ConsumerWidget {
  const _ChaptersList({required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final List<HadithChapter> chapters =
        ref.watch(chaptersProvider(collectionId)).value ??
            const <HadithChapter>[];
    final int? currentChapter = ref
        .watch(todayControllerProvider)
        .value
        ?.hadith
        ?.chapterNumber;

    return SafeArea(
      child: ConstrainedBox(
        // Never a full-height takeover: the hadith stays visible behind it.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.lg,
                AppSpacing.gutter,
                AppSpacing.md,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  'Chapters',
                  style: AppTypography.sectionTitle
                      .copyWith(color: colors.textPrimary),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: chapters.length,
                separatorBuilder: (BuildContext context, int index) => Divider(
                  height: 1,
                  color: colors.border,
                  indent: AppSpacing.gutter,
                  endIndent: AppSpacing.gutter,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final HadithChapter chapter = chapters[index];
                  return _ChapterRow(
                    chapter: chapter,
                    isCurrent: chapter.chapterNumber == currentChapter,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterRow extends ConsumerStatefulWidget {
  const _ChapterRow({required this.chapter, required this.isCurrent});

  final HadithChapter chapter;
  final bool isCurrent;

  @override
  ConsumerState<_ChapterRow> createState() => _ChapterRowState();
}

class _ChapterRowState extends ConsumerState<_ChapterRow> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final HadithChapter chapter = widget.chapter;
    final Color titleColour =
        widget.isCurrent ? colors.accent : colors.textPrimary;

    return Semantics(
      button: true,
      selected: widget.isCurrent,
      child: InkWell(
        onTap: _opening ? null : _open,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Text(
                  '${chapter.chapterNumber}',
                  style: AppTypography.metadata.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      chapter.titleEnglish.isEmpty
                          ? 'Chapter ${chapter.chapterNumber}'
                          : chapter.titleEnglish,
                      style: AppTypography.body.copyWith(
                        color: titleColour,
                        fontWeight:
                            widget.isCurrent ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (chapter.titleArabic.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        chapter.titleArabic,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.arabicTitle.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isCurrent)
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(start: AppSpacing.sm),
                  child: Icon(Icons.check, size: 18, color: colors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Moves the reader to the first hadith of the chapter.
  ///
  /// Browsing, not reading: nothing between here and there is marked, exactly
  /// as with the Previous and Next controls.
  Future<void> _open() async {
    setState(() => _opening = true);
    final NavigatorState navigator = Navigator.of(context);
    final HadithRepository repository = ref.read(hadithRepositoryProvider);

    final int? ordinal = await repository.firstOrdinalOfChapter(
      widget.chapter.collectionId,
      widget.chapter.chapterNumber,
    );
    // A chapter with no hadith stored against it stays put rather than
    // sending the reader somewhere arbitrary.
    if (ordinal == null) {
      if (mounted) setState(() => _opening = false);
      return;
    }

    await ref.read(todayControllerProvider.notifier).goTo(ordinal);
    navigator.pop();
  }
}
