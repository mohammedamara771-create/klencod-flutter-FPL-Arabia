import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FPLArabiaApp());
}

const Color purple = Color(0xFF37003C);
const Color green = Color(0xFF00FF87);
const Color background = Color(0xFF0D1117);
const Color cardColor = Color(0xFF171C25);
const Color secondaryText = Color(0xFF9CA3AF);

const String baseUrl = 'https://fantasy.premierleague.com/api';

class FPLArabiaApp extends StatelessWidget {
  const FPLArabiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FPL Arabia',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
          primary: green,
          secondary: green,
          surface: cardColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: cardColor,
          indicatorColor: Color(0xFF343040),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: MainScreen(),
      ),
    );
  }
}

// =========================
// نماذج البيانات
// =========================

class Player {
  final int id;
  final String name;
  final String firstName;
  final int teamId;
  final int positionId;
  final double price;
  final int totalPoints;
  final int eventPoints;
  final double ownership;
  final String form;
  final String status;
  final String news;
  final String? photo;

  const Player({
    required this.id,
    required this.name,
    required this.firstName,
    required this.teamId,
    required this.positionId,
    required this.price,
    required this.totalPoints,
    required this.eventPoints,
    required this.ownership,
    required this.form,
    required this.status,
    required this.news,
    this.photo,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as int? ?? 0,
      name: json['web_name']?.toString() ?? 'غير معروف',
      firstName: json['first_name']?.toString() ?? '',
      teamId: json['team'] as int? ?? 0,
      positionId: json['element_type'] as int? ?? 0,
      price: (json['now_cost'] as num? ?? 0) / 10,
      totalPoints: json['total_points'] as int? ?? 0,
      eventPoints: json['event_points'] as int? ?? 0,
      ownership: double.tryParse(
            json['selected_by_percent']?.toString() ?? '0',
          ) ??
          0,
      form: json['form']?.toString() ?? '0',
      status: json['status']?.toString() ?? 'a',
      news: json['news']?.toString() ?? '',
      photo: json['photo']?.toString(),
    );
  }

  String get position {
    switch (positionId) {
      case 1:
        return 'حارس';
      case 2:
        return 'دفاع';
      case 3:
        return 'وسط';
      case 4:
        return 'هجوم';
      default:
        return 'غير معروف';
    }
  }

  bool get unavailable => status != 'a';
}

class Club {
  final int id;
  final String name;
  final String shortName;
  final int code;

  const Club({
    required this.id,
    required this.name,
    required this.shortName,
    required this.code,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
      code: json['code'] as int? ?? 0,
    );
  }
}

class Fixture {
  final int id;
  final int? homeTeam;
  final int? awayTeam;
  final int? homeScore;
  final int? awayScore;
  final DateTime? kickoff;
  final int? gameweek;
  final bool finished;

  const Fixture({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.kickoff,
    required this.gameweek,
    required this.finished,
  });

  factory Fixture.fromJson(Map<String, dynamic> json) {
    return Fixture(
      id: json['id'] as int? ?? 0,
      homeTeam: json['team_h'] as int?,
      awayTeam: json['team_a'] as int?,
      homeScore: json['team_h_score'] as int?,
      awayScore: json['team_a_score'] as int?,
      kickoff: json['kickoff_time'] == null
          ? null
          : DateTime.tryParse(json['kickoff_time'].toString()),
      gameweek: json['event'] as int?,
      finished: json['finished'] as bool? ?? false,
    );
  }
}

class Gameweek {
  final int id;
  final String name;
  final bool isCurrent;
  final bool isNext;
  final bool finished;
  final bool deadlinePassed;
  final DateTime? deadline;

  const Gameweek({
    required this.id,
    required this.name,
    required this.isCurrent,
    required this.isNext,
    required this.finished,
    required this.deadlinePassed,
    required this.deadline,
  });

  factory Gameweek.fromJson(Map<String, dynamic> json) {
    return Gameweek(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      isCurrent: json['is_current'] as bool? ?? false,
      isNext: json['is_next'] as bool? ?? false,
      finished: json['finished'] as bool? ?? false,
      deadlinePassed: json['deadline_time_epoch'] == null
          ? false
          : (json['deadline_time_epoch'] as num) * 1000 <=
              DateTime.now().millisecondsSinceEpoch,
      deadline: json['deadline_time'] == null
          ? null
          : DateTime.tryParse(json['deadline_time'].toString()),
    );
  }
}

// =========================
// خدمة بيانات فانتازي
// =========================

class FPLService {
  static const Duration timeout = Duration(seconds: 20);

