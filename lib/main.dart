// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:async';

// -----------------------------------------------------------------------------
// 1. 모델 (Models)
// -----------------------------------------------------------------------------

/// 브레인 포그 기록을 위한 데이터 모델
class BrainFogEntry {
  int? id; // sembast에서는 int로 자동 생성되므로 선언
  final int intensity; // 1 (맑음) - 5 (심함)
  final String factors; // 쉼표로 구분된 영향 요인 (예: "수면 부족,스트레스")
  final DateTime date;

  BrainFogEntry({
    this.id,
    required this.intensity,
    required this.factors,
    required this.date,
  });

  // 객체를 Map으로 변환 (데이터베이스 저장을 위함)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'intensity': intensity,
      'factors': factors,
      'date': date.toIso8601String(),
    };
  }

  // Map에서 객체로 변환 (데이터베이스에서 불러올 때 사용)
  factory BrainFogEntry.fromMap(Map<String, dynamic> map) {
    return BrainFogEntry(
      id: map['id'],
      intensity: map['intensity'],
      factors: map['factors'],
      date: DateTime.parse(map['date']),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. 서비스/데이터베이스 헬퍼 (Services/Database Helper)
// -----------------------------------------------------------------------------

/// Sembast 데이터베이스 작업을 위한 헬퍼 클래스
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;
  static final _store = intMapStoreFactory.store('brain_fog_entries');

  Future<Database> get db async {
    if (_db == null) {
      // 웹 환경에서는 sembast_web 사용
      final dbFactory = databaseFactoryWeb;
      _db = await dbFactory.openDatabase('clear_mind.db');
    }
    return _db!;
  }

  Future<void> insertEntry(BrainFogEntry entry) async {
    final database = await db;
    // id가 null이면 자동 생성, 있으면 upsert
    if (entry.id == null) {
      await _store.add(database, entry.toMap());
    } else {
      await _store.record(entry.id!).put(database, entry.toMap());
    }
  }

  Future<List<BrainFogEntry>> getEntries() async {
    final database = await db;
    final records = await _store.find(
      database,
      finder: Finder(sortOrders: [SortOrder('date', false)]),
    );
    return records.map((snapshot) {
      // sembast는 key가 int로 자동 생성됨
      final map = Map<String, dynamic>.from(snapshot.value);
      map['id'] = snapshot.key;
      return BrainFogEntry.fromMap(map);
    }).toList();
  }

  Future<void> deleteEntry(int id) async {
    final database = await db;
    await _store.record(id).delete(database);
  }
}

// -----------------------------------------------------------------------------
// 3. 상태 관리 (State Management) - Provider


// -----------------------------------------------------------------------------

/// 브레인 포그 기록 상태를 관리하는 ChangeNotifier
class BrainFogProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<BrainFogEntry> _entries = [];
  bool _isLoading = true;

  List<BrainFogEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  BrainFogProvider() {
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      _isLoading = true;
      notifyListeners();
      _entries = await _dbHelper.getEntries();
    } catch (e) {
      print('Error loading entries: $e');
      _entries = [];
    } finally {
      _isLoading = false;
      notifyListeners(); // 데이터가 로드되면 UI 업데이트
    }
  }

  Future<void> addEntry(BrainFogEntry entry) async {
    try {
      await _dbHelper.insertEntry(entry);
      await _loadEntries(); // 데이터 추가 후 다시 로드하여 UI 업데이트
    } catch (e) {
      print('Error adding entry: $e');
    }
  }

  Future<void> removeEntry(int id) async {
    try {
      await _dbHelper.deleteEntry(id);
      await _loadEntries(); // 데이터 삭제 후 다시 로드하여 UI 업데이트
    } catch (e) {
      print('Error removing entry: $e');
    }
  }
}

// -----------------------------------------------------------------------------
// 4. 메인 앱 위젯 (Main App Widget)
// -----------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 초기화에 필요
  runApp(
    ChangeNotifierProvider(
      create: (BuildContext context) => BrainFogProvider(), // 앱 전체에 BrainFogProvider 제공
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clear Mind',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          centerTitle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(secondary: Colors.blueAccent),
      ),
      home: const HomePage(),
    );
  }
}

