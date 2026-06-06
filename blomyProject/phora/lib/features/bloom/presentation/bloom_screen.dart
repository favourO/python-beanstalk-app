import 'dart:math' as math;

import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/features/bloom/data/ai_chat_repository.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class BloomScreen extends ConsumerStatefulWidget {
  const BloomScreen({super.key});

  @override
  ConsumerState<BloomScreen> createState() => _BloomScreenState();
}

class _BloomScreenState extends ConsumerState<BloomScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  final DraggableScrollableController _historyController =
      DraggableScrollableController();
  bool? _hasAiConsent;
  bool _isSending = false;
  bool _isUploadingDocument = false;
  String? _streamingText;
  _DocumentUploadPhase _documentUploadPhase = _DocumentUploadPhase.idle;
  PlatformFile? _pendingDocument;
  bool _isLoadingHistory = false;
  bool _isLoadingThreads = false;
  bool _isLoadingOlderMessages = false;
  bool _hasMoreMessages = false;
  bool _historyPanelVisible = false;
  String? _olderMessagesCursor;
  String? _threadId;
  final List<_BloomMessage> _messages = [];
  final List<String> _savedRecords = [];
  List<AiChatThreadSummary> _threads = const [];
  List<AiMissingDataPrompt> _missingData = const [];
  double _historyPanelExtent = _HistoryPanelSheet.minSize;
  bool _isComposerFocused = false;
  bool _medicalNoticeExpanded = true;
  bool _dataNoticeExpanded = true;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _composerFocusNode.addListener(_handleComposerFocusChange);
    _chatScrollController.addListener(_handleChatScroll);
    _bootstrapChat();
  }

  @override
  void dispose() {
    _composerFocusNode
      ..removeListener(_handleComposerFocusChange)
      ..dispose();
    _chatScrollController.removeListener(_handleChatScroll);
    _chatScrollController.dispose();
    _questionController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  void _handleComposerFocusChange() {
    if (!mounted) return;
    setState(() {
      _isComposerFocused = _composerFocusNode.hasFocus;
    });
    if (_composerFocusNode.hasFocus) {
      _scrollToLatest();
    }
  }

  void _dismissComposer() {
    _composerFocusNode.unfocus();
  }

  void _handleChatScroll() {
    if (!_chatScrollController.hasClients ||
        _isLoadingOlderMessages ||
        !_hasMoreMessages ||
        _isLoadingHistory ||
        _threadId == null) {
      return;
    }
    if (_chatScrollController.position.pixels <= 80) {
      _loadOlderMessages();
    }
  }

  void _scrollToLatest({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      final target = _chatScrollController.position.maxScrollExtent;
      if (animated) {
        _chatScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _chatScrollController.jumpTo(target);
      }
    });
  }

  Future<void> _bootstrapChat() async {
    final preferences = ref.read(appPreferencesProvider);
    final cachedConsent = await preferences.getAllowPhoraAiChat();
    if (!mounted) return;
    setState(() => _hasAiConsent = cachedConsent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadConsent(refreshOnly: true);
      if (cachedConsent) {
        _loadLatestThread();
        _loadThreads();
      }
    });
  }

  Future<void> _loadConsent({bool refreshOnly = false}) async {
    final preferences = ref.read(appPreferencesProvider);
    try {
      final status =
          await ref.read(aiChatRepositoryProvider).fetchConsentStatus();
      await preferences.setAllowPhoraAiChat(status.accepted);
      if (!mounted) return;
      final previousConsent = _hasAiConsent == true;
      if (_hasAiConsent != status.accepted) {
        setState(() => _hasAiConsent = status.accepted);
      }
      if (status.accepted && !previousConsent && refreshOnly) {
        _loadLatestThread();
        _loadThreads();
      } else if (status.accepted && !refreshOnly) {
        await _loadThreadData();
      }
    } catch (_) {
      if (refreshOnly) return;
      final hasConsent = await preferences.getAllowPhoraAiChat();
      if (!mounted) return;
      setState(() => _hasAiConsent = hasConsent);
      if (hasConsent) {
        await _loadThreadData();
      }
    }
  }

  Future<void> _acceptAiConsent() async {
    await ref
        .read(aiChatRepositoryProvider)
        .updateConsentStatus(accepted: true);
    await ref.read(appPreferencesProvider).setAllowPhoraAiChat(true);
    if (!mounted) return;
    setState(() => _hasAiConsent = true);
    await _loadThreadData();
  }

  Future<void> _loadThreadData() async {
    await Future.wait([_loadThreads(), _loadLatestThread()]);
  }

  Future<void> _loadThreads() async {
    if (_isLoadingThreads) return;
    if (mounted && _threads.isNotEmpty) {
      setState(() => _isLoadingThreads = true);
    } else {
      _isLoadingThreads = true;
    }
    try {
      final threads = await ref.read(aiChatRepositoryProvider).fetchThreads();
      if (!mounted) return;
      setState(() => _threads = threads);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isLoadingThreads = false);
      } else {
        _isLoadingThreads = false;
      }
    }
  }

  Future<void> _loadLatestThread() async {
    if (_isLoadingHistory) return;
    if (mounted && _messages.isNotEmpty) {
      setState(() => _isLoadingHistory = true);
    } else {
      _isLoadingHistory = true;
    }
    try {
      final history =
          await ref.read(aiChatRepositoryProvider).fetchLatestThread();
      if (!mounted) return;
      setState(() {
        _threadId = history.threadId;
        _hasMoreMessages = history.hasMore;
        _olderMessagesCursor = history.nextBefore;
        _messages
          ..clear()
          ..addAll(
            history.messages.map((item) {
              return item.role == 'assistant'
                  ? _BloomMessage.assistant(item.content)
                  : _BloomMessage.user(item.content);
            }),
          );
      });
      _scrollToLatest(animated: false);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      } else {
        _isLoadingHistory = false;
      }
    }
  }

  Future<void> _loadThread(String threadId) async {
    if (_isLoadingHistory) return;
    setState(() => _isLoadingHistory = true);
    try {
      final history = await ref
          .read(aiChatRepositoryProvider)
          .fetchThread(threadId);
      if (!mounted) return;
      setState(() {
        _threadId = history.threadId;
        _hasMoreMessages = history.hasMore;
        _olderMessagesCursor = history.nextBefore;
        _savedRecords.clear();
        _missingData = const [];
        _messages
          ..clear()
          ..addAll(
            history.messages.map((item) {
              return item.role == 'assistant'
                  ? _BloomMessage.assistant(item.content)
                  : _BloomMessage.user(item.content);
            }),
          );
      });
      _scrollToLatest(animated: false);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiFailure ? error.message : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    final threadId = _threadId;
    final cursor = _olderMessagesCursor;
    if (threadId == null ||
        cursor == null ||
        _isLoadingOlderMessages ||
        !_hasMoreMessages) {
      return;
    }
    final previousMaxExtent =
        _chatScrollController.hasClients
            ? _chatScrollController.position.maxScrollExtent
            : 0.0;
    setState(() => _isLoadingOlderMessages = true);
    try {
      final history = await ref
          .read(aiChatRepositoryProvider)
          .fetchThread(threadId, before: cursor);
      if (!mounted) return;
      setState(() {
        _hasMoreMessages = history.hasMore;
        _olderMessagesCursor = history.nextBefore;
        _messages.insertAll(
          0,
          history.messages.map((item) {
            return item.role == 'assistant'
                ? _BloomMessage.assistant(item.content)
                : _BloomMessage.user(item.content);
          }),
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_chatScrollController.hasClients) return;
        final newMaxExtent = _chatScrollController.position.maxScrollExtent;
        final offsetDelta = newMaxExtent - previousMaxExtent;
        _chatScrollController.jumpTo(
          (_chatScrollController.position.pixels + offsetDelta).clamp(
            0.0,
            _chatScrollController.position.maxScrollExtent,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isLoadingOlderMessages = false);
      }
    }
  }

  void _startNewChat() {
    setState(() {
      _threadId = null;
      _messages.clear();
      _savedRecords.clear();
      _missingData = const [];
      _pendingDocument = null;
      _hasMoreMessages = false;
      _olderMessagesCursor = null;
    });
  }

  Future<void> _sendMessage([String? seededMessage]) async {
    if (_isSending || _isUploadingDocument) return;
    final message = (seededMessage ?? _questionController.text).trim();
    if (_pendingDocument != null && seededMessage == null) {
      if (message.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ask a question about this document.')),
        );
        _composerFocusNode.requestFocus();
        return;
      }
      await _sendPendingMedicalDocument(message);
      return;
    }
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
      _streamingText = '';
      _messages.add(_BloomMessage.user(message));
      _questionController.clear();
      _missingData = const [];
    });
    _scrollToLatest();

    try {
      await for (final event in ref
          .read(aiChatRepositoryProvider)
          .sendMessageStream(threadId: _threadId, message: message)) {
        if (!mounted) return;
        switch (event) {
          case AiChatStreamStart(:final threadId):
            setState(() {
              if (threadId.isNotEmpty) _threadId = threadId;
            });
          case AiChatStreamDelta(:final text):
            setState(() => _streamingText = (_streamingText ?? '') + text);
            _scrollToLatest();
          case AiChatStreamDone(
            :final sufficientData,
            :final missingData,
            :final savedRecords,
            :final disclaimer,
          ):
            setState(() {
              _messages.add(_BloomMessage.assistant(
                _streamingText ?? '',
                disclaimer: disclaimer,
                sufficientData: sufficientData,
              ));
              _streamingText = null;
              _savedRecords
                ..clear()
                ..addAll(savedRecords);
              _missingData = missingData;
            });
            _scrollToLatest();
            await _loadThreads();
          case AiChatStreamError(:final message):
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
            setState(() {
              if (_messages.isNotEmpty && _messages.last.isUser) {
                _messages.removeLast();
              }
              _streamingText = null;
            });
        }
      }
    } catch (error) {
      if (!mounted) return;
      final errorMessage =
          error is ApiFailure ? error.message : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isUser) {
          _messages.removeLast();
        }
        _streamingText = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _streamingText = null;
        });
      }
    }
  }

  Future<void> _showAttachmentMenu() async {
    if (_isSending || _isUploadingDocument) return;
    final selected = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AttachmentActionSheet(),
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case _AttachmentAction.takePhoto:
        await _pickMedicalPhoto(ImageSource.camera);
      case _AttachmentAction.choosePhotos:
        await _pickMedicalPhoto(ImageSource.gallery);
      case _AttachmentAction.attachFiles:
        await _pickMedicalDocument();
    }
  }

  Future<void> _pickMedicalPhoto(ImageSource source) async {
    if (_isSending || _isUploadingDocument) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
      );
      if (image == null || image.path.isEmpty) return;
      final size = await image.length();
      setState(() {
        _pendingDocument = PlatformFile(
          name: image.name,
          path: image.path,
          size: size,
        );
      });
      _composerFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiFailure ? error.message : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickMedicalDocument() async {
    if (_isSending || _isUploadingDocument) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'webp',
          'heic',
          'heif',
          'xlsx',
          'xls',
          'csv',
          'txt',
        ],
      );
      final file = result?.files.single;
      final path = file?.path;
      if (file == null || path == null || path.isEmpty) return;

      setState(() {
        _pendingDocument = file;
      });
      _composerFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiFailure ? error.message : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _clearPendingDocument() {
    if (_isUploadingDocument) return;
    setState(() {
      _pendingDocument = null;
    });
  }

  Future<void> _sendPendingMedicalDocument(String question) async {
    if (_isSending || _isUploadingDocument) return;
    final file = _pendingDocument;
    final path = file?.path;
    if (file == null || path == null || path.isEmpty) return;

    try {
      setState(() {
        _isUploadingDocument = true;
        _documentUploadPhase = _DocumentUploadPhase.uploading;
        _pendingDocument = null;
        _messages.add(
          _BloomMessage.user(
            question,
            attachmentName: file.name,
            attachmentMeta: _formatFileSize(file.size),
          ),
        );
        _questionController.clear();
        _missingData = const [];
      });
      _scrollToLatest();

      final response = await ref
          .read(aiChatRepositoryProvider)
          .analyzeDocument(
            filePath: path,
            filename: file.name,
            threadId: _threadId,
            question: question,
            onUploadProgress: (sent, total) {
              if (!mounted || total <= 0 || sent < total) return;
              setState(() {
                _documentUploadPhase = _DocumentUploadPhase.thinking;
              });
              _scrollToLatest();
            },
          );
      if (!mounted) return;
      setState(() {
        _threadId =
            response.threadId.isNotEmpty ? response.threadId : _threadId;
        _messages.add(
          _BloomMessage.assistant(
            response.answer,
            disclaimer: response.disclaimer,
            sufficientData: response.sufficientData,
          ),
        );
        _savedRecords
          ..clear()
          ..addAll(response.savedRecords);
        _missingData = response.missingData;
      });
      _scrollToLatest();
      await _loadThreads();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiFailure ? error.message : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isUser) {
          _messages.removeLast();
        }
        _pendingDocument = file;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDocument = false;
          _documentUploadPhase = _DocumentUploadPhase.idle;
        });
      }
    }
  }

  AiChatThreadSummary? get _activeThread {
    final threadId = _threadId;
    if (threadId == null || threadId.isEmpty) {
      return null;
    }
    for (final thread in _threads) {
      if (thread.threadId == threadId) {
        return thread;
      }
    }
    return null;
  }

  Future<void> _showHistorySheet() async {
    await _loadThreads();
    if (!mounted) return;
    setState(() => _historyPanelVisible = true);
    await WidgetsBinding.instance.endOfFrame;
    final target =
        _historyPanelExtent < _HistoryPanelSheet.halfSize + 0.04
            ? _HistoryPanelSheet.halfSize
            : _HistoryPanelSheet.maxSize;
    await _animateHistoryPanel(target);
  }

  Future<void> _animateHistoryPanel(double size) async {
    if (!_historyController.isAttached) return;
    await _historyController.animateTo(
      size,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleHistoryExtentChanged(double extent) {
    if (!mounted) return;
    final isVisible = extent > _HistoryPanelSheet.minSize + 0.01;
    if (_historyPanelExtent == extent && _historyPanelVisible == isVisible) {
      return;
    }
    setState(() {
      _historyPanelExtent = extent;
      _historyPanelVisible = isVisible;
    });
  }

  Future<void> _handleHistorySelection(String selection) async {
    if (selection == '__new__') {
      _startNewChat();
      await _animateHistoryPanel(_HistoryPanelSheet.halfSize);
      return;
    }
    await _loadThread(selection);
    if (!mounted) return;
    await _animateHistoryPanel(_HistoryPanelSheet.minSize);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.phora.colors;
    final dims = context.dims;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final noticeBackground =
        isLight ? const Color(0xFFFFF7F1) : const Color(0xFF1B1B20);
    final noticeBorder =
        isLight ? const Color(0xFFF1DECF) : const Color(0xFF2B2C35);
    final noticeTitleColor = isLight ? colors.textPrimary : Colors.white;
    final noticeBodyColor =
        isLight ? colors.textSecondary : Colors.white.withValues(alpha: 0.72);
    final hasAiConsent = _hasAiConsent ?? false;
    final isLoadingConsent = _hasAiConsent == null;
    final hasMessages = _messages.isNotEmpty;
    final showIntroHints = !hasMessages;
    final activeThread = _activeThread;
    final suggestions = [
      l10n.bloomSuggestionCycleLong,
      l10n.bloomSuggestionLhTesting,
      l10n.bloomSuggestionEggWhiteMucus,
    ];

    return Scaffold(
      backgroundColor: isLight ? _kBloomSurface : colors.bg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissComposer,
          child: Stack(
            children: [
              if (isLight) const _BloomBackdrop(),
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(20),
                      dims.scaleSpace(12),
                      dims.scaleWidth(20),
                      0,
                    ),
                    child: _BloomTopBar(
                      hasAiConsent: hasAiConsent,
                      activeThreadTitle:
                          activeThread?.title?.trim().isNotEmpty == true
                              ? activeThread!.title!.trim()
                              : (_threadId == null
                                  ? 'New conversation'
                                  : 'Current conversation'),
                      historyExpanded:
                          _historyPanelExtent >= _HistoryPanelSheet.halfSize,
                      onHistoryTap: hasAiConsent ? _showHistorySheet : null,
                      onNewChat: hasAiConsent ? _startNewChat : null,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _chatScrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        dims.scaleWidth(20),
                        dims.scaleSpace(18),
                        dims.scaleWidth(20),
                        dims.scaleSpace(220),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showIntroHints) ...[
                            _CollapsibleNoticeCard(
                              title: 'Not medical advice',
                              body: _kBloomPredictionDisclaimer,
                              icon: Icons.health_and_safety_outlined,
                              expanded: _medicalNoticeExpanded,
                              onToggle:
                                  () => setState(
                                    () =>
                                        _medicalNoticeExpanded =
                                            !_medicalNoticeExpanded,
                                  ),
                            ),
                            SizedBox(height: dims.scaleSpace(12)),
                            _CollapsibleNoticeCard(
                              title:
                                  hasAiConsent
                                      ? l10n.bloomDataUsageNoticeTitle
                                      : l10n.bloomConsentTitle,
                              body:
                                  hasAiConsent
                                      ? l10n.bloomDataUsageNoticeBody
                                      : l10n.bloomConsentBody,
                              expanded: _dataNoticeExpanded,
                              background: noticeBackground,
                              borderColor: noticeBorder,
                              titleColor: noticeTitleColor,
                              bodyColor: noticeBodyColor,
                              onToggle:
                                  () => setState(
                                    () =>
                                        _dataNoticeExpanded =
                                            !_dataNoticeExpanded,
                                  ),
                              child:
                                  !hasAiConsent
                                      ? _PrimaryActionButton(
                                        label: l10n.acceptLabel,
                                        onTap:
                                            isLoadingConsent
                                                ? null
                                                : _acceptAiConsent,
                                      )
                                      : null,
                            ),
                          ],
                          if (hasAiConsent) ...[
                            if (showIntroHints) ...[
                              SizedBox(height: dims.scaleSpace(16)),
                              _ProfileStyleSection(
                                title: l10n.bloomSuggestedQuestionsTitle,
                                child: Column(
                                  children: [
                                    ...suggestions.map(
                                      (label) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom: dims.scaleSpace(12),
                                        ),
                                        child: _SuggestionTile(
                                          label: label,
                                          onTap: () => _sendMessage(label),
                                        ),
                                      ),
                                    ),
                                    _StatusCopy(
                                      label: l10n.bloomConversationHelper,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_messages.isNotEmpty) ...[
                              if (showIntroHints)
                                SizedBox(height: dims.scaleSpace(16)),
                              Column(
                                children: [
                                  if (_isLoadingOlderMessages)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        bottom: dims.scaleSpace(12),
                                      ),
                                      child: const _StatusCopy(
                                        label: 'Loading earlier messages...',
                                      ),
                                    ),
                                  ..._messages.map(
                                    (message) => Padding(
                                      padding: EdgeInsets.only(
                                        bottom: dims.scaleSpace(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _ChatBubbleCard(
                                            text: message.text,
                                            isUser: message.isUser,
                                            compact: message.isCompact,
                                            attachmentName:
                                                message.attachmentName,
                                            attachmentMeta:
                                                message.attachmentMeta,
                                          ),
                                          if (!message.isUser &&
                                              (message.disclaimer?.isNotEmpty ??
                                                  false))
                                            const _ChatCaption(
                                              label:
                                                  _kBloomPredictionDisclaimer,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_isSending || _isUploadingDocument)
                                    _isUploadingDocument
                                        ? _ChatBubbleCard(
                                          text: _documentUploadPhase.label,
                                          compact: true,
                                        )
                                        : (_streamingText != null &&
                                                _streamingText!.isNotEmpty
                                            ? _ChatBubbleCard(
                                              text: _streamingText!,
                                              isUser: false,
                                            )
                                            : const _ThinkingBubble(
                                              compact: true,
                                            )),
                                ],
                              ),
                            ],
                            if (_missingData.isNotEmpty) ...[
                              SizedBox(height: dims.scaleSpace(16)),
                              _ProfileStyleSection(
                                title: 'Missing data',
                                child: Column(
                                  children:
                                      _missingData
                                          .map(
                                            (item) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom: dims.scaleSpace(12),
                                              ),
                                              child: _MissingDataCard(
                                                prompt: item,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _BloomComposer(
                  enabled: hasAiConsent,
                  isSending: _isSending || _isUploadingDocument,
                  controller: _questionController,
                  focusNode: _composerFocusNode,
                  showDismissAction: _isComposerFocused,
                  onDismiss: _dismissComposer,
                  onSend: () => _sendMessage(),
                  onAttachDocument: _showAttachmentMenu,
                  pendingDocumentName: _pendingDocument?.name,
                  pendingDocumentMeta:
                      _pendingDocument == null
                          ? null
                          : _formatFileSize(_pendingDocument!.size),
                  onClearPendingDocument: _clearPendingDocument,
                ),
              ),
              if (hasAiConsent &&
                  (_historyPanelVisible ||
                      _historyPanelExtent > _HistoryPanelSheet.minSize))
                _HistoryPanelSheet(
                  controller: _historyController,
                  visible: _historyPanelVisible,
                  threads: _threads,
                  activeThreadId: _threadId,
                  isLoading: _isLoadingThreads,
                  extent: _historyPanelExtent,
                  onExtentChanged: _handleHistoryExtentChanged,
                  onSelect: _handleHistorySelection,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const Color _kBloomAccent = Color(0xFFFF7A45);
const Color _kBloomAccentSoft = Color(0xFFFFF1E9);
const Color _kBloomAccentBorder = Color(0xFFF1DDD1);
const Color _kBloomSurface = Color(0xFFFFFBF8);
const Color _kBloomTextPrimary = Color(0xFF2F1C14);
const Color _kBloomTextSecondary = Color(0xFF7F6357);
const Color _kBloomTextMuted = Color(0xFF9B8478);
const String _kBloomPredictionDisclaimer =
    'Vyla is a prediction application not a medical device';

enum _DocumentUploadPhase {
  idle,
  uploading,
  thinking;

  String get label {
    return switch (this) {
      _DocumentUploadPhase.uploading => 'Uploading...',
      _DocumentUploadPhase.thinking => 'Thinking...',
      _DocumentUploadPhase.idle => 'Thinking...',
    };
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) return '';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(bytes >= 10 * mb ? 0 : 1)} MB';
  }
  return '${(bytes / kb).ceil()} KB';
}

class _BloomBackdrop extends StatelessWidget {
  const _BloomBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -30,
            left: -44,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1FFFAE8C), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 160,
            right: -26,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x16FF8A4C), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          const Positioned(
            right: 22,
            top: 86,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0x18FF8A4C),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _BloomTopBar extends StatelessWidget {
  const _BloomTopBar({
    required this.hasAiConsent,
    required this.activeThreadTitle,
    required this.historyExpanded,
    this.onHistoryTap,
    this.onNewChat,
  });

  final bool hasAiConsent;
  final String activeThreadTitle;
  final bool historyExpanded;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vyla AI ✨',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: dims.scaleText(32),
                      height: 1,
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w500,
                      color: isDark ? colors.textPrimary : _kBloomTextPrimary,
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(6)),
                  Text(
                    'Your cycle companion',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: dims.scaleText(13),
                      height: 1.35,
                      color:
                          isDark ? colors.textSecondary : _kBloomTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _HistoryPillButton(expanded: historyExpanded, onTap: onHistoryTap),
          ],
        ),
        if (hasAiConsent) ...[
          SizedBox(height: dims.scaleSpace(14)),
          Row(
            children: [
              Expanded(child: _ActiveThreadChip(label: activeThreadTitle)),
              SizedBox(width: dims.scaleWidth(10)),
              _InlineTextAction(label: 'New chat', onTap: onNewChat),
            ],
          ),
        ],
      ],
    );
  }
}

class _CollapsibleNoticeCard extends StatelessWidget {
  const _CollapsibleNoticeCard({
    required this.title,
    required this.body,
    required this.expanded,
    required this.onToggle,
    this.icon,
    this.background,
    this.borderColor,
    this.titleColor,
    this.bodyColor,
    this.child,
  });

  final String title;
  final String body;
  final bool expanded;
  final VoidCallback onToggle;
  final IconData? icon;
  final Color? background;
  final Color? borderColor;
  final Color? titleColor;
  final Color? bodyColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(14),
        dims.scaleWidth(14),
        dims.scaleSpace(14),
      ),
      decoration: BoxDecoration(
        color:
            background ??
            (isDark ? Colors.white.withValues(alpha: 0.04) : _kBloomSurface),
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        border: Border.all(
          color:
              borderColor ??
              (isDark ? const Color(0x33FFFFFF) : const Color(0xFFF1DECF)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            onTap: onToggle,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: dims.scaleText(18), color: _kBloomAccent),
                  SizedBox(width: dims.scaleWidth(10)),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: dims.scaleText(14),
                      fontWeight: FontWeight.w700,
                      color:
                          titleColor ??
                          (isDark ? colors.textPrimary : _kBloomTextPrimary),
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: dims.scaleText(22),
                  color: isDark ? colors.textSecondary : _kBloomTextMuted,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: EdgeInsets.only(top: dims.scaleSpace(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: dims.scaleText(12),
                      height: 1.45,
                      color:
                          bodyColor ??
                          (isDark ? Colors.white70 : _kBloomTextSecondary),
                    ),
                  ),
                  if (child != null) ...[
                    SizedBox(height: dims.scaleSpace(14)),
                    child!,
                  ],
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kBloomAccent, Color(0xFFFF9B78)],
        ),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(14)),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(14),
                  fontWeight: FontWeight.w700,
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

class _ProfileStyleSection extends StatelessWidget {
  const _ProfileStyleSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(14),
        dims.scaleWidth(16),
        dims.scaleSpace(16),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: dims.scaleText(11),
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textTertiary : const Color(0xFF8F766A),
            ),
          ),
          SizedBox(height: dims.scaleSpace(10)),
          child,
        ],
      ),
    );
  }
}

