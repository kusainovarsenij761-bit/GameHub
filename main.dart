import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_mode.dart';

void main() => runApp(const GameHubApp());

const bg = Color(0xFF0B0A14);
const panel = Color(0xFF171426);
const accent = Color(0xFF9B5CFF);
const accent2 = Color(0xFF36D9C5);

class GameHubApp extends StatelessWidget {
  const GameHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accent2,
          surface: panel,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF211D32),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class PlayerProfile {
  PlayerProfile({
    required this.id,
    required this.game,
    required this.nickname,
    required this.kills,
    required this.deaths,
    required this.wins,
    required this.matches,
  });

  final String id;
  String game;
  String nickname;
  int kills;
  int deaths;
  int wins;
  int matches;

  double get kd => deaths == 0 ? kills.toDouble() : kills / deaths;
  double get winRate => matches == 0 ? 0 : wins * 100 / matches;

  Map<String, dynamic> toJson() => {
    'id': id, 'game': game, 'nickname': nickname, 'kills': kills,
    'deaths': deaths, 'wins': wins, 'matches': matches,
  };

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
    id: j['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    game: j['game'] as String? ?? 'PUBG Mobile',
    nickname: j['nickname'] as String? ?? '',
    kills: (j['kills'] as num?)?.toInt() ?? 0,
    deaths: (j['deaths'] as num?)?.toInt() ?? 0,
    wins: (j['wins'] as num?)?.toInt() ?? 0,
    matches: (j['matches'] as num?)?.toInt() ?? 0,
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<PlayerProfile> profiles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('gamehub_profiles_v2') ?? [];
    final loaded = <PlayerProfile>[];
    for (final entry in raw) {
      try {
        final decoded = Map<String, dynamic>.from(
          // SharedPreferences stores JSON strings; decoded in helper below.
          jsonDecode(entry),
        );
        loaded.add(PlayerProfile.fromJson(decoded));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      profiles
        ..clear()
        ..addAll(loaded);
      loading = false;
    });
  }

  Map<String, dynamic> _decodeJson(String value) {
    // Kept separate so malformed saved entries can be skipped safely.
    return Map<String, dynamic>.from(
      (const _JsonDecoder()).decode(value) as Map,
    );
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'gamehub_profiles_v2',
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> _openEditor({PlayerProfile? existing}) async {
    final result = await showModalBottomSheet<PlayerProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      builder: (_) => ProfileEditor(profile: existing),
    );
    if (result == null) return;
    setState(() {
      final index = profiles.indexWhere((p) => p.id == result.id);
      if (index >= 0) {
        profiles[index] = result;
      } else {
        profiles.add(result);
      }
    });
    await _saveProfiles();
  }

  Future<void> _deleteProfile(PlayerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Удалить профиль?'),
        content: Text('Профиль «${profile.nickname}» будет удалён с устройства.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => profiles.removeWhere((p) => p.id == profile.id));
    await _saveProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header()),
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 4),
                  child: Text('ИГРОВОЙ ЦЕНТР', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w700)),
                )),
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: GameLauncherCard(),
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Мои профили', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                      Text('${profiles.length}', style: const TextStyle(color: accent2, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add),
                        tooltip: 'Добавить профиль',
                      ),
                    ],
                  ),
                )),
                if (profiles.isEmpty)
                  const SliverToBoxAdapter(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: _EmptyState(),
                  ))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    sliver: SliverList.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final p = profiles[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ProfileCard(
                            profile: p,
                            onEdit: () => _openEditor(existing: p),
                            onDelete: () => _deleteProfile(p),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
      ),
      floatingActionButton: profiles.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Профиль'),
          )
        : null,
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    child: Row(
      children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [accent, Color(0xFF5B4DFF)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: accent.withOpacity(.25), blurRadius: 22)],
          ),
          child: const Icon(Icons.sports_esports_rounded, size: 30),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GAMEHUB', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            SizedBox(height: 3),
            Text('Твой игровой профиль', style: TextStyle(color: Colors.white60)),
          ],
        )),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.bolt, color: accent2),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22)),
    child: const Column(
      children: [
        Icon(Icons.person_search_rounded, size: 42, color: accent),
        SizedBox(height: 12),
        Text('Пока нет профилей', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('Добавь игровой профиль, чтобы отслеживать K/D и Win Rate.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit, required this.onDelete});
  final PlayerProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pubg = profile.game == 'PUBG Mobile';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: (pubg ? accent : accent2).withOpacity(.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(pubg ? Icons.local_fire_department : Icons.shield_moon, color: pubg ? accent : accent2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.nickname, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(profile.game, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              )),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            _Stat(label: 'K/D', value: profile.kd.toStringAsFixed(2), color: accent),
            _Stat(label: 'WIN RATE', value: '${profile.winRate.toStringAsFixed(1)}%', color: accent2),
            _Stat(label: 'МАТЧИ', value: '${profile.matches}', color: Colors.white),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    margin: const EdgeInsets.only(right: 7),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1)),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
    ]),
  ));
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, this.profile});
  final PlayerProfile? profile;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final TextEditingController _kills;
  late final TextEditingController _deaths;
  late final TextEditingController _wins;
  late final TextEditingController _matches;
  late String _game;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _game = p?.game ?? 'PUBG Mobile';
    _nickname = TextEditingController(text: p?.nickname ?? '');
    _kills = TextEditingController(text: '${p?.kills ?? 0}');
    _deaths = TextEditingController(text: '${p?.deaths ?? 0}');
    _wins = TextEditingController(text: '${p?.wins ?? 0}');
    _matches = TextEditingController(text: '${p?.matches ?? 0}');
  }

  @override
  void dispose() {
    _nickname.dispose(); _kills.dispose(); _deaths.dispose(); _wins.dispose(); _matches.dispose();
    super.dispose();
  }

  int _number(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 24),
    child: SingleChildScrollView(child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.profile == null ? 'Новый профиль' : 'Редактирование', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          value: _game,
          decoration: const InputDecoration(labelText: 'Игра'),
          items: const [
            DropdownMenuItem(value: 'PUBG Mobile', child: Text('PUBG Mobile')),
            DropdownMenuItem(value: 'Mobile Legends', child: Text('Mobile Legends')),
          ],
          onChanged: (v) => setState(() => _game = v ?? _game),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nickname,
          decoration: const InputDecoration(labelText: 'Игровой ник'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Введи ник' : null,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _numericField(_kills, 'Убийства')),
          const SizedBox(width: 10),
          Expanded(child: _numericField(_deaths, 'Смерти')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _numericField(_wins, 'Победы')),
          const SizedBox(width: 10),
          Expanded(child: _numericField(_matches, 'Матчи')),
        ]),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final wins = _number(_wins), matches = _number(_matches);
            if (wins > matches) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Побед не может быть больше числа матчей')));
              return;
            }
            Navigator.pop(context, PlayerProfile(
              id: widget.profile?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
              game: _game,
              nickname: _nickname.text.trim(),
              kills: _number(_kills),
              deaths: _number(_deaths),
              wins: wins,
              matches: matches,
            ));
          },
          child: const Text('Сохранить профиль'),
        ),
      ]),
    )),
  );

  Widget _numericField(TextEditingController c, String label) => TextFormField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      final n = int.tryParse((v ?? '').trim());
      if (n == null || n < 0) return 'Введи число ≥ 0';
      return null;
    },
  );
}