/// 앱의 메인 페이지 (하단 내비게이션 바 포함)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // 현재 선택된 탭 인덱스

  // 각 탭에 해당하는 화면 목록
  static final List<Widget> _widgetOptions = <Widget>[
    const CognitiveTrainingScreen(),
    const BrainFogTrackerScreen(),
    const SolutionsScreen(),
    const RestMeditationScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clear Mind'),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex), // 선택된 탭의 화면 표시
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            label: '인지 훈련',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes_outlined),
            label: '기록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline),
            label: '솔루션',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.self_improvement_outlined),
            label: '휴식/명상',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // 아이템이 4개 이상일 때 고정
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. 각 화면 위젯 (Screen Widgets)
// -----------------------------------------------------------------------------

/// 5.1. 인지 훈련 화면 (Cognitive Training Screen)
class CognitiveTrainingScreen extends StatelessWidget {
  const CognitiveTrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    '인지 훈련 게임',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '기억력, 집중력, 문제 해결 능력을 향상시키는 게임을 통해 뇌를 활성화하세요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const MemoryGame(), // 메모리 게임 위젯 추가
        ],
      ),
    );
  }
}

/// 메모리 게임 위젯
class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  List<String> _emojis = []; // 게임에 사용될 이모지 목록
  List<bool> _cardFlipped = []; // 카드가 뒤집혔는지 여부
  List<bool> _cardMatched = []; // 카드가 매칭되었는지 여부
  int _flippedIndex1 = -1; // 첫 번째 뒤집힌 카드의 인덱스
  int _flippedIndex2 = -1; // 두 번째 뒤집힌 카드의 인덱스
  int _score = 0; // 점수
  bool _isProcessing = false; // 카드 처리 중인지 여부 (중복 클릭 방지)
  int _moves = 0; // 시도 횟수

  final List<String> _availableEmojis = [
    '🍎', '🍌', '🍇', '🍓', '🍍', '🥝', '🍑', '🍓',
    '🚗', '🚲', '🚂', '🚁', '🚀', '⛵', '🚤', '🚢',
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
    '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏉', '🎱',
  ];

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  /// 게임 초기화
  void _initializeGame() {
    _emojis.clear();
    _cardFlipped.clear();
    _cardMatched.clear();
    _flippedIndex1 = -1;
    _flippedIndex2 = -1;
    _score = 0;
    _isProcessing = false;
    _moves = 0;

    // 8쌍의 이모지를 무작위로 선택
    List<String> selectedEmojis = (_availableEmojis.toList()..shuffle()).take(8).toList();
    _emojis = (selectedEmojis + selectedEmojis)..shuffle(); // 두 번씩 추가하고 섞기

    _cardFlipped = List.generate(_emojis.length, (index) => false);
    _cardMatched = List.generate(_emojis.length, (index) => false);
    setState(() {});
  }

  /// 카드 클릭 처리
  void _onCardTap(int index) {
    if (_isProcessing || _cardFlipped[index] || _cardMatched[index]) {
      return; // 처리 중이거나 이미 뒤집혔거나 매칭된 카드면 무시
    }

    setState(() {
      _cardFlipped[index] = true; // 카드 뒤집기
      if (_flippedIndex1 == -1) {
        _flippedIndex1 = index; // 첫 번째 카드 저장
      } else {
        _flippedIndex2 = index; // 두 번째 카드 저장
        _isProcessing = true; // 처리 시작
        _moves++; // 시도 횟수 증가
        _checkForMatch(); // 매칭 확인
      }
    });
  }

  /// 카드 매칭 확인
  void _checkForMatch() {
    if (_emojis[_flippedIndex1] == _emojis[_flippedIndex2]) {
      // 매칭 성공
      _score += 10; // 점수 증가
      _cardMatched[_flippedIndex1] = true;
      _cardMatched[_flippedIndex2] = true;
      _resetFlippedCards(); // 뒤집힌 카드 인덱스 초기화
      if (_cardMatched.every((element) => element)) {
        _showGameCompleteDialog(context); // 모든 카드 매칭 시 게임 완료 다이얼로그 표시
      }
    } else {
      // 매칭 실패
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) { // 위젯이 여전히 마운트되어 있는지 확인
          setState(() {
            _cardFlipped[_flippedIndex1] = false; // 다시 뒤집기
            _cardFlipped[_flippedIndex2] = false; // 다시 뒤집기
            _resetFlippedCards(); // 뒤집힌 카드 인덱스 초기화
          });
        }
      });
    }
  }

  /// 뒤집힌 카드 인덱스 초기화 및 처리 상태 해제
  void _resetFlippedCards() {
    _flippedIndex1 = -1;
    _flippedIndex2 = -1;
    _isProcessing = false;
  }

  /// 게임 완료 다이얼로그 표시
  void _showGameCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 사용자가 다이얼로그 외부를 탭하여 닫을 수 없음
      builder: (BuildContext dialogContext) { // BuildContext 이름을 dialogContext로 변경하여 충돌 방지
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('게임 완료!', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 50, color: Colors.amber),
              const SizedBox(height: 10),
              Text(
                '모든 카드를 맞췄습니다!\n점수: $_score점\n시도 횟수: $_moves회',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('다시 시작', style: TextStyle(color: Colors.blueAccent)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // dialogContext 사용
                _initializeGame(); // 게임 다시 시작
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('점수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$_score', style: const TextStyle(fontSize: 24, color: Colors.blueAccent)),
                  ],
                ),
                Column(
                  children: [
                    const Text('시도 횟수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$_moves', style: const TextStyle(fontSize: 24, color: Colors.blueAccent)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _initializeGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('새 게임'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true, // GridView가 Column 안에 있을 때 필요
          physics: const NeverScrollableScrollPhysics(), // 스크롤 방지
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // 한 줄에 4개 카드
            crossAxisSpacing: 8.0, // 가로 간격
            mainAxisSpacing: 8.0, // 세로 간격
            childAspectRatio: 0.8, // 카드 비율 (너비/높이)
          ),
          itemCount: _emojis.length,
          itemBuilder: (BuildContext gridContext, int index) { // BuildContext 이름을 gridContext로 변경
            return GestureDetector(
              onTap: () => _onCardTap(index),
              child: Card(
                color: _cardMatched[index] ? Colors.grey[300] : Theme.of(gridContext).colorScheme.secondary,
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      final rotate = Tween(begin: 0.0, end: 1.0).animate(animation);
                      return AnimatedBuilder(
                        animation: rotate,
                        child: child,
                        builder: (BuildContext builderContext, Widget? child) { // BuildContext 이름을 builderContext로 변경
                          final isFront = _cardFlipped[index] || _cardMatched[index];
                          final angle = isFront ? 0.0 : pi;
                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // 3D 효과를 위한 원근감
                              ..rotateY(angle * rotate.value),
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                      );
                    },
                    child: _cardFlipped[index] || _cardMatched[index]
                        ? Text(
                            _emojis[index],
                            key: const ValueKey<bool>(true), // 키를 변경하여 애니메이션 트리거
                            style: const TextStyle(fontSize: 40),
                          )
                        : const Icon(
                            Icons.question_mark,
                            key: ValueKey<bool>(false), // 키를 변경하여 애니메이션 트리거
                            size: 40,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 5.2. 브레인 포그 기록 화면 (Brain Fog Tracker Screen)
class BrainFogTrackerScreen extends StatefulWidget {
  const BrainFogTrackerScreen({super.key});

  @override
  State<BrainFogTrackerScreen> createState() => _BrainFogTrackerScreenState();
}

class _BrainFogTrackerScreenState extends State<BrainFogTrackerScreen> {
  double _currentIntensity = 3.0; // 현재 브레인 포그 강도 (1-5)
  final Map<String, bool> _selectedFactors = {
    '수면 부족': false,
    '스트레스': false,
    '운동 부족': false,
    '특정 음식': false,
    '피로': false,
    '호르몬 변화': false,
    '질병': false,
    '약물': false,
  };

  @override
  Widget build(BuildContext context) {
    // BrainFogProvider를 Watch하여 데이터 변경 감지
    final brainFogProvider = Provider.of<BrainFogProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '브레인 포그 기록',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '오늘의 브레인 포그 강도와 영향 요인을 기록하여 패턴을 파악하세요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '오늘의 브레인 포그 강도: ${_currentIntensity.toInt()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _currentIntensity,
                    min: 1,
                    max: 5,
                    divisions: 4, // 1, 2, 3, 4, 5
                    label: _currentIntensity.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _currentIntensity = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '영향 요인 (복수 선택 가능)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8.0,
                    children: _selectedFactors.keys.map((String key) {
                      return FilterChip(
                        label: Text(key),
                        selected: _selectedFactors[key]!,
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedFactors[key] = selected;
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _selectedFactors[key]! ? Colors.white : Colors.black87,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final selectedFactorList = _selectedFactors.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .join(',');

                      final newEntry = BrainFogEntry(
                        intensity: _currentIntensity.toInt(),
                        factors: selectedFactorList,
                        date: DateTime.now(),
                      );
                      await brainFogProvider.addEntry(newEntry);
                      if (mounted) { // Ensure the widget is still mounted before showing SnackBar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('기록이 저장되었습니다!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50), // 버튼 너비를 최대로
                    ),
                    child: const Text('기록 저장'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '나의 브레인 포그 기록',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          // 로딩 중일 때 표시
          if (brainFogProvider.isLoading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          // 기록이 있을 때만 그래프 표시
          else if (brainFogProvider.entries.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              // 최근 7일 데이터만 표시 (데이터가 역순으로 저장되므로 인덱스 계산 필요)
                              final reversedEntries = brainFogProvider.entries.reversed.toList();
                              if (value.toInt() >= reversedEntries.length || value.toInt() < 0) {
                                return const Text('');
                              }
                              final entry = reversedEntries[value.toInt()];
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4,
                                child: Text(DateFormat('MM/dd').format(entry.date), style: const TextStyle(fontSize: 10)),
                              );
                            },
                            interval: 1, // 모든 날짜 표시
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                            },
                            interval: 1,
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: const Color(0xff37434d), width: 1),
                      ),
                      minX: 0,
                      maxX: (min(brainFogProvider.entries.length, 7) - 1).toDouble().clamp(0, double.infinity), // 최대 7개 데이터 (0-6)
                      minY: 0,
                      maxY: 5,
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            min(brainFogProvider.entries.length, 7), // 최대 7개 데이터만 그래프에 표시
                            (index) {
                              final entry = brainFogProvider.entries.reversed.toList()[index]; // 최신 데이터가 오른쪽에 오도록 역순으로 접근
                              return FlSpot(index.toDouble(), entry.intensity.toDouble());
                            },
                          ),
                          isCurved: true,
                          color: Theme.of(context).colorScheme.secondary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // 기록 목록
          if (!brainFogProvider.isLoading)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: brainFogProvider.entries.length,
              itemBuilder: (BuildContext listContext, int index) { // BuildContext 이름을 listContext로 변경
                final entry = brainFogProvider.entries[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    title: Text(
                      '${DateFormat('yyyy년 MM월 dd일').format(entry.date)} - 강도: ${entry.intensity}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('요인: ${entry.factors.isEmpty ? '없음' : entry.factors}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        // 삭제 확인 다이얼로그
                        final bool? confirmDelete = await showDialog<bool>(
                          context: listContext, // listContext 사용
                          builder: (BuildContext dialogContext) { // BuildContext 이름을 dialogContext로 변경
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('기록 삭제', textAlign: TextAlign.center),
                              content: const Text('이 기록을 정말 삭제하시겠습니까?', textAlign: TextAlign.center),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop(false);
                                  },
                                ),
                                TextButton(
                                  child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop(true);
                                  },
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmDelete == true) {
                          await brainFogProvider.removeEntry(entry.id!);
                          if (mounted) { // Ensure the widget is still mounted before showing SnackBar
                            ScaffoldMessenger.of(listContext).showSnackBar( // listContext 사용
                              const SnackBar(content: Text('기록이 삭제되었습니다.')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// 5.3. 솔루션 화면 (Solutions Screen)
class SolutionsScreen extends StatelessWidget {
  const SolutionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    '브레인 포그 솔루션',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '브레인 포그 완화에 도움이 되는 다양한 생활 습관 가이드를 확인하세요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          _buildSolutionTile(
            context,
            '수면 가이드',
            '충분한 수면은 뇌 기능 회복에 필수적입니다. 규칙적인 수면 습관을 만들고, 잠들기 전 스마트폰 사용을 자제하며, 편안한 수면 환경을 조성하세요. 하루 7~8시간의 수면을 권장합니다.',
            Icons.bedtime_outlined,
          ),
          _buildSolutionTile(
            context,
            '운동 가이드',
            '규칙적인 운동은 뇌 혈류를 개선하고 염증을 줄이는 데 도움이 됩니다. 주 3회 이상 유산소 운동(걷기, 조깅 등)을 꾸준히 하고, 가벼운 스트레칭을 병행하세요.',
            Icons.directions_run_outlined,
          ),
          _buildSolutionTile(
            context,
            '식단 가이드',
            '뇌 건강에 좋은 음식을 섭취하세요. 오메가-3 지방산이 풍부한 생선, 항산화 물질이 많은 베리류, 견과류, 녹색 잎채소 등을 충분히 섭취하고, 가공식품과 설탕 섭취는 줄이세요.',
            Icons.restaurant_menu_outlined,
          ),
          _buildSolutionTile(
            context,
            '스트레스 관리',
            '만성 스트레스는 브레인 포그의 주요 원인입니다. 명상, 심호흡, 요가 등 자신에게 맞는 스트레스 해소법을 찾고, 규칙적인 휴식 시간을 가지세요. 취미 활동을 통해 뇌의 피로를 풀어주는 것도 좋습니다.',
            Icons.spa_outlined,
          ),
          _buildSolutionTile(
            context,
            '수분 섭취',
            '충분한 수분 섭취는 뇌 기능을 원활하게 유지하는 데 중요합니다. 하루 8잔 이상의 물을 마시는 것을 목표로 하세요. 탈수는 집중력 저하와 피로감을 유발할 수 있습니다.',
            Icons.water_drop_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionTile(
      BuildContext context, String title, String content, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// 5.4. 휴식/명상 화면 (Rest/Meditation Screen)
class RestMeditationScreen extends StatefulWidget {
  const RestMeditationScreen({super.key});

  @override
  State<RestMeditationScreen> createState() => _RestMeditationScreenState();
}

class _RestMeditationScreenState extends State<RestMeditationScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer(); // 오디오 플레이어 인스턴스
  bool _isPlaying = false; // 현재 재생 중인지 여부
  Duration _duration = Duration.zero; // 현재 오디오의 총 길이
  Duration _position = Duration.zero; // 현재 재생 위치
  String? _currentAudioPath; // 현재 재생 중인 오디오 파일 경로

  // 앱 내에 포함된 오디오 파일 목록 (assets/audio 폴더에 가정)
  final List<Map<String, String>> _audioTracks = [
    {'name': '고요한 숲', 'path': 'audio/forest.mp3'},
    {'name': '잔잔한 파도', 'path': 'audio/waves.mp3'},
    {'name': '빗소리', 'path': 'audio/rain.mp3'},
    {'name': '명상 음악', 'path': 'audio/meditation.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  /// 오디오 플레이어 초기화 및 이벤트 리스너 설정
  void _initAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _position = p);
      }
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero; // 재생 완료 시 위치 초기화
        });
      }
    });
  }

  /// 오디오 재생/일시정지 토글
  Future<void> _togglePlayPause(String audioPath) async {
    try {
      if (_currentAudioPath != audioPath) {
        // 다른 오디오를 선택한 경우
        await _audioPlayer.stop(); // 현재 재생 중인 오디오 중지
        await _audioPlayer.setSource(AssetSource(audioPath)); // 새 오디오 로드
        _currentAudioPath = audioPath;
        await _audioPlayer.resume(); // 재생 시작
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      } else if (_isPlaying) {
        // 현재 오디오가 재생 중이면 일시정지
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      } else {
        // 현재 오디오가 일시정지 상태면 재생
        await _audioPlayer.resume();
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      print('Audio playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오디오 재생 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  /// 오디오 재생 위치 변경
  Future<void> _seek(double value) async {
    try {
      final position = Duration(seconds: value.toInt());
      await _audioPlayer.seek(position);
    } catch (e) {
      print('Seek error: $e');
    }
  }

  /// 시간 포맷 변환 (00:00)
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // 위젯이 dispose될 때 플레이어 리소스 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    '휴식 및 명상',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '마음의 안정을 찾고 뇌의 피로를 풀어주는 명상 오디오를 들어보세요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    _currentAudioPath != null
                        ? _audioTracks.firstWhere((track) => track['path'] == _currentAudioPath)['name']!
                        : '오디오를 선택하세요',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Slider(
                    min: 0.0,
                    max: _duration.inSeconds.toDouble(),
                    value: _position.inSeconds.toDouble(),
                    onChanged: _seek,
                    activeColor: Theme.of(context).colorScheme.secondary,
                    inactiveColor: Colors.grey[300],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position)),
                        Text(_formatDuration(_duration)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      size: 60,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    onPressed: _currentAudioPath != null
                        ? () => _togglePlayPause(_currentAudioPath!)
                        : null, // 오디오 선택 안 됐을 때는 버튼 비활성화
                  ),
                ],
              ),
            ),
          ),
          Text(
            '오디오 트랙',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _audioTracks.length,
            itemBuilder: (BuildContext listContext, int index) { // BuildContext 이름을 listContext로 변경
              final track = _audioTracks[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: Icon(Icons.music_note, color: Theme.of(listContext).colorScheme.secondary),
                  title: Text(track['name']!),
                  trailing: _currentAudioPath == track['path'] && _isPlaying
                      ? Icon(Icons.volume_up, color: Theme.of(listContext).colorScheme.secondary)
                      : null,
                  onTap: () {
                    _togglePlayPause(track['path']!);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
