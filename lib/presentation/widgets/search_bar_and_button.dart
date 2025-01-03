import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:flutter/material.dart';

class SearchWithButton extends StatefulWidget {
  const SearchWithButton({Key? key}) : super(key: key);

  @override
  _SearchWithButtonState createState() => _SearchWithButtonState();
}

class _SearchWithButtonState extends State<SearchWithButton> {
  String? _currentStyleName; // Default selected value

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          flex: 2, // Makes the dropdown occupy 2/6 of the row's width
          child: Container(
            height: 40, // Fixed height for the dropdown
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(30), // Circular corners
            ),
            child: BlocBuilder<MapBloc, MapState>(
              builder: (context, state) {
                final styles = state.availableStyles;

                return DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    isDense: true,
                    isExpanded: true,
                    value: _currentStyleName,
                    hint: const Text(
                      'Select Theme',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    items: styles
                        .map((style) => DropdownMenuItem<String>(
                              value: style['name'],
                              child: Text(
                                style['name']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white, // White text
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      final selectedStyle = styles.firstWhere(
                        (style) => style['name'] == value,
                        orElse: () => <String, String>{}, // Provide a default empty map
                      );
                      if (selectedStyle.isNotEmpty) {
                        context.read<MapBloc>().updateStyle(selectedStyle['style_url']!);
                        setState(() {
                          _currentStyleName = value;
                        });
                      }
                    },
                    buttonStyleData: const ButtonStyleData(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    iconStyleData: const IconStyleData(
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                      ),
                      iconSize: 20,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.7),
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
          ),
        ),
        const SizedBox(width: 8), // Spacing between dropdown and search bar
        Flexible(
          flex: 4, // Makes the search bar occupy 4/6 of the row's width
          child: _buildSearchBar(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40, // Fixed height for the search bar
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search location...",
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 16), // Search icon
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onSubmitted: (value) {
          debugPrint("Search query: $value");
        },
      ),
    );
  }
}
