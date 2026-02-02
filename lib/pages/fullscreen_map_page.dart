import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FullScreenMapPage extends StatelessWidget {
  final double lat;
  final double lon;
  final bool isTor;
  final String country;

  const FullScreenMapPage({
    Key? key,
    required this.lat,
    required this.lon,
    required this.isTor,
    required this.country,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(country),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lon),
          initialZoom: 12.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.yourapp.networkchecker',
            maxZoom: 19,
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lon),
                width: 60,
                height: 60,
                child: Icon(
                  isTor ? Icons.vpn_lock : Icons.location_on,
                  color: isTor ? Colors.purple : theme.colorScheme.error,
                  size: 60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
