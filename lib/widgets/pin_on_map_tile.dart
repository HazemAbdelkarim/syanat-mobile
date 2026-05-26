import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

/// Compact tile showing the current map-pin state, used inside add-location
/// sheets and dialogs. Tap to open a map picker (caller wires `onTap`).
class PinOnMapTile extends StatelessWidget {
  final bool isEn;
  final LatLng? pinned;
  final VoidCallback onTap;

  /// When true, uses tighter padding + smaller icons (for cramped dialogs).
  final bool compact;

  const PinOnMapTile({
    super.key,
    required this.isEn,
    required this.pinned,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPin = pinned != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: hasPin ? _syanatBlue : Colors.grey.shade300,
            width: hasPin ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: compact
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 8 : 9),
              decoration: BoxDecoration(
                color: const Color(0x143C21C8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.map_outlined,
                  color: _syanatBlue, size: compact ? 20 : 22),
            ),
            SizedBox(width: compact ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPin
                        ? (isEn ? 'Pin set' : 'تم تحديد الموقع')
                        : (isEn ? 'Pin on map' : 'حدد على الخريطة'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: hasPin ? _syanatBlue : Colors.black87,
                      fontSize: compact ? 13 : 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPin
                        ? '${pinned!.latitude.toStringAsFixed(5)}, ${pinned!.longitude.toStringAsFixed(5)}'
                        : (isEn
                            ? 'Required for accurate dispatch'
                            : 'مطلوب لتحديد الموقع بدقة'),
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasPin ? Icons.check_circle : Icons.chevron_right,
              color: hasPin ? _syanatBlue : Colors.grey.shade400,
              size: compact ? 20 : 24,
            ),
          ],
        ),
      ),
    );
  }
}
