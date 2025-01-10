import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../../domain/blocs/map_bloc.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchBarAndResults extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Function(Map<String, dynamic>) onLocationSelected;
  final MapBloc mapBloc; // Added this line

  const SearchBarAndResults({
    Key? key,
    required this.scaffoldKey,
    required this.onLocationSelected,
    required this.mapBloc, // Added this parameter
  }) : super(key: key);

  @override
  State<SearchBarAndResults> createState() => _SearchBarAndResultsState();
}

class _SearchBarAndResultsState extends State<SearchBarAndResults> {
  final List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _textController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _isCameraMoving = false; // Flag to indicate camera movement

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBar(),
        if (_searchResults.isNotEmpty) _buildResultsList(),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_isCameraMoving)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _textController,
        onChanged: (value) => _onSearchChanged(value),
        decoration: InputDecoration(
          hintText: "Search location...",
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 16),
          suffixIcon: _textController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 16),
                  onPressed: () {
                    _textController.clear();
                    setState(() {
                      _searchResults.clear();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: _searchResults.take(5).map((result) {
          final placeName = result['name'] ?? 'Unnamed';
          final placeAddress = result['address'] ?? '';

          return ListTile(
            title: Text(
              placeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              placeAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () async {
              debugPrint("Selected location: $result");
              final details = await _fetchLocationDetails(result['id']);
              // Show details for the location
              debugPrint("Details for ${result['id']}: $details");
              if (details != null) {
                final geometry = details['geometry'];
                if (geometry != null &&
                    geometry['type'] == 'Point' &&
                    geometry['coordinates'] is List) {
                  final coordinates = geometry['coordinates'] as List;
                  debugPrint("Coordinates: $coordinates");
                  if (coordinates.length == 2 &&
                      coordinates[0] != null &&
                      coordinates[1] != null) {
                    final lng = coordinates[0] is String
                        ? double.tryParse(coordinates[0]) ?? 0.0
                        : (coordinates[0] as num).toDouble();
                    final lat = coordinates[1] is String
                        ? double.tryParse(coordinates[1]) ?? 0.0
                        : (coordinates[1] as num).toDouble();

                    await _moveCameraToLatLng({
                      'latitude': lat,
                      'longitude': lng,
                    });
                  }
                }
                widget.onLocationSelected(details);

                // **Pop the Search Bar**
                setState(() {
                  _textController.clear(); // Clears the search text
                  _searchResults.clear(); // Hides the search results
                });
                FocusScope.of(context).unfocus(); // Dismisses the keyboard
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchLocationDetails(String id) async {
    final url = Uri.parse('https://api.tap-map.net/api/points/$id/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint("Failed to fetch details for ID $id: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching details for ID $id: $e");
    }
    return null;
  }

  Future<void> _moveCameraToLatLng(Map<String, dynamic> result) async {
    if (_isCameraMoving) {
      debugPrint("Camera is already moving. Please wait.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera is moving. Please wait.")),
      );
      return;
    }

    final currentState = widget.mapBloc.state;

    if (currentState.mapController == null) {
      debugPrint("MapController is not set in MapBloc.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Map controller is not initialized.")),
      );
      return;
    }

    final controller = currentState.mapController!;
    debugPrint("MapController is available: $controller");
    debugPrint("MapController address: ${controller.hashCode}"); // Added for verification

    final lat = result['latitude'] as double;
    final lng = result['longitude'] as double;

    debugPrint("Moving camera to Lat: $lat, Lng: $lng");

    setState(() {
      _isCameraMoving = true;
    });

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(lat, lng)),
      );
      debugPrint("Camera moved successfully.");
    } catch (e) {
      debugPrint("Error moving camera: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to move camera to the location.")),
      );
    } finally {
      setState(() {
        _isCameraMoving = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.isEmpty || query.length < 2) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    final url = Uri.parse('https://api.tap-map.net/api/search/?q=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>;
        setState(() {
          _searchResults.addAll(results.take(5).map((item) {
            return {
              'id': item['id'],
              'name': item['name'],
              'address': item['address'],
            };
          }).toList());
        });
      } else {
        debugPrint("Search API returned status code ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch search results.")),
        );
      }
    } catch (e) {
      debugPrint("Error performing search: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An error occurred during search.")),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }
}