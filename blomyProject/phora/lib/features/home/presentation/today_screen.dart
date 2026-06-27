import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/i18n/formatters.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/features/home/domain/home_dashboard.dart';
import 'package:phora/features/home/home_providers.dart';
import 'package:phora/features/home/presentation/widgets/cycle_phase_ring.dart';
import 'package:phora/features/profile/profile_providers.dart';
import 'package:phora/features/wearables/data/gtl1_watch_sync_repository.dart';
import 'package:phora/features/wearables/domain/wearable_models.dart';
import 'package:phora/features/wearables/presentation/wearable_provider_picker.dart';
import 'package:phora/features/wearables/repositories/wearable_repository.dart';
import 'package:phora/features/wearables/services/bbt_reminder_service.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(homeDashboardProvider);
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final offline = ref.watch(homeDashboardOfflineProvider);

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const _HomeLoadingState(),
          error:
              (error, _) => _HomeErrorState(
                message: l10n.todayDashboardLoadError,
                onRetry:
                    () => ref.read(homeDashboardProvider.notifier).refresh(),
              ),
          data: (dashboard) {
            final wearableConnected =
                dashboard.healthSnapshot.wearableConnected ||
                _localWearableConnected(ref);
            final wearableStatus = _headerWearableStatus(
              ref,
              dashboard.healthSnapshot,
              wearableConnected: wearableConnected,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offline) const _NoInternetBanner(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(18),
                    offline ? dims.scaleSpace(8) : dims.scaleSpace(12),
                    dims.scaleWidth(18),
                    0,
                  ),
                  child: _HomeHeader(
                    firstName: dashboard.user.firstName,
                    wearableStatus: wearableStatus,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(8)),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh:
                        () =>
                            ref.read(homeDashboardProvider.notifier).refresh(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        dims.scaleWidth(18),
                        0,
                        dims.scaleWidth(18),
                        dims.scaleSpace(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PhaseHeroCard(
                            status: dashboard.mainStatus,
                            fertility: dashboard.fertility,
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          _HomeDashboardBody(
                            dashboard: dashboard,
                            wearableConnected: wearableConnected,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoInternetBanner extends StatelessWidget {
  const _NoInternetBanner();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A2118) : const Color(0xFFFFF1D7);
    final fg = isDark ? const Color(0xFFFFD99C) : const Color(0xFF6A3D00);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(18),
        vertical: dims.scaleSpace(7),
      ),
      color: bg,
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: dims.scaleText(14), color: fg),
          SizedBox(width: dims.scaleWidth(8)),
          Expanded(
            child: Text(
              'No internet connection',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: dims.scaleText(10.5),
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _localVylaWearLastSyncProvider = FutureProvider<DateTime?>((ref) async {
  final pairing =
      await ref.watch(gtl1WatchSyncRepositoryProvider).getPairedPhoraWear();
  return pairing?.lastSyncedAt;
});

bool _localWearableConnected(WidgetRef ref) {
  final statuses = ref.watch(wearableConnectionStatusesProvider).valueOrNull;
  return statuses?.any((status) => status.isConnected) ?? false;
}

_HeaderWearableStatus _headerWearableStatus(
  WidgetRef ref,
  HomeHealthSnapshot snapshot, {
  required bool wearableConnected,
}) {
  final statuses = ref.watch(wearableConnectionStatusesProvider).valueOrNull;
  final connectedProviderId =
      statuses
          ?.where((status) => status.isConnected)
          .map((status) => status.providerId)
          .firstOrNull;
  return _headerWearableStatusFromProviderId(
    connectedProviderId ?? snapshot.wearableType,
    wearableConnected: wearableConnected,
  );
}

_HeaderWearableStatus _headerWearableStatusFromProviderId(
  String? providerId, {
  required bool wearableConnected,
}) {
  if (!wearableConnected) {
    return _HeaderWearableStatus.none;
  }
  final normalized = providerId?.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    WearableProviderIds.vylaWearable ||
    'vyla' ||
    'vyla_wear' ||
    'phora_wear' => _HeaderWearableStatus.vylaWearable,
    _ => _HeaderWearableStatus.connected,
  };
}

DateTime? _effectiveDeviceSyncTime({
  required DateTime? backendSyncedAt,
  required DateTime? backendRecordedAt,
  required DateTime? localSyncedAt,
}) {
  if (backendSyncedAt != null) {
    return backendSyncedAt;
  }
  if (localSyncedAt != null) {
    return localSyncedAt;
  }
  if (backendRecordedAt != null && !_isDateOnlyTimestamp(backendRecordedAt)) {
    return backendRecordedAt;
  }
  return null;
}

bool _isDateOnlyTimestamp(DateTime value) {
  final local = value.toLocal();
  return local.hour == 0 &&
      local.minute == 0 &&
      local.second == 0 &&
      local.millisecond == 0 &&
      local.microsecond == 0;
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.firstName, required this.wearableStatus});

  final String? firstName;
  final _HeaderWearableStatus wearableStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greetingName =
        (firstName?.trim().isNotEmpty ?? false) ? firstName!.trim() : 'there';
    final greeting = _timeGreeting();
    final hasUnread =
        (ref.watch(notificationHistoryProvider).valueOrNull?.unreadCount ?? 0) >
        0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: dims.scaleWidth(176),
              height: dims.scaleHeight(72),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.08),
                  child: Image.asset('assets/images/vyla_home_logo.png'),
                ),
              ),
            ),
            const Spacer(),
            _HeaderIconButton(
              onTap: () => context.push('/notifications'),
              icon: Icons.notifications_none_rounded,
              dotColor: hasUnread ? const Color(0xFFFF8A4C) : null,
              iconColor: isDark ? colors.textPrimary : const Color(0xFF3B241A),
            ),
            SizedBox(width: dims.scaleWidth(8)),
            _HeaderDeviceStatus(status: wearableStatus),
          ],
        ),
        SizedBox(height: dims.scaleSpace(3)),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: dims.scaleWidth(6),
          runSpacing: dims.scaleSpace(4),
          children: [
            Text(
              '$greeting, $greetingName',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: dims.scaleText(20),
                height: 1.15,
                color: isDark ? colors.textPrimary : const Color(0xFF2A1913),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
              ),
            ),
            Text(
              '♡',
              style: TextStyle(
                fontSize: dims.scaleText(17),
                color: const Color(0xFFFF7F9D),
              ),
            ),
          ],
        ),
        SizedBox(height: dims.scaleSpace(4)),
        Text(
          'Let’s make this a balanced, beautiful day.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: dims.scaleText(12.5),
            height: 1.35,
            color: isDark ? colors.textSecondary : const Color(0xFF8D5F4C),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    this.dotColor,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: SizedBox(
          width: dims.scaleWidth(42),
          height: dims.scaleWidth(42),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(icon, size: dims.scaleText(24), color: iconColor),
              ),
              if (dotColor != null)
                Positioned(
                  top: dims.scaleSpace(8),
                  right: dims.scaleWidth(8),
                  child: Container(
                    width: dims.scaleWidth(10),
                    height: dims.scaleWidth(10),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
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

enum _HeaderWearableStatus { none, vylaWearable, connected }

class _HeaderDeviceStatus extends StatelessWidget {
  const _HeaderDeviceStatus({required this.status});

  final _HeaderWearableStatus status;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = status != _HeaderWearableStatus.none;
    final icon = switch (status) {
      _HeaderWearableStatus.vylaWearable => Icons.watch_rounded,
      _HeaderWearableStatus.connected => Icons.bluetooth_connected_rounded,
      _HeaderWearableStatus.none => Icons.watch_rounded,
    };
    final accentColor = switch (status) {
      _HeaderWearableStatus.vylaWearable => const Color(0xFF3D8BFF),
      _HeaderWearableStatus.connected => const Color(0xFF18A76B),
      _HeaderWearableStatus.none => const Color(0xFFE35D5D),
    };
    final iconColor =
        connected
            ? accentColor
            : isDark
            ? colors.textPrimary
            : const Color(0xFF3B241A);

    return InkWell(
      borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
      onTap: () => context.go('/you/connected-devices'),
      child: SizedBox(
        width: dims.scaleWidth(46),
        height: dims.scaleWidth(46),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: dims.scaleWidth(42),
              height: dims.scaleWidth(42),
              decoration: BoxDecoration(
                color: isDark ? colors.bgElevated : const Color(0xFFFFEFE8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: connected ? accentColor : colors.border,
                  width: connected ? 1.5 : 1,
                ),
              ),
              child: Icon(icon, size: dims.scaleText(22), color: iconColor),
            ),
            if (connected)
              Positioned(
                right: dims.scaleWidth(3),
                top: dims.scaleSpace(5),
                child: Container(
                  width: dims.scaleWidth(11),
                  height: dims.scaleWidth(11),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? colors.bg : const Color(0xFFFFFBF7),
                      width: 2,
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.72,
                    child: Text(
                      '/',
                      style: TextStyle(
                        color: const Color(0xFFE35D5D),
                        fontSize: dims.scaleText(32),
                        height: 0.9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseHeroCard extends ConsumerWidget {
  const _PhaseHeroCard({required this.status, required this.fertility});

  final HomeMainStatus status;
  final HomeFertility fertility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cycleDay = status.currentCycleDay?.toString() ?? '--';
    final activePeriodEndDate = _activePeriodEndDate(status);
    final isOnCurrentPeriod = activePeriodEndDate != null;
    final effectivePhase =
        isOnCurrentPeriod ? 'menstrual' : status.currentPhase;
    final phase = _phaseLabel(context, effectivePhase);
    final phaseTitle = '${_titleCase(phase)} Phase';
    final nextPeriod =
        _nextPeriodLegendValue(
          nextPredictedPeriodDate: status.nextPredictedPeriodDate,
          context: context,
        ) ??
        '--';
    final periodLegend = isOnCurrentPeriod ? 'Active now' : nextPeriod;
    final ovulation =
        _formatMonthDay(context, fertility.predictedOvulationDate) ?? '--';
    final fertileWindow =
        _fertileWindowRangeText(
          context,
          fertility.fertileWindowStart,
          fertility.fertileWindowEnd,
        ) ??
        _formatMonthDay(context, fertility.predictedOvulationDate);
    final ovulationLegend = fertility.fertileToday ? 'Active now' : ovulation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final circleSize = math.min(
          constraints.maxWidth - dims.scaleWidth(8),
          dims.scaleWidth(345),
        );
        final compact = circleSize < dims.scaleWidth(320);
        final visualCircleSize = circleSize + 11;
        final innerSize = circleSize * (compact ? 0.685 : 0.735);
        final innerHorizontalPadding = dims.scaleWidth(compact ? 12 : 18);
        final innerVerticalPadding = dims.scaleSpace(compact ? 14 : 24);
        final phaseIconSize = dims.scaleText(compact ? 20 : 28);
        final phaseTitleSize = dims.scaleText(compact ? 17.5 : 23);
        final pillFontSize = dims.scaleText(compact ? 9.5 : 11);
        final metadataFontSize = dims.scaleText(compact ? 10.8 : 12.5);
        final dividerGap = dims.scaleSpace(compact ? 6 : 10);
        final sectionSpacing = dims.scaleSpace(compact ? 5 : 10);

        return SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(
                width: visualCircleSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: visualCircleSize,
                      height: visualCircleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            isDark
                                ? const RadialGradient(
                                  colors: [
                                    Color(0xFF2F2730),
                                    Color(0xFF19161B),
                                    Color(0xFF111015),
                                  ],
                                  stops: [0.0, 0.72, 1.0],
                                )
                                : null,
                        border: Border.all(
                          color:
                              isDark
                                  ? const Color(0xFF453A45)
                                  : const Color(0xFFEDD5C8),
                          width: 3.4,
                        ),
                        boxShadow:
                            isDark
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF52C79A,
                                    ).withValues(alpha: 0.12),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF8A4C,
                                    ).withValues(alpha: 0.10),
                                    blurRadius: 32,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.42),
                                    blurRadius: 34,
                                    offset: const Offset(0, 18),
                                  ),
                                ]
                                : null,
                      ),
                    ),
                    CyclePhaseRing(
                      currentPhase:
                          isOnCurrentPeriod
                              ? 'menstrual'
                              : status.currentPhase ?? 'follicular',
                      fertileToday: fertility.fertileToday,
                      nextPeriodDate: status.nextPredictedPeriodDate,
                      nextOvulationDate: fertility.predictedOvulationDate,
                      size: visualCircleSize,
                      strokeWidth: dims.scaleWidth(24),
                      backgroundColor:
                          isDark
                              ? const Color(0xFF332B34)
                              : const Color(0xFFFFF6F0),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: innerHorizontalPadding,
                          vertical: innerVerticalPadding,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: innerSize - (innerHorizontalPadding * 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_florist_outlined,
                                  color: const Color(0xFFF4AF9F),
                                  size: phaseIconSize,
                                ),
                                SizedBox(
                                  height: dims.scaleSpace(compact ? 3 : 6),
                                ),
                                Text(
                                  phaseTitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall?.copyWith(
                                    fontSize: phaseTitleSize,
                                    height: compact ? 1.0 : 1.08,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark
                                            ? colors.textPrimary
                                            : const Color(0xFF2B160F),
                                    fontFamily: 'Georgia',
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                SizedBox(
                                  height: dims.scaleSpace(compact ? 4 : 8),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: dims.scaleWidth(
                                      compact ? 10 : 14,
                                    ),
                                    vertical: dims.scaleSpace(compact ? 3 : 5),
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDF6E9),
                                    borderRadius: BorderRadius.circular(
                                      dims.scaleRadius(999),
                                    ),
                                  ),
                                  child: Text(
                                    'Today',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      fontSize: pillFontSize,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF27A86E),
                                    ),
                                  ),
                                ),
                                SizedBox(height: sectionSpacing),
                                Text(
                                  'Cycle Day $cycleDay',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    fontSize: metadataFontSize,
                                    color:
                                        isDark
                                            ? colors.textPrimary
                                            : const Color(0xFF2C1A13),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (fertility.fertileToday) ...[
                                  SizedBox(
                                    height: dims.scaleSpace(compact ? 5 : 8),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: dims.scaleWidth(
                                        compact ? 10 : 12,
                                      ),
                                      vertical: dims.scaleSpace(
                                        compact ? 4 : 5,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? const Color(0xFF223328)
                                              : const Color(0xFFEAF7F0),
                                      borderRadius: BorderRadius.circular(
                                        dims.scaleRadius(999),
                                      ),
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? const Color(0xFF355742)
                                                : const Color(0xFFCBE9D6),
                                      ),
                                    ),
                                    child: Text(
                                      fertileWindow == null
                                          ? 'Fertile window active'
                                          : 'Fertile window active · $fertileWindow',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        fontSize: dims.scaleText(
                                          compact ? 9.2 : 10.4,
                                        ),
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isDark
                                                ? const Color(0xFF97E0B2)
                                                : const Color(0xFF2A8B58),
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(
                                  height: dims.scaleSpace(compact ? 7 : 12),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color:
                                            isDark
                                                ? const Color(0xFF4A4048)
                                                : const Color(0xFFF1D8CC),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: dims.scaleWidth(
                                          compact ? 5 : 8,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: dims.scaleText(
                                          compact ? 7.5 : 10,
                                        ),
                                        color: const Color(0xFFF4C7B4),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color:
                                            isDark
                                                ? const Color(0xFF4A4048)
                                                : const Color(0xFFF1D8CC),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: dividerGap),
                                _DateLegendRow(
                                  compact: compact,
                                  icon: Icons.water_drop_rounded,
                                  iconColor: const Color(0xFFFF638C),
                                  label:
                                      isOnCurrentPeriod
                                          ? 'Period'
                                          : context.l10n.todayNextPeriodLabel,
                                  value: periodLegend,
                                  onTap:
                                      () => context.go('/log?section=period'),
                                ),
                                SizedBox(
                                  height: dims.scaleSpace(compact ? 4 : 8),
                                ),
                                _DateLegendRow(
                                  compact: compact,
                                  icon: Icons.wb_sunny_rounded,
                                  iconColor: const Color(0xFF3E94F4),
                                  label: 'Ovulation',
                                  value: ovulationLegend,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: dims.scaleSpace(18)),
              _PredictionSummaryCard(
                compact: compact,
                inOvulationWindow: fertility.fertileToday,
                ovulationRange: _ovulationRangeText(
                  context,
                  fertility.fertileWindowStart,
                  fertility.fertileWindowEnd,
                  fertility.predictedOvulationDate,
                ),
                predictionSource: _predictionSourceLabel(
                  fertility.predictionMethod,
                ),
                calculationNote: _ovulationCalculationNote(
                  fertility.predictionMethod,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String? _nextPeriodLegendValue({
  required DateTime? nextPredictedPeriodDate,
  required BuildContext context,
}) {
  return _formatMonthDay(context, nextPredictedPeriodDate);
}

bool _isMenstrualPhase(String? phase) {
  final normalized = (phase ?? '').trim().toLowerCase();
  return normalized == 'menstrual' || normalized == 'menstruation';
}

DateTime? _activePeriodEndDate(HomeMainStatus status) {
  final periodLength = (status.periodLengthDays ?? 5).clamp(1, 10).toInt();
  final today = DateTime.now();
  final todayDate = _dateOnly(today);
  final predictedPeriodStart = _dateOnlyOrNull(status.nextPredictedPeriodDate);
  if (predictedPeriodStart != null) {
    final predictedPeriodEnd = predictedPeriodStart.add(
      Duration(days: periodLength - 1),
    );
    if (!todayDate.isBefore(predictedPeriodStart) &&
        !todayDate.isAfter(predictedPeriodEnd)) {
      return predictedPeriodEnd;
    }
  }

  final cycleDay = status.currentCycleDay;
  if (cycleDay == null) {
    return _isMenstrualPhase(status.currentPhase) ? DateTime.now() : null;
  }
  if (cycleDay < 1 || cycleDay > periodLength) return null;
  final periodStart = todayDate.subtract(Duration(days: cycleDay - 1));
  return periodStart.add(Duration(days: periodLength - 1));
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime? _dateOnlyOrNull(DateTime? value) {
  if (value == null) return null;
  return _dateOnly(value);
}

class _DateLegendRow extends StatelessWidget {
  const _DateLegendRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.compact = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final row = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: dims.scaleText(compact ? 12.5 : 14),
          ),
          SizedBox(width: dims.scaleWidth(compact ? 5 : 6)),
          if (label.isNotEmpty) ...[
            Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(compact ? 10.5 : 11.5),
                color: isDark ? colors.textSecondary : const Color(0xFF835D4B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(compact ? 10.8 : 11.8),
                color: isDark ? colors.textPrimary : const Color(0xFF2B1A12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTap != null) ...[
            SizedBox(width: dims.scaleWidth(4)),
            Icon(
              Icons.edit_rounded,
              size: dims.scaleText(compact ? 9 : 10),
              color: isDark ? colors.textSecondary : const Color(0xFFB08A78),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(dims.scaleRadius(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(4),
          vertical: dims.scaleSpace(2),
        ),
        child: row,
      ),
    );
  }
}

class _PredictionSummaryCard extends StatelessWidget {
  const _PredictionSummaryCard({
    required this.compact,
    required this.inOvulationWindow,
    required this.ovulationRange,
    required this.predictionSource,
    required this.calculationNote,
  });

  final bool compact;
  final bool inOvulationWindow;
  final String ovulationRange;
  final String predictionSource;
  final String calculationNote;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(compact ? 16 : 20)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white,
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10C58B68),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(compact ? 36 : 40),
            height: dims.scaleWidth(compact ? 36 : 40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF223241) : const Color(0xFFEAF4FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wb_sunny_rounded,
              color: const Color(0xFF4298EF),
              size: dims.scaleText(compact ? 18 : 20),
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inOvulationWindow
                      ? 'Your current cycle pattern suggests you may be in your fertile window today.'
                      : 'Vyla estimates your next ovulation window around $ovulationRange.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF4A2C1A),
                    fontSize: dims.scaleText(compact ? 11.5 : 12.5),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(8)),
                Text(
                  predictionSource,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        isDark ? colors.textSecondary : const Color(0xFFA06A52),
                    fontSize: dims.scaleText(compact ? 10 : 11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(10)),
                Text(
                  calculationNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF8B6A5A),
                    fontSize: dims.scaleText(compact ? 9.6 : 10.4),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
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

class _HomeDashboardBody extends ConsumerWidget {
  const _HomeDashboardBody({
    required this.dashboard,
    required this.wearableConnected,
  });

  final HomeDashboard dashboard;
  final bool wearableConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final localLastSync = ref.watch(_localVylaWearLastSyncProvider).valueOrNull;
    final effectiveLastSync = _effectiveDeviceSyncTime(
      backendSyncedAt: dashboard.healthSnapshot.latestSyncedAt,
      backendRecordedAt: dashboard.healthSnapshot.latestRecordedAt,
      localSyncedAt: localLastSync,
    );
    void showPicker() => showWearableProviderPicker(context, ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<BBTCollectionHomeState?>(
          future: ref.read(bbtReminderServiceProvider).homeState(dashboard),
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.only(bottom: dims.scaleSpace(18)),
              child: _BBTCollectionActiveCard(state: state, onTap: showPicker),
            );
          },
        ),
        _SectionHeader(
          title: 'Body Signals',
          actionLabel: 'View all',
          leadingIcon: Icons.multitrack_audio_rounded,
          accentColor: const Color(0xFFFF8A4C),
          onActionTap:
              () => _showBodySignalsDetails(
                context,
                snapshot: dashboard.healthSnapshot,
                trends: dashboard.deviceTrends,
                effectiveSyncedAt: effectiveLastSync,
                wearableConnected: wearableConnected,
                onConnectWearable: showPicker,
              ),
        ),
        SizedBox(height: dims.scaleSpace(12)),
        _LastDeviceSyncLabel(syncedAt: effectiveLastSync),
        SizedBox(height: dims.scaleSpace(8)),
        _BodySignalsStrip(
          snapshot: dashboard.healthSnapshot,
          trends: dashboard.deviceTrends,
          wearableConnected: wearableConnected,
          onConnectWearable: showPicker,
        ),
        SizedBox(height: dims.scaleSpace(18)),
        _SectionHeader(
          title: 'Today’s Insights',
          actionLabel: 'View all',
          accentColor: const Color(0xFFFF8A4C),
          onActionTap:
              () => _showInsightsDetails(
                context,
                insights: dashboard.deviceCycleInsights,
                predictionDisclaimer: dashboard.predictionDisclaimer,
              ),
        ),
        SizedBox(height: dims.scaleSpace(12)),
        _LastDeviceSyncLabel(syncedAt: effectiveLastSync),
        SizedBox(height: dims.scaleSpace(8)),
        _InsightsDeck(
          insights: dashboard.deviceCycleInsights,
          predictionDisclaimer: dashboard.predictionDisclaimer,
        ),
      ],
    );
  }
}

class _LastDeviceSyncLabel extends StatelessWidget {
  const _LastDeviceSyncLabel({required this.syncedAt});

  final DateTime? syncedAt;

  String _label() {
    if (syncedAt == null) return 'Last sync: Not synced yet';
    final local = syncedAt!.toLocal();
    final now = DateTime.now();
    final dateLabel =
        local.year == now.year &&
                local.month == now.month &&
                local.day == now.day
            ? 'Today'
            : '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
    final hour = local.hour == 0 ? 12 : ((local.hour - 1) % 12) + 1;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final age = now.difference(local);
    final ageLabel =
        age.inMinutes < 1
            ? 'just now'
            : age.inHours < 1
            ? '${age.inMinutes}m ago'
            : age.inHours < 24
            ? '${age.inHours}h ago'
            : '${age.inDays}d ago';
    return 'Last synced: $dateLabel, $hour:$minute $period ($ageLabel)';
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    return Row(
      children: [
        Icon(
          Icons.sync_rounded,
          size: dims.scaleText(13),
          color: colors.textSecondary,
        ),
        SizedBox(width: dims.scaleWidth(4)),
        Text(
          _label(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: dims.scaleText(11.5),
            color: colors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _BBTCollectionActiveCard extends StatelessWidget {
  const _BBTCollectionActiveCard({required this.state, required this.onTap});

  final BBTCollectionHomeState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? colors.bgElevated : const Color(0xFFFFF7F1),
      borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(dims.scaleWidth(16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
            border: Border.all(
              color:
                  state.needsPermission
                      ? const Color(0xFFFF8A4C)
                      : const Color(0xFFFFD8C2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: dims.scaleWidth(42),
                height: dims.scaleWidth(42),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE6D6),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
                ),
                child: Icon(
                  Icons.thermostat_rounded,
                  color: const Color(0xFFFF7C68),
                  size: dims.scaleText(22),
                ),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BBT tracking is active',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontSize: dims.scaleText(14),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(4)),
                    Text(
                      state.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontSize: dims.scaleText(11.5),
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(8)),
                    Text(
                      state.statusLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFFF7C68),
                        fontSize: dims.scaleText(10.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(8)),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: dims.scaleText(22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _lastSyncSheetLabel(DateTime? syncedAt) {
  if (syncedAt == null) {
    return 'No device sync recorded yet.';
  }
  final local = syncedAt.toLocal();
  final now = DateTime.now();
  final dateLabel =
      local.year == now.year && local.month == now.month && local.day == now.day
          ? 'today'
          : '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  final hour = local.hour == 0 ? 12 : ((local.hour - 1) % 12) + 1;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return 'Last synced $dateLabel at $hour:$minute $period.';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.accentColor,
    this.leadingIcon,
    this.onActionTap,
  });

  final String title;
  final String actionLabel;
  final Color accentColor;
  final IconData? leadingIcon;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: dims.scaleText(16), color: accentColor),
          SizedBox(width: dims.scaleWidth(6)),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: dims.scaleText(13.5),
            fontWeight: FontWeight.w700,
            color: isDark ? colors.textPrimary : const Color(0xFF4A2C1A),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onActionTap,
          borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dims.scaleWidth(6),
              vertical: dims.scaleSpace(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(10.8),
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF7F594A),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(4)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: dims.scaleText(16),
                  color: accentColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightsDeck extends StatelessWidget {
  const _InsightsDeck({
    required this.insights,
    required this.predictionDisclaimer,
  });

  final List<HomeCycleInsight> insights;
  final String predictionDisclaimer;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = dims.scaleWidth(12);
        final cardWidth =
            constraints.maxWidth >= dims.scaleWidth(620)
                ? (constraints.maxWidth - (spacing * 2)) / 3
                : constraints.maxWidth >= dims.scaleWidth(380)
                ? (constraints.maxWidth - spacing) / 2
                : constraints.maxWidth;

        if (insights.isEmpty) {
          return _BodySignalEmptyState(
            icon: Icons.insights_rounded,
            title: 'Insights are still building',
            message:
                'Keep syncing your wearable and logging your cycle so Vyla can explain your patterns with more confidence.',
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              insights.take(6).map((insight) {
                final style = _cycleInsightStyle(insight);
                return _InsightCard(
                  onTap:
                      () => _showHomeCardDetails(
                        context,
                        title: insight.title,
                        subtitle: insight.summary,
                        description:
                            '${insight.advice}\n\n${insight.cycleImpact}',
                        accentColor: style.accentColor,
                        icon: style.icon,
                        disclaimer:
                            insight.showMedicalDisclaimer
                                ? _signalDisclaimerForInsight(
                                  insight,
                                  predictionDisclaimer,
                                )
                                : null,
                      ),
                  width: cardWidth,
                  icon: style.icon,
                  iconColor: style.iconColor,
                  iconBackground: style.iconBackground,
                  arrowColor: style.arrowColor,
                  title: insight.title,
                  subtitle: insight.summary,
                  footer:
                      '${_titleCase(insight.confidence)} confidence • ${_readableSignalSummary(insight.sourceSignals)}',
                  surfaceTint: style.surfaceTint,
                  emphasizeSubtitle: insight.severity == 'positive',
                );
              }).toList(),
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.width,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.arrowColor,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.surfaceTint,
    required this.onTap,
    this.emphasizeSubtitle = false,
  });

  final double width;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color arrowColor;
  final String title;
  final String subtitle;
  final String footer;
  final Color surfaceTint;
  final VoidCallback onTap;
  final bool emphasizeSubtitle;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
      child: Container(
        width: width,
        padding: EdgeInsets.all(dims.scaleWidth(14)),
        decoration: BoxDecoration(
          color: isDark ? colors.bgElevated : surfaceTint,
          borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
          border: Border.all(
            color: isDark ? colors.border : const Color(0xFFF4E4D9),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: dims.scaleWidth(42),
                  height: dims.scaleWidth(42),
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: dims.scaleText(20), color: iconColor),
                ),
                const Spacer(),
                Container(
                  width: dims.scaleWidth(34),
                  height: dims.scaleWidth(34),
                  decoration: BoxDecoration(
                    color: isDark ? colors.bgSurface : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow:
                        isDark
                            ? null
                            : const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: dims.scaleText(16),
                    color: arrowColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: dims.scaleSpace(12)),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: dims.scaleText(11.4),
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: isDark ? colors.textPrimary : const Color(0xFF33211A),
              ),
            ),
            SizedBox(height: dims.scaleSpace(8)),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(emphasizeSubtitle ? 11.0 : 10.3),
                height: 1.4,
                fontWeight:
                    emphasizeSubtitle ? FontWeight.w700 : FontWeight.w500,
                color:
                    emphasizeSubtitle
                        ? const Color(0xFF32B977)
                        : (isDark
                            ? colors.textSecondary
                            : const Color(0xFF8A6656)),
              ),
            ),
            if (footer.isNotEmpty) ...[
              SizedBox(height: dims.scaleSpace(2)),
              Text(
                footer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: dims.scaleText(10),
                  color:
                      isDark ? colors.textSecondary : const Color(0xFF8A6656),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BodySignalsStrip extends StatelessWidget {
  const _BodySignalsStrip({
    required this.snapshot,
    required this.trends,
    required this.wearableConnected,
    required this.onConnectWearable,
  });

  final HomeHealthSnapshot snapshot;
  final List<HomeDeviceTrend> trends;
  final bool wearableConnected;
  final VoidCallback onConnectWearable;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    if (!wearableConnected) {
      return _BodySignalEmptyState(
        icon: Icons.watch_rounded,
        title: snapshot.bodySignalTitle,
        message: snapshot.bodySignalMessage,
        actionLabel: snapshot.bodySignalActionLabel ?? 'Connect wearable',
        onPressed: onConnectWearable,
      );
    }

    if (snapshot.cycleSupportSignals.isEmpty) {
      return _BodySignalEmptyState(
        icon: Icons.sync_rounded,
        title: snapshot.bodySignalTitle,
        message: snapshot.bodySignalMessage,
      );
    }

    final cards = _signalCardsForSnapshot(context, snapshot, trends);

    if (cards.isEmpty) {
      return _BodySignalEmptyState(
        icon: Icons.sync_rounded,
        title: snapshot.bodySignalTitle,
        message: snapshot.bodySignalMessage,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = dims.scaleWidth(10);
        final width =
            constraints.maxWidth >= dims.scaleWidth(620)
                ? (constraints.maxWidth - (spacing * 3)) / 4
                : (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              cards
                  .map(
                    (card) => _SignalCard(
                      width: width,
                      label: card.label,
                      value: card.value,
                      subvalue: card.subvalue,
                      progress: card.progress,
                      icon: card.icon,
                      iconColor: card.iconColor,
                      iconBackground: card.iconBackground,
                      accentColor: card.accentColor,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.width,
    required this.label,
    required this.value,
    required this.subvalue,
    required this.progress,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.accentColor,
  });

  final double width;
  final String label;
  final String value;
  final String subvalue;
  final double progress;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      padding: EdgeInsets.all(dims.scaleWidth(12)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white,
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF1E3D8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: dims.scaleWidth(28),
                height: dims.scaleWidth(28),
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: dims.scaleText(15), color: iconColor),
              ),
              SizedBox(width: dims.scaleWidth(8)),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(9.8),
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF6E584E),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(9)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: dims.scaleText(11.8),
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textPrimary : const Color(0xFF332119),
            ),
          ),
          SizedBox(height: dims.scaleSpace(3)),
          Text(
            subvalue,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(9.4),
              color: isDark ? colors.textSecondary : const Color(0xFF8B6A59),
            ),
          ),
          SizedBox(height: dims.scaleSpace(10)),
          ClipRRect(
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            child: LinearProgressIndicator(
              minHeight: dims.scaleHeight(4),
              value: progress,
              backgroundColor:
                  isDark ? colors.bgSurface : const Color(0xFFF3ECE8),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodySignalEmptyState extends StatelessWidget {
  const _BodySignalEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showAction = actionLabel != null && onPressed != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(14)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white,
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF1E3D8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(38),
            height: dims.scaleWidth(38),
            decoration: BoxDecoration(
              color: isDark ? colors.bgSurface : const Color(0xFFFFF0E8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: dims.scaleText(19),
              color: const Color(0xFFFF8A4C),
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF332119),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10.5),
                    height: 1.35,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF8B6A59),
                  ),
                ),
              ],
            ),
          ),
          if (showAction) ...[
            SizedBox(width: dims.scaleWidth(10)),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A4C),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(12),
                  vertical: dims.scaleSpace(8),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: dims.scaleText(10.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return const PhoraLoadingView(size: 96);
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(dims.scaleWidth(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: colors.textSecondary,
              size: dims.scaleText(36),
            ),
            SizedBox(height: dims.scaleSpace(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: dims.scaleSpace(16)),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showHomeCardDetails(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String description,
  required Color accentColor,
  required IconData icon,
  String? disclaimer,
}) {
  final dims = context.dims;
  final colors = context.phora.colors;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          dims.scaleWidth(14),
          0,
          dims.scaleWidth(14),
          dims.scaleSpace(14),
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            dims.scaleWidth(18),
            dims.scaleSpace(16),
            dims.scaleWidth(18),
            dims.scaleSpace(20),
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.bgElevated : const Color(0xFFFFFCFA),
            borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
            border: Border.all(
              color: isDark ? colors.border : const Color(0xFFF2E2D8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: dims.scaleWidth(42),
                  height: dims.scaleHeight(4),
                  decoration: BoxDecoration(
                    color: isDark ? colors.border : const Color(0xFFE9D8CE),
                    borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                  ),
                ),
              ),
              SizedBox(height: dims.scaleSpace(16)),
              Row(
                children: [
                  Container(
                    width: dims.scaleWidth(44),
                    height: dims.scaleWidth(44),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: dims.scaleText(21),
                    ),
                  ),
                  SizedBox(width: dims.scaleWidth(12)),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF2E1C15),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: dims.scaleSpace(14)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(12),
                  vertical: dims.scaleSpace(9),
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
              SizedBox(height: dims.scaleSpace(14)),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: dims.scaleText(12.4),
                  height: 1.55,
                  color:
                      isDark ? colors.textSecondary : const Color(0xFF74584B),
                ),
              ),
              if (disclaimer != null && disclaimer.trim().isNotEmpty) ...[
                SizedBox(height: dims.scaleSpace(14)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.scaleWidth(12),
                    vertical: dims.scaleSpace(10),
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? colors.bgSurface : const Color(0xFFFFF5EF),
                    borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
                    border: Border.all(
                      color: isDark ? colors.border : const Color(0xFFF2DED1),
                    ),
                  ),
                  child: Text(
                    disclaimer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: dims.scaleText(11),
                      height: 1.45,
                      color:
                          isDark
                              ? colors.textSecondary
                              : const Color(0xFF7A5D50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showInsightsDetails(
  BuildContext context, {
  required List<HomeCycleInsight> insights,
  required String predictionDisclaimer,
}) {
  final dims = context.dims;
  final colors = context.phora.colors;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => _HomeDetailsSheet(
          title: 'Today’s Insights',
          subtitle: 'Detailed cycle and body-signal context for today.',
          icon: Icons.insights_rounded,
          accentColor: const Color(0xFFFF8A4C),
          child:
              insights.isEmpty
                  ? Text(
                    'Insights are still building. Keep syncing your wearable and logging your cycle so Vyla can explain your patterns with more confidence.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: dims.scaleText(12),
                      height: 1.5,
                      color:
                          isDark
                              ? colors.textSecondary
                              : const Color(0xFF735447),
                    ),
                  )
                  : Column(
                    children: [
                      for (final insight in insights)
                        Padding(
                          padding: EdgeInsets.only(bottom: dims.scaleSpace(10)),
                          child: _InsightDetailTile(
                            insight: insight,
                            predictionDisclaimer: predictionDisclaimer,
                          ),
                        ),
                    ],
                  ),
        ),
  );
}

Future<void> _showBodySignalsDetails(
  BuildContext context, {
  required HomeHealthSnapshot snapshot,
  required List<HomeDeviceTrend> trends,
  required DateTime? effectiveSyncedAt,
  required bool wearableConnected,
  required VoidCallback onConnectWearable,
}) {
  final dims = context.dims;
  final cards = _signalCardsForSnapshot(context, snapshot, trends);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => _HomeDetailsSheet(
          title: 'Body Signals',
          subtitle: _lastSyncSheetLabel(effectiveSyncedAt),
          icon: Icons.multitrack_audio_rounded,
          accentColor: const Color(0xFFFF8A4C),
          child:
              !wearableConnected
                  ? _BodySignalEmptyState(
                    icon: Icons.watch_rounded,
                    title: snapshot.bodySignalTitle,
                    message: snapshot.bodySignalMessage,
                    actionLabel:
                        snapshot.bodySignalActionLabel ?? 'Connect wearable',
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConnectWearable();
                    },
                  )
                  : cards.isEmpty
                  ? _BodySignalEmptyState(
                    icon: Icons.sync_rounded,
                    title: snapshot.bodySignalTitle,
                    message: snapshot.bodySignalMessage,
                  )
                  : Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: EdgeInsets.only(bottom: dims.scaleSpace(10)),
                          child: _SignalDetailTile(card: card),
                        ),
                      if (trends.isNotEmpty) ...[
                        SizedBox(height: dims.scaleSpace(4)),
                        _TrendSummaryTile(trends: trends),
                      ],
                    ],
                  ),
        ),
  );
}

class _HomeDetailsSheet extends StatelessWidget {
  const _HomeDetailsSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder:
          (context, controller) => Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(14),
              0,
              dims.scaleWidth(14),
              dims.scaleSpace(14),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? colors.bgElevated : const Color(0xFFFFFCFA),
                borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
                border: Border.all(
                  color: isDark ? colors.border : const Color(0xFFF2E2D8),
                ),
              ),
              child: ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                  dims.scaleWidth(18),
                  dims.scaleSpace(12),
                  dims.scaleWidth(18),
                  dims.scaleSpace(20),
                ),
                children: [
                  Center(
                    child: Container(
                      width: dims.scaleWidth(42),
                      height: dims.scaleHeight(4),
                      decoration: BoxDecoration(
                        color: isDark ? colors.border : const Color(0xFFE9D8CE),
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(999),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(16)),
                  Row(
                    children: [
                      Container(
                        width: dims.scaleWidth(44),
                        height: dims.scaleWidth(44),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: accentColor,
                          size: dims.scaleText(21),
                        ),
                      ),
                      SizedBox(width: dims.scaleWidth(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontSize: dims.scaleText(16),
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? colors.textPrimary
                                        : const Color(0xFF2E1C15),
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(3)),
                            Text(
                              subtitle,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                fontSize: dims.scaleText(11),
                                color:
                                    isDark
                                        ? colors.textSecondary
                                        : const Color(0xFF7A5A4E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
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

class _InsightDetailTile extends StatelessWidget {
  const _InsightDetailTile({
    required this.insight,
    required this.predictionDisclaimer,
  });

  final HomeCycleInsight insight;
  final String predictionDisclaimer;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _cycleInsightStyle(insight);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(13)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : style.surfaceTint,
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF1E3D8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                style.icon,
                color: style.accentColor,
                size: dims.scaleText(18),
              ),
              SizedBox(width: dims.scaleWidth(8)),
              Expanded(
                child: Text(
                  insight.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF332119),
                  ),
                ),
              ),
              Text(
                _titleCase(insight.confidence),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: dims.scaleText(9.5),
                  fontWeight: FontWeight.w800,
                  color: style.accentColor,
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            insight.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(11.5),
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: isDark ? colors.textPrimary : const Color(0xFF4A2C1A),
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            '${insight.advice}\n\nCycle impact: ${insight.cycleImpact}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(10.8),
              height: 1.45,
              color: isDark ? colors.textSecondary : const Color(0xFF75584B),
            ),
          ),
          if (insight.sourceSignals.isNotEmpty) ...[
            SizedBox(height: dims.scaleSpace(8)),
            Text(
              'Signals: ${_readableSignalSummary(insight.sourceSignals)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: dims.scaleText(10),
                color: isDark ? colors.textSecondary : const Color(0xFF8A6656),
              ),
            ),
          ],
          if (insight.showMedicalDisclaimer) ...[
            SizedBox(height: dims.scaleSpace(8)),
            Text(
              _signalDisclaimerForInsight(insight, predictionDisclaimer),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: dims.scaleText(9.8),
                height: 1.35,
                color: isDark ? colors.textSecondary : const Color(0xFF8A6656),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalDetailTile extends StatelessWidget {
  const _SignalDetailTile({required this.card});

  final _SignalCardData card;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(dims.scaleWidth(13)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF1E3D8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(40),
            height: dims.scaleWidth(40),
            decoration: BoxDecoration(
              color: card.iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              card.icon,
              color: card.iconColor,
              size: dims.scaleText(20),
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10.2),
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF705347),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(3)),
                Text(
                  card.subvalue,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10.5),
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF7A5A4E),
                  ),
                ),
              ],
            ),
          ),
          Text(
            card.value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(12.2),
              fontWeight: FontWeight.w800,
              color: isDark ? colors.textPrimary : const Color(0xFF332119),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendSummaryTile extends StatelessWidget {
  const _TrendSummaryTile({required this.trends});

  final List<HomeDeviceTrend> trends;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = trends
        .where((trend) => trend.latestValue != null)
        .take(4)
        .map((trend) => trend.label)
        .join(', ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(13)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : const Color(0xFFFFF5EF),
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF2DED1),
        ),
      ),
      child: Text(
        labels.isEmpty
            ? 'Trend history is still building.'
            : 'Trend history available for $labels.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: dims.scaleText(10.8),
          height: 1.4,
          color: isDark ? colors.textSecondary : const Color(0xFF75584B),
        ),
      ),
    );
  }
}

class _CycleInsightStyle {
  const _CycleInsightStyle({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.arrowColor,
    required this.surfaceTint,
    required this.accentColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color arrowColor;
  final Color surfaceTint;
  final Color accentColor;
}

_CycleInsightStyle _cycleInsightStyle(HomeCycleInsight insight) {
  final severity = insight.severity;
  if (insight.type == 'temperature') {
    return const _CycleInsightStyle(
      icon: Icons.device_thermostat_rounded,
      iconColor: Color(0xFF2CC47E),
      iconBackground: Color(0xFFE7FAEF),
      arrowColor: Color(0xFF4AC98B),
      surfaceTint: Color(0xFFF6FFF9),
      accentColor: Color(0xFF2CC47E),
    );
  }
  if (insight.type == 'sleep' || insight.type == 'deep_sleep') {
    return const _CycleInsightStyle(
      icon: Icons.nightlight_round,
      iconColor: Color(0xFF7E5BEF),
      iconBackground: Color(0xFFF0EAFE),
      arrowColor: Color(0xFF9A7BFF),
      surfaceTint: Color(0xFFFCFAFF),
      accentColor: Color(0xFF7E5BEF),
    );
  }
  if (insight.type == 'resting_hr') {
    return const _CycleInsightStyle(
      icon: Icons.favorite_rounded,
      iconColor: Color(0xFFFF7C45),
      iconBackground: Color(0xFFFFE8DB),
      arrowColor: Color(0xFFFF9A6B),
      surfaceTint: Color(0xFFFFF8F5),
      accentColor: Color(0xFFFF7C45),
    );
  }
  if (insight.type == 'steps') {
    return const _CycleInsightStyle(
      icon: Icons.directions_walk_rounded,
      iconColor: Color(0xFF48A5F5),
      iconBackground: Color(0xFFEAF5FF),
      arrowColor: Color(0xFF72B8F6),
      surfaceTint: Color(0xFFF8FBFF),
      accentColor: Color(0xFF48A5F5),
    );
  }
  if (insight.type == 'spo2') {
    return const _CycleInsightStyle(
      icon: Icons.bloodtype_rounded,
      iconColor: Color(0xFF48A5F5),
      iconBackground: Color(0xFFEAF5FF),
      arrowColor: Color(0xFF72B8F6),
      surfaceTint: Color(0xFFF8FBFF),
      accentColor: Color(0xFF48A5F5),
    );
  }
  if (severity == 'high_caution' || severity == 'caution') {
    return const _CycleInsightStyle(
      icon: Icons.warning_amber_rounded,
      iconColor: Color(0xFFE07A1F),
      iconBackground: Color(0xFFFFEFDF),
      arrowColor: Color(0xFFF2A55E),
      surfaceTint: Color(0xFFFFFBF7),
      accentColor: Color(0xFFE07A1F),
    );
  }
  return const _CycleInsightStyle(
    icon: Icons.auto_awesome_rounded,
    iconColor: Color(0xFF2CC47E),
    iconBackground: Color(0xFFE8FBF1),
    arrowColor: Color(0xFF45C98A),
    surfaceTint: Color(0xFFF5FFFA),
    accentColor: Color(0xFF2CC47E),
  );
}

String _readableSignalSummary(List<String> sourceSignals) {
  if (sourceSignals.isEmpty) {
    return 'cycle context';
  }
  return sourceSignals.map(_readableSignalName).join(', ');
}

String _readableSignalName(String signal) {
  return switch (signal) {
    'temperature' => 'temperature',
    'sleep' => 'sleep',
    'deep_sleep' => 'deep sleep',
    'resting_hr' => 'resting HR',
    'steps' => 'steps',
    'spo2' => 'SpO₂',
    'blood_pressure' => 'blood pressure',
    'combined_cycle' => 'combined signals',
    'recovery' => 'recovery',
    'ovulation_window' => 'ovulation window',
    'period_shift' => 'period estimate',
    _ => signal.replaceAll('_', ' '),
  };
}

String _signalDisclaimerForInsight(
  HomeCycleInsight insight,
  String predictionDisclaimer,
) {
  if (insight.type == 'blood_pressure' ||
      insight.type == 'resting_hr' ||
      insight.type == 'temperature' ||
      insight.type == 'spo2') {
    return 'If this reading is unusual for you or you feel unwell, consider speaking with a healthcare professional.\n\n$predictionDisclaimer';
  }
  return predictionDisclaimer;
}

String _sleepDisplay(double? sleepHours) {
  if (sleepHours == null) {
    return '--';
  }
  final hours = sleepHours.floor();
  final minutes = ((sleepHours - hours) * 60).round();
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

class _SignalCardData {
  const _SignalCardData({
    required this.label,
    required this.value,
    required this.subvalue,
    required this.progress,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.accentColor,
  });

  final String label;
  final String value;
  final String subvalue;
  final double progress;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color accentColor;
}

List<_SignalCardData> _signalCardsForSnapshot(
  BuildContext context,
  HomeHealthSnapshot snapshot,
  List<HomeDeviceTrend> trends,
) {
  double trendDelta(String metric) {
    final matches =
        trends
            .where((item) => item.metric == metric)
            .map((item) => item.deltaPercent)
            .whereType<double>()
            .toList();
    return matches.isEmpty ? 0 : matches.first;
  }

  final cards = <_SignalCardData>[
    if (snapshot.temperatureDeltaC != null)
      _SignalCardData(
        label: 'Temp',
        value: _temperatureDisplay(snapshot.temperatureDeltaC!, context),
        subvalue: _temperatureStatus(snapshot.temperatureDeltaC!),
        progress: _temperatureProgress(snapshot.temperatureDeltaC!),
        icon: Icons.device_thermostat_rounded,
        iconColor: const Color(0xFF29C473),
        iconBackground: const Color(0xFFE8FBF0),
        accentColor: const Color(0xFF42C97E),
      ),
    if (snapshot.restingHeartRate != null)
      _SignalCardData(
        label: 'Resting HR',
        value: '${snapshot.restingHeartRate!.toStringAsFixed(0)} bpm',
        subvalue: _restingHeartRateStatus(snapshot.restingHeartRate!),
        progress: _boundedProgress(
          snapshot.restingHeartRate!,
          min: 50,
          max: 90,
        ),
        icon: Icons.favorite_rounded,
        iconColor: const Color(0xFFFF7097),
        iconBackground: const Color(0xFFFFEEF3),
        accentColor: const Color(0xFFFF7097),
      ),
    if (snapshot.sleepHours != null)
      _SignalCardData(
        label: 'Sleep',
        value: _sleepDisplay(snapshot.sleepHours),
        subvalue: _sleepStatus(snapshot.sleepHours!),
        progress: _boundedProgress(snapshot.sleepHours!, min: 4.5, max: 9),
        icon: Icons.dark_mode_rounded,
        iconColor: const Color(0xFFB67AE6),
        iconBackground: const Color(0xFFF5ECFF),
        accentColor: const Color(0xFFB67AE6),
      ),
    if (snapshot.hrv != null)
      _SignalCardData(
        label: 'HRV',
        value: '${snapshot.hrv!.toStringAsFixed(0)} ms',
        subvalue: _hrvStatus(snapshot.hrv!),
        progress: _boundedProgress(snapshot.hrv!, min: 20, max: 80),
        icon: Icons.favorite_outline_rounded,
        iconColor: const Color(0xFF51AEF5),
        iconBackground: const Color(0xFFEAF5FF),
        accentColor: const Color(0xFF51AEF5),
      ),
    if (snapshot.steps != null)
      _SignalCardData(
        label: 'Steps',
        value: _stepsDisplay(snapshot.steps!, context),
        subvalue: _stepsStatus(snapshot.steps!, trendDelta('steps')),
        progress: _boundedProgress(
          snapshot.steps!.toDouble(),
          min: 0,
          max: 12000,
        ),
        icon: Icons.directions_walk_rounded,
        iconColor: const Color(0xFFFF8A32),
        iconBackground: const Color(0xFFFFF0E1),
        accentColor: const Color(0xFFFF8A32),
      ),
    if (snapshot.bloodOxygenAvg != null)
      _SignalCardData(
        label: 'SpO₂',
        value: '${snapshot.bloodOxygenAvg!.toStringAsFixed(0)}%',
        subvalue: _bloodOxygenStatus(snapshot.bloodOxygenAvg!),
        progress: _boundedProgress(snapshot.bloodOxygenAvg!, min: 90, max: 100),
        icon: Icons.air_rounded,
        iconColor: const Color(0xFF3CB9C5),
        iconBackground: const Color(0xFFE8FAFC),
        accentColor: const Color(0xFF3CB9C5),
      ),
    if (snapshot.stressAvg != null)
      _SignalCardData(
        label: 'Stress',
        value: snapshot.stressAvg!.toStringAsFixed(0),
        subvalue: _stressStatus(snapshot.stressAvg!),
        progress: _boundedProgress(snapshot.stressAvg!, min: 0, max: 100),
        icon: Icons.spa_outlined,
        iconColor: const Color(0xFF8C7CFF),
        iconBackground: const Color(0xFFF1EEFF),
        accentColor: const Color(0xFF8C7CFF),
      ),
  ];

  return cards;
}

String _temperatureDisplay(double value, BuildContext context) {
  final prefix = value > 0 ? '+' : '';
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  final formatted = AppFormatters.formatDecimal(
    double.parse(value.abs().toStringAsFixed(2)),
    localeTag: localeTag,
  );
  return '$prefix$formatted°C';
}

String _temperatureStatus(double value) {
  final absValue = value.abs();
  if (absValue < 0.15) {
    return 'Near baseline';
  }
  if (value > 0) {
    return 'Above baseline';
  }
  return 'Below baseline';
}

double _temperatureProgress(double value) {
  return _boundedProgress(value.abs(), min: 0, max: 0.6);
}

String _restingHeartRateStatus(double value) {
  if (value < 60) {
    return 'Low and steady';
  }
  if (value <= 75) {
    return 'In usual range';
  }
  return 'Running higher';
}

String _sleepStatus(double hours) {
  if (hours >= 8) {
    return 'Well rested';
  }
  if (hours >= 6.5) {
    return 'Solid sleep';
  }
  return 'Short sleep';
}

String _hrvStatus(double value) {
  if (value >= 55) {
    return 'Recovery up';
  }
  if (value >= 35) {
    return 'Recovery steady';
  }
  return 'Recovery dipped';
}

String _stepsDisplay(int steps, BuildContext context) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  if (steps >= 1000) {
    final formatted = AppFormatters.formatDecimal(
      double.parse((steps / 1000).toStringAsFixed(1)),
      localeTag: localeTag,
    );
    return '${formatted}k';
  }
  return '$steps';
}

String _stepsStatus(int steps, double deltaPercent) {
  if (deltaPercent >= 10) {
    return 'Above usual';
  }
  if (steps >= 8000) {
    return 'Active today';
  }
  if (steps >= 4000) {
    return 'Building up';
  }
  return 'Light movement';
}

String _bloodOxygenStatus(double value) {
  if (value >= 97) {
    return 'Strong oxygen';
  }
  if (value >= 95) {
    return 'Normal range';
  }
  return 'Slightly low';
}

String _stressStatus(double value) {
  if (value <= 30) {
    return 'Calm';
  }
  if (value <= 60) {
    return 'Moderate load';
  }
  return 'Elevated';
}

double _boundedProgress(
  double value, {
  required double min,
  required double max,
}) {
  if (max <= min) {
    return 0;
  }
  return ((value - min) / (max - min)).clamp(0.08, 1.0);
}

String _phaseLabel(BuildContext context, String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return switch (normalized) {
    'menstrual' || 'menstruation' => context.l10n.todayPhaseMenstrual,
    'follicular' => context.l10n.todayPhaseFollicular,
    'ovulation' || 'ovulatory' => context.l10n.todayPhaseOvulatory,
    'luteal' => context.l10n.todayPhaseLuteal,
    '' => context.l10n.todayPhaseCycle,
    _ => _titleCase(value ?? context.l10n.todayPhaseCycle),
  };
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value
      .split(RegExp(r'[\s_]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String? _formatDate(BuildContext context, DateTime? date) {
  if (date == null) {
    return null;
  }
  return AppFormatters.formatDateMedium(
    date,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

String? _formatMonthDay(BuildContext context, DateTime? date) {
  final formatted = _formatDate(context, date);
  if (formatted == null) {
    return null;
  }
  final parts = formatted.split(' ');
  if (parts.length >= 2) {
    final month = parts.first;
    final day = parts[1].replaceAll(',', '');
    return '$month $day';
  }
  return formatted;
}

String _ovulationRangeText(
  BuildContext context,
  DateTime? start,
  DateTime? end,
  DateTime? predicted,
) {
  final startText = _formatMonthDay(context, start);
  final endText = _formatMonthDay(context, end);
  if (startText != null && endText != null) {
    return '$startText and $endText';
  }
  return _formatMonthDay(context, predicted) ?? '--';
}

String? _fertileWindowRangeText(
  BuildContext context,
  DateTime? start,
  DateTime? end,
) {
  final startText = _formatMonthDay(context, start);
  final endText = _formatMonthDay(context, end);
  if (startText != null && endText != null) {
    return '$startText - $endText';
  }
  return startText ?? endText;
}

String _predictionSourceLabel(String? predictionMethod) {
  final normalized = (predictionMethod ?? '').trim().toLowerCase();
  if (normalized.contains('model') || normalized.contains('ml')) {
    return 'Prediction source: model ran';
  }
  if (normalized.contains('calendar')) {
    return 'Prediction source: calendar fallback was used';
  }
  return 'Prediction source: ${predictionMethod?.trim().isNotEmpty == true ? predictionMethod!.trim() : 'calendar fallback was used'}';
}

String _ovulationCalculationNote(String? predictionMethod) {
  final normalized = (predictionMethod ?? '').trim().toLowerCase();
  if (normalized.contains('model') || normalized.contains('ml')) {
    return 'Ovulation is estimated from your period history, cycle pattern, and health signals such as LH tests, cervical mucus, temperature, sleep, recovery, and wearable trends when available.';
  }
  return 'Ovulation is estimated from your logged period dates and cycle pattern. Adding LH tests, cervical mucus, temperature, sleep, recovery, or wearable data can make the fertile-window estimate more personal.';
}

String _timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Good morning';
  }
  if (hour < 17) {
    return 'Good afternoon';
  }
  return 'Good evening';
}
