import 'package:flutter/material.dart';
import '../content/content_loader.dart';
import '../content/content_repository.dart';
import '../content/game_content.dart';
import '../domain/models/models.dart';
import '../ui/widgets/game_icon.dart';
import '../ui/widgets/game_glyph.dart';
import 'download.dart';
import 'stand_app.dart';
import 'stand_assets.dart';

class StandLauncher extends StatefulWidget {
  const StandLauncher({super.key, required this.assets});
  final StandAssetBundle assets;
  @override
  State<StandLauncher> createState() => _StandLauncherState();
}

class _StandLauncherState extends State<StandLauncher> {
  ContentBundle? content;
  SoundScheme? sounds;
  Map<String, dynamic>? config;
  double progress = 0;
  bool failed = false, ready = false, entered = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      failed = false;
      ready = false;
      progress = 0;
    });
    try {
      content = await const ContentLoader().loadAll();
      config = await GameContent.load();
      sounds = await const ContentLoader().loadSoundScheme();
      await widget.assets.preload((done, total) {
        if (mounted) {
          setState(() => progress = total == 0 ? .9 : done / total * .9);
        }
      });
      await GameIcon.preload();
      for (final sheet in [
        'dreams-a',
        'dreams-b',
        'essentials',
        'learning',
        'food',
        'care',
        'world',
        'friends',
        'actions',
        'signals',
        'dreams-solo-robot',
        'dreams-solo-keyboard',
        'food-solo-icecream',
        'food-solo-cake',
      ]) {
        await loadGameArtSheet(sheet);
      }
      if (mounted) {
        setState(() {
          progress = 1;
          ready = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (entered) {
      return DefaultAssetBundle(
          bundle: widget.assets,
          child: StandApp(content: content!, config: config!, sounds: sounds));
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Финни — тестовый стенд',
      theme: ThemeData(
          useMaterial3: true,
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xff263b56))),
      home: Scaffold(
        backgroundColor: const Color(0xffeef0f2),
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sports_esports_outlined,
                      size: 48, color: Color(0xff263b56)),
                  const SizedBox(height: 24),
                  const Text('Тестовый стенд Финни',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  const Text(
                      'Здесь можно попробовать игру и проверить её состояния. Это веб-стенд, а не установленное приложение.',
                      style: TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 12),
                  const Text(
                      'Скорость первой загрузки напрямую зависит от интернета. Сначала загрузим картинки, чтобы они не появлялись по частям во время игры.',
                      style: TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(
                      value: failed ? 0 : progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 10),
                  Text(
                      failed
                          ? 'Не удалось загрузить игру. Проверьте интернет и попробуйте ещё раз.'
                          : ready
                              ? 'Всё готово'
                              : 'Загружаем игру · ${(progress * 100).round()}%',
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: failed
                          ? load
                          : ready
                              ? () => setState(() => entered = true)
                              : null,
                      child:
                          Text(failed ? 'Повторить загрузку' : 'Открыть игру')),
                  const SizedBox(height: 20),
                  const Text(
                      'Для полноценной игры на Android скачайте APK: после установки интернет не нужен.',
                      style: TextStyle(fontSize: 14, height: 1.5)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: downloadApk,
                      icon: const Icon(Icons.download),
                      label: const Text('Скачать APK для Android')),
                ]),
          ),
        ))),
      ),
    );
  }
}
