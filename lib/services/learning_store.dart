import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==============================================
// LASTSEEN - LEARNING STORE
//
// SINGLE SOURCE OF TRUTH
// NO DUMMY DATA
// LOCAL STORAGE
// VOCABULARY MANAGEMENT
// DAILY LEARNING PROGRESS
// ==============================================

// ==============================================
// STATUS PENGUASAAN KOSAKATA
// ==============================================

enum WordLevel {
  newWord,
  review,
  mastered,
}

// ==============================================
// MODEL KOSAKATA
// ==============================================

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

  // ============================================
  // COPY WITH
  //
  // Mendukung perubahan seluruh informasi
  // tanpa kehilangan data sebelumnya.
  // ============================================

  StudyWord copyWith({
    String? id,
    String? word,
    String? meaning,
    String? pronunciation,
    String? wordType,
    String? exampleEnglish,
    String? exampleIndonesia,
    WordLevel? level,
  }) {
    return StudyWord(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      pronunciation: pronunciation ?? this.pronunciation,
      wordType: wordType ?? this.wordType,
      exampleEnglish: exampleEnglish ?? this.exampleEnglish,
      exampleIndonesia: exampleIndonesia ?? this.exampleIndonesia,
      level: level ?? this.level,
    );
  }

  // ============================================
  // STATUS HELPER
  // ============================================

  bool get isNewWord => level == WordLevel.newWord;

  bool get needsReview => level == WordLevel.review;

  bool get isMastered => level == WordLevel.mastered;

  String get statusLabel {
    switch (level) {
      case WordLevel.newWord:
        return 'Belajar';

      case WordLevel.review:
        return 'Review';

      case WordLevel.mastered:
        return 'Hafal';
    }
  }

  // ============================================
  // SERIALIZATION
  // ============================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'pronunciation': pronunciation,
      'wordType': wordType,
      'exampleEnglish': exampleEnglish,
      'exampleIndonesia': exampleIndonesia,
      'level': level.name,
    };
  }

  // ============================================
  // DESERIALIZATION
  // ============================================

  factory StudyWord.fromJson(
    Map<String, dynamic> json,
  ) {
    final savedLevel = json['level']?.toString();

    return StudyWord(
      id: json['id']?.toString() ?? '',
      word: json['word']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      pronunciation: json['pronunciation']?.toString() ?? '',
      wordType: json['wordType']?.toString() ?? '',
      exampleEnglish: json['exampleEnglish']?.toString() ?? '',
      exampleIndonesia: json['exampleIndonesia']?.toString() ?? '',
      level: WordLevel.values.firstWhere(
        (value) => value.name == savedLevel,
        orElse: () => WordLevel.newWord,
      ),
    );
  }
}