class _StatusCopy extends StatelessWidget {
  const _StatusCopy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Padding(
      padding: EdgeInsets.only(top: dims.scaleSpace(4)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: dims.scaleText(12),
          height: 1.4,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _HistoryPillButton extends StatelessWidget {
  const _HistoryPillButton({required this.expanded, this.onTap});

  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? colors.bgSurface : Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(14),
            vertical: dims.scaleSpace(12),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(
              color: isDark ? colors.border : const Color(0xFFF0E1D7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: dims.scaleText(18),
                color: isDark ? colors.textPrimary : _kBloomTextPrimary,
              ),
              SizedBox(width: dims.scaleWidth(8)),
              Text(
                'History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? colors.textPrimary : _kBloomTextPrimary,
                ),
              ),
              SizedBox(width: dims.scaleWidth(6)),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                size: dims.scaleText(18),
                color: isDark ? colors.textSecondary : _kBloomTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveThreadChip extends StatelessWidget {
  const _ActiveThreadChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(12),
        vertical: dims.scaleSpace(10),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : _kBloomAccentSoft,
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: dims.scaleText(16),
            color: isDark ? colors.textSecondary : _kBloomTextSecondary,
          ),
          SizedBox(width: dims.scaleWidth(8)),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(12),
                fontWeight: FontWeight.w600,
                color: isDark ? colors.textPrimary : _kBloomTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineTextAction extends StatelessWidget {
  const _InlineTextAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: _kBloomAccent,
        padding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(10),
          vertical: dims.scaleSpace(10),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: dims.scaleText(13),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(14),
            vertical: dims.scaleSpace(12),
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.bgSurface : Colors.white,
            borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
            border: Border.all(
              color: isDark ? colors.border : const Color(0xFFF2E6DE),
            ),
          ),
          child: Row(
            children: [
              const _HistoryLeadingIcon(icon: Icons.auto_awesome_rounded),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(14),
                    fontWeight: FontWeight.w700,
                    color: isDark ? colors.textPrimary : _kBloomTextPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: dims.scaleText(20),
                color: isDark ? colors.textTertiary : _kBloomTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble({this.compact = false});
  final bool compact;

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(18),
          vertical: dims.scaleSpace(widget.compact ? 12 : 14),
        ),
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Thinking',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(13),
                height: 1.45,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: dims.scaleWidth(3)),
            for (int i = 0; i < 3; i++)
              _AnimatedDot(
                controller: _controller,
                delay: i * 0.22,
                color: colors.textSecondary,
                size: dims.scaleText(5),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  const _AnimatedDot({
    required this.controller,
    required this.delay,
    required this.color,
    required this.size,
  });

  final AnimationController controller;
  final double delay;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value - delay) % 1.0;
        final bounce = t < 0.45 ? math.sin(math.pi * t / 0.45) : 0.0;
        return Transform.translate(
          offset: Offset(0, -bounce * 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.45 + 0.55 * bounce),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatBubbleCard extends StatelessWidget {
  const _ChatBubbleCard({
    required this.text,
    this.isUser = false,
    this.compact = false,
    this.attachmentName,
    this.attachmentMeta,
  });

  final String text;
  final bool isUser;
  final bool compact;
  final String? attachmentName;
  final String? attachmentMeta;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final displayText = _cleanChatText(text);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: dims.scaleWidth(isUser ? 270 : 320),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(18),
          vertical: dims.scaleSpace(compact ? 12 : 14),
        ),
        decoration: BoxDecoration(
          color: isUser ? _kBloomAccent : colors.bgCard,
          borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
          border: Border.all(color: isUser ? _kBloomAccent : colors.border),
          boxShadow:
              isUser
                  ? const [
                    BoxShadow(
                      color: Color(0x10FF9B78),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((attachmentName ?? '').isNotEmpty) ...[
              _DocumentPreviewPill(
                name: attachmentName!,
                meta: attachmentMeta,
                isInUserBubble: isUser,
              ),
              if (displayText.isNotEmpty) SizedBox(height: dims.scaleSpace(10)),
            ],
            if (displayText.isNotEmpty)
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    height: 1.45,
                    color: isUser ? Colors.white : colors.textPrimary,
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                  ),
                  children: _chatTextSpans(displayText),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _cleanChatText(String value) {
  return value
      .replaceAll('\\n', '\n')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

List<TextSpan> _chatTextSpans(String value) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  var cursor = 0;
  for (final match in pattern.allMatches(value)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: value.substring(cursor, match.start)));
    }
    final boldText = match.group(1) ?? '';
    if (boldText.isNotEmpty) {
      spans.add(
        TextSpan(
          text: boldText,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    cursor = match.end;
  }
  if (cursor < value.length) {
    spans.add(TextSpan(text: value.substring(cursor)));
  }
  return spans.isEmpty ? [TextSpan(text: value)] : spans;
}

enum _AttachmentAction { takePhoto, attachFiles, choosePhotos }

class _AttachmentActionSheet extends StatelessWidget {
  const _AttachmentActionSheet();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(top: dims.scaleSpace(48)),
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(12),
        dims.scaleWidth(20),
        dims.scaleSpace(24),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dims.scaleWidth(42),
            height: dims.scaleHeight(4),
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          _AttachmentActionTile(
            icon: Icons.photo_camera_outlined,
            title: 'Take photo',
            onTap: () => Navigator.of(context).pop(_AttachmentAction.takePhoto),
          ),
          _AttachmentActionTile(
            icon: Icons.attach_file_rounded,
            title: 'Attach files',
            onTap:
                () => Navigator.of(context).pop(_AttachmentAction.attachFiles),
          ),
          _AttachmentActionTile(
            icon: Icons.photo_library_outlined,
            title: 'Choose photos',
            onTap:
                () => Navigator.of(context).pop(_AttachmentAction.choosePhotos),
          ),
        ],
      ),
    );
  }
}

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(12)),
          child: Row(
            children: [
              Container(
                width: dims.scaleWidth(40),
                height: dims.scaleWidth(40),
                decoration: BoxDecoration(
                  color: _kBloomAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
                child: Icon(
                  icon,
                  color: _kBloomAccent,
                  size: dims.scaleText(20),
                ),
              ),
              SizedBox(width: dims.scaleWidth(14)),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(15),
                    fontWeight: FontWeight.w700,
                    color: isDark ? colors.textPrimary : _kBloomTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatCaption extends StatelessWidget {
  const _ChatCaption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(8)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: dims.scaleText(12),
          color: colors.textQuaternary,
        ),
      ),
    );
  }
}

class _MissingDataCard extends StatelessWidget {
  const _MissingDataCard({required this.prompt});

