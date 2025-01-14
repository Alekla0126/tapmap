import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../../presentation/widgets/search_bar_and_button.dart';
import '../../domain/repositories/map_repository.dart';
import 'package:mapbox_gl/mapbox_gl.dart' as mapbox;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../../domain/controllers/map_controller.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../widgets/drawer.dart';
import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Drawer details
  Map<String, dynamic>? _drawerDetails;

  // Map-related fields
  MapboxMapController? _controller;
  mapbox.LatLng? _savedCenter;
  String? _accessToken;
  double? _savedZoom;

  bool _isLocationDetailsLoading = false;

  // -------------------------------------------------------------
  //  Lifecycle
  // -------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _initializeRemoteConfig();
  }

  // -------------------------------------------------------------
  //  UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (_) => MapBloc(MapRepository()),
      child: Builder(
        builder: (context) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: _buildDrawer(),
            body: Stack(
              children: [
                // Main map rendering
                BlocBuilder<MapBloc, MapState>(
                  builder: (context, state) {
                    // If we don’t have an access token yet, show a loader
                    if (_accessToken == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // If the MapBloc says we haven’t loaded style or user location
                    if (state.mapboxUrl.isEmpty ||
                        (state.userLocation.latitude == 0 &&
                            state.userLocation.longitude == 0)) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Use the saved center/zoom if available; otherwise, fallback to userLocation
                    final initialCameraCenter = _savedCenter ??
                        mapbox.LatLng(
                          state.userLocation.latitude,
                          state.userLocation.longitude,
                        );
                    final initialCameraZoom = _savedZoom ?? 12.0;

                    return MapboxMap(
                      gestureRecognizers: {
                        Factory<PanGestureRecognizer>(
                            () => PanGestureRecognizer()),
                      },
                      accessToken: _accessToken!, // Now safe to use !
                      styleString: state.mapboxUrl,
                      initialCameraPosition: CameraPosition(
                        target: initialCameraCenter,
                        zoom: initialCameraZoom,
                      ),
                      onMapCreated: (controller) async {
                        _controller = controller;
                        debugPrint("Map created and controller assigned.");
                      },
                      onStyleLoadedCallback: () async {
                        debugPrint(
                            "Style loaded. Re-adding custom marker image...");
                        if (_controller != null) {
                          await MapController(_controller!)
                              .addMarkerImage(_controller!);
                          // Remove old tap handler to avoid duplicates
                          _controller?.onSymbolTapped
                              .remove(_handleMarkerClick);
                          // Add the new tap handler
                          _controller?.onSymbolTapped.add(_handleMarkerClick);

                          // Add vector tile source
                          await MapController(_controller!)
                              .addVectorTileSource();
                          // Decode & place markers
                          await MapController(_controller!)
                              .decodeAndAddMarkersFromTile(zoom: 0, x: 0, y: 0);
                        }
                      },
                      onCameraIdle: () async {
                        if (_controller != null) {
                          final position = _controller!.cameraPosition;
                          if (position != null) {
                            setState(() {
                              _savedCenter = position.target;
                              _savedZoom = position.zoom;
                            });
                            debugPrint(
                              "Camera idle. savedCenter=$_savedCenter, savedZoom=$_savedZoom",
                            );
                          }
                        }
                      },
                    );
                  },
                ),

                // A global overlay if state.isLoading from the bloc is true
                BlocBuilder<MapBloc, MapState>(
                  builder: (context, state) {
                    if (state.isLoading || _isLocationDetailsLoading) {
                      return Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // The Search bar and button at the top
                Positioned(
                  top: 20.0,
                  left: 20.0,
                  right: 50.0,
                  child: SearchBarAndButton(
                    scaffoldKey: _scaffoldKey,
                    onLocationSelected: _setDrawerDetails,
                    // We can pass the existing _controller to the search bar
                    // if you want to move the camera from inside the search logic
                    controller: _controller,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  //  Drawer
  // -------------------------------------------------------------
  Widget _buildDrawer() {
    return CustomDrawer(
      drawerDetails: _drawerDetails,
    );
  }

  void _setDrawerDetails(Map<String, dynamic> details) {
    setState(() {
      _drawerDetails = details;
    });
    _scaffoldKey.currentState?.openDrawer();
  }

  // -------------------------------------------------------------
  //  Remote Config
  // -------------------------------------------------------------
  Future<void> _initializeRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(days: 1),
        ),
      );

      await remoteConfig.fetchAndActivate();
      final token = remoteConfig.getString('mapbox_access_token');

      if (token.isNotEmpty) {
        // Assign the token to our state variable so we can use it in build
        setState(() {
          _accessToken = token;
        });
        debugPrint("Mapbox access token retrieved: $token");
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

  // -------------------------------------------------------------
  Future<void> _handleMarkerClick(Symbol symbol) async {
    final props = symbol.data;
    final name = props?['name'] ?? 'Unnamed';
    debugPrint("Marker clicked! Name: $name, All props: $props");
    if (props != null) {
      final locationId = props['id'].toString();
      setState(() {
        _isLocationDetailsLoading = true;
      });
      final details = await _fetchLocationDetails(locationId);
      setState(() {
        _isLocationDetailsLoading = false;
      });
      if (details != null) {
        _setDrawerDetails(details);
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchLocationDetails(String id) async {
    final url = Uri.parse('https://api.tap-map.net/api/points/$id/');
    try {
      final response = await http.get(url);
      // Print the response to the console
      debugPrint("Details for ID $id: ${utf8.decode(response.bodyBytes)}");
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } else {
        debugPrint(
            "Failed to fetch details for ID $id: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching details for ID $id: $e");
    }
    return null;
  }

  // -------------------------------------------------------------
}
