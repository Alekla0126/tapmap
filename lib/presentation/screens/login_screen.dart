import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tap_map_app/presentation/widgets/dark_light_switch.dart';
import '../../../domain/blocs/auth_bloc.dart';
import '../widgets/rounded_text_field.dart';
import '../widgets/rounded_button.dart';
import 'package:flutter/material.dart';
import 'forgot_password.dart';
import 'map_screen.dart';
import 'register.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dispatch CheckTokenEvent when the screen is loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(CheckTokenEvent());
    });

    return Scaffold(
      appBar: buildAppBar("Tap Map"),
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
                RoundedTextField(
                  controller: _emailController,
                  labelText: "Email",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                RoundedTextField(
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
                    return RoundedButton(
                      text: "Login",
                      onPressed: () {
                        final email = _emailController.text.trim();
                        final password = _passwordController.text.trim();
                        if (email.isNotEmpty && password.isNotEmpty) {
                          context.read<AuthBloc>().add(
                                LoginEvent(email: email, password: password),
                              );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter email and password'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 20), // Add spacing between the buttons
                RoundedButton(
                  text: "Register",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RegisterScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20), // Add spacing before Forgot Password
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Forgot My Password?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
