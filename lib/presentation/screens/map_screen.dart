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
            appBar: AppBar(
              title: const Text("Tap Map"),
            ),
            drawer: _buildDrawer(context),
            body: BlocBuilder<MapBloc, MapState>(
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
                );
              },
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
                          debugPrint("Selected Style: ${style['name']}");
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          backgroundColor: Colors.blue,
          tooltip: 'Select Style',
          child: const Icon(Icons.style),
        ),
      ],
    );
  }
}