// ==============================================
// LEARNING SNAPSHOT
//
// Data yang digunakan oleh:
//
// - Smart Learning
// - Vocabulary Library
// - Vocabulary Review
// - Learning Progress
// - Quiz
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

  // ============================================
  // EMPTY SNAPSHOT
  // ============================================

  factory LearningSnapshot.empty() {
    return const LearningSnapshot(
      dailyGoal: null,
      learnedToday: 0,
      streakDays: 0,
      words: [],
    );
  }

  // ============================================
  // STATISTIK KOSAKATA
  // ============================================

  int get savedCount => words.length;

  int get newWordCount {
    return words
        .where(
          (word) => word.level == WordLevel.newWord,
        )
        .length;
  }

  int get learningCount => newWordCount;

  int get reviewCount {
    return words
        .where(
          (word) => word.level == WordLevel.review,
        )
        .length;
  }

  int get masteredCount {
    return words
        .where(
          (word) => word.level == WordLevel.mastered,
        )
        .length;
  }

  int get unmasteredCount {
    return words
        .where(
          (word) => word.level != WordLevel.mastered,
        )
        .length;
  }

  bool get isEmpty => words.isEmpty;

  bool get hasWords => words.isNotEmpty;

  bool get hasReview => reviewCount > 0;

  bool get hasMastered => masteredCount > 0;

  bool get hasDailyGoal => dailyGoal != null;

  // ============================================
  // DAFTAR BERDASARKAN STATUS
  // ============================================

  List<StudyWord> get newWords {
    return List<StudyWord>.unmodifiable(
      words.where(
        (word) => word.level == WordLevel.newWord,
      ),
    );
  }

  List<StudyWord> get learningWords => newWords;

  List<StudyWord> get reviewWords {
    return List<StudyWord>.unmodifiable(
      words.where(
        (word) => word.level == WordLevel.review,
      ),
    );
  }

  List<StudyWord> get masteredWords {
    return List<StudyWord>.unmodifiable(
      words.where(
        (word) => word.level == WordLevel.mastered,
      ),
    );
  }

  // ============================================
  // PROGRES TARGET HARIAN
  // ============================================

  double get progress {
    final goal = dailyGoal;

    if (goal == null || goal <= 0) {
      return 0.0;
    }

    return (learnedToday / goal).clamp(0.0, 1.0).toDouble();
  }

  int get progressPercentage {
    return (progress * 100).round();
  }

  // ============================================
  // PROGRES PENGUASAAN KOSAKATA
  // ============================================

  double get masteryProgress {
    if (savedCount == 0) {
      return 0.0;
    }

    return (masteredCount / savedCount).clamp(0.0, 1.0).toDouble();
  }

  int get masteryPercentage {
    return (masteryProgress * 100).round();
  }

  double get learningProgress {
    if (savedCount == 0) {
      return 0.0;
    }

    return learningCount / savedCount;
  }

  double get reviewProgress {
    if (savedCount == 0) {
      return 0.0;
    }

    return reviewCount / savedCount;
  }

  // ============================================
  // SISA TARGET HARIAN
  // ============================================

  int get remainingToday {
    final goal = dailyGoal;

    if (goal == null) {
      return 0;
    }

    final remaining = goal - learnedToday;

    return remaining < 0 ? 0 : remaining;
  }

  bool get isDailyGoalCompleted {
    final goal = dailyGoal;

    if (goal == null || goal <= 0) {
      return false;
    }

    return learnedToday >= goal;
  }

  // ============================================
  // ESTIMASI DURASI REVIEW
  //
  // Perkiraan 15 detik per kosakata.
  // Bukan durasi aktual pengguna.
  // ============================================

  int get estimatedReviewMinutes {
    if (reviewCount == 0) {
      return 0;
    }

    return (reviewCount * 15 / 60).ceil();
  }
}

// ==============================================
// LEARNING STORE
// ==============================================

class LearningStore {
  LearningStore._();

  // ============================================
  // LOCAL STORAGE
  // ============================================

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  // Seluruh key lama dipertahankan.
  // Tidak membuat database kosakata baru.

  static const String _goalKey = 'lastseen_daily_goal_v1';

  static const String _dateKey = 'lastseen_learning_date_v1';

  static const String _todayIdsKey = 'lastseen_learning_today_ids_v1';

  static const String _wordsKey = 'lastseen_study_words_v1';

  static const String _streakKey = 'lastseen_streak_v1';

  static const String _lastStudyKey = 'lastseen_last_study_date_v1';

  static const List<int> allowedGoals = [
    5,
    10,
    15,
    20,
  ];

  // ============================================
  // DATA CHANGE NOTIFICATION
  //
  // Halaman yang mendengarkan perubahan
  // dapat memuat ulang data secara otomatis.
  // ============================================

  static final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  static ValueListenable<int> get changes => _revision;

  static void _notifyChanged() {
    _revision.value++;
  }

  // ============================================
  // SERIAL OPERATION QUEUE
  //
  // Mencegah operasi baca-tulis bertabrakan
  // dalam isolate aplikasi yang sama.
  // ============================================

  static Future<void> _operationQueue = Future<void>.value();

  static Future<T> _runExclusive<T>(
    Future<T> Function() operation,
  ) {
    final completer = Completer<T>();

    _operationQueue = _operationQueue.then(
      (_) async {
        try {
          final result = await operation();

          completer.complete(result);
        } catch (error, stackTrace) {
          completer.completeError(
            error,
            stackTrace,
          );
        }
      },
    );

    return completer.future;
  }

