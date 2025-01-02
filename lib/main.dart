import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'presentation/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'domain/blocs/map_bloc.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MapBloc>(
      create: (context) => MapBloc(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tap Map',
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: MapScreen(),
      ),
    );
  }
}
