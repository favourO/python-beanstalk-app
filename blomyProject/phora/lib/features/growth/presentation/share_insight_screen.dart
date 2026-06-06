import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/growth/data/growth_repository.dart';
import 'package:phora/features/growth/domain/growth_models.dart';
import 'package:phora/features/growth/growth_providers.dart';
import 'package:phora/features/growth/services/growth_analytics_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareInsightScreen extends ConsumerStatefulWidget {
  const ShareInsightScreen({super.key});

  @override
  ConsumerState<ShareInsightScreen> createState() => _ShareInsightScreenState();
}

class _ShareInsightScreenState extends ConsumerState<ShareInsightScreen> {
  final Set<String> _selectedSectionIds = <String>{};
  String? _selectedAudience;
  String? _selectedMethod;
  int? _selectedCycleCount;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(shareInsightConfigProvider);
    final shareInsightAsync = ref.watch(shareInsightProvider);
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF8),
      body: SafeArea(
        child: configAsync.when(
          data: (config) {
            final previewInsight = _previewInsight(shareInsightAsync);
            final selectedAudience =
                _selectedAudience ?? config.defaultAudience;
            final selectedMethod = _selectedMethod ?? config.defaultMethod;
            final selectedCycleCount =
                _selectedCycleCount ?? config.defaultCycleCount;
            final selectedSections =
                _selectedSectionIds.isEmpty
                    ? config.sections
                        .where((section) => section.selectedByDefault)
                        .map((section) => section.id)
                        .toSet()
                    : _selectedSectionIds;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                dims.scaleWidth(20),
                dims.scaleSpace(14),
                dims.scaleWidth(20),
                dims.scaleSpace(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    title: config.screenTitle,
                    subtitle: config.screenSubtitle,
                  ),
                  SizedBox(height: dims.scaleSpace(24)),
                  _HeroCard(title: config.heroTitle, body: config.heroBody),
                  SizedBox(height: dims.scaleSpace(18)),
                  _InsightPreviewCard(
                    insight: previewInsight,
                    helperText: switch (shareInsightAsync) {
                      AsyncData() => null,
                      AsyncLoading() => 'Preparing your latest cycle snapshot.',
                      AsyncError() =>
                        'Live preview unavailable right now. You can still generate and share.',
                      _ => null,
                    },
                  ),
                  SizedBox(height: dims.scaleSpace(28)),
                  _SectionLabel(label: 'What you can share'),
                  SizedBox(height: dims.scaleSpace(14)),
                  _SurfaceCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < config.sections.length; i++) ...[
                          _SelectableShareRow(
                            option: config.sections[i],
                            selected: selectedSections.contains(
                              config.sections[i].id,
                            ),
                            icon: _sectionIcon(config.sections[i].id),
                            onTap:
                                () => _toggleSection(
                                  config.sections[i].id,
                                  config.sections,
                                ),
                          ),
                          if (i != config.sections.length - 1)
                            const _DashedDivider(),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(22)),
                  _SectionLabel(label: 'Share with'),
                  SizedBox(height: dims.scaleSpace(14)),
                  _SurfaceCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < config.audiences.length; i++) ...[
                          _AudienceRow(
                            option: config.audiences[i],
                            selected:
                                selectedAudience == config.audiences[i].id,
                            icon: _audienceIcon(config.audiences[i].id),
                            onTap:
                                () => setState(
                                  () =>
                                      _selectedAudience =
                                          config.audiences[i].id,
                                ),
                          ),
                          if (i != config.audiences.length - 1)
                            const _DashedDivider(),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(22)),
                  _SectionLabel(label: 'Share method'),
                  SizedBox(height: dims.scaleSpace(14)),
                  Row(
                    children: [
                      for (var i = 0; i < config.methods.length; i++) ...[
                        Expanded(
                          child: _MethodCard(
                            option: config.methods[i],
                            selected: selectedMethod == config.methods[i].id,
                            icon: _methodIcon(config.methods[i].id),
                            onTap:
                                () => setState(
                                  () => _selectedMethod = config.methods[i].id,
                                ),
                          ),
                        ),
                        if (i != config.methods.length - 1)
                          SizedBox(width: dims.scaleWidth(12)),
                      ],
                    ],
                  ),
                  SizedBox(height: dims.scaleSpace(16)),
                  _IncludeBar(
                    label:
                        config.cycleCountOptions
                            .firstWhere(
                              (option) => option.value == selectedCycleCount,
                              orElse:
                                  () => ShareCycleCountOptionModel(
                                    value: selectedCycleCount,
                                    label:
                                        '$selectedCycleCount cycle${selectedCycleCount == 1 ? '' : 's'}',
                                  ),
                            )
                            .label,
                    onSelectCycles:
                        () => _showCycleCountPicker(
                          context,
                          config.cycleCountOptions,
                          selectedCycleCount,
                        ),
                    onCustomize:
                        () => _showCustomizeSheet(
                          context,
                          config,
                          selectedSections,
                          selectedCycleCount,
                        ),
                  ),
                  SizedBox(height: dims.scaleSpace(24)),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _submitting || selectedSections.isEmpty
                              ? null
                              : () => _generateAndShare(
                                sectionIds: selectedSections.toList(),
                                audience: selectedAudience,
                                method: selectedMethod,
                                cycleCount: selectedCycleCount,
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6C3E),
                        foregroundColor: Colors.white,
                        minimumSize: Size(
                          double.infinity,
                          dims.scaleHeight(60),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            dims.scaleRadius(999),
                          ),
                        ),
                      ),
                      icon: Icon(
                        Icons.lock_outline_rounded,
                        size: dims.scaleText(20),
                      ),
                      label: Text(
                        _submitting ? 'Generating...' : 'Generate & Share',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontSize: dims.scaleText(16),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(16)),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: dims.scaleText(18),
                          color:
                              isDark
                                  ? colors.textSecondary
                                  : const Color(0xFF8B817A),
                        ),
                        SizedBox(width: dims.scaleWidth(8)),
                        Flexible(
                          child: Text(
                            config.privacyNote,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color:
                                  isDark
                                      ? colors.textSecondary
                                      : const Color(0xFF8B817A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
                child: Padding(
                  padding: EdgeInsets.all(dims.scaleSpace(24)),
                  child: Text(error.toString(), textAlign: TextAlign.center),
                ),
              ),
        ),
      ),
    );
  }

  void _toggleSection(
    String sectionId,
    List<ShareSectionOptionModel> sections,
  ) {
    final fallbackSelection =
        sections
            .where((section) => section.selectedByDefault)
            .map((section) => section.id)
            .toSet();
    final nextSelection =
        _selectedSectionIds.isEmpty
            ? fallbackSelection
            : {..._selectedSectionIds};

    if (nextSelection.contains(sectionId)) {
      if (nextSelection.length == 1) {
        return;
      }
      nextSelection.remove(sectionId);
    } else {
      nextSelection.add(sectionId);
    }

    setState(() {
      _selectedSectionIds
        ..clear()
        ..addAll(nextSelection);
    });
  }

  Future<void> _generateAndShare({
    required List<String> sectionIds,
    required String audience,
    required String method,
    required int cycleCount,
  }) async {
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(growthRepositoryProvider)
          .generateShareInsight(
            sectionIds: sectionIds,
            audience: audience,
            method: method,
            cycleCount: cycleCount,
          );
      await ref
          .read(growthRepositoryProvider)
          .trackShareEvent(
            shareId: result.shareId,
            event: 'share_sheet_opened',
            channel: method,
            deepLinkId: _deepLinkId(result.secureLinkUrl),
          );
      await ref.read(growthAnalyticsServiceProvider).track(
        'share_sheet_opened',
        <String, Object?>{
          'share_id': result.shareId,
          'method': method,
          'audience': audience,
        },
      );

      switch (method) {
        case 'pdf_report':
          await _sharePdf(result);
          break;
        case 'email':
          await _shareEmail(result);
          break;
        case 'secure_link':
          await _shareSecureLink(result);
          break;
      }

      await ref
          .read(growthRepositoryProvider)
          .trackShareEvent(
            shareId: result.shareId,
            event: 'share_completed',
            channel: method,
            deepLinkId: _deepLinkId(result.secureLinkUrl),
          );
      await ref.read(growthAnalyticsServiceProvider).track(
        'share_completed',
        <String, Object?>{
          'share_id': result.shareId,
          'method': method,
          'audience': audience,
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _shareSecureLink(ShareGenerateResultModel result) {
    return SharePlus.instance.share(
      ShareParams(text: result.shareText, subject: result.title),
    );
  }

  Future<void> _sharePdf(ShareGenerateResultModel result) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${result.reportFileName}');
    final bytes = base64Decode(result.reportPdfBase64);
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        text: '${result.title}\n${result.subtitle}',
        subject: result.title,
        files: [XFile(file.path)],
      ),
    );
  }

  Future<void> _shareEmail(ShareGenerateResultModel result) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': result.emailSubject,
        'body': result.emailBody,
      },
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await SharePlus.instance.share(
        ShareParams(text: result.emailBody, subject: result.emailSubject),
      );
    }
  }

  Future<void> _showCycleCountPicker(
    BuildContext context,
    List<ShareCycleCountOptionModel> options,
    int selectedCycleCount,
  ) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _BottomSheetShell(
            title: 'Include past cycles',
            child: Column(
              children: [
                for (final option in options)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option.label),
                    trailing:
                        option.value == selectedCycleCount
                            ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFFFF6C3E),
                            )
                            : const SizedBox.shrink(),
                    onTap: () => Navigator.of(context).pop(option.value),
                  ),
              ],
            ),
          ),
    );
    if (chosen != null) {
      setState(() => _selectedCycleCount = chosen);
    }
  }

  Future<void> _showCustomizeSheet(
    BuildContext context,
    ShareInsightConfigModel config,
    Set<String> selectedSections,
    int selectedCycleCount,
  ) async {
    final nextSections = {...selectedSections};
    var nextCycleCount = selectedCycleCount;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => _BottomSheetShell(
                  title: 'Customize share',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sections',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      for (final section in config.sections)
                        CheckboxListTile(
                          value: nextSections.contains(section.id),
                          activeColor: const Color(0xFFFF6C3E),
                          contentPadding: EdgeInsets.zero,
                          title: Text(section.title),
                          subtitle: Text(section.subtitle),
                          onChanged: (selected) {
                            setSheetState(() {
                              if (selected == true) {
                                nextSections.add(section.id);
                              } else if (nextSections.length > 1) {
                                nextSections.remove(section.id);
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Cycles',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final option in config.cycleCountOptions)
                            ChoiceChip(
                              label: Text(option.label),
                              selected: nextCycleCount == option.value,
                              selectedColor: const Color(0xFFFFE3D8),
                              onSelected: (_) {
                                setSheetState(() {
                                  nextCycleCount = option.value;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedCycleCount = nextCycleCount;
                              _selectedSectionIds
                                ..clear()
                                ..addAll(nextSections);
                            });
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6C3E),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  String? _deepLinkId(String secureLinkUrl) {
    final uri = Uri.tryParse(secureLinkUrl);
    return uri?.queryParameters['dl'];
  }

  ShareInsightModel _previewInsight(AsyncValue<ShareInsightModel> asyncValue) {
    return asyncValue.maybeWhen(
      data:
          (insight) => _hasPreviewContent(insight) ? insight : _fallbackInsight,
      orElse: () => _fallbackInsight,
    );
  }

  bool _hasPreviewContent(ShareInsightModel insight) {
    return insight.title.trim().isNotEmpty ||
        insight.summary.trim().isNotEmpty ||
        insight.cards.isNotEmpty ||
        insight.tags.isNotEmpty;
  }

  ShareInsightModel get _fallbackInsight {
    return const ShareInsightModel(
      shareId: '',
      title: 'Your cycle snapshot',
      subtitle: 'A simple overview of your current cycle patterns',
      summary:
          'Preview the kind of summary you can share with your doctor or partner before generating the final report.',
      privacyNote: 'Only summary-level information is shown here.',
      deepLinkUrl: '',
      cards: [
        ShareInsightCardModel(
          title: 'Phase',
          value: 'Current cycle',
          subtitle: 'Predicted phase overview',
        ),
        ShareInsightCardModel(
          title: 'Trends',
          value: 'Recent patterns',
          subtitle: 'Cycle timing and symptom patterns',
        ),
        ShareInsightCardModel(
          title: 'Notes',
          value: 'Personal context',
          subtitle: 'Highlights from your logs',
        ),
      ],
      tags: ['Cycle summary', 'Symptoms', 'Trends'],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: isDark ? colors.bgElevated : const Color(0xFFFFEFE8),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: EdgeInsets.all(dims.scaleWidth(14)),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? colors.textPrimary : const Color(0xFF3E2219),
              ),
            ),
          ),
        ),
        SizedBox(width: dims.scaleWidth(16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.screenHeaderStyle(
                  context,
                  dims,
                  color: isDark ? colors.textPrimary : const Color(0xFF321711),
                )?.copyWith(fontSize: dims.scaleText(17)),
              ),
              SizedBox(height: dims.scaleSpace(8)),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      isDark ? colors.textSecondary : const Color(0xFF6D625D),fontSize: dims.scaleText(12)
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(18)),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF3D7CA),
        ),
        boxShadow:
            isDark
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x10FF9A6E),
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w600,
                    fontSize: dims.scaleText(12),
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF321711),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(12)),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF6D625D),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          const _HeroIllustration(),
        ],
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SizedBox(
      width: dims.scaleWidth(118),
      height: dims.scaleWidth(132),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 8,
            child: Transform.rotate(
              angle: -0.16,
              child: Container(
                width: dims.scaleWidth(96),
                height: dims.scaleWidth(120),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF4ED), Color(0xFFFFE2D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFFFFDFC9)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: dims.scaleWidth(44),
                      height: dims.scaleWidth(44),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Color(0xFFFFD7C7),
                            Color(0xFFFF8B5D),
                            Color(0xFFFFD7C7),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(12)),
                    for (final width in [56.0, 48.0, 40.0])
                      Padding(
                        padding: EdgeInsets.only(bottom: dims.scaleSpace(6)),
                        child: Container(
                          width: dims.scaleWidth(width),
                          height: dims.scaleSpace(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC2A8),
                            borderRadius: BorderRadius.circular(
                              dims.scaleRadius(999),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 6,
            bottom: 2,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0x33FF9A6E),
              size: 18,
            ),
          ),
          const Positioned(
            right: 6,
            top: 0,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0x26FF9A6E),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: dims.scaleText(11.5),
        letterSpacing: 2.0,
        fontWeight: FontWeight.w700,
        color: isDark ? colors.textTertiary : const Color(0xFF857872),
      ),
    );
  }
}