  // ============================================
  // NORMALISASI TEKS
  //
  // Digunakan untuk pencarian dan
  // pemeriksaan data duplikat.
  // ============================================

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
  }

  // ============================================
  // TANGGAL LOKAL
  // ============================================

  static String _today() {
    final now = DateTime.now();

    final year = now.year.toString();

    final month = now.month.toString().padLeft(2, '0');

    final day = now.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static int? _daysBetween(
    String before,
    String after,
  ) {
    final a = DateTime.tryParse(before);

    final b = DateTime.tryParse(after);

    if (a == null || b == null) {
      return null;
    }

    final first = DateTime.utc(
      a.year,
      a.month,
      a.day,
    );

    final second = DateTime.utc(
      b.year,
      b.month,
      b.day,
    );

    return second.difference(first).inDays;
  }

  // ============================================
  // VALIDASI KOSAKATA
  // ============================================

  static StudyWord _validateWord(
    StudyWord word,
  ) {
    final id = word.id.trim();

    final english = word.word.trim();

    final meaning = word.meaning.trim();

    if (id.isEmpty) {
      throw ArgumentError(
        'ID kosakata tidak boleh kosong.',
      );
    }

    if (english.isEmpty) {
      throw ArgumentError(
        'Kosakata tidak boleh kosong.',
      );
    }

    if (meaning.isEmpty) {
      throw ArgumentError(
        'Arti kosakata tidak boleh kosong.',
      );
    }

    return word.copyWith(
      id: id,
      word: english,
      meaning: meaning,
      pronunciation: word.pronunciation.trim(),
      wordType: word.wordType.trim(),
      exampleEnglish: word.exampleEnglish.trim(),
      exampleIndonesia: word.exampleIndonesia.trim(),
    );
  }

  // ============================================
  // TARGET BELAJAR HARIAN
  // ============================================

  static Future<int?> getDailyGoal() {
    return _runExclusive<int?>(() async {
      return _prefs.getInt(_goalKey);
    });
  }

  // ============================================
  // TARGET HANYA BOLEH DIPILIH SEKALI
  //
  // Logika asli tetap dipertahankan.
  // ============================================

  static Future<int> chooseGoalOnce(
    int selected,
  ) {
    return _runExclusive<int>(() async {
      if (!allowedGoals.contains(selected)) {
        throw ArgumentError(
          'Pilihan target tidak valid.',
        );
      }

      final existing = await _prefs.getInt(_goalKey);

      if (existing != null) {
        return existing;
      }

      await _prefs.setInt(
        _goalKey,
        selected,
      );

      _notifyChanged();

      return selected;
    });
  }

  // ============================================
  // RESET PROGRES HARIAN
  //
  // - Target tetap tersimpan.
  // - Koleksi kosakata tidak dihapus.
  // - Status penguasaan tidak direset.
  // ============================================

  static Future<void> _checkDailyReset(
    String today,
  ) async {
    final savedDate = await _prefs.getString(_dateKey);

    if (savedDate == today) {
      return;
    }

    // Bersihkan progres lama terlebih dahulu.
    await _prefs.setString(
      _todayIdsKey,
      '[]',
    );

    await _prefs.setString(
      _dateKey,
      today,
    );
  }

  // ============================================
  // MEMBACA AKTIVITAS HARI INI
  // ============================================

  static Future<Set<String>> _readTodayIds(
    String today,
  ) async {
    await _checkDailyReset(today);

    final raw = await _prefs.getString(_todayIdsKey) ?? '[]';

    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      throw const FormatException(
        'Format progres belajar tidak valid.',
      );
    }

    return decoded
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  // ============================================
  // MEMBACA KOSAKATA
  //
  // Jika belum pernah menyimpan data,
  // hasilnya adalah list kosong.
  //
  // Tidak menggunakan data dummy.
  // ============================================

  static Future<List<StudyWord>> _readWords() async {
    final raw = await _prefs.getString(_wordsKey) ?? '[]';

    if (raw.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      throw const FormatException(
        'Format penyimpanan kosakata tidak valid.',
      );
    }

    final words = <StudyWord>[];

    for (final item in decoded) {
      if (item is! Map) {
        throw const FormatException(
          'Data kosakata tidak valid.',
        );
      }

      final word = StudyWord.fromJson(
        Map<String, dynamic>.from(item),
      );

      // Jangan menghapus data rusak secara diam-diam.
      // Berikan error agar halaman dapat menampilkan
      // opsi muat ulang atau pemulihan.

      if (word.id.trim().isEmpty ||
          word.word.trim().isEmpty ||
          word.meaning.trim().isEmpty) {
        throw const FormatException(
          'Terdapat informasi kosakata yang tidak lengkap.',
        );
      }

      words.add(word);
    }

    return words;
  }

  // ============================================
  // MENULIS KOSAKATA
  // ============================================

  static Future<void> _writeWords(
    List<StudyWord> words,
  ) async {
    final encoded = jsonEncode(
      words.map((word) => word.toJson()).toList(),
    );

    await _prefs.setString(
      _wordsKey,
      encoded,
    );
  }

  // ============================================
  // AMBIL SELURUH KOSAKATA
  // ============================================

  static Future<List<StudyWord>> getWords() {
    return _runExclusive<List<StudyWord>>(
      () async {
        final words = await _readWords();

        return List<StudyWord>.unmodifiable(
          words,
        );
      },
    );
  }

  // ============================================
  // AMBIL KOSAKATA BERDASARKAN ID
  // ============================================

  static Future<StudyWord?> getWordById(
    String wordId,
  ) {
    return _runExclusive<StudyWord?>(
      () async {
        final id = wordId.trim();

        if (id.isEmpty) {
          return null;
        }

        final words = await _readWords();

        final index = words.indexWhere(
          (word) => word.id == id,
        );

        if (index < 0) {
          return null;
        }

        return words[index];
      },
    );
  }

  // ============================================
  // CEK KOSAKATA TERSIMPAN
  // ============================================

  static Future<bool> containsWord(
    String wordId,
  ) async {
    final word = await getWordById(wordId);

    return word != null;
  }

  // ============================================
  // DETEKSI DUPLIKAT INTERNAL
  //
  // Kata yang sama dengan arti berbeda
  // tetap diperbolehkan.
  // ============================================

  static bool _hasDuplicate(
    List<StudyWord> words, {
    required String word,
    required String meaning,
    String? excludeId,
  }) {
    final normalizedWord = _normalize(word);

    final normalizedMeaning = _normalize(meaning);

    if (normalizedWord.isEmpty || normalizedMeaning.isEmpty) {
      return false;
    }

    return words.any((existing) {
      if (existing.id == excludeId) {
        return false;
      }

      final sameWord = _normalize(existing.word) == normalizedWord;

      final sameMeaning = _normalize(existing.meaning) == normalizedMeaning;

      return sameWord && sameMeaning;
    });
  }

  // ============================================
  // CEK DUPLIKAT PUBLIK
  // ============================================

  static Future<bool> isDuplicate({
    required String word,
    required String meaning,
    String? excludeId,
  }) {
    return _runExclusive<bool>(() async {
      final words = await _readWords();

      return _hasDuplicate(
        words,
        word: word,
        meaning: meaning,
        excludeId: excludeId,
      );
    });
  }

  // ============================================
  // GENERATE ID
  //
  // Tidak memerlukan package UUID tambahan.
  // ID diperiksa terhadap koleksi yang tersimpan.
  // ============================================

  static int _idSequence = 0;

  static String _generateId(
    List<StudyWord> words,
  ) {
    String id;

    do {
      _idSequence++;

      final timestamp = DateTime.now().microsecondsSinceEpoch;

      id = 'word_${timestamp}_$_idSequence';
    } while (words.any((word) => word.id == id));

    return id;
  }

  // ============================================
  // TAMBAH KOSAKATA MANUAL
  //
  // Seluruh informasi berasal dari input asli.
  // Tidak menerjemahkan secara otomatis.
  // ============================================

  static Future<StudyWord> addWord({
    required String word,
    required String meaning,
    String pronunciation = '',
    String wordType = '',
    String exampleEnglish = '',
    String exampleIndonesia = '',
  }) {
    return _runExclusive<StudyWord>(
      () async {
        final words = await _readWords();

        final newWord = _validateWord(
          StudyWord(
            id: _generateId(words),
            word: word,
            meaning: meaning,
            pronunciation: pronunciation,
            wordType: wordType,
            exampleEnglish: exampleEnglish,
            exampleIndonesia: exampleIndonesia,
            level: WordLevel.newWord,
          ),
        );

        final duplicate = _hasDuplicate(
          words,
          word: newWord.word,
          meaning: newWord.meaning,
        );

        if (duplicate) {
          throw StateError(
            'Kosakata tersebut sudah tersimpan.',
          );
        }

        words.add(newWord);

        await _writeWords(words);

        _notifyChanged();

        return newWord;
      },
    );
  }

  // ============================================
  // SIMPAN KOSAKATA
  //
  // Fungsi lama tetap dipertahankan.
  //
  // Dapat digunakan oleh:
  // - Translate
  // - Smart Scan
  // - Kamus
  // - Phrasebook
  // - Library
  // ============================================

  static Future<void> saveWord(
    StudyWord word,
  ) {
    return _runExclusive<void>(() async {
      final validated = _validateWord(word);

      final words = await _readWords();

      final index = words.indexWhere(
        (existing) => existing.id == validated.id,
      );

      // ID sama berarti memperbarui data
      // yang sudah tersedia.

      if (index >= 0) {
        final duplicate = _hasDuplicate(
          words,
          word: validated.word,
          meaning: validated.meaning,
          excludeId: validated.id,
        );

        if (duplicate) {
          throw StateError(
            'Kosakata tersebut sudah tersimpan.',
          );
        }

        // Status belajar lama dipertahankan.
        words[index] = validated.copyWith(
          level: words[index].level,
        );
      } else {
        final duplicate = _hasDuplicate(
          words,
          word: validated.word,
          meaning: validated.meaning,
        );

        if (duplicate) {
          // Penyimpanan ulang kata yang sama
          // tidak membuat entri tambahan.
          return;
        }

        // Kata baru tidak otomatis dianggap hafal.
        words.add(
          validated.copyWith(
            level: WordLevel.newWord,
          ),
        );
      }

      await _writeWords(words);

      _notifyChanged();
    });
  }

  // ============================================
  // EDIT KOSAKATA
  //
  // ID dan status penguasaan tetap dipertahankan.
  // Edit kata bukan aktivitas belajar.
  // ============================================

  static Future<StudyWord> updateWord({
    required String wordId,
    String? word,
    String? meaning,
    String? pronunciation,
    String? wordType,
    String? exampleEnglish,
    String? exampleIndonesia,
  }) {
    return _runExclusive<StudyWord>(
      () async {
        final id = wordId.trim();

        final words = await _readWords();

        final index = words.indexWhere(
          (item) => item.id == id,
        );

        if (index < 0) {
          throw StateError(
            'Kosakata tidak ditemukan.',
          );
        }

        final previous = words[index];

        final updated = _validateWord(
          previous.copyWith(
            word: word,
            meaning: meaning,
            pronunciation: pronunciation,
            wordType: wordType,
            exampleEnglish: exampleEnglish,
            exampleIndonesia: exampleIndonesia,
          ),
        );

        final duplicate = _hasDuplicate(
          words,
          word: updated.word,
          meaning: updated.meaning,
          excludeId: previous.id,
        );

        if (duplicate) {
          throw StateError(
            'Kosakata tersebut sudah tersimpan.',
          );
        }

        words[index] = updated;

        await _writeWords(words);

        _notifyChanged();

        return updated;
      },
    );
  }

  // ============================================
  // HAPUS KOSAKATA
  //
  // Statistik koleksi diperbarui.
  //
  // Riwayat belajar yang benar-benar sudah
  // dilakukan tidak dihapus.
  // ============================================

  static Future<bool> deleteWord(
    String wordId,
  ) {
    return _runExclusive<bool>(() async {
      final id = wordId.trim();

      if (id.isEmpty) {
        return false;
      }

      final words = await _readWords();

      final initialLength = words.length;

      words.removeWhere(
        (word) => word.id == id,
      );

      if (words.length == initialLength) {
        return false;
      }

      await _writeWords(words);

      _notifyChanged();

      return true;
    });
  }

  // ============================================
  // HAPUS BEBERAPA KOSAKATA
  //
  // Hanya menghapus ID yang diberikan.
  // Tidak mereset seluruh aplikasi.
  // ============================================

  static Future<int> deleteWords(
    Iterable<String> wordIds,
  ) {
    return _runExclusive<int>(() async {
      final ids =
          wordIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();

      if (ids.isEmpty) {
        return 0;
      }

      final words = await _readWords();

      final initialLength = words.length;

      words.removeWhere(
        (word) => ids.contains(word.id),
      );

      final removed = initialLength - words.length;

      if (removed > 0) {
        await _writeWords(words);

        _notifyChanged();
      }

      return removed;
    });
  }

  // ============================================
  // FILTER KOSAKATA
  // ============================================

  static Future<List<StudyWord>> getWordsByLevel(
    WordLevel level,
  ) {
    return _runExclusive<List<StudyWord>>(
      () async {
        final words = await _readWords();

        return List<StudyWord>.unmodifiable(
          words.where(
            (word) => word.level == level,
          ),
        );
      },
    );
  }

  static Future<List<StudyWord>> getReviewWords() {
    return getWordsByLevel(
      WordLevel.review,
    );
  }

  static Future<List<StudyWord>> getMasteredWords() {
    return getWordsByLevel(
      WordLevel.mastered,
    );
  }

  static Future<List<StudyWord>> getNewWords() {
    return getWordsByLevel(
      WordLevel.newWord,
    );
  }

  // ============================================
  // PENCARIAN KOSAKATA
  //
  // Mendukung pencarian:
  // - Bahasa Inggris
  // - Arti Bahasa Indonesia
  // - Pelafalan
  // - Jenis kata
  // - Contoh kalimat
  //
  // Filter status dapat digunakan bersamaan.
  // ============================================

  static Future<List<StudyWord>> searchWords(
    String query, {
    WordLevel? level,
  }) {
    return _runExclusive<List<StudyWord>>(
      () async {
        final words = await _readWords();

        final keyword = _normalize(query);

        final results = words.where((word) {
          if (level != null && word.level != level) {
            return false;
          }

          if (keyword.isEmpty) {
            return true;
          }

          final fields = [
            word.word,
            word.meaning,
            word.pronunciation,
            word.wordType,
            word.exampleEnglish,
            word.exampleIndonesia,
          ];

          return fields.any(
            (field) => _normalize(field).contains(
              keyword,
            ),
          );
        });

        return List<StudyWord>.unmodifiable(
          results,
        );
      },
    );
  }

  // ============================================
  // DAFTAR KOSAKATA UNTUK LATIHAN
  //
  // Prioritas:
  // 1. Perlu review.
  // 2. Kosakata baru.
  // 3. Kosakata dikuasai jika diminta.
  //
  // Tidak menghasilkan kosakata tambahan.
  // ============================================

  static Future<List<StudyWord>> getStudyQueue({
    int? limit,
    bool includeMastered = false,
  }) {
    return _runExclusive<List<StudyWord>>(
      () async {
        final words = await _readWords();

        final queue = <StudyWord>[
          ...words.where(
            (word) => word.level == WordLevel.review,
          ),
          ...words.where(
            (word) => word.level == WordLevel.newWord,
          ),
          if (includeMastered)
            ...words.where(
              (word) => word.level == WordLevel.mastered,
            ),
        ];

        if (limit != null) {
          if (limit <= 0) {
            return [];
          }

          return List<StudyWord>.unmodifiable(
            queue.take(limit),
          );
        }

        return List<StudyWord>.unmodifiable(
          queue,
        );
      },
    );
  }

  // ============================================
  // UBAH STATUS MANUAL
  //
  // Berbeda dengan reviewWord().
  //
  // Perubahan status melalui Library
  // tidak otomatis menambah target harian
  // atau streak belajar.
  // ============================================

  static Future<bool> updateWordLevel({
    required String wordId,
    required WordLevel level,
  }) {
    return _runExclusive<bool>(() async {
      final id = wordId.trim();

      final words = await _readWords();

      final index = words.indexWhere(
        (word) => word.id == id,
      );

      if (index < 0) {
        return false;
      }

      if (words[index].level == level) {
        return true;
      }

      words[index] = words[index].copyWith(
        level: level,
      );

      await _writeWords(words);

      _notifyChanged();

      return true;
    });
  }

  // ============================================
  // STREAK BERDASARKAN AKTIVITAS NYATA
  // ============================================

  static Future<void> _updateStreak(
    String today,
  ) async {
    final lastStudy = await _prefs.getString(_lastStudyKey);

    final previousStreak = await _prefs.getInt(_streakKey) ?? 0;

    if (lastStudy == today) {
      return;
    }

    int newStreak = 1;

    if (lastStudy != null) {
      final difference = _daysBetween(
        lastStudy,
        today,
      );

      if (difference == 1) {
        newStreak = previousStreak > 0 ? previousStreak + 1 : 1;
      }
    }

    await _prefs.setInt(
      _streakKey,
      newStreak,
    );

    await _prefs.setString(
      _lastStudyKey,
      today,
    );
  }

  // ============================================
  // CATAT AKTIVITAS BELAJAR INTERNAL
  //
  // Satu kosakata dihitung satu kali
  // untuk setiap tanggal.
  // ============================================

  static Future<bool> _recordStudyActivity(
    String wordId,
    String today,
  ) async {
    final todayIds = await _readTodayIds(today);

    final isNewActivity = todayIds.add(wordId);

    if (isNewActivity) {
      await _prefs.setString(
        _todayIdsKey,
        jsonEncode(todayIds.toList()),
      );
    }

    // Tetap periksa streak meskipun ID sudah
    // tercatat, untuk membantu pemulihan
    // apabila penyimpanan sebelumnya terputus.

    await _updateStreak(today);

    return isNewActivity;
  }

  // ============================================
  // SIMPAN HASIL REVIEW
  //
  // Fungsi asli dipertahankan agar kompatibel
  // dengan Smart Learning dan halaman review.
  // ============================================

  static Future<void> reviewWord({
    required String wordId,
    required WordLevel level,
  }) {
    return _runExclusive<void>(() async {
      final id = wordId.trim();

      if (id.isEmpty) {
        return;
      }

      final words = await _readWords();

      final index = words.indexWhere(
        (word) => word.id == id,
      );

      // Jangan membuat aktivitas fiktif
      // untuk kosakata yang tidak tersedia.

      if (index < 0) {
        return;
      }

      final today = _today();

      final previousLevel = words[index].level;

      final levelChanged = previousLevel != level;

      if (levelChanged) {
        words[index] = words[index].copyWith(
          level: level,
        );

        await _writeWords(words);
      }

      // Dipanggil setelah pengguna benar-benar
      // memberikan jawaban atau penilaian
      // pada sesi latihan.

      try {
        await _recordStudyActivity(
          id,
          today,
        );
      } finally {
        // Muat ulang UI apabila terdapat
        // perubahan data yang sudah terjadi.
        _notifyChanged();
      }
    });
  }

  // ============================================
  // CATAT AKTIVITAS LATIHAN
  //
  // Dapat digunakan oleh Quiz apabila pengguna
  // sudah menyelesaikan latihan suatu kata,
  // tanpa mengubah status penguasaan.
  // ============================================

  static Future<bool> recordStudyActivity(
    String wordId,
  ) {
    return _runExclusive<bool>(() async {
      final id = wordId.trim();

      if (id.isEmpty) {
        return false;
      }

      final words = await _readWords();

      final exists = words.any(
        (word) => word.id == id,
      );

      if (!exists) {
        return false;
      }

      final today = _today();

      try {
        return await _recordStudyActivity(
          id,
          today,
        );
      } finally {
        _notifyChanged();
      }
    });
  }

  // ============================================
  // CEK SUDAH DIPELAJARI HARI INI
  // ============================================

  static Future<bool> isStudiedToday(
    String wordId,
  ) {
    return _runExclusive<bool>(() async {
      final todayIds = await _readTodayIds(_today());

      return todayIds.contains(
        wordId.trim(),
      );
    });
  }

  // ============================================
  // AMBIL ID AKTIVITAS HARI INI
  // ============================================

  static Future<Set<String>> getTodayStudiedIds() {
    return _runExclusive<Set<String>>(
      () async {
        final ids = await _readTodayIds(_today());

        return Set<String>.unmodifiable(
          ids,
        );
      },
    );
  }

  // ============================================
  // HITUNG STREAK AKTIF
  // ============================================

  static Future<int> _readActiveStreak(
    String today,
  ) async {
    final lastStudy = await _prefs.getString(_lastStudyKey);

    final storedStreak = await _prefs.getInt(_streakKey) ?? 0;

    if (lastStudy == null || storedStreak <= 0) {
      return 0;
    }

    final difference = _daysBetween(
      lastStudy,
      today,
    );

    // Streak masih aktif apabila pengguna
    // belajar hari ini atau kemarin.

    if (difference == 0 || difference == 1) {
      return storedStreak;
    }

    return 0;
  }

  // ============================================
  // AMBIL JUMLAH STREAK
  // ============================================

  static Future<int> getStreakDays() {
    return _runExclusive<int>(() async {
      return _readActiveStreak(
        _today(),
      );
    });
  }

  // ============================================
  // AMBIL SELURUH DATA TERBARU
  //
  // Sumber data utama untuk UI LastSeen.
  // ============================================

  static Future<LearningSnapshot> load() {
    return _runExclusive<LearningSnapshot>(
      () async {
        final today = _today();

        final goal = await _prefs.getInt(_goalKey);

        final todayIds = await _readTodayIds(today);

        final words = await _readWords();

        final activeStreak = await _readActiveStreak(today);

        return LearningSnapshot(
          dailyGoal: goal,
          learnedToday: todayIds.length,
          streakDays: activeStreak,
          words: List<StudyWord>.unmodifiable(
            words,
          ),
        );
      },
    );
  }
}

