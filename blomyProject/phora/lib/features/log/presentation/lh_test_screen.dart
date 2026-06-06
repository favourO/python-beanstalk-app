import 'dart:io';

import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/i18n/formatters.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/design_tokens.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/utils/image_upload_preparer.dart';
import 'package:phora/features/cycle/data/cycle_repository.dart';
import 'package:phora/features/log/presentation/log_ui.dart';
import 'package:phora/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class LhTestScreen extends ConsumerStatefulWidget {
  const LhTestScreen({super.key});

  @override
  ConsumerState<LhTestScreen> createState() => _LhTestScreenState();
}

final lhHistoryProvider = FutureProvider.autoDispose<LhLogHistoryResponse>((
  ref,
) {
  return ref
      .watch(cycleRepositoryProvider)
      .fetchLhHistory(limit: 20, offset: 0);
});

class _LhTestScreenState extends ConsumerState<LhTestScreen> {
  String? _selectedResult;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageUploadPreparer _imageUploadPreparer = ImageUploadPreparer();
  XFile? _selectedImage;
  bool _isSaving = false;
  String? _analysisMessage;
  String? _analysisState;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 30);

  Future<void> _refreshLhHistory() async {
    final refresh = ref.refresh(lhHistoryProvider.future);
    await refresh;
  }

  Future<void> _openEntryEditor(_LhEntryMode mode) async {
    if (mode == _LhEntryMode.manual) {
      await _showManualEntryDialog();
      return;
    }
    await _showImageEntryDialog();
  }

  void _showPickerUnavailableMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.logLhPickerUnavailableMessage)),
    );
  }

  Future<void> _showEntryMethodPicker() async {
    final colors = context.phora.colors;
    final dims = context.dims;
    final l10n = context.l10n;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(20),
              dims.scaleSpace(12),
              dims.scaleWidth(20),
              dims.scaleSpace(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: dims.scaleWidth(42),
                    height: dims.scaleHeight(5),
                    decoration: BoxDecoration(
                      color: colors.borderStrong,
                      borderRadius: BorderRadius.circular(
                        dims.scaleRadius(999),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                Text(
                  l10n.logLhChooseEntryMethodTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: dims.scaleText(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(16)),
                Row(
                  children: [
                    Expanded(
                      child: _LhModeTile(
                        label: l10n.logLhImageAnalysisLabel,
                        subtitle: l10n.logLhUploadStripPhotoSubtitle,
                        icon: Icons.camera_alt_rounded,
                        selected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          _openEntryEditor(_LhEntryMode.image);
                        },
                      ),
                    ),
                    SizedBox(width: dims.scaleWidth(12)),
                    Expanded(
                      child: _LhModeTile(
                        label: l10n.logLhManualEntryLabel,
                        subtitle: l10n.logLhSelectResultSubtitle,
                        icon: Icons.edit_note_rounded,
                        selected: false,
                        onTap: () {
                          Navigator.of(context).pop();
                          _openEntryEditor(_LhEntryMode.manual);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showManualEntryDialog() async {
    final colors = context.phora.colors;
    final gradients = context.phora.gradients;
    final dims = context.dims;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    _selectedResult = null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.7,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(16),
                    dims.scaleSpace(12),
                    dims.scaleWidth(16),
                    dims.scaleSpace(16),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: dims.scaleWidth(42),
                            height: dims.scaleHeight(5),
                            decoration: BoxDecoration(
                              color: colors.borderStrong,
                              borderRadius: BorderRadius.circular(
                                dims.scaleRadius(999),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(18)),
                        _LhManualEditorFragment(
                          selectedResult: _selectedResult,
                          selectedTime: _selectedTime,
                          isSaving: _isSaving,
                          gradients: gradients.primary,
                          onSelectResult: (value) {
                            setState(() => _selectedResult = value);
                            setModalState(() {});
                          },
                          onEditTime: () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (selected == null) return;
                            setState(() => _selectedTime = selected);
                            setModalState(() {});
                          },
                          onSave: () async {
                            setState(() => _isSaving = true);
                            setModalState(() {});
                            try {
                              if (_selectedResult == null) {
                                throw l10n.logLhSelectManualResultMessage;
                              }
                              final repository = ref.read(
                                cycleRepositoryProvider,
                              );
                              final now = DateTime.now();
                              final logDate = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                              await repository.logLh(
                                logDate: logDate,
                                testTime: _apiTime(_selectedTime),
                                state: _apiStateFromLabel(_selectedResult!),
                              );
                              if (!mounted) return;
                              await _refreshLhHistory();
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              messenger.showSnackBar(
                                SnackBar(content: Text(l10n.logLhSaved)),
                              );
                              setState(() => _selectedResult = null);
                            } catch (error) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _saveFailureMessage(l10n, error),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                                setModalState(() {});
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showImageEntryDialog() async {
    final colors = context.phora.colors;
    final gradients = context.phora.gradients;
    final dims = context.dims;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    _selectedImage = null;
    _analysisMessage = null;
    _analysisState = null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickImageForDialog(ImageSource source) async {
              try {
                final image = await _imagePicker.pickImage(
                  source: source,
                  imageQuality: 90,
                  maxWidth: 2200,
                );
                if (image == null) return;
                setState(() {
                  _selectedImage = image;
                  _analysisMessage = null;
                  _analysisState = null;
                });
                setModalState(() {});
              } on PlatformException catch (_) {
                if (!mounted) return;
                _showPickerUnavailableMessage();
              } on MissingPluginException {
                if (!mounted) return;
                _showPickerUnavailableMessage();
              }
            }

            Future<void> showImageSourcePickerForDialog() async {
              await showModalBottomSheet<void>(
                context: context,
                backgroundColor: colors.bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(dims.scaleRadius(28)),
                  ),
                ),
                builder: (context) {
                  return SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        dims.scaleWidth(20),
                        dims.scaleSpace(12),
                        dims.scaleWidth(20),
                        dims.scaleSpace(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: dims.scaleWidth(42),
                              height: dims.scaleHeight(5),
                              decoration: BoxDecoration(
                                color: colors.borderStrong,
                                borderRadius: BorderRadius.circular(
                                  dims.scaleRadius(999),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          Text(
                            l10n.logImageSourceTitle,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontSize: dims.scaleText(18),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(16)),
                          _ImageSourceOption(
                            icon: Icons.camera_alt_rounded,
                            label: l10n.logTakePhotoLabel,
                            onTap: () {
                              Navigator.of(context).pop();
                              pickImageForDialog(ImageSource.camera);
                            },
                          ),
                          SizedBox(height: dims.scaleSpace(10)),
                          _ImageSourceOption(
                            icon: Icons.photo_library_rounded,
                            label: l10n.logUploadFromLibraryLabel,
                            onTap: () {
                              Navigator.of(context).pop();
                              pickImageForDialog(ImageSource.gallery);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return FractionallySizedBox(
              heightFactor: 0.7,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(16),
                    dims.scaleSpace(12),
                    dims.scaleWidth(16),
                    dims.scaleSpace(16),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: dims.scaleWidth(42),
                            height: dims.scaleHeight(5),
                            decoration: BoxDecoration(
                              color: colors.borderStrong,
                              borderRadius: BorderRadius.circular(
                                dims.scaleRadius(999),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(18)),
                        _LhImageEntryFragment(
                          selectedImagePath: _selectedImage?.path,
                          analysisMessage: _analysisMessage,
                          analysisState: _analysisState,
                          onTapImagePicker: showImageSourcePickerForDialog,
                        ),
                        SizedBox(height: dims.scaleSpace(18)),
                        _LhTimeCard(
                          selectedTime: _selectedTime,
                          onEditTime: () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (selected == null) return;
                            setState(() => _selectedTime = selected);
                            setModalState(() {});
                          },
                        ),
                        SizedBox(height: dims.scaleSpace(26)),
                        _LhSaveButton(
                          isSaving: _isSaving,
                          gradients: gradients.primary,
                          onTap: () async {
                            setState(() => _isSaving = true);
                            setModalState(() {});
                            try {
                              if (_selectedImage == null) {
                                throw l10n.logLhUploadStripMessage;
                              }
                              final repository = ref.read(
                                cycleRepositoryProvider,
                              );
                              final now = DateTime.now();
                              final logDate = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                              PreparedUploadImage? preparedImage;
                              try {
                                preparedImage = await _imageUploadPreparer
                                    .prepareForUpload(_selectedImage!.path);
                                final result = await repository.logLhImage(
                                  logDate: logDate,
                                  testTime: _apiTime(_selectedTime),
                                  imagePath: preparedImage.path,
                                );
                                if (result.status == 'ok' &&
                                    result.stripValid) {
                                  if (!mounted) return;
                                  await _refreshLhHistory();
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).pop();
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(l10n.logLhSaved)),
                                  );
                                  setState(() {
                                    _selectedResult = _labelFromApiState(
                                      result.state,
                                    );
                                    _selectedImage = null;
                                    _analysisMessage = null;
                                    _analysisState = null;
                                  });
                                  await _deletePreparedImage(preparedImage);
                                  return;
                                }

                                setState(() {
                                  _analysisState = result.state;
                                  _analysisMessage =
                                      result.explanation ??
                                      l10n.logLhUnreadableStripMessage;
                                });
                                setModalState(() {});
                                await _deletePreparedImage(preparedImage);
                                return;
                              } on ApiFailure catch (error) {
                                setState(() {
                                  _analysisState = 'invalid_strip';
                                  _analysisMessage = _imageFailureMessage(
                                    l10n,
                                    error,
                                  );
                                });
                                setModalState(() {});
                                return;
                              }
                            } catch (error) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _saveFailureMessage(l10n, error),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                                setModalState(() {});
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final historyAsync = ref.watch(lhHistoryProvider);
    final l10n = context.l10n;

    return LogPageScaffold(
      header: LogPageHeader(
        title: l10n.logSectionLhTestTitle,
        trailing: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
          onTap: _showEntryMethodPicker,
          child: Container(
            width: dims.scaleWidth(48),
            height: dims.scaleWidth(48),
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
              border: Border.all(color: colors.border),
            ),
            child: Icon(
              Icons.add_rounded,
              color: colors.textPrimary,
              size: dims.scaleText(22),
            ),
          ),
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: dims.scaleSpace(8)),
              _LhSectionCard(
                title: l10n.logLhHistoryLogsTitle,
                child: historyAsync.when(
                  loading:
                      () => PhoraLoadingView(
                        message: l10n.logLhLoadingHistoryMessage,
                        size: 56,
                      ),
                  error:
                      (error, _) => Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  data: (history) {
                    if (history.items.isEmpty) {
                      return Text(
                        l10n.logLhEmptyHistoryMessage,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < history.items.length; i++) ...[
                          _LhHistoryTile(item: history.items[i]),
                          if (i < history.items.length - 1)
                            SizedBox(height: dims.scaleSpace(12)),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deletePreparedImage(PreparedUploadImage? preparedImage) async {
    if (preparedImage == null || !preparedImage.isTemporary) {
      return;
    }
    try {
      await File(preparedImage.path).delete();
    } catch (_) {}
  }
}

enum _LhEntryMode { image, manual }

class _ImageSourceOption extends StatelessWidget {
  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(18),
            vertical: dims.scaleSpace(16),
          ),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.textPrimary, size: dims.scaleText(20)),
              SizedBox(width: dims.scaleWidth(12)),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LhModeTile extends StatelessWidget {
  const _LhModeTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(14),
            vertical: dims.scaleSpace(16),
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF7ECFF) : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(
              color: selected ? const Color(0xFFAE7FC3) : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFFAE7FC3) : colors.textPrimary,
                size: dims.scaleText(22),
              ),
              SizedBox(height: dims.scaleSpace(12)),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(15),
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: dims.scaleSpace(6)),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: dims.scaleText(12),
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LhHistoryTile extends StatelessWidget {
  const _LhHistoryTile({required this.item});

  final LhLogHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final l10n = context.l10n;
    final stateLabel = _historyStateLabel(l10n, item.state);
    final logDateLabel = _historyDateLabel(context, item.logDate);
    final sourceLabel =
        item.source == 'image_analysis'
            ? l10n.logLhImageAnalysisSourceLabel
            : l10n.logLhManualSourceLabel;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(color: colors.accentPrimary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: colors.accentPrimary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: dims.scaleWidth(4),
                height: dims.scaleHeight(42),
                decoration: BoxDecoration(
                  color: _historyAccentColor(colors, item.state),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Text(
                  '$stateLabel • $logDateLabel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(15),
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(10),
                  vertical: dims.scaleSpace(6),
                ),
                decoration: BoxDecoration(
                  color: _historyAccentColor(
                    colors,
                    item.state,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
                child: Text(
                  sourceLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: dims.scaleText(11),
                    fontWeight: FontWeight.w700,
                    color: _historyAccentColor(colors, item.state),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            _historySubtitle(context, item),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: dims.scaleText(13),
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          if ((item.explanation ?? '').isNotEmpty) ...[
            SizedBox(height: dims.scaleSpace(8)),
            Text(
              item.explanation!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(12),
                color: colors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LhImageEntryFragment extends StatelessWidget {
  const _LhImageEntryFragment({
    required this.selectedImagePath,
    required this.analysisMessage,
    required this.analysisState,
    required this.onTapImagePicker,
  });

  final String? selectedImagePath;
  final String? analysisMessage;
  final String? analysisState;
  final VoidCallback onTapImagePicker;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final l10n = context.l10n;

    return Column(
      children: [
        _LhSectionCard(
          title: l10n.logLhUploadStripPhotoTitle,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
                    onTap: onTapImagePicker,
                    child: Ink(
                      padding: EdgeInsets.symmetric(
                        horizontal: dims.scaleWidth(20),
                        vertical: dims.scaleSpace(24),
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(20),
                        ),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          if (selectedImagePath != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                dims.scaleRadius(16),
                              ),
                              child: Image.file(
                                File(selectedImagePath!),
                                height: dims.scaleHeight(180),
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(18)),
                          ] else ...[
                            Text(
                              '📷',
                              style: TextStyle(fontSize: dims.scaleText(42)),
                            ),
                            SizedBox(height: dims.scaleSpace(18)),
                          ],
                          Text(
                            selectedImagePath == null
                                ? l10n.logLhTakePhotoOrUploadLabel
                                : l10n.logLhReplaceSelectedPhotoLabel,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontSize: dims.scaleText(16),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(8)),
                          Text(
                            selectedImagePath == null
                                ? l10n.logLhAiWillAnalyzeLabel
                                : l10n.logLhImageReadyLabel,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontSize: dims.scaleText(14),
                              color: colors.textSecondary,
                            ),
                          ),
                          if (analysisMessage != null) ...[
                            SizedBox(height: dims.scaleSpace(12)),
                            Text(
                              analysisMessage!,
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                fontSize: dims.scaleText(13),
                                color:
                                    (analysisState == 'invalid_strip' ||
                                            analysisState == 'unreadable')
                                        ? colors.accentDanger
                                        : colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: dims.scaleSpace(16)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(16),
                  vertical: dims.scaleSpace(14),
                ),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                ),
                child: Text(
                  l10n.logLhImageTipMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: dims.scaleText(14),
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LhManualEditorFragment extends StatelessWidget {
  const _LhManualEditorFragment({
    required this.selectedResult,
    required this.selectedTime,
    required this.isSaving,
    required this.gradients,
    required this.onSelectResult,
    required this.onEditTime,
    required this.onSave,
  });

  final String? selectedResult;
  final TimeOfDay selectedTime;
  final bool isSaving;
  final List<Color> gradients;
  final ValueChanged<String> onSelectResult;
  final VoidCallback onEditTime;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final l10n = context.l10n;

    return Column(
      key: key,
      children: [
        _LhSectionCard(
          title: l10n.logLhManualEntryLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: dims.scaleWidth(12),
                mainAxisSpacing: dims.scaleSpace(12),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.16,
                children: [
                  _LhResultTile(
                    label: l10n.logDailyLhNegativeLabel,
                    visual: '−',
                    subtitle: l10n.logLhNegativeSubtitle,
                    selected: selectedResult == 'Negative',
                    onTap: () => onSelectResult('Negative'),
                  ),
                  _LhResultTile(
                    label: l10n.logScaleLowLabel,
                    visual: '〰️',
                    subtitle: l10n.logLhLowSubtitle,
                    selected: selectedResult == 'Low',
                    onTap: () => onSelectResult('Low'),
                  ),
                  _LhResultTile(
                    label: l10n.logScaleHighLabel,
                    visual: '+',
                    subtitle: l10n.logLhHighSubtitle,
                    selected: selectedResult == 'High',
                    activeColor: const Color(0xFF65CAE8),
                    onTap: () => onSelectResult('High'),
                  ),
                  _LhResultTile(
                    label: l10n.logDailyLhPeakLabel,
                    visual: '🔥',
                    subtitle: l10n.logLhPeakSubtitle,
                    selected: selectedResult == 'Peak',
                    onTap: () => onSelectResult('Peak'),
                  ),
                ],
              ),
              SizedBox(height: dims.scaleSpace(24)),
              _LhTimeCard(selectedTime: selectedTime, onEditTime: onEditTime),
              SizedBox(height: dims.scaleSpace(26)),
              _LhSaveButton(
                isSaving: isSaving,
                gradients: gradients,
                onTap: onSave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LhTimeCard extends StatelessWidget {
  const _LhTimeCard({required this.selectedTime, required this.onEditTime});

  final TimeOfDay selectedTime;
  final VoidCallback onEditTime;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final l10n = context.l10n;

    return _LhSectionCard(
      title: l10n.logLhTestTimeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: dims.scaleWidth(18),
              vertical: dims.scaleSpace(18),
            ),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              _displayTime(context, selectedTime),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: dims.scaleText(18),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          Text(
            l10n.logLhBestTestedHint,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: dims.scaleText(14),
              color: colors.textTertiary,
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          TextButton(
            onPressed: onEditTime,
            child: Text(l10n.logLhEditTimeLabel),
          ),
        ],
      ),
    );
  }
}

class _LhSaveButton extends StatelessWidget {
  const _LhSaveButton({
    required this.isSaving,
    required this.gradients,
    required this.onTap,
  });

  final bool isSaving;
  final List<Color> gradients;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradients),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
          onTap: isSaving ? null : onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(18)),
            child: Center(
              child: Text(
                isSaving ? l10n.savingLabel : l10n.logLhSaveButtonLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(16),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _apiTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _displayTime(BuildContext context, TimeOfDay time) {
  final dateTime = DateTime(2000, 1, 1, time.hour, time.minute);
  return AppFormatters.formatTime(
    dateTime,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

String _apiStateFromLabel(String label) {
  return switch (label.trim().toLowerCase()) {
    'negative' => 'negative',
    'low' => 'low',
    'high' => 'high',
    'peak' => 'peak',
    _ => 'negative',
  };
}

String? _labelFromApiState(String state) {
  return switch (state.trim().toLowerCase()) {
    'negative' => 'Negative',
    'low' => 'Low',
    'high' => 'High',
    'peak' => 'Peak',
    _ => null,
  };
}

String _imageFailureMessage(AppLocalizations l10n, ApiFailure error) {
  final message = error.message.toLowerCase();
  if (message.contains('not found')) {
    return l10n.logLhImageAnalysisUnavailableMessage;
  }
  if (message.contains('unavailable') || message.contains('502')) {
    return l10n.logLhStripAnalysisUnavailableMessage;
  }
  return error.message;
}

String _saveFailureMessage(AppLocalizations l10n, Object error) {
  if (error is ApiFailure) {
    return error.message;
  }
  return error.toString();
}

String _historyStateLabel(AppLocalizations l10n, String? state) {
  return switch (state?.trim().toLowerCase()) {
    'negative' => l10n.logDailyLhNegativeLabel,
    'low' => l10n.logScaleLowLabel,
    'high' => l10n.logScaleHighLabel,
    'peak' => l10n.logDailyLhPeakLabel,
    'invalid_strip' => l10n.logLhInvalidStripLabel,
    'unreadable' => l10n.logLhUnreadableLabel,
    _ => l10n.logLhUnknownLabel,
  };
}

String _historySubtitle(BuildContext context, LhLogHistoryItem item) {
  final l10n = context.l10n;
  final parts = <String>[
    if ((item.testTime ?? '').isNotEmpty)
      _displayApiTime(context, item.testTime!),
    if (item.cycleDay != null) l10n.logLhCycleDayLabel(item.cycleDay!),
    if (item.ratio != null)
      l10n.logLhRatioLabel(item.ratio!.toStringAsFixed(2)),
    item.positive ? l10n.logLhPositiveLabel : l10n.logDailyLhNegativeLabel,
  ];
  return parts.join(' • ');
}

String _historyDateLabel(BuildContext context, String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  return AppFormatters.formatDateMedium(
    parsed,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

Color _historyAccentColor(AppColors colors, String? state) {
  return switch (state?.trim().toLowerCase()) {
    'peak' => colors.accentPrimary,
    'high' => colors.accentInfo,
    'low' => colors.phaseFollicular,
    'negative' => colors.textTertiary,
    'invalid_strip' || 'unreadable' => colors.accentDanger,
    _ => colors.accentPrimary,
  };
}

String _displayApiTime(BuildContext context, String value) {
  final parts = value.split(':');
  if (parts.length < 2) {
    return value;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return value;
  }
  return _displayTime(context, TimeOfDay(hour: hour, minute: minute));
}

class _LhSectionCard extends StatelessWidget {
  const _LhSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(20)),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: dims.scaleText(18),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          child,
        ],
      ),
    );
  }
}

class _LhResultTile extends StatelessWidget {
  const _LhResultTile({
    required this.label,
    required this.visual,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final String visual;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final selectedColor = activeColor ?? const Color(0xFFDF577E);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(10),
            vertical: dims.scaleSpace(14),
          ),
          decoration: BoxDecoration(
            color: selected ? selectedColor : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(color: selected ? selectedColor : colors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                visual,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: dims.scaleText(28),
                  fontWeight: FontWeight.w800,
                  color:
                      selected && visual == '+'
                          ? const Color(0xFF374151)
                          : null,
                ),
              ),
              SizedBox(height: dims.scaleSpace(8)),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(15),
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : colors.textPrimary,
                ),
              ),
              SizedBox(height: dims.scaleSpace(6)),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(12),
                  color:
                      selected
                          ? Colors.white.withValues(alpha: 0.84)
                          : colors.textTertiary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
