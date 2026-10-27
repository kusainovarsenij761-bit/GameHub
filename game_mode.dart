import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GameLauncherCard extends StatefulWidget {
  const GameLauncherCard({super.key});

  @override
  State<GameLauncherCard> createState() => _GameLauncherCardState();
}

class _GameLauncherCardState extends State<GameLauncherCard> {
  static const _channel = MethodChannel('gamehub/game_mode');
  bool _busy = false;

  Future<void> _launch(String packageName, String gameName) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _channel.invokeMethod<String>('launchGame', {
        'packageName': packageName,
      });
      if (!mounted) return;
      if (result == 'launched') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$gameName запускается. Игровой режим включён, если выдали разрешение.')),
        );
      } else {
        _message('$gameName не найден. Проверь, установлена ли игра на телефоне.');
      }
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Не удалось запустить игру.');
    } on MissingPluginException {
      if (mounted) _message('Android-модуль не подключён. См. README.md в проекте.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDndSettings() async {
    try {
      await _channel.invokeMethod<void>('openDndSettings');
      if (mounted) _message('Разреши GameHub доступ к режиму «Не беспокоить», затем вернись сюда.');
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Не удалось открыть настройки.');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF282044), Color(0xFF171426)],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF9B5CFF).withOpacity(.24)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.shield_moon_rounded, color: Color(0xFF36D9C5)),
        SizedBox(width: 8),
        Text('Режим без отвлечений', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      const Text(
        'GameHub попробует включить «Не беспокоить» перед запуском игры. Это не блокирует SMS полностью, а подавляет уведомления по правилам Android.',
        style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _openDndSettings,
        icon: const Icon(Icons.settings_outlined),
        label: const Text('Разрешение «Не беспокоить»'),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _GameButton(
          title: 'PUBG Mobile',
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFFB454),
          busy: _busy,
          onTap: () => _launch('com.tencent.ig', 'PUBG Mobile'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _GameButton(
          title: 'Mobile Legends',
          icon: Icons.shield_rounded,
          color: const Color(0xFF36D9C5),
          busy: _busy,
          onTap: () => _launch('com.mobile.legends', 'Mobile Legends'),
        )),
      ]),
    ]),
  );
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    required this.title, required this.icon, required this.color,
    required this.busy, required this.onTap,
  });
  final String title;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: color.withOpacity(.13),
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onPressed: busy ? null : onTap,
    child: Column(children: [
      Icon(icon, size: 25),
      const SizedBox(height: 5),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    ]),
  );
}
