import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';

class FinniApp extends StatefulWidget {
  const FinniApp({super.key});

  @override
  State<FinniApp> createState() => _FinniAppState();
}

class _FinniAppState extends State<FinniApp> {
  final AppState appState = AppState();

  @override
  void initState() {
    super.initState();
    appState.load();
  }

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Питомец Финни',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFFB74D),
      ),
      home: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          if (appState.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return HomeScreen(appState: appState);
        },
      ),
    );
  }
}
