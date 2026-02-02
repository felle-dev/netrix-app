import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPreviewWidget extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final bool isTor;
  final String country;
  final VoidCallback? onTap;
  final double height;

  const MapPreviewWidget({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.isTor = false,
    this.country = 'Unknown',
    this.onTap,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Return empty widget if coordinates are invalid
    if (latitude == null || longitude == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AbsorbPointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(latitude!, longitude!),
                  initialZoom: 10.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yourapp.networkchecker',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(latitude!, longitude!),
                        width: 40,
                        height: 40,
                        child: Icon(
                          isTor ? Icons.vpn_lock : Icons.location_on,
                          color: isTor
                              ? Colors.purple
                              : theme.colorScheme.error,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to expand',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
