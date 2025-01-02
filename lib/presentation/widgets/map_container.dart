import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/material.dart';

import '../../domain/blocs/map_bloc.dart';

class MapContainer extends StatefulWidget {
  final String mapboxUrl;
  final LatLng userLocation;
  final List<Map<String, dynamic>> points;
  final bool isLoading;

  const MapContainer({
    required this.mapboxUrl,
    required this.userLocation,
    required this.points,
    required this.isLoading,
    Key? key,
  }) : super(key: key);

  @override
  State<MapContainer> createState() => _MapContainerState();
}

class _MapContainerState extends State<MapContainer> {
  MapboxMapController? _controller;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _initializeRemoteConfig();
  }

  Future<void> _initializeRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await remoteConfig.fetchAndActivate();
      final token = remoteConfig.getString('mapbox_access_token');

      if (token.isNotEmpty) {
        debugPrint("Fetched access token: $token");
        setState(() {
          _accessToken = token;
        });
      } else {
        throw Exception("Mapbox access token is empty.");
      }
    } catch (e) {
      debugPrint("Error fetching access token: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load map configuration.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapboxMap(
          key: UniqueKey(),
          accessToken: _accessToken!,
          styleString: widget.mapboxUrl,
          initialCameraPosition: CameraPosition(
            target: widget.userLocation,
            zoom: 15,
          ),
          onMapCreated: (controller) {
            _controller = controller;
            _addMarkers();
          },
          onStyleLoadedCallback: () {
            _addMarkers();
            debugPrint("Style applied: ${widget.mapboxUrl}");
            // Notify the bloc to stop loading
            context.read<MapBloc>().emit(
                  context.read<MapBloc>().state.copyWith(isLoading: false),
                );
          },
        ),
        if (widget.isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Future<void> _addMarkers() async {
    if (_controller == null) return;

    for (final point in widget.points) {
      final geometry = point['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final lat = coordinates[1] as double;
      final lng = coordinates[0] as double;

      await _controller?.addSymbol(
        SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage: "marker-15", // Default Mapbox marker
          iconSize: 1.5,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
