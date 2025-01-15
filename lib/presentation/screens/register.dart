import 'package:tap_map_app/presentation/widgets/dark_light_switch.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/blocs/auth_bloc.dart';
import '../widgets/rounded_text_field.dart';
import '../widgets/rounded_button.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class RegisterScreen extends StatelessWidget {
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Register"),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration successful!')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LoginScreen(),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RoundedTextField(
                    controller: _firstNameController,
                    labelText: "First Name",
                  ),
                  const SizedBox(height: 20),
                  RoundedTextField(
                    controller: _lastNameController,
                    labelText: "Last Name",
                  ),
                  const SizedBox(height: 20),
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
                  RoundedTextField(
                    controller: _confirmPasswordController,
                    labelText: "Confirm Password",
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state is AuthLoading) {
                        return const CircularProgressIndicator();
                      }
                      return RoundedButton(
                        text: "Register",
                        onPressed: () {
                          final firstName = _firstNameController.text.trim();
                          final lastName = _lastNameController.text.trim();
                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();
                          final confirmPassword =
                              _confirmPasswordController.text.trim();

                          if (firstName.isEmpty ||
                              lastName.isEmpty ||
                              email.isEmpty ||
                              password.isEmpty ||
                              confirmPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all fields'),
                              ),
                            );
                          } else if (password != confirmPassword) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match'),
                              ),
                            );
                          } else {
                            context.read<AuthBloc>().add(
                                  RegisterEvent(
                                    email: email,
                                    password: password,
                                    username: "$firstName$lastName".toLowerCase(),
                                    firstName: firstName,
                                    lastName: lastName,
                                  ),
                                );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
