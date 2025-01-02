import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/blocs/auth_bloc.dart';
import '../../../domain/blocs/map_bloc.dart';
import 'package:flutter/material.dart';
import 'map_screen.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        actions: [
          BlocBuilder<MapBloc, MapState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(state.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                onPressed: () {
                  context.read<MapBloc>().toggleTheme();
                },
              );
            },
          ),
        ],
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MapScreen(),
              ),
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRoundedTextField(
                  controller: _emailController,
                  labelText: "Email",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                _buildRoundedTextField(
                  controller: _passwordController,
                  labelText: "Password",
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return const CircularProgressIndicator();
                    }
                    return _buildRoundedButton(
                      context,
                      text: "Tap Map Login",
                      onPressed: () {
                        final email = _emailController.text;
                        final password = _passwordController.text;
                        context.read<AuthBloc>().add(
                              LoginEvent(
                                email: email,
                                password: password,
                              ),
                            );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundedTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
      ),
    );
  }

  Widget _buildRoundedButton(BuildContext context,
      {required String text, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