  final AiMissingDataPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(18)),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.prompt,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(14),
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            prompt.reason,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(12),
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          SizedBox(height: dims.scaleSpace(10)),
          Text(
            prompt.endpoint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(12),
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingDocumentPreview extends StatelessWidget {
  const _PendingDocumentPreview({
    required this.name,
    required this.meta,
    required this.enabled,
    required this.onRemove,
  });

  final String name;
  final String? meta;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(12),
        vertical: dims.scaleSpace(10),
      ),
      decoration: BoxDecoration(
        color: _kBloomAccentSoft,
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(color: _kBloomAccentBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_rounded,
            size: dims.scaleText(18),
            color: _kBloomAccent,
          ),
          SizedBox(width: dims.scaleWidth(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    fontWeight: FontWeight.w700,
                    color: _kBloomTextPrimary,
                  ),
                ),
                if ((meta ?? '').isNotEmpty)
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: dims.scaleText(11),
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Remove document',
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _DocumentPreviewPill extends StatelessWidget {
  const _DocumentPreviewPill({
    required this.name,
    required this.meta,
    required this.isInUserBubble,
  });

  final String name;
  final String? meta;
  final bool isInUserBubble;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final textColor = isInUserBubble ? Colors.white : colors.textPrimary;
    final mutedColor =
        isInUserBubble
            ? Colors.white.withValues(alpha: 0.78)
            : colors.textSecondary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(10),
        vertical: dims.scaleSpace(8),
      ),
      decoration: BoxDecoration(
        color:
            isInUserBubble
                ? Colors.white.withValues(alpha: 0.16)
                : _kBloomAccentSoft,
        borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
        border: Border.all(
          color:
              isInUserBubble
                  ? Colors.white.withValues(alpha: 0.24)
                  : _kBloomAccentBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_rounded,
            size: dims.scaleText(16),
            color: isInUserBubble ? Colors.white : _kBloomAccent,
          ),
          SizedBox(width: dims.scaleWidth(8)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(12),
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if ((meta ?? '').isNotEmpty)
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: dims.scaleText(10),
                      color: mutedColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BloomComposer extends StatelessWidget {
  const _BloomComposer({
    required this.enabled,
    required this.isSending,
    required this.controller,
    required this.focusNode,
    required this.showDismissAction,
    required this.onDismiss,
    required this.onSend,
    required this.onAttachDocument,
    this.pendingDocumentName,
    this.pendingDocumentMeta,
    required this.onClearPendingDocument,
  });

  final bool enabled;
  final bool isSending;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showDismissAction;
  final VoidCallback onDismiss;
  final VoidCallback onSend;
  final VoidCallback onAttachDocument;
  final String? pendingDocumentName;
  final String? pendingDocumentMeta;
  final VoidCallback onClearPendingDocument;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        0,
        dims.scaleWidth(16),
        dims.scaleSpace(14),
      ),
      padding: EdgeInsets.all(dims.scaleWidth(8)),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
        boxShadow:
            isDark
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x12C78862),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((pendingDocumentName ?? '').isNotEmpty) ...[
            _PendingDocumentPreview(
              name: pendingDocumentName!,
              meta: pendingDocumentMeta,
              enabled: enabled && !isSending,
              onRemove: onClearPendingDocument,
            ),
            SizedBox(height: dims.scaleSpace(8)),
          ],
          Row(
            children: [
              IconButton(
                onPressed: enabled && !isSending ? onAttachDocument : null,
                icon: const Icon(Icons.attach_file_rounded),
                tooltip: 'Attach medical document',
                color: _kBloomAccent,
              ),
              SizedBox(width: dims.scaleWidth(4)),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(14),
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        enabled
                            ? ((pendingDocumentName ?? '').isNotEmpty
                                ? 'Ask about this document'
                                : context.l10n.bloomAskQuestionHint)
                            : context.l10n.bloomConsentRequiredHint,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: dims.scaleText(14),
                      color: colors.textTertiary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                  ),
                  textInputAction: TextInputAction.newline,
                ),
              ),
              if (showDismissAction) ...[
                SizedBox(width: dims.scaleWidth(6)),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.keyboard_hide_rounded),
                  tooltip: 'Hide keyboard',
                  color: colors.textSecondary,
                ),
              ],
              SizedBox(width: dims.scaleWidth(10)),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kBloomAccent, Color(0xFFFF9B78)],
                  ),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                    onTap: enabled && !isSending ? onSend : null,
                    child: Padding(
                      padding: EdgeInsets.all(dims.scaleWidth(12)),
                      child: Icon(
                        Icons.send_rounded,
                        size: dims.scaleText(20),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryPanelSheet extends StatelessWidget {
  const _HistoryPanelSheet({
    required this.controller,
    required this.visible,
    required this.threads,
    required this.activeThreadId,
    required this.isLoading,
    required this.extent,
    required this.onExtentChanged,
    required this.onSelect,
  });

  static const double minSize = 0.0;
  static const double halfSize = 0.42;
  static const double maxSize = 0.92;

  final DraggableScrollableController controller;
  final bool visible;
  final List<AiChatThreadSummary> threads;
  final String? activeThreadId;
  final bool isLoading;
  final double extent;
  final ValueChanged<double> onExtentChanged;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        onExtentChanged(notification.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        controller: controller,
        initialChildSize: minSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        snap: true,
        snapSizes: const [halfSize, maxSize],
        builder: (context, scrollController) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: visible || extent > minSize ? 1 : 0.98,
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDark
                        ? colors.bgElevated
                        : _kBloomSurface.withValues(alpha: 0.98),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(dims.scaleRadius(30)),
                ),
                border: Border.all(
                  color: isDark ? colors.border : const Color(0xFFF0E1D7),
                ),
                boxShadow:
                    isDark
                        ? null
                        : const [
                          BoxShadow(
                            color: Color(0x12C78862),
                            blurRadius: 32,
                            offset: Offset(0, -8),
                          ),
                        ],
              ),
              child: Column(
                children: [
                  SizedBox(height: dims.scaleSpace(10)),
                  Container(
                    width: dims.scaleWidth(56),
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? colors.borderStrong
                              : const Color(0xFFD4D0CD),
                      borderRadius: BorderRadius.circular(
                        dims.scaleRadius(999),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              dims.scaleWidth(16),
                              dims.scaleSpace(16),
                              dims.scaleWidth(16),
                              dims.scaleSpace(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Recent chats',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.copyWith(
                                          fontSize: dims.scaleText(18),
                                          fontWeight: FontWeight.w700,
                                          color:
                                              isDark
                                                  ? colors.textPrimary
                                                  : _kBloomTextPrimary,
                                        ),
                                      ),
                                      SizedBox(height: dims.scaleSpace(4)),
                                      Text(
                                        extent >= maxSize - 0.02
                                            ? 'Full history view'
                                            : 'Pull up for full history',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          fontSize: dims.scaleText(12),
                                          color:
                                              isDark
                                                  ? colors.textSecondary
                                                  : _kBloomTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _InlineTextAction(
                                  label: 'New chat',
                                  onTap: () => onSelect('__new__'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isLoading)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (threads.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(dims.scaleWidth(24)),
                                child: Text(
                                  'No previous conversations yet.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    fontSize: dims.scaleText(13),
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              dims.scaleWidth(16),
                              0,
                              dims.scaleWidth(16),
                              dims.scaleSpace(28),
                            ),
                            sliver: SliverList.separated(
                              itemCount: threads.length,
                              separatorBuilder:
                                  (_, _) =>
                                      SizedBox(height: dims.scaleSpace(12)),
                              itemBuilder: (context, index) {
                                final thread = threads[index];
                                return _HistoryThreadTile(
                                  thread: thread,
                                  index: index,
                                  active: thread.threadId == activeThreadId,
                                  onTap: () => onSelect(thread.threadId),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryThreadTile extends StatelessWidget {
  const _HistoryThreadTile({
    required this.thread,
    required this.index,
    required this.active,
    required this.onTap,
  });

  final AiChatThreadSummary thread;
  final int index;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(14),
            vertical: dims.scaleSpace(14),
          ),
          decoration: BoxDecoration(
            color:
                active
                    ? _kBloomAccentSoft
                    : (isDark ? colors.bgSurface : Colors.white),
            borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
            border: Border.all(
              color:
                  active
                      ? _kBloomAccentBorder
                      : (isDark ? colors.border : const Color(0xFFF2E6DE)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HistoryLeadingIcon(
                icon: Icons.chat_bubble_outline_rounded,
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.title?.trim().isNotEmpty == true
                          ? thread.title!.trim()
                          : 'Conversation ${index + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(14),
                        fontWeight: FontWeight.w700,
                        color: isDark ? colors.textPrimary : _kBloomTextPrimary,
                      ),
                    ),
                    if ((thread.preview ?? '').isNotEmpty) ...[
                      SizedBox(height: dims.scaleSpace(3)),
                      Text(
                        thread.preview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: dims.scaleText(12),
                          height: 1.35,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    SizedBox(height: dims.scaleSpace(6)),
                    Text(
                      _historyMeta(thread),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(12),
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(10)),
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: dims.scaleText(20),
                color:
                    active
                        ? _kBloomAccent
                        : (isDark ? colors.textTertiary : _kBloomTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _historyMeta(AiChatThreadSummary thread) {
    final updated = _compactDate(thread.updatedAt);
    if (updated == null) {
      return '${thread.messageCount} messages';
    }
    return '${thread.messageCount} messages • $updated';
  }

  String? _compactDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) {
      return null;
    }
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) {
      return null;
    }
    final month = switch (date.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      12 => 'Dec',
      _ => '',
    };
    return '$month ${date.day}, ${date.year}';
  }
}

class _HistoryLeadingIcon extends StatelessWidget {
  const _HistoryLeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(38),
      height: dims.scaleWidth(38),
      decoration: BoxDecoration(
        color: _kBloomAccentSoft,
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Icon(icon, size: dims.scaleText(18), color: _kBloomAccent),
    );
  }
}

class _BloomMessage {
  const _BloomMessage({
    required this.text,
    required this.isUser,
    this.disclaimer,
    this.isCompact = false,
    this.sufficientData = true,
    this.attachmentName,
    this.attachmentMeta,
  });

  factory _BloomMessage.user(
    String text, {
    String? attachmentName,
    String? attachmentMeta,
  }) {
    return _BloomMessage(
      text: text,
      isUser: true,
      isCompact: text.length < 48 && attachmentName == null,
      attachmentName: attachmentName,
      attachmentMeta: attachmentMeta,
    );
  }

  factory _BloomMessage.assistant(
    String text, {
    String? disclaimer,
    bool sufficientData = true,
  }) {
    return _BloomMessage(
      text: text,
      isUser: false,
      disclaimer: disclaimer,
      sufficientData: sufficientData,
    );
  }

  final String text;
  final bool isUser;
  final String? disclaimer;
  final bool isCompact;
  final bool sufficientData;
  final String? attachmentName;
  final String? attachmentMeta;
}
