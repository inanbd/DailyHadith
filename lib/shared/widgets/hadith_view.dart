import 'package:flutter/material.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/hadith.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Renders one hadith as a page of a book.
///
/// Arabic is shown first and always laid out right-to-left, regardless of the
/// app's own direction. Text is passed through untouched — this widget only
/// decides how it looks, never what it says.
class HadithView extends StatelessWidget {
  const HadithView({
    required this.hadith,
    required this.languageMode,
    required this.textScale,
    this.showReference = true,
    super.key,
  });

  final Hadith hadith;
  final LanguageMode languageMode;

  /// The reader's text-size preference. Platform dynamic type is applied on top
  /// of this by the framework, so both settings compose.
  final double textScale;

  final bool showReference;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    final bool wantsArabic = languageMode.showsArabic && hadith.hasArabic;
    final bool wantsEnglish = languageMode.showsEnglish && hadith.hasEnglish;

    // If the reader's chosen language is missing for this entry, fall back to
    // whatever the source does have rather than showing an empty page.
    final bool showArabic = wantsArabic || (!wantsEnglish && hadith.hasArabic);
    final bool showEnglish = wantsEnglish || (!wantsArabic && hadith.hasEnglish);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showArabic) _ArabicText(text: hadith.arabicText!, scale: textScale),
        if (showArabic && showEnglish)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: HadithDivider(),
          ),
        if (showEnglish)
          _EnglishText(text: hadith.englishText!, scale: textScale),
        if (!showArabic && !showEnglish)
          Text(
            'This entry has no text in the selected language.',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        if (hadith.narrator != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            hadith.narrator!,
            style: AppTypography.reference.copyWith(
              color: colors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (showReference) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          _ReferenceBlock(hadith: hadith),
        ],
      ],
    );
  }
}

/// A hairline rule with a small warm centre mark — the one decorative flourish
/// in the app, standing in for the divider between text and translation.
class HadithDivider extends StatelessWidget {
  const HadithDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: colors.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: colors.warm,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.border, height: 1)),
        ],
      ),
    );
  }
}

class _ArabicText extends StatelessWidget {
  const _ArabicText({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Directionality(
      // Arabic is laid out right-to-left even when the app itself is not.
      textDirection: TextDirection.rtl,
      // `locale` drives font and glyph selection for this run. Flutter does
      // not currently expose a per-node screen-reader language, so the reader's
      // system voice setting decides how the Arabic is spoken.
      child: Text(
        text,
        textAlign: TextAlign.right,
        locale: const Locale('ar'),
        style: AppTypography.arabicBody.copyWith(
          color: colors.textPrimary,
          fontSize: AppTypography.arabicBody.fontSize! * scale,
        ),
      ),
    );
  }
}

class _EnglishText extends StatelessWidget {
  const _EnglishText({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Text(
      text,
      locale: const Locale('en'),
      style: AppTypography.englishBody.copyWith(
        color: colors.textPrimary,
        fontSize: AppTypography.englishBody.fontSize! * scale,
      ),
    );
  }
}

/// Citation, chapter and grading — everything needed to trace the text back to
/// its source.
class _ReferenceBlock extends StatelessWidget {
  const _ReferenceBlock({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextStyle labelStyle = AppTypography.overline.copyWith(
      color: colors.textSecondary,
    );
    final TextStyle valueStyle = AppTypography.reference.copyWith(
      color: colors.textPrimary,
    );

    final List<Widget> rows = <Widget>[];

    if (hadith.reference != null) {
      rows.add(Text(hadith.reference!, style: valueStyle));
    }
    if (hadith.chapterEnglish != null) {
      rows.add(
        Text(
          'Chapter: ${hadith.chapterEnglish}',
          style: AppTypography.reference.copyWith(color: colors.textSecondary),
        ),
      );
    }
    if (hadith.grade != null) {
      rows.add(
        Text(
          'Grading: ${hadith.grade}',
          style: AppTypography.reference.copyWith(color: colors.textSecondary),
        ),
      );
    }
    if (hadith.source != null) {
      rows.add(
        Text(
          'Source: ${hadith.source}',
          style: AppTypography.reference.copyWith(color: colors.textSecondary),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Divider(color: colors.border, height: 1),
        const SizedBox(height: AppSpacing.lg),
        Text('REFERENCE', style: labelStyle),
        const SizedBox(height: AppSpacing.sm),
        for (final Widget row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: row,
          ),
      ],
    );
  }
}
