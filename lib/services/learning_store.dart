import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==============================================
// MODEL KOSAKATA
// ==============================================

enum WordLevel {
  newWord,
  review,
  mastered,
}

class StudyWord {
  final String id;
  final String word;
  final String meaning;
  final String pronunciation;
  final String wordType;
  final String exampleEnglish;
  final String exampleIndonesia;
  final WordLevel level;

  const StudyWord({
    required this.id,
    required this.word,
    required this.meaning,
    this.pronunciation = '',
    this.wordType = '',
    this.exampleEnglish = '',
    this.exampleIndonesia = '',
    this.level = WordLevel.newWord,
  });

  StudyWord copyWith({WordLevel? level}) {
    return StudyWord(
      id: id,
      word: word,
      meaning: meaning,
      pronunciation: pronunciation,
      wordType: wordType,
      exampleEnglish: exampleEnglish,
      exampleIndonesia: exampleIndonesia,
      level: level ?? this.level,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'meaning': meaning,
        'pronunciation': pronunciation,
        'wordType': wordType,
        'exampleEnglish': exampleEnglish,
        'exampleIndonesia': exampleIndonesia,
        'level': level.name,
      };

  factory StudyWord.fromJson(Map<String, dynamic> json) {
    final savedLevel = json['level'] as String?;

    return StudyWord(
      id: json['id'] as String,
      word: json['word'] as String,
      meaning: json['meaning'] as String,
      pronunciation: json['pronunciation'] as String? ?? '',
      wordType: json['wordType'] as String? ?? '',
      exampleEnglish: json['exampleEnglish'] as String? ?? '',
      exampleIndonesia: json['exampleIndonesia'] as String? ?? '',
      level: WordLevel.values.firstWhere(
        (value) => value.name == savedLevel,
        orElse: () => WordLevel.newWord,
      ),
    );
  }
}

// ==============================================
// DATA UNTUK DASHBOARD
// ==============================================

class LearningSnapshot {
  final int? dailyGoal;
  final int learnedToday;
  final int streakDays;
  final List<StudyWord> words;

  const LearningSnapshot({
    required this.dailyGoal,
    required this.learnedToday,
    required this.streakDays,
    required this.words,
  });

  int get savedCount => words.length;

  int get reviewCount =>
      words.where((word) => word.level == WordLevel.review).length;

  int get masteredCount =>
      words.where((word) => word.level == WordLevel.mastered).length;

  double get progress {
    final goal = dailyGoal;

    if (goal == null || goal <= 0) return 0;

    return (learnedToday / goal).clamp(0.0, 1.0).toDouble();
  }
}

// ==============================================
// PENYIMPANAN LASTSEEN
// ==============================================

class LearningStore {
  LearningStore._();

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const _goalKey = 'lastseen_daily_goal_v1';
  static const _dateKey = 'lastseen_learning_date_v1';
  static const _todayIdsKey = 'lastseen_learning_today_ids_v1';
  static const _wordsKey = 'lastseen_study_words_v1';
  static const _streakKey = 'lastseen_streak_v1';
  static const _lastStudyKey = 'lastseen_last_study_date_v1';

  static const allowedGoals = [5, 10, 15, 20];

  // ==========================================
  // TANGGAL LOKAL
  // ==========================================

