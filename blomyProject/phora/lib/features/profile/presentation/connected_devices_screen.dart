import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/home/domain/home_dashboard.dart';
import 'package:phora/features/home/home_providers.dart';
import 'package:phora/features/home/presentation/widgets/cycle_phase_ring.dart';
import 'package:phora/features/onboarding/data/onboarding_repository.dart';
import 'package:phora/features/wearables/data/gtl1_watch_sync_repository.dart';
import 'package:phora/features/wearables/domain/wearable_models.dart';
import 'package:phora/features/wearables/domain/wearable_provider.dart';
import 'package:phora/features/wearables/providers/phora_wear_sync_controller.dart';
import 'package:phora/features/wearables/repositories/wearable_repository.dart';
import 'package:phora_gtl1_watch/phora_gtl1_watch.dart';

const _wearableHeartWatchSvg = '''
<svg width="96" height="96" viewBox="0 0 96 96" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="48" cy="48" r="46" fill="#FFF0E8" stroke="#FFD8C8" stroke-width="2"/>
  <path d="M39 25C39 21.6863 41.6863 19 45 19H51C54.3137 19 57 21.6863 57 25V31H39V25Z" fill="#FFE4D6" stroke="#FF6B2F" stroke-width="3" stroke-linejoin="round"/>
  <rect x="32" y="30" width="32" height="38" rx="10" fill="#FFFFFF" stroke="#FF6B2F" stroke-width="3"/>
  <path d="M39 68H57V74C57 77.3137 54.3137 80 51 80H45C41.6863 80 39 77.3137 39 74V68Z" fill="#FFE4D6" stroke="#FF6B2F" stroke-width="3" stroke-linejoin="round"/>
  <path d="M64 43H67C68.1046 43 69 43.8954 69 45V51C69 52.1046 68.1046 53 67 53H64" stroke="#FF6B2F" stroke-width="3" stroke-linecap="round"/>
  <path d="M41 49L46 54L56 42" stroke="#2E8C3D" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

enum _WearableOperationTarget { vylaWearable, other }

class ConnectedDevicesScreen extends ConsumerStatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  ConsumerState<ConnectedDevicesScreen> createState() =>
      _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState
    extends ConsumerState<ConnectedDevicesScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _error;
  String? _status;
  Gtl1WatchDevice? _connectedDevice;
  Gtl1DailyHealthData? _localTodayPayload;
  DateTime? _lastSyncedAt;
  int? _batteryLevel;
  bool _isCharging = false;
  bool _phoneNotificationsEnabled = true;
  bool _isUpdatingWatchSettings = false;
  _WearableOperationTarget? _activeOperationTarget;
  String? _activeProviderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restorePairingOrScan();
      }
    });
  }

  Future<void> _restorePairingOrScan() async {
    final repository = ref.read(gtl1WatchSyncRepositoryProvider);
    final pairing = await repository.getPairedPhoraWear();
    if (!mounted) return;
    if (pairing == null) {
      setState(() {
        _status = 'Choose a wearable or health source to connect.';
        _error = null;
      });
      return;
    }
    setState(() {
      _isConnected = true;
      _activeProviderId = WearableProviderIds.vylaWearable;
      _connectedDevice = Gtl1WatchDevice(
        id: pairing.deviceId,
        name: pairing.displayName,
        metadata: {
          if (pairing.deviceName != null) 'deviceName': pairing.deviceName,
          if (pairing.manufacturerMac != null)
            'manufacturerMac': pairing.manufacturerMac,
          if (pairing.manufacturerPrefix != null)
            'manufacturerPrefix': pairing.manufacturerPrefix,
        },
      );
      _status =
          pairing.lastSyncedAt == null
              ? 'Vyla Wear paired. Syncing when available...'
              : 'Vyla Wear paired. Last sync data is available.';
      _lastSyncedAt = pairing.lastSyncedAt;
      _error = null;
    });
    unawaited(_refreshBatteryLevel());
    unawaited(_loadWatchSettings());
    unawaited(ref.read(phoraWearSyncControllerProvider.notifier).start());
  }

  Future<void> _loadWatchSettings() async {
    try {
      final enabled =
          await ref
              .read(gtl1WatchSyncRepositoryProvider)
              .getPhoneNotificationsEnabled();
      if (!mounted) return;
      setState(() {
        _phoneNotificationsEnabled = enabled;
      });
    } catch (error) {
      debugPrint('[VylaWear] Watch settings read failed: $error');
    }
  }

  Future<void> _refreshBatteryLevel() async {
    try {
      final battery =
          await ref.read(gtl1WatchSyncRepositoryProvider).getPairedBattery();
      debugPrint(
        '[VylaWear] Battery level collected: ${battery.level}%, charging=${battery.isCharging}',
      );
      if (!mounted) return;
      setState(() {
        _batteryLevel = battery.level.clamp(0, 100);
        _isCharging = battery.isCharging;
      });
    } catch (error) {
      debugPrint('[VylaWear] Battery read failed: $error');
    }
  }

  Future<void> _scanAndAutoConnect() async {
    if (_activeOperationTarget != null) {
      return;
    }
    debugPrint('[VylaWear] Connect tapped. Starting scan...');
    setState(() {
      _activeOperationTarget = _WearableOperationTarget.vylaWearable;
      _isScanning = true;
      _isConnecting = false;
      _error = null;
      _status = 'Scanning for Vyla Wear...';
    });

    try {
      final repository = ref.read(gtl1WatchSyncRepositoryProvider);
      final devices = await repository.scanDevices();
      final gtl1Devices = devices.where(_isGtl1Device).toList();
      debugPrint(
        '[VylaWear] Scan finished. total=${devices.length}, gtl1=${gtl1Devices.length}, '
        'devices=${devices.map((device) => '${device.name}/${device.id}/${device.rssi}').join(', ')}',
      );
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });

      if (gtl1Devices.isEmpty) {
        debugPrint('[VylaWear] No supported Vyla Wear device found.');
        setState(() {
          _status =
              devices.isEmpty
                  ? 'No Vyla Wear found nearby.'
                  : 'No Vyla Wear device identified.';
          _error =
              devices.isEmpty
                  ? 'Keep Vyla Wear nearby with Bluetooth and location enabled, then try again.'
                  : 'Only Vyla Wear is supported for automatic pairing.';
          _activeOperationTarget = null;
        });
        return;
      }

      gtl1Devices.sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
      debugPrint(
        '[VylaWear] Auto-connecting strongest device: '
        '${gtl1Devices.first.name}/${gtl1Devices.first.id}/${gtl1Devices.first.rssi}',
      );
      await _connect(gtl1Devices.first);
    } catch (error) {
      debugPrint('[VylaWear] Scan/connect flow failed: $error');
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _isConnecting = false;
        _activeOperationTarget = null;
        _status = 'Scan failed';
        _error = _friendlyBluetoothError(error);
      });
    }
  }

  Future<void> _connect(Gtl1WatchDevice device) async {
    if (!_isGtl1Device(device)) {
      setState(() {
        _isScanning = false;
        _isConnecting = false;
        _activeOperationTarget = null;
        _status = 'Unsupported wearable';
        _error = 'Only GTL1 Vyla Wear devices can be connected.';
      });
      return;
    }
    debugPrint('[VylaWear] Connecting to ${device.name}/${device.id}...');
    setState(() {
      _activeOperationTarget = _WearableOperationTarget.vylaWearable;
      _activeProviderId = WearableProviderIds.vylaWearable;
      _isConnecting = true;
      _error = null;
      _status = 'Connecting to Vyla Wear...';
    });

    try {
      final repository = ref.read(gtl1WatchSyncRepositoryProvider);
      await repository.connect(device.id);
      debugPrint(
        '[VylaWear] BLE connect completed for ${device.id}. Saving pairing...',
      );
      final pairing = await repository.savePairing(device);
      try {
        final battery = await repository.getBattery();
        debugPrint(
          '[VylaWear] Battery level collected after connect: ${battery.level}%, charging=${battery.isCharging}',
        );
        if (mounted) {
          setState(() {
            _batteryLevel = battery.level.clamp(0, 100);
            _isCharging = battery.isCharging;
          });
        }
      } catch (error) {
        debugPrint('[VylaWear] Battery read after connect failed: $error');
      }
      try {
        final phoneNotificationsEnabled =
            await repository.getPhoneNotificationsEnabled();
        if (mounted) {
          setState(() {
            _phoneNotificationsEnabled = phoneNotificationsEnabled;
          });
        }
      } catch (error) {
        debugPrint(
          '[VylaWear] Watch settings read after connect failed: $error',
        );
      }
      await ref
          .read(onboardingRepositoryProvider)
          .submitWearable(
            wearableType: 'gtl1',
            metadata: {
              'display_device_type': 'phora_wear',
              'stable_identifier': pairing.stableIdentifier,
              'device_id': device.id,
              'device_name': _rawDeviceName(device),
              'manufacturer_mac': device.metadata['manufacturerMac'],
              'manufacturer_prefix': device.metadata['manufacturerPrefix'],
              'is_starmax': device.metadata['isStarmax'] == true,
              if (device.rssi != null) 'rssi': device.rssi,
            },
          );

      var syncMessage = "Vyla Wear connected. Syncing today's readings...";
      if (mounted) {
        setState(() {
          _isConnected = true;
          _activeProviderId = WearableProviderIds.vylaWearable;
          _connectedDevice = device;
          _status = syncMessage;
        });
      }

      try {
        debugPrint('[VylaWear] Updating GTL1 watch time from app...');
        await repository.syncPairedDeviceTime();
        debugPrint('[VylaWear] Collecting GTL1 readings after connect...');
        final payload = await repository.collectPairedToday();
        _logGtl1Payload('sync-after-connect', payload);
        if (mounted) {
          setState(() {
            _localTodayPayload = payload;
          });
        }
        await repository.uploadPairedDailyData(payload);
        final syncedAt = DateTime.now();
        debugPrint('[VylaWear] Sync after connect completed.');
        syncMessage = 'Vyla Wear connected and synced readings.';
        if (mounted) {
          setState(() {
            _lastSyncedAt = syncedAt;
          });
        }
      } catch (error) {
        debugPrint('[VylaWear] Sync after connect failed: $error');
        syncMessage =
            'Vyla Wear connected. Readings will update after the next successful sync.';
      }

      await ref.read(homeDashboardProvider.notifier).refresh();
      ref.invalidate(wearableConnectionStatusesProvider);
      unawaited(ref.read(phoraWearSyncControllerProvider.notifier).start());
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _status = syncMessage;
      });
    } catch (error) {
      debugPrint('[VylaWear] BLE connect failed: $error');
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _isConnected = false;
        _status = 'Connection failed';
        _error = _friendlyBluetoothError(error);
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _activeOperationTarget = _WearableOperationTarget.vylaWearable;
      _isConnecting = true;
      _error = null;
      _status = 'Disconnecting wearable...';
    });
    try {
      await ref.read(gtl1WatchSyncRepositoryProvider).disconnect();
      await ref.read(gtl1WatchSyncRepositoryProvider).clearPairing();
      await ref
          .read(onboardingRepositoryProvider)
          .submitWearable(wearableType: 'none');
      ref.read(phoraWearSyncControllerProvider.notifier).stop();
      await ref.read(homeDashboardProvider.notifier).refresh();
      ref.invalidate(wearableConnectionStatusesProvider);
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _isConnected = false;
        _activeProviderId = null;
        _connectedDevice = null;
        _localTodayPayload = null;
        _lastSyncedAt = null;
        _batteryLevel = null;
        _isCharging = false;
        _phoneNotificationsEnabled = true;
        _status = 'Wearable disconnected.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _error = _friendlyBluetoothError(error);
      });
    }
  }

  Future<void> _syncConnectedDevice() async {
    debugPrint('[VylaWear][sync-now] Sync now action started.');
    setState(() {
      _activeOperationTarget = _WearableOperationTarget.vylaWearable;
      _isConnecting = true;
      _error = null;
      _status = 'Syncing recent readings from Vyla Wear...';
    });

    try {
      final repository = ref.read(gtl1WatchSyncRepositoryProvider);
      debugPrint('[VylaWear][sync-now] Updating GTL1 watch time from app...');
      await repository.syncPairedDeviceTime();
      unawaited(_refreshBatteryLevel());
      debugPrint('[VylaWear][sync-now] Collecting recent GTL1 data...');
      final payload = await repository.collectPairedToday();
      _logGtl1Payload('sync-now', payload);
      if (!mounted) return;
      setState(() {
        _localTodayPayload = payload;
        _status = 'Collected GTL1 readings locally. Uploading...';
      });
      debugPrint('[VylaWear][sync-now] Uploading collected GTL1 data...');
      await repository.uploadPairedDailyData(payload);
      final syncedAt = DateTime.now();
      debugPrint('[VylaWear][sync-now] Backend upload completed.');
      await ref.read(homeDashboardProvider.notifier).refresh();
      ref.invalidate(wearableConnectionStatusesProvider);
      unawaited(ref.read(phoraWearSyncControllerProvider.notifier).start());
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _lastSyncedAt = syncedAt;
        _status = "Vyla Wear synced today's readings.";
      });
    } catch (error) {
      debugPrint('[VylaWear][sync-now] Sync now failed: $error');
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _status = 'Sync failed';
        _error = _friendlyBluetoothError(error);
      });
    }
  }

  Future<void> _updatePhoneNotificationsEnabled(bool enabled) async {
    setState(() {
      _isUpdatingWatchSettings = true;
    });
    try {
      await ref
          .read(gtl1WatchSyncRepositoryProvider)
          .setPhoneNotificationsEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _phoneNotificationsEnabled = enabled;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyBluetoothError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingWatchSettings = false;
        });
      }
    }
  }

  Future<void> _handleProviderSelected(
    WearableProviderDescriptor provider,
  ) async {
    if (_activeOperationTarget != null) {
      return;
    }
    if (provider.id == WearableProviderIds.vylaWearable) {
      await _scanAndAutoConnect();
      return;
    }

    setState(() {
      _activeOperationTarget = _operationTargetForProvider(provider.id);
      _isConnecting = true;
      _error = null;
      _status = 'Connecting ${provider.name}...';
      _localTodayPayload = null;
    });

    try {
      final repo = ref.read(wearableRepositoryProvider);
      await repo.connect(provider.id);
      await repo.sync(provider.id);
      await ref.read(homeDashboardProvider.notifier).refresh();
      ref.invalidate(wearableConnectionStatusesProvider);
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _isConnected = true;
        _activeProviderId = provider.id;
        _connectedDevice = null;
        _lastSyncedAt = DateTime.now();
        _status = '${provider.name} connected and synced.';
      });
    } catch (error) {
      if (!mounted) return;
      final message =
          error is WearableConnectionException
              ? error.message
              : 'Could not connect ${provider.name}. Please try again.';
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _status = 'Connection needs attention';
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isScanning || _isConnecting;
    final busyProviderId = _busyProviderId(_activeOperationTarget);
    final dashboard = ref.watch(homeDashboardProvider).valueOrNull;
    final healthSnapshot = dashboard?.healthSnapshot;
    final providers = ref.watch(wearableProviderDescriptorsProvider);
    final providerStatuses =
        ref.watch(wearableConnectionStatusesProvider).valueOrNull ?? const [];
    final connectedProvider = _connectedProviderDescriptor(
      providers,
      providerStatuses,
      preferredProviderId: _activeProviderId,
    );
    final hasConnectedDevice = _isConnected || connectedProvider != null;
    final connectedDeviceName =
        _connectedDevice != null
            ? _displayDeviceName(_connectedDevice)
            : connectedProvider?.name ?? 'Connected device';
    final connectedStatus =
        providerStatuses
            .where((s) => s.isConnected)
            .cast<WearableConnectionStatus?>()
            .firstOrNull;
    final effectiveLastSyncedAt =
        connectedStatus?.lastSyncedAt ?? _lastSyncedAt;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child:
              hasConnectedDevice
                  ? _ConnectedWearableView(
                    key: const ValueKey('connected-wearable'),
                    busy: busy,
                    deviceName: connectedDeviceName,
                    healthSnapshot: healthSnapshot,
                    mainStatus: dashboard?.mainStatus,
                    fertility: dashboard?.fertility,
                    cyclePredictionImpact: dashboard?.cyclePredictionImpact,
                    deviceTrends: dashboard?.deviceTrends ?? const [],
                    localTodayPayload: _localTodayPayload,
                    batteryLevel: _batteryLevel,
                    isCharging: _isCharging,
                    lastSyncedAt: effectiveLastSyncedAt,
                    status: _status,
                    providers: providers,
                    providerStatuses: providerStatuses,
                    busyProviderId: busyProviderId,
                    onBack: _goBack,
                    onSync:
                        busy
                            ? null
                            : (_connectedDevice == null
                                ? null
                                : _syncConnectedDevice),
                    onDisconnect: busy ? null : _disconnectActiveConnection,
                    onProviderSelected:
                        busy
                            ? null
                            : (provider) => _handleProviderSelected(provider),
                    showWatchNotificationSetting:
                        defaultTargetPlatform == TargetPlatform.iOS &&
                        _connectedDevice != null,
                    phoneNotificationsEnabled: _phoneNotificationsEnabled,
                    onPhoneNotificationsChanged:
                        busy || _isUpdatingWatchSettings
                            ? null
                            : _updatePhoneNotificationsEnabled,
                  )
                  : _ConnectWearableView(
                    key: const ValueKey('connect-wearable'),
                    busy: busy,
                    status: _status,
                    error: _error,
                    providers: providers,
                    providerStatuses: providerStatuses,
                    busyProviderId: busyProviderId,
                    onBack: _goBack,
                    onProviderSelected:
                        busy
                            ? null
                            : (provider) => _handleProviderSelected(provider),
                  ),
        ),
      ),
    );
  }

  void _goBack() {
    context.go('/today');
  }

  WearableProviderDescriptor? _connectedProviderDescriptor(
    List<WearableProviderDescriptor> providers,
    List<WearableConnectionStatus> statuses, {
    String? preferredProviderId,
  }) {
    if (preferredProviderId != null) {
      for (final provider in providers) {
        if (provider.id == preferredProviderId) {
          return provider;
        }
      }
    }
    for (final status in statuses) {
      if (!status.isConnected) {
        continue;
      }
      for (final provider in providers) {
        if (provider.id == status.providerId) {
          return provider;
        }
      }
    }
    return null;
  }

  Future<void> _disconnectActiveConnection() async {
    if (_activeOperationTarget != null) {
      return;
    }
    final statuses =
        ref.read(wearableConnectionStatusesProvider).valueOrNull ?? const [];
    WearableConnectionStatus? connectedStatus;
    if (_activeProviderId != null) {
      for (final status in statuses) {
        if (status.providerId == _activeProviderId && status.isConnected) {
          connectedStatus = status;
          break;
        }
      }
    }
    for (final status in statuses) {
      if (connectedStatus != null) {
        break;
      }
      if (status.isConnected) {
        connectedStatus = status;
        break;
      }
    }

    final providerId = connectedStatus?.providerId ?? _activeProviderId;
    if (providerId == null || providerId == WearableProviderIds.vylaWearable) {
      await _disconnect();
      return;
    }

    setState(() {
      _activeOperationTarget = _operationTargetForProvider(providerId);
      _isConnecting = true;
      _status = 'Disconnecting wearable...';
      _error = null;
    });

    try {
      await ref.read(wearableRepositoryProvider).disconnect(providerId);
      ref.invalidate(wearableConnectionStatusesProvider);
      await ref.read(homeDashboardProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _isConnected = false;
        _activeProviderId = null;
        _status = 'Wearable disconnected.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _activeOperationTarget = null;
        _status = 'Could not disconnect wearable.';
        _error = error.toString();
      });
    }
  }
}

_WearableOperationTarget _operationTargetForProvider(String providerId) {
  return switch (providerId) {
    WearableProviderIds.vylaWearable => _WearableOperationTarget.vylaWearable,
    _ => _WearableOperationTarget.other,
  };
}

String? _busyProviderId(_WearableOperationTarget? target) {
  return switch (target) {
    _WearableOperationTarget.vylaWearable => WearableProviderIds.vylaWearable,
    _WearableOperationTarget.other => '',
    null => null,
  };
}

class _ConnectWearableView extends StatelessWidget {
  const _ConnectWearableView({
    super.key,
    required this.busy,
    required this.status,
    required this.error,
    required this.providers,
    required this.providerStatuses,
    required this.busyProviderId,
    required this.onBack,
    required this.onProviderSelected,
  });

  final bool busy;
  final String? status;
  final String? error;
  final List<WearableProviderDescriptor> providers;
  final List<WearableConnectionStatus> providerStatuses;
  final String? busyProviderId;
  final VoidCallback onBack;
  final ValueChanged<WearableProviderDescriptor>? onProviderSelected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return _WearableBackground(
      child: Column(
        children: [
          _WearableTopBar(title: 'Connect Wearable', onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                dims.scaleWidth(18),
                dims.scaleSpace(8),
                dims.scaleWidth(18),
                dims.scaleSpace(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ConnectHero(),
                  SizedBox(height: dims.scaleSpace(28)),
                  _SectionTitle('Benefits'),
                  SizedBox(height: dims.scaleSpace(10)),
                  _BenefitsPanel(
                    benefits: const [
                      _BenefitData(
                        icon: Icons.trending_up_rounded,
                        label: 'More accurate\npredictions',
                        color: Color(0xFFFF7C68),
                        tint: Color(0xFFFFE5DE),
                      ),
                      _BenefitData(
                        icon: Icons.nightlight_round,
                        label: 'Better sleep\ninsights',
                        color: Color(0xFF2EAD68),
                        tint: Color(0xFFDDF4E5),
                      ),
                      _BenefitData(
                        icon: Icons.favorite_border_rounded,
                        label: 'Heart rate\ntrends',
                        color: Color(0xFF258CE7),
                        tint: Color(0xFFDCEEFF),
                      ),
                      _BenefitData(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Activity\ntracking',
                        color: Color(0xFF9B58D2),
                        tint: Color(0xFFEEDDF9),
                      ),
                    ],
                  ),
                  SizedBox(height: dims.scaleSpace(28)),
                  _SectionTitle('Connect wearable'),
                  SizedBox(height: dims.scaleSpace(10)),
                  _WearableProvidersPanel(
                    providers: providers,
                    statuses: providerStatuses,
                    busy: busy,
                    busyProviderId: busyProviderId,
                    connectedOnly: false,
                    onProviderSelected: onProviderSelected,
                  ),
                  if (status != null || error != null) ...[
                    SizedBox(height: dims.scaleSpace(12)),
                    _ConnectionStatusCard(
                      busy: busy,
                      status: status,
                      error: error,
                    ),
                  ],
                  SizedBox(height: dims.scaleSpace(22)),
                  const _DataSafetyCard(),
                  SizedBox(height: dims.scaleSpace(22)),
                  const _HelpRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedWearableView extends StatelessWidget {
  const _ConnectedWearableView({
    super.key,
    required this.busy,
    required this.deviceName,
    required this.healthSnapshot,
    required this.mainStatus,
    required this.fertility,
    required this.cyclePredictionImpact,
    required this.deviceTrends,
    required this.localTodayPayload,
    required this.batteryLevel,
    required this.isCharging,
    required this.lastSyncedAt,
    required this.status,
    required this.providers,
    required this.providerStatuses,
    required this.busyProviderId,
    required this.onBack,
    required this.onSync,
    required this.onDisconnect,
    required this.onProviderSelected,
    required this.showWatchNotificationSetting,
    required this.phoneNotificationsEnabled,
    required this.onPhoneNotificationsChanged,
  });

  final bool busy;
  final String deviceName;
  final HomeHealthSnapshot? healthSnapshot;
  final HomeMainStatus? mainStatus;
  final HomeFertility? fertility;
  final HomeCyclePredictionImpact? cyclePredictionImpact;
  final List<HomeDeviceTrend> deviceTrends;
  final Gtl1DailyHealthData? localTodayPayload;
  final int? batteryLevel;
  final bool isCharging;
  final DateTime? lastSyncedAt;
  final String? status;
  final List<WearableProviderDescriptor> providers;
  final List<WearableConnectionStatus> providerStatuses;
  final String? busyProviderId;
  final VoidCallback onBack;
  final VoidCallback? onSync;
  final VoidCallback? onDisconnect;
  final ValueChanged<WearableProviderDescriptor>? onProviderSelected;
  final bool showWatchNotificationSetting;
  final bool phoneNotificationsEnabled;
  final ValueChanged<bool>? onPhoneNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return _WearableBackground(
      child: Column(
        children: [
          _WearableTopBar(
            title: 'Device Connected',
            onBack: onBack,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'disconnect') {
                  onDisconnect?.call();
                }
              },
              enabled: onDisconnect != null,
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: 'disconnect',
                      child: Text('Disconnect wearable'),
                    ),
                  ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                dims.scaleWidth(18),
                dims.scaleSpace(8),
                dims.scaleWidth(18),
                dims.scaleSpace(28),
              ),
              child: Column(
                children: [
                  _ConnectedHero(
                    busy: busy,
                    deviceName: deviceName,
                    batteryLevel: batteryLevel,
                    isCharging: isCharging,
                    lastSyncedAt: lastSyncedAt,
                    status: status,
                    onSync: onSync,
                  ),
                  SizedBox(height: dims.scaleSpace(16)),
                  _WearableProvidersPanel(
                    providers: providers,
                    statuses: providerStatuses,
                    busy: busy,
                    busyProviderId: busyProviderId,
                    connectedOnly: true,
                    onProviderSelected: onProviderSelected,
                  ),
                  SizedBox(height: dims.scaleSpace(14)),
                  _TodaysHighlightsCard(
                    snapshot: healthSnapshot,
                    localPayload: localTodayPayload,
                    sourceLabel: 'Vyla wearable',
                  ),
                  SizedBox(height: dims.scaleSpace(14)),
                  _CycleImpactCard(
                    snapshot: healthSnapshot,
                    localPayload: localTodayPayload,
                    fallbackLastSyncedAt: lastSyncedAt,
                    predictionImpact: cyclePredictionImpact,
                  ),
                  SizedBox(height: dims.scaleSpace(14)),
                  _CycleInsightsCard(
                    mainStatus: mainStatus,
                    fertility: fertility,
                  ),
                  SizedBox(height: dims.scaleSpace(14)),
                  _PredictionImprovementCard(impact: cyclePredictionImpact),
                  if (showWatchNotificationSetting) ...[
                    SizedBox(height: dims.scaleSpace(14)),
                    _WatchSettingsCard(
                      phoneNotificationsEnabled: phoneNotificationsEnabled,
                      onPhoneNotificationsChanged: onPhoneNotificationsChanged,
                    ),
                  ],
                  SizedBox(height: dims.scaleSpace(14)),
                  _DeviceTrendsCard(trends: deviceTrends),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WearableBackground extends StatelessWidget {
  const _WearableBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: isDark ? colors.bg : const Color(0xFFFFFBF7),
      child: child,
    );
  }
}

class _WearableTopBar extends StatelessWidget {
  const _WearableTopBar({
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(14),
        dims.scaleWidth(18),
        dims.scaleSpace(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: isDark ? colors.bgElevated : const Color(0xFFFFF4ED),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: Padding(
                padding: EdgeInsets.all(dims.scaleWidth(16)),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: dims.scaleText(20),
                  color: isDark ? colors.textPrimary : const Color(0xFF5A2A18),
                ),
              ),
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: dims.scaleSpace(8),
                right: trailing == null ? dims.scaleWidth(56) : 0,
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: dims.scaleText(32),
                  height: 1,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w500,
                  color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: dims.scaleWidth(12)),
            Material(
              color: isDark ? colors.bgElevated : const Color(0xFFFFF4ED),
              shape: const CircleBorder(),
              child: SizedBox(
                width: dims.scaleWidth(52),
                height: dims.scaleWidth(52),
                child: IconTheme(
                  data: IconThemeData(
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF5A2A18),
                  ),
                  child: trailing!,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectHero extends StatelessWidget {
  const _ConnectHero();

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Center(
      child: Column(
        children: [
          SizedBox(
            width: dims.scaleWidth(132),
            height: dims.scaleWidth(104),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(left: 4, top: 35, child: _TinySparkle()),
                const Positioned(
                  right: 5,
                  top: 20,
                  child: _TinySparkle(size: 11),
                ),
                SvgPicture.string(
                  _wearableHeartWatchSvg,
                  width: dims.scaleWidth(96),
                  height: dims.scaleWidth(96),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          Text(
            'Sync your data,\nunderstand your body better',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: AppTheme.headingFontFamily,
              fontSize: dims.scaleText(16),
              height: 1.2,
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: dims.scaleSpace(10)),
          Text(
            'Connect your wearable to automatically track\nactivity, sleep, heart rate, and more.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: dims.scaleText(12),
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchSettingsCard extends StatelessWidget {
  const _WatchSettingsCard({
    required this.phoneNotificationsEnabled,
    required this.onPhoneNotificationsChanged,
  });

  final bool phoneNotificationsEnabled;
  final ValueChanged<bool>? onPhoneNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SoftCard(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(14),
        dims.scaleWidth(16),
        dims.scaleSpace(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(42),
            height: dims.scaleWidth(42),
            decoration: BoxDecoration(
              color: isDark ? colors.bgSurface : const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mirror phone notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(14),
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  'Turn this off to stop call and app alerts from waking the watch and draining battery.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(8)),
          Switch.adaptive(
            value: phoneNotificationsEnabled,
            onChanged: onPhoneNotificationsChanged,
          ),
        ],
      ),
    );
  }
}

class _BenefitsPanel extends StatelessWidget {
  const _BenefitsPanel({required this.benefits});

  final List<_BenefitData> benefits;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return _SoftCard(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(14),
        vertical: dims.scaleSpace(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < benefits.length; i++) ...[
            Expanded(child: _BenefitItem(benefit: benefits[i])),
            if (i != benefits.length - 1)
              Container(
                width: 1,
                height: dims.scaleHeight(74),
                margin: EdgeInsets.symmetric(horizontal: dims.scaleWidth(6)),
                color: colors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.benefit});

  final _BenefitData benefit;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Column(
      children: [
        Container(
          width: dims.scaleWidth(54),
          height: dims.scaleWidth(54),
          decoration: BoxDecoration(
            color: benefit.tint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            benefit.icon,
            size: dims.scaleText(20),
            color: benefit.color,
          ),
        ),
        SizedBox(height: dims.scaleSpace(12)),
        Text(
          benefit.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: dims.scaleText(9.5),
            height: 1.35,
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BenefitData {
  const _BenefitData({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
}

class _WearableProvidersPanel extends StatelessWidget {
  const _WearableProvidersPanel({
    required this.providers,
    required this.statuses,
    required this.busy,
    required this.busyProviderId,
    required this.connectedOnly,
    required this.onProviderSelected,
  });

  final List<WearableProviderDescriptor> providers;
  final List<WearableConnectionStatus> statuses;
  final bool busy;
  final String? busyProviderId;
  final bool connectedOnly;
  final ValueChanged<WearableProviderDescriptor>? onProviderSelected;

  @override
  Widget build(BuildContext context) {
    final anyConnected = statuses.any((s) => s.isConnected);
    final visibleProviders =
        connectedOnly || anyConnected
            ? providers
                .where((p) => _statusFor(p.id)?.isConnected == true)
                .toList()
            : providers;

    if (visibleProviders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (final provider in visibleProviders)
          Padding(
            padding: EdgeInsets.only(bottom: context.dims.scaleSpace(10)),
            child: _WearableProviderTile(
              descriptor: provider,
              status: _statusFor(provider.id),
              busy: busy,
              isBusy: busyProviderId == provider.id,
              onTap:
                  onProviderSelected == null || busy
                      ? null
                      : () => onProviderSelected!(provider),
            ),
          ),
      ],
    );
  }

  WearableConnectionStatus? _statusFor(String providerId) {
    for (final status in statuses) {
      if (status.providerId == providerId) {
        return status;
      }
    }
    return null;
  }
}

class _WearableProviderTile extends StatelessWidget {
  const _WearableProviderTile({
    required this.descriptor,
    required this.status,
    required this.busy,
    required this.isBusy,
    required this.onTap,
  });

  final WearableProviderDescriptor descriptor;
  final WearableConnectionStatus? status;
  final bool busy;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = status?.isConnected == true;

    return _SoftCard(
      padding: EdgeInsets.all(dims.scaleWidth(14)),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(58),
            height: dims.scaleWidth(58),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isDark
                      ? colors.bgSurface
                      : descriptor.accentColor.withValues(alpha: 0.13),
            ),
            child: Icon(
              descriptor.icon,
              color: descriptor.accentColor,
              size: dims.scaleText(28),
            ),
          ),
          SizedBox(width: dims.scaleWidth(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descriptor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(12.5),
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(2)),
                Text(
                  descriptor.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(9.5),
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (status?.lastSyncedAt != null) ...[
                  SizedBox(height: dims.scaleSpace(5)),
                  Text(
                    'Last sync ${_relativeSyncTime(status!.lastSyncedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: dims.scaleText(8.8),
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(10)),
          if (connected)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(6)),
              child: Text(
                'Connected',
                style: TextStyle(
                  fontSize: dims.scaleText(9.5),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2EAD68),
                ),
              ),
            )
          else
            _ConnectButton(onPressed: onTap, busy: isBusy),
        ],
      ),
    );
  }

  String _relativeSyncTime(DateTime lastSync) {
    final difference = DateTime.now().difference(lastSync);
    if (difference.inMinutes < 1) {
      return 'just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.onPressed, required this.busy});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? colors.bgSurface : const Color(0xFFFFEEE8);
    final foregroundColor =
        isDark ? colors.textPrimary : const Color(0xFF3B170F);

    return SizedBox(
      width: dims.scaleWidth(96),
      height: dims.scaleHeight(44),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.6),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
          ),
        ),
        child:
            busy
                ? SizedBox.square(
                  dimension: dims.scaleWidth(18),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(
                  'Connect',
                  style: TextStyle(
                    fontSize: dims.scaleText(9.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.busy,
    required this.status,
    required this.error,
  });

  final bool busy;
  final String? status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return _SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            SizedBox.square(
              dimension: dims.scaleWidth(20),
              child: const CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Icon(
              error == null
                  ? Icons.bluetooth_searching_rounded
                  : Icons.info_outline_rounded,
              color: error == null ? colors.accentInfo : colors.accentDanger,
            ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Text(
              error ?? status ?? 'Ready to scan',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    error == null ? colors.textSecondary : colors.accentDanger,
                fontSize: dims.scaleText(9.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataSafetyCard extends StatelessWidget {
  const _DataSafetyCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SoftCard(
      color: isDark ? colors.bgCard : const Color(0xFFFFF4F0),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(64),
            height: dims.scaleWidth(64),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? colors.accentPrimary.withValues(alpha: 0.16)
                      : const Color(0xFFFFE3DC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              color: const Color(0xFFFF6E5E),
              size: dims.scaleText(32),
            ),
          ),
          SizedBox(width: dims.scaleWidth(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data is safe with us',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(7)),
                Text(
                  'We never share your data. All data is encrypted and stored securely.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(9.5),
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textPrimary),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.help_outline_rounded,
          size: dims.scaleText(20),
          color: colors.textTertiary,
        ),
        SizedBox(width: dims.scaleWidth(12)),
        Flexible(
          child: Text(
            'Need help connecting your device?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(9.5),
              color: colors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: dims.scaleWidth(8)),
        Icon(
          Icons.chevron_right_rounded,
          size: dims.scaleText(20),
          color: colors.textTertiary,
        ),
      ],
    );
  }
}

class _ConnectedHero extends StatelessWidget {
  const _ConnectedHero({
    required this.busy,
    required this.deviceName,
    required this.batteryLevel,
    required this.isCharging,
    required this.lastSyncedAt,
    required this.status,
    required this.onSync,
  });

  final bool busy;
  final String deviceName;
  final int? batteryLevel;
  final bool isCharging;
  final DateTime? lastSyncedAt;
  final String? status;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < dims.scaleWidth(360);
        final deviceIcon = SizedBox(
          width: compact ? dims.scaleWidth(96) : dims.scaleWidth(124),
          height: compact ? dims.scaleWidth(96) : dims.scaleWidth(124),
          child: Center(
            child: SvgPicture.string(
              _wearableHeartWatchSvg,
              width: compact ? dims.scaleWidth(85) : dims.scaleWidth(107),
              height: compact ? dims.scaleWidth(85) : dims.scaleWidth(107),
            ),
          ),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoundMetricIcon(
                  icon: Icons.check_rounded,
                  color: const Color(0xFF16A366),
                  tint: const Color(0xFFDDF4E5),
                  size: 36,
                ),
                SizedBox(width: dims.scaleWidth(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: dims.scaleText(12),
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: dims.scaleSpace(15)),
            Wrap(
              spacing: dims.scaleWidth(10),
              runSpacing: dims.scaleSpace(6),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (batteryLevel != null)
                  _InlineIconLabel(
                    icon:
                        isCharging
                            ? Icons.battery_charging_full_rounded
                            : Icons.battery_5_bar_rounded,
                    iconColor: colors.accentSuccess,
                    label: _batteryDisplay(batteryLevel, isCharging),
                    maxWidth: dims.scaleWidth(96),
                  ),
                _InlineIconLabel(
                  icon: Icons.sync_rounded,
                  iconColor: colors.textTertiary,
                  label: status ?? 'Ready to sync',
                  maxWidth:
                      compact ? constraints.maxWidth : dims.scaleWidth(174),
                ),
              ],
            ),
            SizedBox(height: dims.scaleSpace(14)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(12),
                vertical: dims.scaleSpace(10),
              ),
              decoration: BoxDecoration(
                color: isDark ? colors.bgSurface : const Color(0xFFFFF3EF),
                borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
                border: Border.all(
                  color: isDark ? colors.border : const Color(0xFFF4DED7),
                ),
              ),
              child: Row(
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: dims.scaleWidth(17),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.sync_rounded,
                      color: colors.textSecondary,
                      size: dims.scaleText(16),
                    ),
                  SizedBox(width: dims.scaleWidth(8)),
                  Expanded(
                    child: Text(
                      _lastSyncDisplay(lastSyncedAt),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: dims.scaleText(10),
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onSync,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(
                        horizontal: dims.scaleWidth(6),
                        vertical: dims.scaleSpace(4),
                      ),
                    ),
                    child: Text(
                      'Sync now',
                      style: TextStyle(
                        color: const Color(0xFFFF5E55),
                        fontSize: dims.scaleText(10),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              deviceIcon,
              SizedBox(height: dims.scaleSpace(10)),
              details,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            deviceIcon,
            SizedBox(width: dims.scaleWidth(18)),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _TodaysHighlightsCard extends StatelessWidget {
  const _TodaysHighlightsCard({
    required this.snapshot,
    required this.localPayload,
    required this.sourceLabel,
  });

  final HomeHealthSnapshot? snapshot;
  final Gtl1DailyHealthData? localPayload;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final highlights = _highlightMetrics(snapshot, localPayload, sourceLabel);

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: "Today's Highlights"),
          SizedBox(height: dims.scaleSpace(16)),
          if (highlights.isEmpty)
            _HighlightsEmptyState(
              message:
                  snapshot?.bodySignalMessage ??
                  'Tap Sync now to collect today\'s readings.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = dims.scaleWidth(8);
                final columns =
                    constraints.maxWidth >= dims.scaleWidth(420) ? 4 : 2;
                final itemWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                    columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: dims.scaleSpace(14),
                  children:
                      highlights
                          .map(
                            (metric) => SizedBox(
                              width: itemWidth,
                              child: _HighlightMetric(
                                icon: metric.icon,
                                value: metric.value,
                                label: metric.label,
                                sublabel: metric.sublabel,
                                color: metric.color,
                                tint: metric.tint,
                                progress: metric.progress,
                              ),
                            ),
                          )
                          .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _HighlightMetricData {
  const _HighlightMetricData({
    required this.icon,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.tint,
    required this.progress,
  });

  final IconData icon;
  final String value;
  final String label;
  final String sublabel;
  final Color color;
  final Color tint;
  final double progress;
}

class _HighlightsEmptyState extends StatelessWidget {
  const _HighlightsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(14),
        vertical: dims.scaleSpace(14),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : const Color(0xFFFFF3EF),
        borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF4DED7),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: dims.scaleText(11),
          height: 1.35,
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

List<_HighlightMetricData> _highlightMetrics(
  HomeHealthSnapshot? snapshot,
  Gtl1DailyHealthData? localPayload,
  String sourceLabel,
) {
  if (localPayload != null) {
    return _localHighlightMetrics(localPayload);
  }
  if (snapshot == null || snapshot.cycleSupportSignals.isEmpty) {
    return const [];
  }

  final sublabel = _wearableSourceSublabel(
    sourceLabel,
    snapshot.latestSyncedAt ?? snapshot.latestRecordedAt,
  );
  final metrics = <_HighlightMetricData>[];
  if (snapshot.sleepHours != null) {
    metrics.add(
      _HighlightMetricData(
        icon: Icons.nightlight_round,
        value: _wearableSleepDisplay(snapshot.sleepHours),
        label: 'Sleep',
        sublabel: sublabel,
        color: const Color(0xFF8E51D5),
        tint: const Color(0xFFEEDDF9),
        progress: _progress(snapshot.sleepHours!, max: 9),
      ),
    );
    if ((snapshot.sleepDeepMinutes ?? 0) > 0) {
      metrics.add(
        _HighlightMetricData(
          icon: Icons.dark_mode_rounded,
          value: _sleepStageDisplay(snapshot.sleepDeepMinutes),
          label: 'Deep sleep',
          sublabel: sublabel,
          color: const Color(0xFF6C4AD1),
          tint: const Color(0xFFEEE8FF),
          progress: _progress(snapshot.sleepDeepMinutes!.toDouble(), max: 180),
        ),
      );
    }
    if ((snapshot.sleepLightMinutes ?? 0) > 0) {
      metrics.add(
        _HighlightMetricData(
          icon: Icons.bedtime_outlined,
          value: _sleepStageDisplay(snapshot.sleepLightMinutes),
          label: 'Light sleep',
          sublabel: sublabel,
          color: const Color(0xFF8E51D5),
          tint: const Color(0xFFF3EAFE),
          progress: _progress(snapshot.sleepLightMinutes!.toDouble(), max: 360),
        ),
      );
    }
    if ((snapshot.sleepAwakeMinutes ?? 0) > 0) {
      metrics.add(
        _HighlightMetricData(
          icon: Icons.visibility_outlined,
          value: _sleepStageDisplay(snapshot.sleepAwakeMinutes),
          label: 'Wake time',
          sublabel: sublabel,
          color: const Color(0xFFF38A16),
          tint: const Color(0xFFFFEDD8),
          progress: _progress(snapshot.sleepAwakeMinutes!.toDouble(), max: 90),
        ),
      );
    }
  }
  if (snapshot.steps != null) {
    metrics.add(
      _HighlightMetricData(
        icon: Icons.directions_walk_rounded,
        value: _integerDisplay(snapshot.steps!),
        label: 'Steps',
        sublabel: sublabel,
        color: const Color(0xFF18A76B),
        tint: const Color(0xFFDDF4E5),
        progress: _progress(snapshot.steps!.toDouble(), max: 10000),
      ),
    );
  }
  if (snapshot.restingHeartRate != null) {
    metrics.add(
      _HighlightMetricData(
        icon: Icons.favorite_rounded,
        value: '${snapshot.restingHeartRate!.toStringAsFixed(0)} bpm',
        label: 'Resting HR',
        sublabel: sublabel,
        color: const Color(0xFFFF6262),
        tint: const Color(0xFFFFE2DF),
        progress: _progress(110 - snapshot.restingHeartRate!, max: 60),
      ),
    );
  }
  if (snapshot.bloodOxygenAvg != null) {
    metrics.add(
      _HighlightMetricData(
        icon: Icons.bloodtype_rounded,
        value: '${snapshot.bloodOxygenAvg!.toStringAsFixed(0)}%',
        label: 'SpO2',
        sublabel:
            snapshot.bloodOxygenMin != null
                ? 'Min ${snapshot.bloodOxygenMin!.toStringAsFixed(0)}%'
                : sublabel,
        color: const Color(0xFF258CE7),
        tint: const Color(0xFFDCEEFF),
        progress: _progress(snapshot.bloodOxygenAvg!, max: 100),
      ),
    );
  }
  if (snapshot.temperatureDeltaC != null) {
    metrics.add(
      _HighlightMetricData(
        icon: Icons.device_thermostat_rounded,
        value: '${snapshot.temperatureDeltaC!.toStringAsFixed(1)}°C',
        label: 'Temp',
        sublabel: sublabel,
        color: const Color(0xFF18A76B),
        tint: const Color(0xFFDDF4E5),
        progress: _progress(snapshot.temperatureDeltaC!.abs(), max: 1),
      ),
    );
  }
  if (snapshot.stressAvg != null) {
    metrics.add(
      _HighlightMetricData(
        icon: Icons.psychology_alt_outlined,
        value: snapshot.stressAvg!.toStringAsFixed(0),
        label: 'Stress',
        sublabel: sublabel,
        color: const Color(0xFFF38A16),
        tint: const Color(0xFFFFEDD8),
        progress: _progress(snapshot.stressAvg!, max: 100),
      ),
    );
  }
  if (snapshot.hrv != null) {
    metrics.add(
      _HighlightMetricData(
        icon: Icons.water_drop_rounded,
        value: snapshot.hrv!.toStringAsFixed(0),
        label: 'HRV',
        sublabel: sublabel,
        color: const Color(0xFF258CE7),
        tint: const Color(0xFFDCEEFF),
        progress: _progress(snapshot.hrv!, max: 100),
      ),
    );
  }
  return metrics;
}

List<_HighlightMetricData> _localHighlightMetrics(Gtl1DailyHealthData payload) {
  const sublabel = 'Loaded from Vyla wearable';
  final sleepHours = payload.sleep.totalMinutes / 60;
  return [
    _HighlightMetricData(
      icon: Icons.nightlight_round,
      value: _wearableSleepDisplay(sleepHours),
      label: 'Sleep',
      sublabel: sublabel,
      color: const Color(0xFF8E51D5),
      tint: const Color(0xFFEEDDF9),
      progress: _progress(sleepHours, max: 9),
    ),
    _HighlightMetricData(
      icon: Icons.directions_walk_rounded,
      value: _integerDisplay(payload.steps),
      label: 'Steps',
      sublabel: sublabel,
      color: const Color(0xFF18A76B),
      tint: const Color(0xFFDDF4E5),
      progress: _progress(payload.steps.toDouble(), max: 10000),
    ),
    _HighlightMetricData(
      icon: Icons.local_fire_department_rounded,
      value: '${payload.caloriesKcal.toStringAsFixed(1)} kcal',
      label: 'Energy',
      sublabel: sublabel,
      color: const Color(0xFFF38A16),
      tint: const Color(0xFFFFEDD8),
      progress: _progress(payload.caloriesKcal, max: 500),
    ),
    _HighlightMetricData(
      icon: Icons.route_rounded,
      value: _distanceDisplay(payload.distanceMeters),
      label: 'Distance',
      sublabel: sublabel,
      color: const Color(0xFF258CE7),
      tint: const Color(0xFFDCEEFF),
      progress: _progress(payload.distanceMeters / 1000, max: 8),
    ),
    _HighlightMetricData(
      icon: Icons.favorite_rounded,
      value: '${payload.heartRate.resting} bpm',
      label: 'Resting HR',
      sublabel: sublabel,
      color: const Color(0xFFFF6262),
      tint: const Color(0xFFFFE2DF),
      progress:
          payload.heartRate.resting <= 0
              ? _progress(0, max: 60)
              : _progress(110 - payload.heartRate.resting.toDouble(), max: 60),
    ),
    _HighlightMetricData(
      icon: Icons.monitor_heart_outlined,
      value: '${payload.heartRate.avg} bpm',
      label: 'Avg BPM',
      sublabel: sublabel,
      color: const Color(0xFFE8505B),
      tint: const Color(0xFFFFE7EA),
      progress: _progress(payload.heartRate.avg.toDouble(), max: 140),
    ),
    _HighlightMetricData(
      icon: Icons.trending_down_rounded,
      value: '${payload.heartRate.min} bpm',
      label: 'Min BPM',
      sublabel: sublabel,
      color: const Color(0xFF258CE7),
      tint: const Color(0xFFDCEEFF),
      progress: _progress(payload.heartRate.min.toDouble(), max: 120),
    ),
    _HighlightMetricData(
      icon: Icons.trending_up_rounded,
      value: '${payload.heartRate.max} bpm',
      label: 'Max BPM',
      sublabel: sublabel,
      color: const Color(0xFFFF6262),
      tint: const Color(0xFFFFE2DF),
      progress: _progress(payload.heartRate.max.toDouble(), max: 180),
    ),
    _HighlightMetricData(
      icon: Icons.bloodtype_rounded,
      value: '${payload.bloodOxygen.avg}%',
      label: 'SpO2 avg',
      sublabel: sublabel,
      color: const Color(0xFF258CE7),
      tint: const Color(0xFFDCEEFF),
      progress: _progress(payload.bloodOxygen.avg.toDouble(), max: 100),
    ),
    _HighlightMetricData(
      icon: Icons.air_rounded,
      value: '${payload.bloodOxygen.min}%',
      label: 'SpO2 min',
      sublabel: sublabel,
      color: const Color(0xFF258CE7),
      tint: const Color(0xFFDCEEFF),
      progress: _progress(payload.bloodOxygen.min.toDouble(), max: 100),
    ),
    _HighlightMetricData(
      icon: Icons.device_thermostat_rounded,
      value: '${payload.temperature.avg.toStringAsFixed(1)}°C',
      label: 'Temp',
      sublabel: sublabel,
      color: const Color(0xFF18A76B),
      tint: const Color(0xFFDDF4E5),
      progress: _progress(payload.temperature.avg.abs(), max: 40),
    ),
    _HighlightMetricData(
      icon: Icons.psychology_alt_outlined,
      value: payload.stress.avg.toString(),
      label: 'Stress',
      sublabel: sublabel,
      color: const Color(0xFFF38A16),
      tint: const Color(0xFFFFEDD8),
      progress: _progress(payload.stress.avg.toDouble(), max: 100),
    ),
  ];
}

double _progress(double value, {required double max}) {
  return (value / max).clamp(0.08, 1).toDouble();
}

String _wearableSleepDisplay(double? sleepHours) {
  if (sleepHours == null) {
    return '--';
  }
  final hours = sleepHours.floor();
  final minutes = ((sleepHours - hours) * 60).round();
  if (minutes == 60) {
    return '${hours + 1}h';
  }
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}m';
}

String _sleepStageDisplay(int? minutes) {
  if (minutes == null || minutes <= 0) {
    return '--';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) {
    return '${remainingMinutes}m';
  }
  if (remainingMinutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainingMinutes}m';
}

String _integerDisplay(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _distanceDisplay(double meters) {
  final kilometers = meters / 1000;
  if (kilometers >= 1) {
    return '${kilometers.toStringAsFixed(2)} km';
  }
  return '${meters.round()} m';
}

String _cyclePhaseLabel(String? phase) {
  final normalized = phase?.replaceAll('_', ' ').trim();
  if (normalized == null || normalized.isEmpty) {
    return 'CURRENT';
  }
  return normalized.toUpperCase();
}

String _dateLabel(DateTime? date) {
  if (date == null) {
    return '--';
  }
  return '${_monthName(date.month)} ${date.day}';
}

String _dateRangeLabel(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return '--';
  }
  if (start.month == end.month) {
    return '${_monthName(start.month)} ${start.day} - ${end.day}';
  }
  return '${_dateLabel(start)} - ${_dateLabel(end)}';
}

String _daysUntilLabel(DateTime? date) {
  if (date == null) {
    return '--';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final days = target.difference(today).inDays;
  if (days == 0) {
    return 'Today';
  }
  if (days < 0) {
    return '${days.abs()}d ago';
  }
  return 'In ${days}d';
}

String _rangeLengthLabel(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return '--';
  }
  final startDate = DateTime(start.year, start.month, start.day);
  final endDate = DateTime(end.year, end.month, end.day);
  final days = endDate.difference(startDate).inDays + 1;
  if (days <= 0) {
    return '--';
  }
  return days == 1 ? '1 day' : '$days days';
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) {
    return '';
  }
  return months[month - 1];
}

String _percentDisplay(double value) {
  return '${(value * 100).round()}%';
}

String _signalLabel(String signal) {
  return switch (signal) {
    'temperature' => 'Temperature shift',
    'resting_heart_rate' => 'Resting heart rate trend',
    'blood_oxygen' => 'Blood oxygen readings',
    'stress' => 'Stress level',
    'hrv' => 'HRV recovery trend',
    'sleep' => 'Sleep duration',
    'steps' => 'Activity level',
    _ => signal.replaceAll('_', ' '),
  };
}

String _methodLabel(String method) {
  return switch (method) {
    'calendar_fallback' => 'calendar update',
    'cusum_fallback' => 'temperature shift',
    'lh_fallback' => 'LH signal',
    'rf_direct' => 'ML model',
    _ => method.replaceAll('_', ' '),
  };
}

IconData _trendIcon(String metric) {
  return switch (metric) {
    'rhr' || 'heart_rate_avg' => Icons.favorite_rounded,
    'hrv' => Icons.health_and_safety_outlined,
    'sleep_minutes' => Icons.nightlight_round,
    'stress' => Icons.psychology_alt_outlined,
    'steps' => Icons.directions_walk_rounded,
    'calories_kcal' => Icons.local_fire_department_rounded,
    'distance_meters' => Icons.route_rounded,
    _ => Icons.show_chart_rounded,
  };
}

Color _trendColor(String metric) {
  return switch (metric) {
    'rhr' || 'heart_rate_avg' => const Color(0xFFFF6262),
    'hrv' => const Color(0xFF18A76B),
    'sleep_minutes' => const Color(0xFF8E51D5),
    'stress' => const Color(0xFFF38A16),
    'steps' => const Color(0xFF258CE7),
    'calories_kcal' => const Color(0xFFF38A16),
    'distance_meters' => const Color(0xFF258CE7),
    _ => const Color(0xFF8E51D5),
  };
}

String _trendValue(HomeDeviceTrend trend) {
  final value = trend.latestValue;
  if (value == null) {
    return '--';
  }
  return switch (trend.metric) {
    'sleep_minutes' => _wearableSleepDisplay(value / 60),
    'steps' => _integerDisplay(value.round()),
    'distance_meters' => _distanceDisplay(value),
    'calories_kcal' => '${value.toStringAsFixed(1)} kcal',
    'rhr' || 'heart_rate_avg' => '${value.toStringAsFixed(0)} bpm',
    'hrv' => '${value.toStringAsFixed(0)} ms',
    _ =>
      trend.unit == null
          ? value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)
          : '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} ${trend.unit}',
  };
}

String _trendDelta(HomeDeviceTrend trend) {
  final delta = trend.deltaPercent;
  if (delta == null) {
    return 'Latest reading';
  }
  final direction = delta >= 0 ? '+' : '';
  return '$direction${delta.toStringAsFixed(1)}% vs prior readings';
}

List<double> _normalizedTrendValues(List<HomeDeviceTrendPoint> points) {
  final values = points.map((point) => point.value).toList();
  if (values.length == 1) {
    return const [0.5, 0.5];
  }
  final minValue = values.reduce(math.min);
  final maxValue = values.reduce(math.max);
  final range = maxValue - minValue;
  if (range <= 0) {
    return List<double>.filled(values.length, 0.5);
  }
  return values
      .map((value) => ((value - minValue) / range).clamp(0.08, 1).toDouble())
      .toList();
}

String _latestSyncSublabel(DateTime? latestRecordedAt) {
  if (latestRecordedAt == null) {
    return 'Synced';
  }
  final local = latestRecordedAt.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return 'Today';
  }
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day';
}

String _wearableSourceSublabel(String sourceLabel, DateTime? latestRecordedAt) {
  final loadedFrom = 'Loaded from $sourceLabel';
  final syncLabel = _latestSyncSublabel(latestRecordedAt);
  return syncLabel == 'Synced' ? loadedFrom : '$loadedFrom · $syncLabel';
}

String _lastSyncDisplay(DateTime? syncedAt) {
  if (syncedAt == null) {
    return 'Last sync: Not synced yet';
  }
  final local = syncedAt.toLocal();
  final now = DateTime.now();
  final dateLabel =
      local.year == now.year && local.month == now.month && local.day == now.day
          ? 'Today'
          : '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  final hour = local.hour == 0 ? 12 : ((local.hour - 1) % 12) + 1;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return 'Last sync: $dateLabel, \n$hour:$minute $period';
}

String _batteryDisplay(int? batteryLevel, bool isCharging) {
  if (batteryLevel == null) {
    return 'Battery --';
  }
  return isCharging ? '$batteryLevel% charging' : '$batteryLevel% battery';
}

void _logGtl1Payload(String source, Gtl1DailyHealthData payload) {
  debugPrint(
    '[VylaWear][$source] collected date=${payload.date} '
    'steps=${payload.steps} '
    'calories=${payload.caloriesKcal.toStringAsFixed(1)}kcal '
    'distance=${(payload.distanceMeters / 1000).toStringAsFixed(3)}km '
    'sleep=${payload.sleep.totalMinutes}m '
    'deep=${payload.sleep.deepMinutes}m '
    'light=${payload.sleep.lightMinutes}m '
    'awake=${payload.sleep.awakeMinutes}m '
    'rhr=${payload.heartRate.resting} '
    'hrAvg=${payload.heartRate.avg} '
    'hrMin=${payload.heartRate.min} '
    'hrMax=${payload.heartRate.max} '
    'spo2Avg=${payload.bloodOxygen.avg} '
    'spo2Min=${payload.bloodOxygen.min} '
    'tempAvg=${payload.temperature.avg} '
    'stressAvg=${payload.stress.avg}',
  );
  debugPrint(
    '[VylaWear][$source] full payload=${jsonEncode(payload.toMap())}',
    wrapWidth: 1024,
  );
}

class _HighlightMetric extends StatelessWidget {
  const _HighlightMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.tint,
    required this.progress,
  });

  final IconData icon;
  final String value;
  final String label;
  final String sublabel;
  final Color color;
  final Color tint;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(4)),
      child: Column(
        children: [
          _RoundMetricIcon(icon: icon, color: color, tint: tint),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: dims.scaleText(12),
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(8.8),
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            sublabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(7.8),
              color: context.phora.colors.textSecondary,
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: dims.scaleHeight(5),
              value: progress,
              color: color,
              backgroundColor: color.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleImpactCard extends StatelessWidget {
  const _CycleImpactCard({
    required this.snapshot,
    required this.localPayload,
    required this.fallbackLastSyncedAt,
    required this.predictionImpact,
  });

  final HomeHealthSnapshot? snapshot;
  final Gtl1DailyHealthData? localPayload;
  final DateTime? fallbackLastSyncedAt;
  final HomeCyclePredictionImpact? predictionImpact;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assessment = _CycleImpactAssessment.fromData(
      snapshot: snapshot,
      localPayload: localPayload,
      fallbackLastSyncedAt: fallbackLastSyncedAt,
      predictionImpact: predictionImpact,
    );

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Cycle Impact',
            info: true,
            action: 'How it works',
          ),
          SizedBox(height: dims.scaleSpace(18)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ImpactItem(
                  icon: Icons.directions_walk_rounded,
                  title: 'Activity',
                  body: assessment.activityText,
                  color: const Color(0xFF18A76B),
                  tint: const Color(0xFFDDF4E5),
                ),
              ),
              Expanded(
                child: _ImpactItem(
                  icon: Icons.nightlight_round,
                  title: 'Sleep',
                  body: assessment.sleepText,
                  color: const Color(0xFF8E51D5),
                  tint: const Color(0xFFEEDDF9),
                ),
              ),
              Expanded(
                child: _ImpactItem(
                  icon: Icons.favorite_rounded,
                  title: 'Resting HR',
                  body: assessment.recoveryText,
                  color: const Color(0xFFFF6262),
                  tint: const Color(0xFFFFE2DF),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(16)),
          _SoftCard(
            color: isDark ? colors.bgSurface : const Color(0xFFFFF4F0),
            padding: EdgeInsets.all(dims.scaleWidth(12)),
            child: Row(
              children: [
                const _FlowerIcon(size: 40),
                SizedBox(width: dims.scaleWidth(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assessment.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: dims.scaleText(9.5),
                          color: context.phora.colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        assessment.body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: dims.scaleText(8.3),
                          color: context.phora.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.scaleWidth(16),
                    vertical: dims.scaleSpace(6),
                  ),
                  decoration: BoxDecoration(
                    color: assessment.tint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    assessment.label,
                    style: TextStyle(
                      color: assessment.color,
                      fontSize: dims.scaleText(8.8),
                      fontWeight: FontWeight.w800,
                    ),
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

class _CycleImpactAssessment {
  const _CycleImpactAssessment({
    required this.label,
    required this.title,
    required this.body,
    required this.activityText,
    required this.sleepText,
    required this.recoveryText,
    required this.color,
    required this.tint,
  });

  final String label;
  final String title;
  final String body;
  final String activityText;
  final String sleepText;
  final String recoveryText;
  final Color color;
  final Color tint;

  factory _CycleImpactAssessment.fromData({
    required HomeHealthSnapshot? snapshot,
    required Gtl1DailyHealthData? localPayload,
    required DateTime? fallbackLastSyncedAt,
    required HomeCyclePredictionImpact? predictionImpact,
  }) {
    final lastSync =
        fallbackLastSyncedAt ??
        snapshot?.latestSyncedAt ??
        snapshot?.latestRecordedAt;
    final stale =
        lastSync == null ||
        DateTime.now().difference(lastSync.toLocal()).inHours > 36;
    final sleepHours =
        localPayload != null
            ? localPayload.sleep.totalMinutes / 60
            : snapshot?.sleepHours;
    final stress =
        localPayload != null && localPayload.stress.avg > 0
            ? localPayload.stress.avg.toDouble()
            : snapshot?.stressAvg;
    final restingHr =
        localPayload != null && localPayload.heartRate.resting > 0
            ? localPayload.heartRate.resting.toDouble()
            : snapshot?.restingHeartRate;
    final steps =
        localPayload != null && localPayload.steps > 0
            ? localPayload.steps
            : snapshot?.steps;
    final signalCount =
        snapshot?.cycleSupportSignals.length ??
        [
          sleepHours,
          stress,
          restingHr,
          steps,
        ].where((value) => value != null).length;
    final periodShiftDays = _periodShiftDays(predictionImpact);
    final hasPeriodImpact =
        predictionImpact != null &&
        (predictionImpact.afterPeriodDate != null ||
            predictionImpact.confidenceAfter > 0 ||
            predictionImpact.explanation.isNotEmpty);

    var score = stale ? -2 : 2;
    if ((sleepHours ?? 0) >= 7) {
      score += 2;
    } else if ((sleepHours ?? 0) >= 5.5) {
      score += 1;
    } else if (sleepHours != null) {
      score -= 1;
    }
    if (stress != null && stress > 0) {
      if (stress <= 35) {
        score += 2;
      } else if (stress <= 60) {
        score += 1;
      } else {
        score -= 2;
      }
    }
    if (restingHr != null && restingHr > 0) {
      if (restingHr <= 75) {
        score += 1;
      } else if (restingHr >= 90) {
        score -= 1;
      }
    }
    if ((steps ?? 0) >= 6000) {
      score += 1;
    }
    if (signalCount >= 3) {
      score += 1;
    }

    final label =
        score >= 5
            ? 'Great'
            : score >= 2
            ? 'Good'
            : 'Poor';
    final title =
        hasPeriodImpact
            ? _periodImpactTitle(predictionImpact, periodShiftDays)
            : label == 'Great'
            ? 'Synced data is supporting your period estimate'
            : label == 'Good'
            ? 'Synced data is usable for period context'
            : 'Period impact needs more reliable data';
    final body =
        hasPeriodImpact
            ? _periodImpactBody(predictionImpact, periodShiftDays)
            : label == 'Great'
            ? 'Sleep, recovery, stress, and activity signals are giving Vyla stronger context for your next period.'
            : label == 'Good'
            ? 'Your device data is useful, but one or more signals could still add uncertainty to the next period estimate.'
            : 'Signals are stale, missing, or under strain, so the next period estimate should stay cautious.';

    return _CycleImpactAssessment(
      label: label,
      title: title,
      body: body,
      activityText:
          steps == null
              ? 'No step data synced yet.'
              : steps >= 6000
              ? 'Activity looks supportive today.'
              : 'Lower activity may shape energy and period comfort.',
      sleepText:
          sleepHours == null
              ? 'Sleep data has not synced yet.'
              : sleepHours >= 7
              ? 'Sleep duration supports cleaner overnight signals.'
              : 'Shorter sleep can make temperature and HR signals noisier.',
      recoveryText:
          restingHr == null
              ? 'Resting HR is still waiting for synced data.'
              : restingHr <= 75
              ? 'Resting HR suggests steadier recovery context.'
              : 'Elevated resting HR can reduce cycle-signal confidence.',
      color:
          label == 'Great'
              ? const Color(0xFF14784F)
              : label == 'Good'
              ? const Color(0xFFF38A16)
              : const Color(0xFFC03434),
      tint:
          label == 'Great'
              ? const Color(0xFFDDF4E5)
              : label == 'Good'
              ? const Color(0xFFFFEDD8)
              : const Color(0xFFFFE2DF),
    );
  }
}

int? _periodShiftDays(HomeCyclePredictionImpact? impact) {
  final before = impact?.beforePeriodDate;
  final after = impact?.afterPeriodDate;
  if (before == null || after == null) {
    return null;
  }
  return DateTime(
    after.year,
    after.month,
    after.day,
  ).difference(DateTime(before.year, before.month, before.day)).inDays;
}

String _periodImpactTitle(
  HomeCyclePredictionImpact? impact,
  int? periodShiftDays,
) {
  final after = impact?.afterPeriodDate;
  if (after == null) {
    return 'Device data is updating your period estimate';
  }
  final shift =
      periodShiftDays == null || periodShiftDays == 0
          ? 'confirmed'
          : periodShiftDays > 0
          ? 'moved later'
          : 'moved earlier';
  return 'Device data $shift your next period estimate';
}

String _periodImpactBody(
  HomeCyclePredictionImpact? impact,
  int? periodShiftDays,
) {
  final explanation = impact?.explanation.trim();
  if (explanation != null && explanation.isNotEmpty) {
    return explanation;
  }
  final confidence =
      impact?.confidenceAfter != null && impact!.confidenceAfter > 0
          ? ' Confidence is now ${_percentDisplay(impact.confidenceAfter)}.'
          : '';
  if (periodShiftDays == null || periodShiftDays == 0) {
    return 'Recent device signals support the current next-period date.$confidence';
  }
  final days = periodShiftDays.abs();
  final direction = periodShiftDays > 0 ? 'later' : 'earlier';
  return 'Recent device signals adjusted the next-period date $days day${days == 1 ? '' : 's'} $direction.$confidence';
}

class _ImpactItem extends StatelessWidget {
  const _ImpactItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(4)),
      child: Column(
        children: [
          _RoundMetricIcon(icon: icon, color: color, tint: tint),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(9.5),
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(7.3),
              height: 1.28,
              color: context.phora.colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleInsightsCard extends StatelessWidget {
  const _CycleInsightsCard({required this.mainStatus, required this.fertility});

  final HomeMainStatus? mainStatus;
  final HomeFertility? fertility;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phase = mainStatus?.currentPhase ?? mainStatus?.currentPhaseRaw;
    final phaseLabel = _cyclePhaseLabel(phase);
    final cycleDayLabel =
        mainStatus?.currentCycleDay == null
            ? 'Cycle day --'
            : 'Cycle Day ${mainStatus!.currentCycleDay}';
    final nextPeriod = mainStatus?.nextPredictedPeriodDate;
    final ovulation = fertility?.predictedOvulationDate;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Cycle Insights',
            action: 'View calendar',
            onActionTap: () => context.go('/cycle'),
          ),
          SizedBox(height: dims.scaleSpace(14)),
          Row(
            children: [
              CyclePhaseRing(
                currentPhase: phase ?? 'unknown',
                fertileToday: fertility?.fertileToday ?? false,
                nextPeriodDate: nextPeriod,
                nextOvulationDate: ovulation,
                size: dims.scaleWidth(140),
                strokeWidth: dims.scaleWidth(14),
                backgroundColor:
                    isDark ? colors.bgSurface : const Color(0xFFFFF2ED),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _FlowerIcon(size: 22),
                    Text(
                      '$phaseLabel\nPHASE',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFamily: AppTheme.headingFontFamily,
                        fontSize: dims.scaleText(8.8),
                        color: context.phora.colors.textPrimary,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(3)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: dims.scaleWidth(8),
                        vertical: dims.scaleSpace(3),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDF4E5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        cycleDayLabel,
                        style: TextStyle(
                          color: const Color(0xFF14784F),
                          fontSize: dims.scaleText(8.4),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(18)),
              Expanded(
                child: Column(
                  children: [
                    _DateInsightRow(
                      icon: Icons.water_drop_rounded,
                      iconColor: const Color(0xFFFF6262),
                      label: 'Next period',
                      value: _dateLabel(nextPeriod),
                      trailing: _daysUntilLabel(nextPeriod),
                    ),
                    _DateInsightRow(
                      icon: Icons.wb_sunny_rounded,
                      iconColor: const Color(0xFF258CE7),
                      label: 'Next ovulation',
                      value: _dateLabel(ovulation),
                      trailing: _daysUntilLabel(ovulation),
                    ),
                    _FertileWindowRow(
                      start: fertility?.fertileWindowStart,
                      end: fertility?.fertileWindowEnd,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateInsightRow extends StatelessWidget {
  const _DateInsightRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(11)),
      child: Row(
        children: [
          _RoundMetricIcon(
            icon: icon,
            color: iconColor,
            tint: const Color(0xFFFFF0EF),
            size: 38,
          ),
          SizedBox(width: dims.scaleWidth(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(8.3),
                    color: context.phora.colors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    color: context.phora.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(7.8),
              color: context.phora.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FertileWindowRow extends StatelessWidget {
  const _FertileWindowRow({required this.start, required this.end});

  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(dims.scaleWidth(12)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : const Color(0xFFFFF4F0),
        borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const _TinySparkle(size: 18),
          SizedBox(width: dims.scaleWidth(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fertile window',
                  style: TextStyle(
                    color: const Color(0xFFFF5E55),
                    fontSize: dims.scaleText(8.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _dateRangeLabel(start, end),
                  style: TextStyle(
                    color: context.phora.colors.textPrimary,
                    fontSize: dims.scaleText(9.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _rangeLengthLabel(start, end),
            style: TextStyle(
              color: context.phora.colors.textSecondary,
              fontSize: dims.scaleText(7.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionImprovementCard extends StatelessWidget {
  const _PredictionImprovementCard({required this.impact});

  final HomeCyclePredictionImpact? impact;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = impact ?? const HomeCyclePredictionImpact.empty();
    final signals =
        data.contributingSignals.isEmpty
            ? ['Cycle history only']
            : data.contributingSignals.map(_signalLabel).toList();
    final confidenceLabel =
        data.confidenceAfter > 0
            ? 'Confidence ${_percentDisplay(data.confidenceAfter)}'
            : 'Awaiting signal confidence';

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Cycle Predictions Improved by Your Data',
            info: true,
          ),
          SizedBox(height: dims.scaleSpace(14)),
          Row(
            children: [
              Expanded(
                child: _PredictionMiniPanel(
                  title: 'Before wearable data',
                  accent: context.phora.colors.textTertiary,
                  items: [
                    'Ovulation\n${_dateLabel(data.beforeOvulationDate)}',
                    'Period\n${_dateLabel(data.beforePeriodDate)}',
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(10)),
                child: Container(
                  width: dims.scaleWidth(36),
                  height: dims.scaleWidth(36),
                  decoration: BoxDecoration(
                    color: isDark ? colors.bgSurface : const Color(0xFFFFE4DE),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isDark
                              ? colors.border.withValues(alpha: 0.75)
                              : Colors.transparent,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFFFF6E5E),
                  ),
                ),
              ),
              Expanded(
                child: _PredictionMiniPanel(
                  title:
                      data.method == null
                          ? 'After body signals'
                          : 'After ${_methodLabel(data.method!)}',
                  accent: const Color(0xFF18A76B),
                  items: [
                    'Ovulation\n${_dateLabel(data.afterOvulationDate)}',
                    'Period\n${_dateLabel(data.afterPeriodDate)}',
                  ],
                  checked: true,
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(14)),
          _SoftCard(
            color: isDark ? colors.bgSurface : const Color(0xFFFFF7F4),
            padding: EdgeInsets.all(dims.scaleWidth(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CheckLine(confidenceLabel),
                ...signals.take(4).map((signal) => _CheckLine(signal)),
                if (data.explanation.isNotEmpty) _CheckLine(data.explanation),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionMiniPanel extends StatelessWidget {
  const _PredictionMiniPanel({
    required this.title,
    required this.accent,
    required this.items,
    this.checked = false,
  });

  final String title;
  final Color accent;
  final List<String> items;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accent,
            fontSize: dims.scaleText(8.3),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: dims.scaleSpace(8)),
        Row(
          children:
              items
                  .map(
                    (item) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: dims.scaleWidth(6)),
                        padding: EdgeInsets.all(dims.scaleWidth(9)),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? colors.bgSurface
                                  : const Color(0xFFFFF5F1),
                          borderRadius: BorderRadius.circular(
                            dims.scaleRadius(12),
                          ),
                          border: Border.all(
                            color:
                                isDark
                                    ? colors.border.withValues(alpha: 0.7)
                                    : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item,
                              style: TextStyle(
                                color: context.phora.colors.textPrimary,
                                fontSize: dims.scaleText(7.8),
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(6)),
                            SizedBox(
                              height: dims.scaleHeight(20),
                              child: CustomPaint(
                                painter: _SparklinePainter(
                                  color: accent.withValues(alpha: .7),
                                  values: const [.2, .5, .35, .7, .45, .66],
                                ),
                              ),
                            ),
                            if (checked)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: const Color(0xFF18A76B),
                                  size: dims.scaleText(13.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }
}

class _DeviceTrendsCard extends StatelessWidget {
  const _DeviceTrendsCard({required this.trends});

  final List<HomeDeviceTrend> trends;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final visibleTrends =
        trends.where((trend) => trend.points.isNotEmpty).take(6).toList();

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: 'Trends from your device', action: 'View all'),
          SizedBox(height: dims.scaleSpace(14)),
          if (visibleTrends.isEmpty)
            Text(
              'Sync your wearable to build trend lines from backend readings.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(10.5),
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = dims.scaleWidth(8);
                final columns =
                    constraints.maxWidth >= dims.scaleWidth(420) ? 3 : 2;
                final itemWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                    columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: dims.scaleSpace(12),
                  children:
                      visibleTrends
                          .map(
                            (trend) => SizedBox(
                              width: itemWidth,
                              child: _TrendMetric(
                                icon: _trendIcon(trend.metric),
                                title: trend.label,
                                value: _trendValue(trend),
                                delta: _trendDelta(trend),
                                color: _trendColor(trend.metric),
                                values: _normalizedTrendValues(trend.points),
                              ),
                            ),
                          )
                          .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TrendMetric extends StatelessWidget {
  const _TrendMetric({
    required this.icon,
    required this.title,
    required this.value,
    required this.delta,
    required this.color,
    required this.values,
  });

  final IconData icon;
  final String title;
  final String value;
  final String delta;
  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Padding(
      padding: EdgeInsets.only(right: dims.scaleWidth(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: dims.scaleText(13.5)),
              SizedBox(width: dims.scaleWidth(4)),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(7.3),
                    color: context.phora.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(5)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: dims.scaleText(9.5),
              color: context.phora.colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            delta,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(8.4),
              color: context.phora.colors.textSecondary,
            ),
          ),
          SizedBox(
            height: dims.scaleHeight(30),
            child: CustomPaint(
              painter: _SparklinePainter(color: color, values: values),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    this.info = false,
    this.action,
    this.onActionTap,
  });

  final String title;
  final bool info;
  final String? action;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: AppTheme.headingFontFamily,
                    fontSize: dims.scaleText(12),
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (info) ...[
                SizedBox(width: dims.scaleWidth(6)),
                Icon(
                  Icons.info_outline_rounded,
                  size: dims.scaleText(16),
                  color: colors.textSecondary,
                ),
              ],
            ],
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(4),
                vertical: dims.scaleSpace(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    style: TextStyle(
                      color: const Color(0xFFFF5E55),
                      fontSize: dims.scaleText(8.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFFFF5E55),
                    size: dims.scaleText(16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(5)),
      child: Row(
        children: [
          Icon(
            Icons.check_rounded,
            color: const Color(0xFFB65A44),
            size: dims.scaleText(13.5),
          ),
          SizedBox(width: dims.scaleWidth(7)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: dims.scaleText(8.3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineIconLabel extends StatelessWidget {
  const _InlineIconLabel({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.maxWidth,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: dims.scaleText(16)),
        SizedBox(width: dims.scaleWidth(5)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(8.3),
              color: context.phora.colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundMetricIcon extends StatelessWidget {
  const _RoundMetricIcon({
    required this.icon,
    required this.color,
    required this.tint,
    this.size = 46,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final scaledSize = dims.scaleWidth(size);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: scaledSize,
      height: scaledSize,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      foregroundDecoration:
          isDark
              ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.18)),
              )
              : null,
      child: Icon(icon, color: color, size: scaledSize * .56),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: context.dims.scaleText(12),
        color: context.phora.colors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color:
            color ??
            (isDark ? colors.bgCard : Colors.white.withValues(alpha: 0.92)),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF2E3DE),
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFFE9BBB0).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.color, required this.values});

  final Color color;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i].clamp(0, 1) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .18), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.values != values;
  }
}

class _TinySparkle extends StatelessWidget {
  const _TinySparkle({this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparklePainter()),
    );
  }
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..moveTo(size.width / 2, 0)
          ..quadraticBezierTo(
            size.width * .62,
            size.height * .38,
            size.width,
            size.height / 2,
          )
          ..quadraticBezierTo(
            size.width * .62,
            size.height * .62,
            size.width / 2,
            size.height,
          )
          ..quadraticBezierTo(
            size.width * .38,
            size.height * .62,
            0,
            size.height / 2,
          )
          ..quadraticBezierTo(
            size.width * .38,
            size.height * .38,
            size.width / 2,
            0,
          );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF9A8E).withValues(alpha: .72)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlowerIcon extends StatelessWidget {
  const _FlowerIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FlowerPainter(outline: false)),
    );
  }
}

class _FlowerPainter extends CustomPainter {
  const _FlowerPainter({required this.outline});

  final bool outline;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint =
        Paint()
          ..color = const Color(
            0xFFFF8F80,
          ).withValues(alpha: outline ? .18 : .9)
          ..style = outline ? PaintingStyle.stroke : PaintingStyle.stroke
          ..strokeWidth = outline ? 2.0 : 1.7;

    for (var i = 0; i < 6; i++) {
      final angle = (math.pi * 2 / 6) * i;
      final petalCenter = Offset(
        center.dx + math.cos(angle) * size.width * .24,
        center.dy + math.sin(angle) * size.height * .24,
      );
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * .2,
          height: size.height * .42,
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.drawCircle(center, size.width * .11, paint);
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter oldDelegate) {
    return oldDelegate.outline != outline;
  }
}

bool _isGtl1Device(Gtl1WatchDevice device) {
  final name = _rawDeviceName(device).toLowerCase();
  return name.contains('gtl1');
}

String _displayDeviceName(Gtl1WatchDevice? device) {
  final name = _rawDeviceName(device);
  if (name.trim().isEmpty) {
    return 'Vyla Wearable';
  }
  if (_isGtl1RawName(name)) {
    return 'Vyla Wearable';
  }
  return name;
}

String _rawDeviceName(Gtl1WatchDevice? device) {
  if (device == null) {
    return 'Vyla Wearable';
  }
  final metadataName = device.metadata['deviceName'];
  if (metadataName is String && metadataName.trim().isNotEmpty) {
    return metadataName.trim();
  }
  if (device.name.trim().isNotEmpty) {
    return device.name.trim();
  }
  return 'Vyla Wearable';
}

bool _isGtl1RawName(String name) {
  final normalized = name.trim().toLowerCase();
  return normalized.startsWith('gtl1') || normalized.contains('gtl1-');
}

String _friendlyBluetoothError(Object error) {
  final text = error.toString();
  if (text.contains('bluetooth_disabled')) {
    return 'Turn on Bluetooth, keep the watch nearby, then scan again.';
  }
  if (text.contains('location') || text.contains('permission')) {
    return 'Allow Bluetooth and location permissions so Vyla can find your watch.';
  }
  if (text.contains('connect_failed')) {
    return 'The watch could not be connected. Keep it awake and close to your phone, then try again.';
  }
  return text.replaceFirst('Exception: ', '');
}
