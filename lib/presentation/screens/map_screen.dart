import '../../presentation/widgets/search_bar_and_button.dart';
import '../../domain/repositories/map_repository.dart';
import '../../presentation/widgets/map_container.dart';
import 'package:mapbox_gl/mapbox_gl.dart' as mapbox;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _drawerDetails;

  void _setDrawerDetails(Map<String, dynamic> details) {
    setState(() {
      _drawerDetails = details;
    });
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (context) => MapBloc(MapRepository()),
      child: Builder(
        builder: (context) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              child: _drawerDetails == null
                  ? const Center(child: Text('No details'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _drawerDetails!['properties']['name'] ??
                                  'Unnamed',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _drawerDetails!['properties']['address'] ??
                                  'No Address',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _drawerDetails!['properties']['description'] ??
                                  'No Description',
                              style: const TextStyle(fontSize: 14),
                            ),
                            // Add more details as needed
                          ],
                        ),
                      ),
                    ),
            ),
            body: Stack(
              children: [
                // Main map rendering
                BlocBuilder<MapBloc, MapState>(
                  builder: (context, state) {
                    if (state.mapboxUrl.isEmpty ||
                        (state.userLocation.latitude == 0 &&
                            state.userLocation.longitude == 0)) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final mapboxUserLocation = mapbox.LatLng(
                      state.userLocation.latitude,
                      state.userLocation.longitude,
                    );
                    return MapContainer(
                      mapboxUrl: state.mapboxUrl,
                      userLocation: mapboxUserLocation,
                      isLoading: state.isLoading,
                    );
                  },
                ),
                // Loading overlay
                BlocBuilder<MapBloc, MapState>(
                  builder: (context, state) {
                    if (state.isLoading) {
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
                // Loading overlay
                BlocBuilder<MapBloc, MapState>(
                  builder: (context, state) {
                    if (state.isLoading) {
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
                // Add SearchBarAndButton widget
                Positioned(
                  top: 20.0,
                  left: 20.0,
                  right: 50.0,
                  child: SearchBarAndButton(
                    scaffoldKey: _scaffoldKey,
                    onLocationSelected: _setDrawerDetails,
                    mapBloc: context.read<MapBloc>(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
