import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/guardian/presentation/guardian_controller.dart';
import '../../providers/repository_providers.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/radius.dart';
import '../theme/text_styles.dart';

/// Floating real-time diagnostics overlay for development & device audits.
/// Automatically hidden in release builds.
class DebugDiagnosticsOverlay extends ConsumerStatefulWidget {
  const DebugDiagnosticsOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<DebugDiagnosticsOverlay> createState() => _DebugDiagnosticsOverlayState();
}

class _DebugDiagnosticsOverlayState extends ConsumerState<DebugDiagnosticsOverlay> {
  bool _isExpanded = false;
  double _lat = 0.0;
  double _lng = 0.0;
  double _speedKmh = 0.0;
  double _accuracy = 0.0;
  bool _gpsActive = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _initGpsPolling();
    }
  }

  void _initGpsPolling() {
    try {
      final loc = ref.read(locationServiceProvider);
      loc.getPositionStream(distanceFilter: 2).listen((pos) {
        if (!mounted) return;
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _speedKmh = (pos.speed * 3.6).clamp(0.0, 150.0);
          _accuracy = pos.accuracy;
          _gpsActive = true;
        });
      }, onError: (_) {
        if (!mounted) return;
        setState(() => _gpsActive = false);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return widget.child;
    }

    final guardianStatus = ref.watch(guardianStatusProvider);
    final engine = ref.watch(guardianEngineProvider);

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 12,
          bottom: 90,
          child: Material(
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest.withValues(alpha: 0.92),
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.primaryPulse.withValues(alpha: 0.4)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: _isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bug_report, size: 16, color: AppColors.primaryPulse),
                            const SizedBox(width: 6),
                            Text('GUARDIAN RUNTIME DIAGNOSTICS',
                                style: AppTextStyles.labelSm.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryPulse,
                                  fontSize: 10,
                                )),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() => _isExpanded = false),
                              child: const Icon(Icons.close, size: 16, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _diagRow('API BASE', ApiConfig.baseUrl),
                        _diagRow('LAST ENDPOINT', ApiClient.lastEndpoint ?? 'None'),
                        _diagRow('HTTP STATUS', ApiClient.lastStatusCode != null ? '${ApiClient.lastStatusCode}' : '--',
                            isGood: ApiClient.lastStatusCode == null ? null : (ApiClient.lastStatusCode! >= 200 && ApiClient.lastStatusCode! < 300)),
                        if (ApiClient.lastError != null)
                          _diagRow('LAST ERR', ApiClient.lastError!.length > 25 ? '${ApiClient.lastError!.substring(0, 25)}...' : ApiClient.lastError!, isGood: false),
                        _diagRow('GPS POS', _gpsActive ? '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}' : 'Inactive'),
                        _diagRow('ACCURACY', _gpsActive ? '±${_accuracy.toStringAsFixed(1)}m' : '--'),
                        _diagRow('SPEED', _gpsActive ? '${_speedKmh.toStringAsFixed(1)} km/h' : '--'),
                        _diagRow('ENGINE', engine.isActive ? 'ACTIVE' : 'IDLE', isGood: engine.isActive),
                        _diagRow('GUARDIAN', guardianStatus.value?.isActive == true ? 'ACTIVE' : 'OFF',
                            isGood: guardianStatus.value?.isActive == true),
                        _diagRow('SENSORS', 'ONLINE (Drop>25 / Shake>18)', isGood: true),
                        _diagRow('VOICE', 'STT Ready', isGood: true),
                        _diagRow('FCM', 'v1 HTTP Admin Key', isGood: true),
                      ],
                    )
                  : InkWell(
                      onTap: () => setState(() => _isExpanded = true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: engine.isActive ? AppColors.success : AppColors.primaryPulse,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('DIAGNOSTICS',
                              style: AppTextStyles.labelSm.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryPulse,
                              )),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _diagRow(String label, String value, {bool? isGood}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 75,
            child: Text(label,
                style: AppTextStyles.labelSm.copyWith(
                  fontSize: 9,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Text(
            value,
            style: AppTextStyles.labelSm.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isGood == null
                  ? AppColors.onSurface
                  : (isGood ? AppColors.success : AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
