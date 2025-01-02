import 'package:mapbox_gl/mapbox_gl.dart' as mapbox;
import 'package:flutter_bloc/flutter_bloc.dart';
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
            drawer: _buildDrawer(context),
            body: Stack(
              children: [
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
                      points: state.points,
                      isLoading: state.isLoading,
                    );
                  },
                ),
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
              ],
            ),
            floatingActionButton: _buildFloatingActionButtons(context),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        final styles = state.availableStyles;
        return Drawer(
          child: Column(
            children: [
              const DrawerHeader(
                child: Text(
                  "Choose a Style",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (styles.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text("No styles available"),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: styles.length,
                    itemBuilder: (context, index) {
                      final style = styles[index];
                      return ListTile(
                        title: Text(style['name']!),
                        onTap: () {
                          context
                              .read<MapBloc>()
                              .updateStyle(style['style_url']!);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButtons(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 30.0,
          left: 30.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FloatingActionButton(
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                backgroundColor: Colors.blue,
                tooltip: 'Select Style',
                child: const Icon(Icons.style, color: Colors.white),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                onPressed: () {
                  context.read<MapBloc>().toggleTheme();
                },
                backgroundColor: Colors.grey,
                tooltip: 'Toggle Theme',
                child: BlocBuilder<MapBloc, MapState>(
                  builder: (context, state) {
                    return Icon(
                        state.isDarkMode ? Icons.dark_mode : Icons.light_mode);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
