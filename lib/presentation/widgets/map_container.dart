import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:math';

class MapContainer extends StatefulWidget {
  final String mapboxUrl;
  final LatLng userLocation;
  final bool isLoading;

  const MapContainer({
    required this.mapboxUrl,
    required this.userLocation,
    required this.isLoading,
    Key? key,
  }) : super(key: key);

  @override
  State<MapContainer> createState() => _MapContainerState();
}

class _MapContainerState extends State<MapContainer> {
  MapboxMapController? _controller;
  String? _accessToken;

  // Track last center and threshold for fetching
  LatLng? _lastCenter;
  final double _fetchThreshold = 500; // meters

  final Set<String> _addedMarkerIds = {};

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
        debugPrint("Mapbox access token retrieved successfully.");
      } else {
        throw Exception("Mapbox access token is empty.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load map configuration.")),
      );
      debugPrint("Error fetching Mapbox access token: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: _accessToken == null || _accessToken!.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : MapboxMap(
              key: UniqueKey(),
              accessToken: _accessToken!,
              styleString: widget.mapboxUrl,
              initialCameraPosition: const CameraPosition(
                // For debugging, set a location in Phuket:
                target: LatLng(7.8804, 98.3923),
                zoom: 15,
              ),
              onMapCreated: (controller) async {
                _controller = controller;
                debugPrint("Map created and controller assigned.");
                await _addMarkerImage(_controller!);
              },
              onStyleLoadedCallback: () async {
                debugPrint("Style loaded. Adding vector tiles and markers...");
                await _addMarkerImage(_controller!);
                await _addVectorTileSource();
                await _addMarkersFromVectorTiles(const LatLng(7.8804, 98.3923));
                if (context.mounted) {
                  context
                      .read<MapBloc>()
                      .emit(context.read<MapBloc>().state.copyWith(
                            isLoading: false,
                          ));
                }
              },
              onCameraIdle: _handleCameraIdle, // Listen for camera idle
            ),
    );
  }

  // Called when the camera stops moving
  void _handleCameraIdle() async {
    if (_controller == null) return;

    // Get the new center
    final camPos = await _controller!.cameraPosition;
    final newCenter = camPos?.target;

    if (_lastCenter == null) {
      _lastCenter = newCenter;
      return;
    }

    // Calculate distance from last center
    final distanceMoved = _calculateDistanceInMeters(_lastCenter!, newCenter!);
    debugPrint("Map moved $distanceMoved meters from old center.");

    // If threshold exceeded, re-fetch
    if (distanceMoved > _fetchThreshold) {
      debugPrint("Moved more than $_fetchThreshold meters => re-fetch data");
      _lastCenter = newCenter;
      await _addMarkersFromVectorTiles(newCenter);
    }
  }

  double _calculateDistanceInMeters(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // in meters
    final lat1 = _degreesToRadians(start.latitude);
    final lat2 = _degreesToRadians(end.latitude);
    final dLat = _degreesToRadians(end.latitude - start.latitude);
    final dLng = _degreesToRadians(end.longitude - start.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double deg) => deg * math.pi / 180;

  /// Load the marker image into the style
  Future<void> _addMarkerImage(MapboxMapController controller) async {
    try {
      final byteData = await rootBundle.load("assets/marker.png");
      final Uint8List imageBytes = byteData.buffer.asUint8List();
      await controller.addImage("custom-marker", imageBytes);
      debugPrint("Marker image added successfully.");
    } catch (e) {
      debugPrint("Error loading marker image: $e");
    }
  }

  Future<void> _addVectorTileSource() async {
    if (_controller == null) return;

    try {
      await _controller!.addSource(
        'places',
        VectorSourceProperties(
          tiles: ['https://map-travel.net/tilesets/data/tiles/{z}/{x}/{y}.pbf'],
          minzoom: 0,
          maxzoom: 18,
        ),
      );
      debugPrint("Vector tile source added successfully.");
    } catch (e) {
      debugPrint("Error adding vector tile source: $e");
    }
  }

  Future<void> _addMarkersFromVectorTiles(LatLng location) async {
    if (_controller == null) return;

    try {
      debugPrint("Attempting to fetch features...");

      // Convert user location (or debugging point) to screen coordinates
      final screenPoint = await _controller!.toScreenLocation(location);

      final features = await _controller!.queryRenderedFeatures(
        Point<double>(
          screenPoint.x.toDouble(),
          screenPoint.y.toDouble(),
        ),
        [], // No layer ID filter
        null, // No filter
      );

      debugPrint("Features: $features");
      debugPrint("Features fetched: ${features.length}");

      // Render each feature
      for (var feature in features) {
        if (feature is Map) {
          // Extract geometry map
          final geometryMap = feature['geometry'] as Map<String, dynamic>?;
          if (geometryMap == null) {
            debugPrint("Feature has no geometry. Skipping...");
            continue;
          }

          // Extract geometry type and coordinates
          final geometryType = geometryMap['type'] as String?;
          final coords = geometryMap['coordinates'];

          // Validate and handle Point geometry
          if (geometryType == 'Point' && coords is List && coords.length == 2) {
            final lng = coords[0] is num ? coords[0] as double : null;
            final lat = coords[1] is num ? coords[1] as double : null;

            if (lng == null || lat == null) {
              debugPrint("Invalid Point coordinates. Skipping...");
              continue;
            }

            final properties = feature['properties'] as Map<String, dynamic>?;
            final id = properties?['id']?.toString() ?? '';
            final name = properties?['name']?.toString() ?? 'Unnamed';

            debugPrint("Adding marker at LatLng($lat, $lng) with ID: $id");

            await _controller!.addSymbol(
              SymbolOptions(
                geometry: LatLng(lat, lng),
                iconImage: "custom-marker",
                iconSize: 0.5,
                // textField: name,
                textOffset: const Offset(0, 1),
                textColor: "#000000",
              ),
            );

            // Handle LineString geometry
          } else if (geometryType == 'LineString' && coords is List) {
            if (coords.isNotEmpty &&
                coords.first is List &&
                coords.last is List) {
              final start = coords.first as List;
              final end = coords.last as List;

              if (start.length >= 2 && end.length >= 2) {
                final startLat = start[1] is num ? start[1] as double : null;
                final startLng = start[0] is num ? start[0] as double : null;
                final endLat = end[1] is num ? end[1] as double : null;
                final endLng = end[0] is num ? end[0] as double : null;

                if (startLat == null ||
                    startLng == null ||
                    endLat == null ||
                    endLng == null) {
                  debugPrint("Invalid LineString coordinates. Skipping...");
                  continue;
                }

                final midLat = (startLat + endLat) / 2;
                final midLng = (startLng + endLng) / 2;

                final properties =
                    feature['properties'] as Map<String, dynamic>?;
                final name = properties?['name']?.toString() ?? 'Unnamed Line';

                debugPrint(
                    "Adding LineString midpoint marker at LatLng($midLat, $midLng)");

                await _controller!.addSymbol(
                  SymbolOptions(
                    geometry: LatLng(midLat, midLng),
                    iconImage: "custom-marker",
                    iconSize: 0.5,
                    // textField: name,
                    textOffset: const Offset(0, 1),
                    textColor: "#000000",
                  ),
                );
              } else {
                debugPrint("Invalid LineString start or end coordinates.");
              }
            } else {
              debugPrint("Invalid LineString coordinates structure.");
            }

            // Handle MultiLineString and Polygon geometries
          } else if (geometryType == 'MultiLineString' ||
              geometryType == 'Polygon') {
            debugPrint("Processing $geometryType geometry...");

            if (geometryType == 'Polygon' && coords is List) {
              // Handle Polygon by calculating the centroid
              final List<List<double>> polygonCoords = [];
              for (var pair in coords.first) {
                if (pair is List &&
                    pair.length == 2 &&
                    pair[0] is num &&
                    pair[1] is num) {
                  polygonCoords.add([pair[0] as double, pair[1] as double]);
                } else {
                  debugPrint("Invalid coordinate pair in Polygon: $pair");
                }
              }

              if (polygonCoords.isNotEmpty) {
                double centroidLat = 0;
                double centroidLng = 0;
                for (var pair in polygonCoords) {
                  centroidLng += pair[0];
                  centroidLat += pair[1];
                }
                centroidLat /= polygonCoords.length;
                centroidLng /= polygonCoords.length;

                debugPrint(
                    "Adding marker for Polygon at LatLng($centroidLat, $centroidLng)");

                await _controller!.addSymbol(
                  SymbolOptions(
                    geometry: LatLng(centroidLat, centroidLng),
                    iconImage: "custom-marker",
                    iconSize: 0.5,
                    // textField: name,
                    textOffset: const Offset(0, 1),
                    textColor: "#000000",
                  ),
                );
              } else {
                debugPrint("Invalid Polygon coordinates. Skipping...");
              }
            } else if (geometryType == 'MultiLineString' && coords is List) {
              // Handle MultiLineString by differentiating cases
              bool needsFlattening = coords.length > 1;

              if (needsFlattening) {
                debugPrint("Flattening MultiLineString...");

                // Flatten the MultiLineString
                final List<List<double>> flattenedCoords = [];
                for (var segment in coords) {
                  if (segment is List) {
                    for (var pair in segment) {
                      if (pair is List &&
                          pair.length == 2 &&
                          pair[0] is num &&
                          pair[1] is num) {
                        flattenedCoords
                            .add([pair[0] as double, pair[1] as double]);
                      } else {
                        debugPrint(
                            "Invalid coordinate pair in MultiLineString: $pair");
                      }
                    }
                  } else {
                    debugPrint("Invalid segment in MultiLineString: $segment");
                  }
                }

                if (flattenedCoords.isNotEmpty) {
                  double totalLat = 0;
                  double totalLng = 0;
                  for (var pair in flattenedCoords) {
                    totalLng += pair[0];
                    totalLat += pair[1];
                  }
                  final centerLat = totalLat / flattenedCoords.length;
                  final centerLng = totalLng / flattenedCoords.length;

                  debugPrint(
                      "Adding marker for flattened MultiLineString at LatLng($centerLat, $centerLng)");

                  await _controller!.addSymbol(
                    SymbolOptions(
                      geometry: LatLng(centerLat, centerLng),
                      iconImage: "custom-marker",
                      iconSize: 0.5,
                      // textField: name, // Display label
                      textOffset: const Offset(0, 1),
                      textColor: "#000000",
                    ),
                  );
                } else {
                  debugPrint(
                      "No valid coordinates found in MultiLineString. Skipping...");
                }
              } else {
                debugPrint(
                    "Calculating midpoint for simple MultiLineString...");

                // Treat as a single line, find the midpoint
                final firstSegment = coords.first;
                final lastSegment = coords.last;

                if (firstSegment is List &&
                    firstSegment.first is List &&
                    lastSegment.last is List) {
                  final start = firstSegment.first as List;
                  final end = lastSegment.last as List;

                  if (start.length >= 2 && end.length >= 2) {
                    final startLat =
                        start[1] is num ? start[1] as double : null;
                    final startLng =
                        start[0] is num ? start[0] as double : null;
                    final endLat = end[1] is num ? end[1] as double : null;
                    final endLng = end[0] is num ? end[0] as double : null;

                    if (startLat == null ||
                        startLng == null ||
                        endLat == null ||
                        endLng == null) {
                      debugPrint(
                          "Invalid MultiLineString coordinates. Skipping...");
                    } else {
                      final midLat = (startLat + endLat) / 2;
                      final midLng = (startLng + endLng) / 2;

                      debugPrint(
                          "Adding MultiLineString midpoint marker at LatLng($midLat, $midLng)");

                      await _controller!.addSymbol(
                        SymbolOptions(
                          geometry: LatLng(midLat, midLng),
                          iconImage: "custom-marker",
                          iconSize: 0.5,
                          // textField: name, // Display label
                          textOffset: const Offset(0, 1),
                          textColor: "#000000",
                        ),
                      );
                    }
                  } else {
                    debugPrint(
                        "Invalid MultiLineString start or end coordinates.");
                  }
                } else {
                  debugPrint("Invalid MultiLineString coordinates structure.");
                }
              }
            }
          } else {
            debugPrint(
                "Skipping unsupported or invalid geometry type: $geometryType");
          }
        } else {
          debugPrint("Unexpected feature format. Skipping...");
        }
      }

      debugPrint("All markers added successfully.");
    } catch (e) {
      debugPrint("Error adding markers from vector tiles: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}