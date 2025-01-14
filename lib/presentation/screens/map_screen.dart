import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../../presentation/widgets/search_bar_and_button.dart';
import '../../domain/repositories/map_repository.dart';
import '../../domain/controllers/map_controller.dart';
import 'package:mapbox_gl/mapbox_gl.dart' as mapbox;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
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

  // Flag to track if the style has fully loaded
  bool _isStyleLoaded = false;

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
      // 1) Wrap your existing Scaffold in a BlocListener
      child: BlocListener<MapBloc, MapState>(
        listenWhen: (previous, current) {
          // Only listen when the user location changes
          return previous.userLocation != current.userLocation;
        },
        listener: (context, state) async {
          // If the style is loaded and we now have a valid user location, place the marker
          if (_isStyleLoaded && _controller != null) {
            final lat = state.userLocation.latitude;
            final lng = state.userLocation.longitude;
            if (lat != 0.0 && lng != 0.0) {
              final myController = MapController(_controller!);
              await myController.addMyMarker(
                latitude: lat,
                longitude: lng,
                pngAssetPath: 'assets/mylocation.png',
                iconImageId: 'mylocation_marker',
              );
              debugPrint(
                "BlocListener placed marker at ($lat, $lng) after location changed.",
              );
            }
          }
        },
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
                            () => PanGestureRecognizer(),
                          ),
                        },
                        accessToken: _accessToken!,
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
                              "Style loaded. Attempting to place user marker FIRST THING...");

                          if (_controller != null) {
                            // 1) Create your MapController wrapper
                            final myController = MapController(_controller!);

                            // 2) Grab user location from your bloc
                            final lat = context
                                .read<MapBloc>()
                                .state
                                .userLocation
                                .latitude;
                            final lng = context
                                .read<MapBloc>()
                                .state
                                .userLocation
                                .longitude;

                            // 3) Place the marker FIRST if location is valid
                            if (lat != 0.0 && lng != 0.0) {
                              await myController.addMyMarker(
                                latitude: lat,
                                longitude: lng,
                                pngAssetPath: 'assets/mylocation.png',
                                iconImageId: 'mylocation_marker',
                              );
                              debugPrint(
                                  "Marker placed at ($lat, $lng) immediately in onStyleLoadedCallback.");
                            } else {
                              debugPrint(
                                  "User location is (0,0). Skipping immediate placement.");
                            }

                            // 4) (Optional) Animate the camera to ensure the marker is visible
                            //    This is helpful if your default camera might be zoomed out or
                            //    a different region. Uncomment if needed.
                            // await _controller!.animateCamera(
                            //   CameraUpdate.newCameraPosition(
                            //     CameraPosition(
                            //       target: mapbox.LatLng(lat, lng),
                            //       zoom: 13.0,
                            //     ),
                            //   ),
                            // );

                            // 5) Load any custom marker images you might need
                            await myController.addMarkerImage(_controller!);

                            // Remove old tap handler to avoid duplicates
                            _controller?.onSymbolTapped
                                .remove(_handleMarkerClick);
                            // Add the new tap handler
                            _controller?.onSymbolTapped.add(_handleMarkerClick);

                            // 6) Continue with your existing vector tile calls, etc.
                            await myController.addVectorTileSource();
                            await myController.decodeAndAddMarkersFromTile(
                                zoom: 0, x: 0, y: 0);
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
                      controller: _controller,
                    ),
                  ),

                  // =========== ADD A FLOATING ACTION BUTTON ===========
                  Positioned(
                    bottom: 30.0,
                    right: 20.0,
                    child: BlocBuilder<MapBloc, MapState>(
                      builder: (context, state) {
                        return FloatingActionButton(
                          backgroundColor: Colors.indigo,
                          onPressed: () async {
                            if (_controller != null) {
                              final lat = state.userLocation.latitude;
                              final lng = state.userLocation.longitude;

                              // 1) Animate camera to user's location
                              await _controller!.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: mapbox.LatLng(lat, lng),
                                    zoom: 13.0,
                                  ),
                                ),
                              );

                              // 2) Place the marker again at user location
                              final myController = MapController(_controller!);
                              await myController.addMyMarker(
                                latitude: lat,
                                longitude: lng,
                                pngAssetPath: 'assets/mylocation.png',
                                iconImageId: 'mylocation_marker',
                              );
                              debugPrint(
                                "Placed marker at ($lat, $lng) on FAB press.",
                              );
                            }
                          },
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
  //  Symbol Tap Handler
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
}
