import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/blocs/auth_bloc.dart';
import '../widgets/dark_light_switch.dart';
import '../widgets/rounded_text_field.dart';
import '../widgets/rounded_button.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();

  ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar('Forgot My Password'),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is PasswordResetSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Password reset email sent!")),
            );
            Navigator.pop(context); // Navigate back to LoginScreen
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
                  labelText: "Enter your email",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return const CircularProgressIndicator();
                    }
                    return RoundedButton(
                      text: "Send Reset Link",
                      onPressed: () {
                        final email = _emailController.text.trim();
                        if (email.isNotEmpty) {
                          context.read<AuthBloc>().add(
                                ForgotPasswordEvent(email: email),
                              );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter your email'),
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
    );
  }
}
