import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../domain/repositories/map_repository.dart';
import '../../domain/controllers/map_controller.dart';
import 'package:mapbox_gl/mapbox_gl.dart' as mapbox;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:flutter/foundation.dart';
import '../widgets/theme_switcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../widgets/search_bar.dart';
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
  LatLng? _savedCenter;
  String? _accessToken;
  double? _savedZoom;

  // Loading flags
  bool _isLocationDetailsLoading = false;
  bool _isStyleLoaded = false;

  // Single symbol for the user’s location
  Symbol? _myLocationSymbol;

  @override
  void initState() {
    super.initState();
    _initializeRemoteConfig();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (_) => MapBloc(MapRepository()),
      child: BlocListener<MapBloc, MapState>(
        listenWhen: (previous, current) =>
            previous.userLocation != current.userLocation,
        listener: (context, state) async {
          // Move or add the marker whenever location changes
          if (_isStyleLoaded && _controller != null) {
            final lat = state.userLocation.latitude;
            final lng = state.userLocation.longitude;

            if (lat != 0.0 && lng != 0.0) {
              if (_myLocationSymbol == null) {
                _myLocationSymbol = await _controller!.addSymbol(
                  SymbolOptions(
                    geometry: LatLng(lat, lng),
                    iconImage: 'mylocation_marker',
                    iconSize: 1.0,
                  ),
                );
                debugPrint("Created user location marker at ($lat, $lng).");
              } else {
                await _controller!.updateSymbol(
                  _myLocationSymbol!,
                  SymbolOptions(
                    geometry: LatLng(lat, lng),
                  ),
                );
                debugPrint("Updated user location marker to ($lat, $lng).");
              }
            }
          }
        },
        child: Builder(
          builder: (context) {
            return Scaffold(
              key: _scaffoldKey,

              // Wrap the drawer in a Container/SizedBox that occupies 40% of the screen width
              drawer: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: _buildDrawer(),
              ),

              body: Stack(
                children: [
                  BlocBuilder<MapBloc, MapState>(
                    builder: (context, state) {
                      // 1) If we don't have a token yet, show a loader
                      if (_accessToken == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // 2) If we haven't loaded style or user location, show a loader
                      if (state.mapboxUrl.isEmpty ||
                          (state.userLocation.latitude == 0 &&
                              state.userLocation.longitude == 0)) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // 3) Use saved center if we have one, otherwise fallback to user location
                      final initialCameraCenter = _savedCenter ??
                          LatLng(
                            state.userLocation.latitude,
                            state.userLocation.longitude,
                          );
                      final initialCameraZoom = _savedZoom ?? 12.0;

                      return MapboxMap(
                        myLocationEnabled: true,
                        myLocationTrackingMode:
                            MyLocationTrackingMode.TrackingCompass,
                        minMaxZoomPreference: const MinMaxZoomPreference(0, 18),
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
                          debugPrint("Style loaded. Checking user location...");
                          _isStyleLoaded = true;

                          if (_controller != null) {
                            final myController = MapController(_controller!);
                            await myController.addMarkerImage(_controller!);
                            _controller?.onSymbolTapped
                                .remove(_handleMarkerClick);
                            _controller?.onSymbolTapped.add(_handleMarkerClick);
                            // Add custom vector tile layers, etc.
                            await myController.addVectorTileSource();
                            await myController.decodeAndAddMarkersFromTile(
                              zoom: 0,
                              x: 0,
                              y: 0,
                            );
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
                            }
                          }
                        },

                        // IMPORTANT: Make sure the map doesn't swallow all pointer events.
                        gestureRecognizers: {
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                          Factory<OneSequenceGestureRecognizer>(
                            () => TapGestureRecognizer(),
                          ),
                        },
                      );
                    },
                  ),

                  // Loading overlay if needed
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

                  // Position the search bar on top, wrapped in a Material
                  Positioned(
                    top: 20.0,
                    left: 20.0,
                    right: 50.0,
                    child: PointerInterceptor(
                      child: Material(
                        color: Colors.transparent,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              flex: 2,
                              child: const MapThemeSwitcher(),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 5,
                              child: SearchBarAndResults(
                                onLocationSelected: _setDrawerDetails,
                                scaffoldKey: _scaffoldKey,
                                controller: _controller,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildDrawer() {
    return CustomDrawer(drawerDetails: _drawerDetails);
  }

  void _setDrawerDetails(Map<String, dynamic> details) {
    setState(() {
      _drawerDetails = details;
    });
    _scaffoldKey.currentState?.openDrawer();
  }

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
        setState(() => _accessToken = token);
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

  Future<void> _handleMarkerClick(Symbol symbol) async {
    final props = symbol.data;
    final name = props?['name'] ?? 'Unnamed';
    debugPrint("Marker clicked! Name: $name, All props: $props");

    if (props != null) {
      final locationId = props['id'].toString();
      setState(() => _isLocationDetailsLoading = true);
      final details = await _fetchLocationDetails(locationId);
      setState(() => _isLocationDetailsLoading = false);

      if (details != null) {
        _setDrawerDetails(details);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load location details.")),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchLocationDetails(String id) async {
    final url = Uri.parse('https://api.tap-map.net/api/points/$id/');
    try {
      final response = await http.get(url);
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
