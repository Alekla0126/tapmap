import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String authToken;

  AuthSuccess({required this.authToken});

  @override
  List<Object?> get props => [authToken];
}

class AuthFailure extends AuthState {
  final String error;

  AuthFailure({required this.error});

  @override
  List<Object?> get props => [error];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<LoginEvent>(_onLogin);
  }

  // Method to save the token in secure storage.
  void _saveToken(String token) async {
    final storage = FlutterSecureStorage();
    await storage.write
    (key: "auth_token", value: token);
  }

  // Method to login the user.
  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final url = Uri.parse("https://api.tap-map.net/api/auth/token/login/");
    final body = jsonEncode({
      "email": event.email,
      "password": event.password,
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Save the token in secure flutter storage.
        _saveToken(data["auth_token"]);
        emit(AuthSuccess(authToken: data["auth_token"]));
      } else {
        emit(AuthFailure(error: "Invalid email or password."));
      }
    } catch (e) {
      emit(AuthFailure(error: "An error occurred. Please try again."));
    }
  }
}