  static Future<Map<String, dynamic>> getJson(String path) async {
    final uri = Uri.parse('$baseUrl/$path');

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'FPLArabia/1.0',
      },
    ).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'تعذر تحميل البيانات. رمز الاستجابة: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception('تنسيق البيانات غير متوقع');
    }

    return decoded;
  }

  static Future<List<dynamic>> getList(String path) async {
    final uri = Uri.parse('$baseUrl/$path');

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'FPLArabia/1.0',
      },
    ).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('تعذر تحميل البيانات');
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (decoded is! List) {
      throw Exception('تنسيق البيانات غير متوقع');
    }

    return decoded;
  }

  static Future<FPLData> loadAll() async {
    final results = await Future.wait([
      getJson('bootstrap-static/'),
      getList('fixtures/'),
    ]);

    final bootstrap = results[0] as Map<String, dynamic>;
    final fixtureJson = results[1] as List<dynamic>;

    final players = (bootstrap['elements'] as List<dynamic>? ?? [])
        .map(
          (item) => Player.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    final clubs = (bootstrap['teams'] as List<dynamic>? ?? [])
        .map(
          (item) => Club.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    final gameweeks = (bootstrap['events'] as List<dynamic>? ?? [])
        .map(
          (item) => Gameweek.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    final fixtures = fixtureJson
        .map(
          (item) => Fixture.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    return FPLData(
      players: players,
      clubs: clubs,
      gameweeks: gameweeks,
      fixtures: fixtures,
    );
  }
}

class FPLData {
  final List<Player> players;
  final List<Club> clubs;
  final List<Gameweek> gameweeks;
  final List<Fixture> fixtures;

  const FPLData({
    required this.players,
    required this.clubs,
    required this.gameweeks,
    required this.fixtures,
  });

  Gameweek? get currentGameweek {
    for (final gameweek in gameweeks) {
      if (gameweek.isCurrent) return gameweek;
    }
    return null;
  }

  Gameweek? get nextGameweek {
    for (final gameweek in gameweeks) {
      if (gameweek.isNext) return gameweek;
    }
    return null;
  }

  String clubName(int id) {
    for (final club in clubs) {
      if (club.id == id) return club.name;
    }
    return 'غير معروف';
  }

  Club? findClub(int id) {
    for (final club in clubs) {
      if (club.id == id) return club;
    }
    return null;
  }
}

// =========================
// الشاشة الرئيسية
// =========================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  FPLData? data;
  bool loading = true;
  String? error;
  DateTime? lastUpdated;

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    loadData();

    refreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => loadData(silent: true),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadData({bool silent = false}) async {
    if (loading && silent) return;

    if (!silent && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final freshData = await FPLService.loadAll();

      if (!mounted) return;

      setState(() {
        data = freshData;
        loading = false;
        error = null;
        lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(data: data, onRefresh: loadData),
      PlayersPage(data: data),
      ClubsPage(data: data),
      FixturesPage(data: data),
      StatisticsPage(data: data),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_soccer, color: green, size: 28),
            SizedBox(width: 10),
            Text(
              'FPL Arabia',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: () => loadData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (lastUpdated != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              color: cardColor,
              child: Text(
                'آخر تحديث: ${lastUpdated!.hour.toString().padLeft(2, '0')}:'
                '${lastUpdated!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                ),
              ),
            ),
          if (error != null && data == null)
            Expanded(
              child: ErrorView(
                message: error!,
                onRetry: () => loadData(),
              ),
            )
          else if (loading && data == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: green),
                    SizedBox(height: 16),
                    Text('جارٍ تحميل بيانات فانتازي...'),
                  ],
                ),
              ),
            )
          else if (data != null)
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children: pages,
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('لا توجد بيانات متاحة'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_search_outlined),
            selectedIcon: Icon(Icons.person_search),
            label: 'اللاعبون',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'الأندية',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'المباريات',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'الإحصائيات',
          ),
        ],
      ),
    );
  }
}

// =========================
// الرئيسية
// =========================

class HomePage extends StatelessWidget {
  final FPLData? data;
  final Future<void> Function() onRefresh;

  const HomePage({
    super.key,
    required this.data,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    final current = data!.currentGameweek;
    final next = data!.nextGameweek;

    final topPlayers = [...data!.players]
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    return RefreshIndicator(
      color: green,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [purple, Color(0xFF54205B)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فانتازي الدوري الإنجليزي',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  current?.name ?? 'الجولة الحالية غير متاحة',
                  style: const TextStyle(
                    color: green,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  current?.deadline != null
                      ? 'موعد الإغلاق: ${formatDate(current!.deadline!)}'
                      : 'لم يُعلن موعد الإغلاق',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  next != null
                      ? 'الجولة القادمة: ${next.name}'
                      : 'لا توجد جولة قادمة معلنة',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: 'أرقام الفانتازي'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'اللاعبون',
                  value: '${data!.players.length}',
                  icon: Icons.people,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  title: 'الأندية',
                  value: '${data!.clubs.length}',
                  icon: Icons.shield,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  title: 'المباريات',
                  value: '${data!.fixtures.length}',
                  icon: Icons.sports_soccer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'أفضل اللاعبين بالنقاط'),
          const SizedBox(height: 10),
          ...topPlayers.take(10).map(
                (player) => PlayerTile(
                  player: player,
                  clubName: data!.clubName(player.teamId),
                ),
              ),
        ],
      ),
    );
  }
}

// =========================
// صفحة اللاعبين
// =========================

class PlayersPage extends StatefulWidget {
  final FPLData? data;

  const PlayersPage({super.key, required this.data});

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  String query = '';
  String selectedPosition = 'الكل';
  String sortBy = 'النقاط';

  @override
  Widget build(BuildContext context) {
    if (widget.data == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    final positions = ['الكل', 'حارس', 'دفاع', 'وسط', 'هجوم'];

    final players = widget.data!.players.where((player) {
      final club = widget.data!.clubName(player.teamId);

      final matchesQuery =
          player.name.toLowerCase().contains(query.toLowerCase()) ||
          club.toLowerCase().contains(query.toLowerCase());

      final matchesPosition =
          selectedPosition == 'الكل' ||
          player.position == selectedPosition;

      return matchesQuery && matchesPosition;
    }).toList();

    switch (sortBy) {
      case 'السعر':
        players.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'الأداء':
        players.sort(
          (a, b) =>
              (double.tryParse(b.form) ?? 0)
                  .compareTo(double.tryParse(a.form) ?? 0),
        );
        break;
      case 'الملكية':
        players.sort((a, b) => b.ownership.compareTo(a.ownership));
        break;
      default:
        players.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: 'ابحث عن لاعب أو نادٍ...',
              prefixIcon: const const Icon(
  Icons.home,
  size: 24.0,
  color: Colors.black,
)