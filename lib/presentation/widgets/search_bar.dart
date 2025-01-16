import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';

class SearchBarAndResults extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Function(Map<String, dynamic>) onLocationSelected;
  final MapboxMapController? controller;

  const SearchBarAndResults({
    super.key,
    required this.scaffoldKey,
    required this.onLocationSelected,
    required this.controller,
  });

  @override
  State<SearchBarAndResults> createState() => _SearchBarAndResultsState();
}

class _SearchBarAndResultsState extends State<SearchBarAndResults> {
  final List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _textController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;

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
        onChanged: _onSearchChanged,
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
        color: Colors.white.withOpacity(0.8),
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
              if (details != null) {
                final geometry = details['geometry'];
                if (geometry != null &&
                    geometry['type'] == 'Point' &&
                    geometry['coordinates'] is List) {
                  final coordinates = geometry['coordinates'] as List;
                  if (coordinates.length == 2 &&
                      coordinates[0] != null &&
                      coordinates[1] != null) {
                    final lng = coordinates[0] is String
                        ? double.tryParse(coordinates[0]) ?? 0.0
                        : (coordinates[0] as num).toDouble();
                    final lat = coordinates[1] is String
                        ? double.tryParse(coordinates[1]) ?? 0.0
                        : (coordinates[1] as num).toDouble();
                    debugPrint("Moving camera to $lat, $lng");
                    // Ensure MapController is initialized before moving the camera
                    widget.controller!.moveCamera(
                      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Failed to fetch location details.")),
                  );
                }
                widget.onLocationSelected(details);

                // **Reset the Search Bar**
                setState(() {
                  _textController.clear(); // Clears the search text
                  _searchResults.clear(); // Hides the search results
                });
                if (context.mounted) {
                  FocusScope.of(context).unfocus(); // Dismisses the keyboard
                }
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
        final data = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        var results = data['results'] as List<dynamic>;

        // Print the results
        debugPrint("Search results for '$query': $results");

        // Set the first 5 results to the search results
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
