import 'package:flutter/material.dart';

class RoundedTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String labelText;
  final bool obscureText;

  const RoundedTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.tealAccent : Colors.blue,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
      ),
    );
  }
}
