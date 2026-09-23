import 'package:flutter/material.dart';
import 'game_controller.dart';
import 'screens/game_shell.dart';
import 'screens/welcome_screen.dart';
import 'theme/finni_theme.dart';

class FinniApp extends StatefulWidget {
  const FinniApp({super.key, this.controller});
  final GameController? controller;
  @override
  State<FinniApp> createState() => _FinniAppState();
}

class _FinniAppState extends State<FinniApp> {
  late Future<GameController> loading;
  GameController? owned;
  @override
  void initState() {
    super.initState();
    loading = _load();
  }

  Future<GameController> _load() async =>
      widget.controller ?? (owned = await GameController.load());
  @override
  void dispose() {
    owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Питомец Финни',
        debugShowCheckedModeBanner: false,
        theme: finniTheme(),
        home: FutureBuilder<GameController>(
            future: loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Scaffold(
                    body: SafeArea(
                        child: Center(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.folder_open_rounded,
                                          size: 40),
                                      const SizedBox(height: 16),
                                      const Text('Не удалось открыть профиль',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 12),
                                      const Text(
                                          'Сохранение не изменено. Попробуй открыть его ещё раз.'),
                                      const SizedBox(height: 24),
                                      FilledButton.icon(
                                          onPressed: () =>
                                              setState(() => loading = _load()),
                                          icon:
                                              const Icon(Icons.refresh_rounded),
                                          label: const Text('Повторить')),
                                    ])))));
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              final state = snapshot.data!;
              return AnimatedBuilder(
                  animation: state,
                  builder: (context, _) => state.onboarded
                      ? GameShell(state: state)
                      : WelcomeScreen(state: state));
            }),
      );
}
