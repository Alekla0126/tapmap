import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';

class SearchBarAndResults extends StatefulWidget {
  const SearchBarAndResults({Key? key}) : super(key: key);

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
    return Positioned(
      top: 20.0,
      left: 10.0,
      right: 10.0,
      child: Column(
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
      ),
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
            onTap: () {
              debugPrint("Result tapped: $result");
              _moveCameraToLatLng(result);
            },
          );
        }).toList(),
      ),
    );
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
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _moveCameraToLatLng(Map<String, dynamic> result) {
    final mapBloc = context.read<MapBloc>();

    if (result.containsKey('latitude') && result.containsKey('longitude')) {
      final lat = result['latitude'];
      final lng = result['longitude'];
      mapBloc.mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(lat, lng)),
      );
    } else {
      debugPrint("LatLng not found for result: ${result['id']}");
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }
}
