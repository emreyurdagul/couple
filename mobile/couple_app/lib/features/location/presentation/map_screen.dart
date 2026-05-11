import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/tokens.dart';
import '../data/location_models.dart';
import '../state/location_controller.dart';
import 'widgets/history_window_picker.dart';
import 'widgets/together_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng? _centerOf(LocationState s) {
    if (s.myLast != null && s.partnerLast != null) {
      return LatLng(
        (s.myLast!.latitude + s.partnerLast!.latitude) / 2,
        (s.myLast!.longitude + s.partnerLast!.longitude) / 2,
      );
    }
    final any = s.myLast ?? s.partnerLast;
    if (any != null) return LatLng(any.latitude, any.longitude);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationControllerProvider);
    final controller = ref.read(locationControllerProvider.notifier);
    final center = _centerOf(state) ?? const LatLng(41.0082, 28.9784); // İstanbul default

    final togetherNow = _withinThreshold(state.myLast, state.partnerLast);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.tileUrlTemplate,
                userAgentPackageName: AppConfig.userAgentPackageName,
                maxZoom: 19,
              ),
              if (state.myHistory.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: state.myHistory
                          .map((d) => LatLng(d.latitude, d.longitude))
                          .toList(growable: false),
                      strokeWidth: 3,
                      color: AppColors.inkSoft.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              if (state.partnerHistory.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: state.partnerHistory
                          .map((d) => LatLng(d.latitude, d.longitude))
                          .toList(growable: false),
                      strokeWidth: 3,
                      color: AppColors.stamp.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers(state, togetherNow)),
            ],
          ),
          // Üst overlay — back + segmented control
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    _CircleIcon(
                      icon: Icons.arrow_back,
                      onTap: () => context.go('/'),
                    ),
                    const Spacer(),
                    HistoryWindowPicker(
                      value: state.historyWindow,
                      onChanged: controller.setHistoryWindow,
                    ),
                    const Spacer(),
                    _CircleIcon(
                      icon: Icons.my_location,
                      onTap: () {
                        final c = _centerOf(state);
                        if (c != null) {
                          _mapController.move(c, _mapController.camera.zoom);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Alt kart — "bugün X dk beraber"
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _TogetherTodayCard(
                  minutes: state.togetherTodayMinutes,
                  loading: state.loading,
                  error: state.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(LocationState s, bool togetherNow) {
    final markers = <Marker>[];
    if (togetherNow && s.myLast != null && s.partnerLast != null) {
      // Tek "biz" imleci — merkez noktaya
      final midLat = (s.myLast!.latitude + s.partnerLast!.latitude) / 2;
      final midLng = (s.myLast!.longitude + s.partnerLast!.longitude) / 2;
      markers.add(
        Marker(
          width: 64,
          height: 80,
          point: LatLng(midLat, midLng),
          alignment: Alignment.topCenter,
          child: const TogetherMarker(myInitial: 'B', partnerInitial: 'P'),
        ),
      );
      return markers;
    }
    if (s.myLast != null) {
      markers.add(_singleMarker(
        s.myLast!,
        color: AppColors.paperDeep,
        borderColor: AppColors.rule,
        textColor: AppColors.ink,
        label: 'B',
      ));
    }
    if (s.partnerLast != null) {
      markers.add(_singleMarker(
        s.partnerLast!,
        color: AppColors.stamp,
        borderColor: AppColors.stampDeep,
        textColor: AppColors.paper,
        label: 'P',
      ));
    }
    return markers;
  }

  Marker _singleMarker(
    LocationDto dto, {
    required Color color,
    required Color borderColor,
    required Color textColor,
    required String label,
  }) {
    return Marker(
      width: 44,
      height: 44,
      point: LatLng(dto.latitude, dto.longitude),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.fraunces(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: textColor,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

bool _withinThreshold(LocationDto? a, LocationDto? b) {
  if (a == null || b == null) return false;
  final distance = const Distance().as(
    LengthUnit.Meter,
    LatLng(a.latitude, a.longitude),
    LatLng(b.latitude, b.longitude),
  );
  return distance < AppConfig.togetherMergeMeters;
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paper,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.rule),
        ),
        child: Icon(icon, color: AppColors.inkSoft, size: 20),
      ),
    );
  }
}

class _TogetherTodayCard extends StatelessWidget {
  const _TogetherTodayCard({
    required this.minutes,
    required this.loading,
    required this.error,
  });

  final int minutes;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.rule),
        boxShadow: AppElevation.page,
      ),
      child: Row(
        children: [
          Text(
            'bugün',
            style: GoogleFonts.fraunces(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.inkMute,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (error != null)
            Expanded(
              child: Text(
                error!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            )
          else if (loading && minutes == 0)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _format(minutes),
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: AppColors.stamp,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'beraber',
                    style: GoogleFonts.fraunces(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _format(int minutes) {
    if (minutes < 60) return '$minutes dk';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
  }
}

