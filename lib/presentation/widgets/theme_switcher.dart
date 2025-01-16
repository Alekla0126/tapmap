import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:flutter/material.dart';

class MapThemeSwitcher extends StatefulWidget {
  const MapThemeSwitcher({super.key});

  @override
  State<MapThemeSwitcher> createState() => _MapThemeSwitcherState();
}

class _MapThemeSwitcherState extends State<MapThemeSwitcher> {
  String? _currentStyleName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(30),
      ),
      child: BlocBuilder<MapBloc, MapState>(
        builder: (context, state) {
          final styles = state.availableStyles;

          return DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isDense: true,
              isExpanded: true,
              value: _currentStyleName,
              hint: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _currentStyleName ?? 'Select Theme',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              selectedItemBuilder: (context) {
                return styles.map((style) {
                  return Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        style['name']!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }).toList();
              },
              items: styles
                  .map((style) => DropdownMenuItem<String>(
                        value: style['name'],
                        child: Text(
                          style['name']!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ))
                  .toList(),
              onChanged: (value) async {
                final selectedStyle = styles.firstWhere(
                  (style) => style['name'] == value,
                  orElse: () => <String, String>{},
                );

                if (selectedStyle.isNotEmpty) {
                  final styleUrl = selectedStyle['style_url']!;
                  final mapBloc = context.read<MapBloc>();

                  // Save current camera position
                  final controller = mapBloc.mapController;
                  final currentCameraPosition =
                      controller?.cameraPosition;

                  debugPrint("Current camera position: $currentCameraPosition");

                  // Change the style
                  mapBloc.updateStyle(styleUrl);

                  // Update the current style name
                  setState(() {
                    _currentStyleName = value;
                  });

                  // Restore camera position after style change
                  if (currentCameraPosition != null) {
                    await Future.delayed(
                        const Duration(milliseconds: 500));
                    debugPrint("Restoring camera position...");
                    mapBloc.mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(currentCameraPosition),
                    );
                  }
                }
              },
              buttonStyleData: const ButtonStyleData(
                padding: EdgeInsets.symmetric(horizontal: 12),
              ),
              iconStyleData: const IconStyleData(
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                iconSize: 20,
              ),
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              menuItemStyleData: const MenuItemStyleData(
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          );
        },
      ),
    );
  }
}
