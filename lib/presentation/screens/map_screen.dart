import 'package:mapbox_gl/mapbox_gl.dart' as mapbox;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/search_bar_and_button.dart';
import '../../../domain/blocs/map_bloc.dart';
import '../widgets/map_container.dart';
import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  MapScreen({super.key});

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (context) => MapBloc(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            key: _scaffoldKey,
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
                // Add SearchWithButton widget at the top
                Positioned(
                  top: 20.0,
                  left: 20.0,
                  right: 50.0,
                  child: SearchWithButton(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
