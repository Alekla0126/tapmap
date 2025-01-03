import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
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
  final Set<String> _addedMarkerIds = {};
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
        setState(() {
          _accessToken = token;
        });
      } else {
        throw Exception("Mapbox access token is empty.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load map configuration.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MapBloc, MapState>(
      listener: (context, state) {
        if (_controller != null && state.points.isNotEmpty) {
          final newPoints = state.points.where((point) {
            final id = point['properties']['id']?.toString();
            return id != null && !_addedMarkerIds.contains(id);
          }).toList();
          _addMarkers(newPoints);
        }
      },
      child: Stack(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: MapboxMap(
              key: UniqueKey(),
              accessToken: _accessToken ?? '',
              styleString: widget.mapboxUrl,
              initialCameraPosition: CameraPosition(
                target: widget.userLocation,
                zoom: 12,
              ),
              onMapCreated: (controller) async {
                _controller = controller;
                debugPrint("STYLE_LOADED: Now safe to add symbols.");
              },
              onStyleLoadedCallback: () async {
                await Future.delayed(Duration(milliseconds: 100));
                await _addMarkers(widget.points);
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
      ),
    );
  }

  Future<void> _addMarkers(List<Map<String, dynamic>> points) async {
    // 1) Check that the controller is initialized.
    if (_controller == null) {
      // debugPrint('INIT: Controller is null');
      return;
    }

    // 2) Decide on a reasonable batch size for your web app.
    const int batchSize = 200;
    final int totalBatches = (points.length / batchSize).ceil();

    // 3) Process points in batches to avoid overwhelming the map.
    for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final start = batchIndex * batchSize;
      final end = math.min(start + batchSize, points.length);
      final batch = points.sublist(start, end);

      // 4) Process each point in the current batch
      for (final point in batch) {
        try {
          // debugPrint('POINT_START: Processing new point');
          // debugPrint('POINT_RAW: $point');

          final coordinates = _extractCoordinates(point);
          if (coordinates == null) {
            // debugPrint('COORDINATES: Extraction failed');
            continue;
          }
          // debugPrint('COORDINATES: Successfully extracted (${coordinates.$1}, ${coordinates.$2})');

          final properties = _extractProperties(point);
          if (properties == null) {
            // debugPrint('PROPERTIES: Extraction failed');
            continue;
          }
          // debugPrint('PROPERTIES: Successfully extracted ${properties['name']}');

          await _addSingleMarker(coordinates, properties);
        } catch (e) {
          // debugPrint('ERROR: Failed to process point: $e');
        }
      }

      // 5) Add a short delay between batches for smoother performance on web.
      //    Adjust this duration as needed.
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  (double, double)? _extractCoordinates(Map<String, dynamic> point) {
    try {
      // debugPrint('COORDS_START: Extracting coordinates');
      final geometry = point['geometry'];
      // debugPrint('COORDS_GEOMETRY: $geometry');

      final coords = geometry?['coordinates'] as List<dynamic>?;
      // debugPrint('COORDS_RAW: $coords');

      if (coords == null || coords.length < 2) {
        // debugPrint('COORDS_INVALID: Null or incomplete coordinates');
        return null;
      }

      final lng = _parseCoordinate(coords[0]);
      final lat = _parseCoordinate(coords[1]);
      // debugPrint('COORDS_PARSED: lat=$lat, lng=$lng');

      if (lat == null || lng == null) {
        // debugPrint('COORDS_PARSE_FAIL: Could not parse as numbers');
        return null;
      }
      return (lat, lng);
    } catch (e) {
      // debugPrint('COORDS_ERROR: $e');
      return null;
    }
  }

  double? _parseCoordinate(dynamic value) {
    // debugPrint('PARSE_START: Parsing coordinate value: $value (${value.runtimeType})');
    double? result;
    if (value is double) {
      result = value;
    } else if (value is int) {
      result = value.toDouble();
    } else if (value is String) {
      result = double.tryParse(value);
    }
    // debugPrint('PARSE_RESULT: $result');
    return result;
  }

  Map<String, dynamic>? _extractProperties(Map<String, dynamic> point) {
    // debugPrint('PROPS_START: Extracting properties');
    final props = point['properties'] as Map<String, dynamic>?;
    // debugPrint('PROPS_RAW: $props');

    if (props == null) {
      // debugPrint('PROPS_ERROR: Null properties');
      return null;
    }

    final result = {
      'name': props['name']?.toString() ?? 'Unnamed',
      'id': props['id']?.toString()
    };
    // debugPrint('PROPS_RESULT: $result');
    return result;
  }

  Future<void> _addSingleMarker(
    (double, double) coordinates,
    Map<String, dynamic> properties,
  ) async {
    // debugPrint('MARKER_START: Adding marker for ${properties['name']}');

    if (_addedMarkerIds.contains(properties['id'])) {
      // debugPrint('MARKER_SKIP: Duplicate ID ${properties['id']}');
      return;
    }

    try {
      // Add the symbol without icon
      final symbol = await _controller?.addSymbol(
        SymbolOptions(
          geometry: LatLng(coordinates.$1, coordinates.$2),
          textField: properties['name'],
          textSize: 12.0,
          textColor: "#FF0000",
          textHaloColor: "#FFFFFF",
          textHaloWidth: 1.5,
          textAnchor: "top",
        ),
      );

      if (symbol != null) {
        _addedMarkerIds.add(properties['id']);
        // debugPrint('MARKER_SUCCESS: Added ${properties['name']}');
      }
    } catch (e) {
      // debugPrint('MARKER_ERROR: Failed to add marker: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
