import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

// Default fallback: central Cairo. Used when the caller has no prior pin and
// geolocation permission is refused/unavailable so the user still sees a
// useful map instead of the middle of the Atlantic.
const LatLng _defaultCenter = LatLng(30.0444, 31.2357);

/// Full-screen OpenStreetMap picker. The pin stays fixed at screen-center and
/// the map pans beneath it (standard rideshare UX). Caller awaits the result;
/// `null` means cancelled.
class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final String? titleEn;
  final String? titleAr;

  const MapPickerScreen({
    super.key,
    this.initial,
    this.titleEn,
    this.titleAr,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _center;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? _defaultCenter;
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    try {
      final svcOn = await Geolocator.isLocationServiceEnabled();
      if (!svcOn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEn
              ? 'Turn on device location to use this.'
              : 'فعّل خدمة الموقع لاستخدام هذه الميزة.'),
        ));
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        // Android 12+ / iOS: once "Don't ask again" is set, requestPermission
        // becomes a no-op. Offer a deep-link to settings so the user has a
        // path out instead of being stuck on the same snackbar.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEn
              ? 'Location is blocked in settings. Open settings to enable it.'
              : 'تم حظر الموقع من الإعدادات. افتح الإعدادات للسماح به.'),
          action: SnackBarAction(
            label: isEn ? 'Open settings' : 'فتح الإعدادات',
            onPressed: () => Geolocator.openAppSettings(),
          ),
        ));
        return;
      }
      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEn
              ? 'Location permission is required.'
              : 'إذن الموقع مطلوب.'),
        ));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _center = target);
      _mapController.move(target, 16.0);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEn
            ? 'Could not get your location.'
            : 'تعذر تحديد موقعك.'),
      ));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    Navigator.of(context).pop<LatLng>(_center);
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final title = isEn
        ? (widget.titleEn ?? 'Pick location')
        : (widget.titleAr ?? 'حدد الموقع');

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        body: Stack(
          alignment: Alignment.center,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 15.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                onPositionChanged: (pos, _) {
                  final c = pos.center;
                  _center = c;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.syanat.app',
                  maxZoom: 19,
                  // tile.openstreetmap.org throttles / 418s heavy clients.
                  // Re-request failed tiles when the user pans back so a
                  // transient block doesn't permanently leave gray squares
                  // on screen. Production should migrate to a paid provider
                  // — see project_maps_feature memory.
                  evictErrorTileStrategy:
                      EvictErrorTileStrategy.notVisibleRespectMargin,
                  errorTileCallback: (tile, error, _) {
                    debugPrint(
                        '[MapPicker] OSM tile failed at ${tile.coordinates}: $error');
                  },
                ),
                // OSM attribution — required by the tile usage policy.
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Fixed center pin overlay. Slight upward translate so the tip
            // points at the visual center, not the icon's bounding-box center.
            const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(Icons.location_on, color: _syanatBlue, size: 44),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _locating ? null : _useMyLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _syanatBlue,
                            ),
                          )
                        : const Icon(Icons.my_location,
                            color: _syanatBlue, size: 18),
                    label: Text(
                      isEn ? 'Use my location' : 'استخدم موقعي',
                      style: const TextStyle(
                        color: _syanatBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _syanatBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isEn ? 'Confirm location' : 'تأكيد الموقع',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