class _InsightPreviewCard extends StatelessWidget {
  const _InsightPreviewCard({required this.insight, this.helperText});

  final ShareInsightModel insight;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w600,
              color: isDark ? colors.textPrimary : const Color(0xFF321711),
            ),
          ),
          SizedBox(height: dims.scaleSpace(6)),
          Text(
            insight.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? colors.textSecondary : const Color(0xFF7A6A64),
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          Text(
            insight.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: isDark ? colors.textSecondary : const Color(0xFF6D625D),
            ),
          ),
          if (insight.cards.isNotEmpty) ...[
            SizedBox(height: dims.scaleSpace(16)),
            Wrap(
              spacing: dims.scaleWidth(10),
              runSpacing: dims.scaleSpace(10),
              children:
                  insight.cards.map((card) {
                    return _InsightMetricChip(card: card);
                  }).toList(),
            ),
          ],
          if (insight.tags.isNotEmpty) ...[
            SizedBox(height: dims.scaleSpace(14)),
            Wrap(
              spacing: dims.scaleWidth(8),
              runSpacing: dims.scaleSpace(8),
              children:
                  insight.tags.map((tag) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: dims.scaleWidth(12),
                        vertical: dims.scaleSpace(7),
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark ? colors.bgSurface : const Color(0xFFFFF2EA),
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(999),
                        ),
                        border: Border.all(
                          color:
                              isDark ? colors.border : const Color(0xFFF5DCCF),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              isDark
                                  ? colors.textSecondary
                                  : const Color(0xFF7A5F54),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
          SizedBox(height: dims.scaleSpace(12)),
          Text(
            insight.privacyNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? colors.textTertiary : const Color(0xFF9E8A82),
            ),
          ),
          if (helperText != null && helperText!.trim().isNotEmpty) ...[
            SizedBox(height: dims.scaleSpace(10)),
            Text(
              helperText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? colors.textSecondary : const Color(0xFF8C756B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightMetricChip extends StatelessWidget {
  const _InsightMetricChip({required this.card});

  final ShareInsightCardModel card;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: dims.scaleWidth(146),
      padding: EdgeInsets.all(dims.scaleWidth(12)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : const Color(0xFFFFFAF7),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF2E1D7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDark ? colors.textTertiary : const Color(0xFF947D72),
            ),
          ),
          SizedBox(height: dims.scaleSpace(6)),
          Text(
            card.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isDark ? colors.textPrimary : const Color(0xFF321711),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (card.subtitle != null && card.subtitle!.isNotEmpty) ...[
            SizedBox(height: dims.scaleSpace(4)),
            Text(
              card.subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? colors.textSecondary : const Color(0xFF7A6A64),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(16),
        vertical: dims.scaleSpace(8),
      ),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(dims.scaleRadius(26)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF3DCCE),
        ),
      ),
      child: child,
    );
  }
}

class _SelectableShareRow extends StatelessWidget {
  const _SelectableShareRow({
    required this.option,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final ShareSectionOptionModel option;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _LeadingCircle(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF726761),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _CheckOrb(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _AudienceRow extends StatelessWidget {
  const _AudienceRow({
    required this.option,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final ShareAudienceOptionModel option;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _LeadingCircle(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF726761),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RadioOrb(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.option,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final ShareMethodOptionModel option;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
      child: Container(
        padding: EdgeInsets.all(dims.scaleWidth(14)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
          border: Border.all(
            color: selected ? const Color(0xFFFF6C3E) : const Color(0xFFF0DDD2),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: 0, top: 0, child: _RadioOrb(selected: selected)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LeadingCircle(icon: icon),
                SizedBox(height: dims.scaleSpace(14)),
                Text(
                  option.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  option.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF726761),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncludeBar extends StatelessWidget {
  const _IncludeBar({
    required this.label,
    required this.onSelectCycles,
    required this.onCustomize,
  });

  final String label;
  final VoidCallback onSelectCycles;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(14),
        vertical: dims.scaleSpace(14),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),
      child: Row(
        children: [
          Text(
            'Include past',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(width: dims.scaleWidth(10)),
          InkWell(
            onTap: onSelectCycles,
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(12),
                vertical: dims.scaleSpace(8),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E8),
                borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFFFF6C3E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: dims.scaleWidth(4)),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFFF6C3E),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onCustomize,
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(4),
                vertical: dims.scaleSpace(4),
              ),
              child: Row(
                children: [
                  Text(
                    'Customize',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFFFF6C3E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFFF6C3E),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadingCircle extends StatelessWidget {
  const _LeadingCircle({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(50),
      height: dims.scaleWidth(50),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFF3EC),
      ),
      child: Icon(icon, color: const Color(0xFFFF6C3E)),
    );
  }
}

class _CheckOrb extends StatelessWidget {
  const _CheckOrb({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: dims.scaleWidth(30),
      height: dims.scaleWidth(30),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFF6C3E) : Colors.transparent,
        borderRadius: BorderRadius.circular(dims.scaleRadius(10)),
        border: Border.all(
          color: selected ? const Color(0xFFFF6C3E) : const Color(0xFFDCCFC7),
          width: 1.4,
        ),
      ),
      child:
          selected
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : null,
    );
  }
}

class _RadioOrb extends StatelessWidget {
  const _RadioOrb({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFFFF6C3E) : const Color(0xFFDCCFC7),
          width: 1.5,
        ),
      ),
      child:
          selected
              ? const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF6C3E),
                ),
              )
              : null,
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: Color(0xFFF3E1D7), height: 1);
  }
}

class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(14),
        0,
        dims.scaleWidth(14),
        dims.scaleSpace(14),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        ),
        child: Padding(
          padding: EdgeInsets.all(dims.scaleWidth(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: dims.scaleSpace(16)),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

IconData _sectionIcon(String id) {
  return switch (id) {
    'cycle_overview' => Icons.calendar_today_rounded,
    'period_details' => Icons.water_drop_outlined,
    'symptoms' => Icons.star_outline_rounded,
    'trends_insights' => Icons.show_chart_rounded,
    'notes' => Icons.edit_note_rounded,
    _ => Icons.checklist_rounded,
  };
}

IconData _audienceIcon(String id) {
  return switch (id) {
    'doctor' => Icons.health_and_safety_outlined,
    'partner' => Icons.people_outline_rounded,
    _ => Icons.person_outline_rounded,
  };
}

IconData _methodIcon(String id) {
  return switch (id) {
    'secure_link' => Icons.link_rounded,
    'pdf_report' => Icons.description_outlined,
    'email' => Icons.mail_outline_rounded,
    _ => Icons.send_outlined,
  };
}