  static String _today() {
    final now = DateTime.now();

    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static int _daysBetween(String before, String after) {
    final a = DateTime.parse(before);
    final b = DateTime.parse(after);

    final first = DateTime.utc(a.year, a.month, a.day);
    final second = DateTime.utc(b.year, b.month, b.day);

    return second.difference(first).inDays;
  }

  // ==========================================
  // TARGET HANYA BOLEH DIPILIH SEKALI
  // ==========================================

  static Future<int?> getDailyGoal() {
    return _prefs.getInt(_goalKey);
  }

  static Future<int> chooseGoalOnce(int selected) async {
    if (!allowedGoals.contains(selected)) {
      throw ArgumentError('Pilihan target tidak valid.');
    }

    final existing = await _prefs.getInt(_goalKey);

    // Jika sudah pernah memilih,
    // gunakan pilihan lama.
    if (existing != null) {
      return existing;
    }

    await _prefs.setInt(_goalKey, selected);

    return selected;
  }

  // ==========================================
  // RESET PROGRES SAAT TANGGAL BERGANTI
  //
  // TARGET TIDAK DIHAPUS.
  // ==========================================

  static Future<void> _checkDailyReset() async {
    final today = _today();
    final savedDate = await _prefs.getString(_dateKey);

    if (savedDate == today) {
      return;
    }

    await _prefs.setString(_dateKey, today);
    await _prefs.setString(_todayIdsKey, '[]');
  }

  static Future<Set<String>> _readTodayIds() async {
    await _checkDailyReset();

    final raw = await _prefs.getString(_todayIdsKey) ?? '[]';

    final decoded = jsonDecode(raw) as List<dynamic>;

    return decoded.map((item) => item.toString()).toSet();
  }

  // ==========================================
  // KOSAKATA TERSIMPAN
  // ==========================================

  static Future<List<StudyWord>> _readWords() async {
    final raw = await _prefs.getString(_wordsKey) ?? '[]';

    final decoded = jsonDecode(raw) as List<dynamic>;

    return decoded.map((item) {
      return StudyWord.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();
  }

  static Future<void> _writeWords(
    List<StudyWord> words,
  ) async {
    final encoded = jsonEncode(
      words.map((word) => word.toJson()).toList(),
    );

    await _prefs.setString(_wordsKey, encoded);
  }

  // Nantinya dipanggil oleh fitur Kamus/
  // Phrasebook saat pengguna menyimpan kata.
  static Future<void> saveWord(StudyWord word) async {
    final words = await _readWords();

    final index = words.indexWhere(
      (existing) => existing.id == word.id,
    );

    if (index >= 0) {
      // Pertahankan status belajar sebelumnya.
      words[index] = word.copyWith(
        level: words[index].level,
      );
    } else {
      words.add(word);
    }

    await _writeWords(words);
  }

  // ==========================================
  // SIMPAN HASIL REVIEW
  // ==========================================

  static Future<void> reviewWord({
    required String wordId,
    required WordLevel level,
  }) async {
    final words = await _readWords();

    final index = words.indexWhere(
      (word) => word.id == wordId,
    );

    if (index < 0) return;

    words[index] = words[index].copyWith(
      level: level,
    );

    await _writeWords(words);

    final todayIds = await _readTodayIds();

    // Satu kata hanya dihitung satu kali
    // untuk target pada tanggal yang sama.
    if (todayIds.contains(wordId)) return;

    todayIds.add(wordId);

    await _prefs.setString(
      _todayIdsKey,
      jsonEncode(todayIds.toList()),
    );

    // ========================================
    // STREAK DARI AKTIVITAS NYATA
    // ========================================

    final today = _today();

    final lastStudy = await _prefs.getString(_lastStudyKey);

    final previousStreak = await _prefs.getInt(_streakKey) ?? 0;

    if (lastStudy != today) {
      int newStreak = 1;

      if (lastStudy != null && _daysBetween(lastStudy, today) == 1) {
        newStreak = previousStreak + 1;
      }

      await _prefs.setInt(_streakKey, newStreak);
      await _prefs.setString(_lastStudyKey, today);
    }
  }

  // ==========================================
  // AMBIL SEMUA DATA TERBARU
  // ==========================================

  static Future<LearningSnapshot> load() async {
    final goal = await getDailyGoal();
    final todayIds = await _readTodayIds();
    final words = await _readWords();

    final lastStudy = await _prefs.getString(_lastStudyKey);

    final storedStreak = await _prefs.getInt(_streakKey) ?? 0;

    int activeStreak = 0;

    if (lastStudy != null) {
      final difference = _daysBetween(
        lastStudy,
        _today(),
      );

      if (difference == 0 || difference == 1) {
        activeStreak = storedStreak;
      }
    }

    return LearningSnapshot(
      dailyGoal: goal,
      learnedToday: todayIds.length,
      streakDays: activeStreak,
      words: words,
    );
  }
}

// ==============================================
// PILIHAN TARGET HARIAN
// HANYA MUNCUL SEBELUM TARGET TERSIMPAN
// ==============================================

Future<int?> showDailyGoalPicker(
  BuildContext context,
) {
  const options = [
    (5, 'Santai', '5 kosakata per hari', Icons.spa_rounded),
    (10, 'Reguler', '10 kosakata per hari', Icons.menu_book_rounded),
    (15, 'Serius', '15 kosakata per hari', Icons.local_fire_department_rounded),
    (20, 'Intensif', '20 kosakata per hari', Icons.rocket_launch_rounded),
  ];

  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 5,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E7F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Tentukan target belajarmu',
                style: TextStyle(
                  color: Color(0xFF171C31),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih jumlah kosakata yang ingin kamu '
                'pelajari setiap hari. Kamu cukup '
                'memilih satu kali.',
                style: TextStyle(
                  color: Color(0xFF8791AC),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ...options.map((option) {
                final (value, name, description, icon) = option;

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: Material(
                    color: const Color(0xFFF7F8FF),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(sheetContext).pop(value);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE3E8F5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9EEFF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                icon,
                                color: const Color(0xFF4664F2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Color(0xFF171C31),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      color: Color(0xFF8791AC),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF8791AC),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
