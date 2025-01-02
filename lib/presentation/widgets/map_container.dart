import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

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
        minimumFetchInterval: const Duration(days: 1),
      ));

      await remoteConfig.fetchAndActivate();
      final token = remoteConfig.getString('mapbox_access_token');

      if (token.isNotEmpty) {
        //debugPrint("Fetched access token: $token");
        setState(() {
          _accessToken = token;
        });
      } else {
        throw Exception("Mapbox access token is empty.");
      }
    } catch (e) {
      //debugPrint("Error fetching access token: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load map configuration.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: MapboxMap(
            key: UniqueKey(),
            accessToken: _accessToken ?? '', // Ensure accessToken is not null
            styleString: widget.mapboxUrl,
            initialCameraPosition: CameraPosition(
              target: widget.userLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _controller = controller;
              // Add markers or other actions if needed
            },
            onStyleLoadedCallback: () {
              // Notify the bloc to stop loading
              context.read<MapBloc>().emit(
                    context.read<MapBloc>().state.copyWith(isLoading: false),
                  );
            },
          ),
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

  Future<List<SymbolOptions>> _prepareMarkers(
      List<Map<String, dynamic>> points) async {
    return compute(_processMarkerData, points);
  }

  List<SymbolOptions> _processMarkerData(List<Map<String, dynamic>> points) {
    return points.where((point) {
      final geometry = point['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      return geometry != null && coordinates != null && coordinates.length == 2;
    }).map((point) {
      final geometry = point['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final lat = coordinates[1] as double;
      final lng = coordinates[0] as double;

      return SymbolOptions(
        geometry: LatLng(lat, lng),
        iconImage: "marker-15", // Default Mapbox marker
        iconSize: 1.5,
      );
    }).toList();
  }

  Future<void> _addMarkers() async {
    if (_controller == null) return;

    debugPrint("Adding markers with points: ${widget.points}");

    try {
      final markerOptions = await _prepareMarkers(widget.points);

      for (final options in markerOptions) {
        await _controller?.addSymbol(options);
      }
    } catch (e) {
      debugPrint("Error adding markers: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