// ==============================================
// PILIHAN TARGET HARIAN
//
// DESAIN ASLI LASTSEEN DIPERTAHANKAN.
// TIDAK MENGGANTI FONT.
// TIDAK MENGGANTI DESIGN SYSTEM.
// ==============================================

Future<int?> showDailyGoalPicker(
  BuildContext context,
) {
  const options = [
    (
      5,
      'Santai',
      '5 kosakata per hari',
      Icons.spa_rounded,
    ),
    (
      10,
      'Reguler',
      '10 kosakata per hari',
      Icons.menu_book_rounded,
    ),
    (
      15,
      'Serius',
      '15 kosakata per hari',
      Icons.local_fire_department_rounded,
    ),
    (
      20,
      'Intensif',
      '20 kosakata per hari',
      Icons.rocket_launch_rounded,
    ),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==============================
                // MODAL HANDLE
                // ==============================

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

                // ==============================
                // TITLE
                // ==============================

                const Text(
                  'Tentukan target belajarmu',
                  style: TextStyle(
                    color: Color(0xFF171C31),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                // ==============================
                // DESCRIPTION
                // ==============================

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

                // ==============================
                // DAILY GOAL OPTIONS
                // ==============================

                ...options.map((option) {
                  final (
                    value,
                    name,
                    description,
                    icon,
                  ) = option;

                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: Material(
                      color: const Color(
                        0xFFF7F8FF,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(
                            sheetContext,
                          ).pop(value);
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(
                                0xFFE3E8F5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // ==================
                              // ICON
                              // ==================

                              Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE9EEFF,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    14,
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  color: const Color(
                                    0xFF4664F2,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              // ==================
                              // TEXT
                              // ==================

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Color(
                                          0xFF171C31,
                                        ),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        color: Color(
                                          0xFF8791AC,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ==================
                              // CHEVRON
                              // ==================

                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(
                                  0xFF8791AC,
                                ),
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
        ),
      );
    },
  );
}
