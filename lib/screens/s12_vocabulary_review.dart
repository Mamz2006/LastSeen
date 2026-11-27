import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../nav.dart';
import '../services/learning_store.dart';
import 's13_vocabulary.dart';

// ==============================================
// LASTSEEN - VOCABULARY REVIEW
//
// - Menggunakan LearningStore
// - Tidak menggunakan data dummy
// - Target mengikuti pilihan pengguna
// - Statistik berdasarkan aktivitas nyata
// - Pelafalan menggunakan Flutter TTS
// - Desain konsisten dengan Smart Learning
// ==============================================

class S12VocabularyReview extends StatefulWidget {
  final int initialFilter;

  const S12VocabularyReview({
    super.key,
    this.initialFilter = 0,
  });

  @override
  State<S12VocabularyReview> createState() => _S12VocabularyReviewState();
}

class _S12VocabularyReviewState extends State<S12VocabularyReview>
    with WidgetsBindingObserver {
  // ==========================================
  // DESIGN SYSTEM LASTSEEN
  // ==========================================

  static const Color primary = Color(0xFF4664F2);
  static const Color ink = Color(0xFF171C31);
  static const Color muted = Color(0xFF8791AC);
  static const Color background = Color(0xFFF5F7FD);
  static const Color border = Color(0xFFE3E8F5);

  static const Color green = Color(0xFF15A879);
  static const Color orange = Color(0xFFEC8C00);
  static const Color red = Color(0xFFE73752);

  // ==========================================
  // CONTROLLER
  // ==========================================

  final FlutterTts _flutterTts = FlutterTts();

  // ==========================================
  // STATE
  // ==========================================

  LearningSnapshot? _data;

  bool _loading = true;
  bool _saving = false;
  bool _flipped = false;
  bool _pickerOpen = false;
  bool _speaking = false;
  bool _loadFailed = false;
  bool _visible = true;

  late int _selectedFilter;

  int _currentIndex = 0;
  int _loadGeneration = 0;
  int _speechGeneration = 0;

  Timer? _reloadTimer;

  // ==========================================
  // LIFECYCLE
  // ==========================================

  @override
  void initState() {
    super.initState();

    _selectedFilter = widget.initialFilter.clamp(0, 2).toInt();

    WidgetsBinding.instance.addObserver(this);

    LearningStore.changes.addListener(
      _onLearningChanged,
    );

    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final visible = TickerMode.of(context);

    if (_visible != visible) {
      _visible = visible;

      if (!visible) {
        _stopSpeaking();
      } else {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            if (mounted && _visible && !_saving) {
              _reload();
            }
          },
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      if (!_saving) {
        _reload();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopSpeaking();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    LearningStore.changes.removeListener(
      _onLearningChanged,
    );

    _reloadTimer?.cancel();

    _loadGeneration++;
    _speechGeneration++;

    _flutterTts.stop();

    super.dispose();
  }

  // ==========================================
  // SINKRONISASI LEARNING STORE
  // ==========================================

  void _onLearningChanged() {
    if (!mounted || _saving) return;

    _reloadTimer?.cancel();

    _reloadTimer = Timer(
      const Duration(milliseconds: 120),
      () {
        if (mounted && !_saving) {
          _reload();
        }
      },
    );
  }

  // ==========================================
  // MEMUAT DATA PENGGUNA
  // ==========================================

  Future<bool> _reload({
    bool preserveCurrentWord = true,
  }) async {
    final generation = ++_loadGeneration;

    final previousWord = _currentWord;

    try {
      final snapshot = await LearningStore.load();

      if (!mounted || generation != _loadGeneration) {
        return false;
      }

      setState(() {
        _data = snapshot;
        _loading = false;
        _loadFailed = false;

        final words = _filteredWords;

        if (words.isEmpty) {
          _currentIndex = 0;
          _flipped = false;

          return;
        }

        if (preserveCurrentWord && previousWord != null) {
          final existingIndex = words.indexWhere(
            (word) => word.id == previousWord.id,
          );

          if (existingIndex >= 0) {
            _currentIndex = existingIndex;
          } else {
            _currentIndex = _currentIndex.clamp(0, words.length - 1).toInt();
          }
        } else {
          _currentIndex = _currentIndex.clamp(0, words.length - 1).toInt();
        }

        final current = _currentWord;

        if (current?.id != previousWord?.id ||
            current?.word != previousWord?.word ||
            current?.meaning != previousWord?.meaning) {
          _flipped = false;
        }
      });

      return true;
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return false;
      }

      setState(() {
        _loading = false;
        _loadFailed = true;
      });

      _showMessage(
        'Gagal memuat kosakata. Silakan coba lagi.',
      );

      return false;
    }
  }

  // ==========================================
  // RETRY LOAD
  // ==========================================

  Future<void> _retryLoad() async {
    if (_loading || _saving) return;

    setState(() {
      _loading = true;
      _loadFailed = false;
    });

    await _reload();
  }

  // ==========================================
  // SNACKBAR
  // ==========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  // ==========================================
  // TARGET HARIAN
  //
  // Pengguna cukup memilih satu kali.
  // ==========================================

  Future<void> _chooseGoal() async {
    if (_pickerOpen || _saving) return;

    setState(() {
      _pickerOpen = true;
    });

    try {
      final existing = await LearningStore.getDailyGoal();

      if (!mounted) return;

      if (existing != null) {
        await _reload();
        return;
      }

      await _stopSpeaking();

      if (!mounted) return;

      final selected = await showDailyGoalPicker(
        context,
      );

      if (!mounted || selected == null) return;

      await LearningStore.chooseGoalOnce(
        selected,
      );

      if (!mounted) return;

      await _reload();
    } catch (_) {
      _showMessage(
        'Gagal menyimpan target belajar.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickerOpen = false;
        });
      }
    }
  }

  // ==========================================
  // FILTER KOSAKATA
  // ==========================================

  List<StudyWord> get _filteredWords {
    final words = _data?.words ?? const <StudyWord>[];

    if (_selectedFilter == 1) {
      return words
          .where(
            (word) => word.level == WordLevel.review,
          )
          .toList();
    }

    if (_selectedFilter == 2) {
      return words
          .where(
            (word) => word.level == WordLevel.mastered,
          )
          .toList();
    }

    return words;
  }

  // ==========================================
  // KOSAKATA AKTIF
  // ==========================================

  StudyWord? get _currentWord {
    final words = _filteredWords;

    if (words.isEmpty) {
      return null;
    }

    final index = _currentIndex.clamp(0, words.length - 1).toInt();

    return words[index];
  }

  // ==========================================
  // GANTI FILTER
  // ==========================================

  void _changeFilter(int filter) {
    if (_saving || _loadFailed) return;

    if (filter == _selectedFilter) return;

    _stopSpeaking();

    setState(() {
      _selectedFilter = filter;
      _currentIndex = 0;
      _flipped = false;
    });
  }

  // ==========================================
  // KARTU SEBELUMNYA
  // ==========================================

  void _previousCard() {
    if (_saving || _loadFailed) return;

    final words = _filteredWords;

    if (words.length <= 1) return;

    _stopSpeaking();

    setState(() {
      _currentIndex = (_currentIndex - 1 + words.length) % words.length;

      _flipped = false;
    });
  }

  // ==========================================
  // KARTU BERIKUTNYA
  // ==========================================

  void _nextCard() {
    if (_saving || _loadFailed) return;

    final words = _filteredWords;

    if (words.length <= 1) return;

    _stopSpeaking();

    setState(() {
      _currentIndex = (_currentIndex + 1) % words.length;

      _flipped = false;
    });
  }

  // ==========================================
  // BALIK FLASHCARD
  // ==========================================

  void _flipCard() {
    if (_saving || _loadFailed || _currentWord == null) {
      return;
    }

    _stopSpeaking();

    setState(() {
      _flipped = !_flipped;
    });
  }

  // ==========================================
  // TEXT TO SPEECH
  // ==========================================

  Future<void> _stopSpeaking() async {
    _speechGeneration++;

    if (mounted && _speaking) {
      setState(() {
        _speaking = false;
      });
    }

    try {
      await _flutterTts.stop();
    } catch (_) {
      // Audio tidak mengganggu fungsi review.
    }
  }

  Future<void> _speakWord(StudyWord word) async {
    if (_saving || _loadFailed) return;

    if (_speaking) {
      await _stopSpeaking();
      return;
    }

    final text = _flipped ? word.meaning.trim() : word.word.trim();

    final language = _flipped ? 'id-ID' : 'en-US';

    if (text.isEmpty) return;

    final generation = ++_speechGeneration;

    setState(() {
      _speaking = true;
    });

    try {
      await _flutterTts.stop();

      final available = await _flutterTts.isLanguageAvailable(
        language,
      );

      if (!mounted || generation != _speechGeneration) {
        return;
      }

      if (available != true) {
        _showMessage(
          'Bahasa pelafalan belum tersedia '
          'di perangkat.',
        );

        return;
      }

      await _flutterTts.setLanguage(language);

      await _flutterTts.setSpeechRate(0.42);

      await _flutterTts.setPitch(1.0);

      await _flutterTts.setVolume(1.0);

      await _flutterTts.awaitSpeakCompletion(
        true,
      );

      if (!mounted || generation != _speechGeneration) {
        return;
      }

      await _flutterTts.speak(text);
    } catch (_) {
      if (mounted && generation == _speechGeneration) {
        _showMessage(
          'Pelafalan tidak dapat diputar.',
        );
      }
    } finally {
      if (mounted && generation == _speechGeneration) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  // ==========================================
  // SIMPAN HASIL REVIEW
  //
  // Lagi:
  // - Status review
  // - Ulangi kartu yang sama
  //
  // Sulit:
  // - Status review
  // - Lanjut kartu berikutnya
  //
  // Hafal:
  // - Status mastered
  // - Lanjut kartu berikutnya
  //
  // Progres harian dicatat LearningStore.
  // ==========================================

  Future<void> _reviewWord(
    WordLevel level, {
    bool repeatImmediately = false,
  }) async {
    final word = _currentWord;

    if (word == null ||
        _saving ||
        !_flipped ||
        _loadFailed ||
        _data?.dailyGoal == null) {
      return;
    }

    final previousWords = _filteredWords;

    final previousIndex = _currentIndex;

    String? nextWordId;

    if (previousWords.length > 1) {
      final nextIndex = (previousIndex + 1) % previousWords.length;

      nextWordId = previousWords[nextIndex].id;
    }

    setState(() {
      _saving = true;
    });

    _reloadTimer?.cancel();

    _loadGeneration++;

    try {
      await _stopSpeaking();

      await LearningStore.reviewWord(
        wordId: word.id,
        level: level,
      );

      if (!mounted) return;

      final refreshed = await _reload();

      if (!mounted || !refreshed) {
        return;
      }

      setState(() {
        final words = _filteredWords;

        if (words.isEmpty) {
          _currentIndex = 0;
          _flipped = false;

          return;
        }

        int nextIndex = -1;

        if (repeatImmediately) {
          nextIndex = words.indexWhere(
            (item) => item.id == word.id,
          );
        }

        if (nextIndex < 0 && nextWordId != null) {
          nextIndex = words.indexWhere(
            (item) => item.id == nextWordId,
          );
        }

        if (nextIndex < 0) {
          nextIndex = previousIndex.clamp(0, words.length - 1).toInt();
        }

        _currentIndex = nextIndex;
        _flipped = false;
      });
    } catch (_) {
      _showMessage(
        'Gagal menyimpan hasil belajar. '
        'Silakan coba lagi.',
      );

      if (mounted) {
        await _reload();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================
  // NAVIGASI KEMBALI
  // ==========================================

  Future<void> _goBack() async {
    if (_saving) return;

    await _stopSpeaking();

    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      openTab(context, 2);
    }
  }

  // ==========================================
  // BUKA LIBRARY
  // ==========================================

  Future<void> _openDictionary() async {
    if (_saving) return;

    await _stopSpeaking();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const S13Vocabulary(),
      ),
    );

    if (mounted) {
      await _reload();
    }
  }

  // ==========================================
  // HEADER
  // ==========================================

  Widget _buildHeader() {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 2,
          shadowColor: const Color(0x178D9AB7),
          child: InkWell(
            onTap: _saving ? null : _goBack,
            borderRadius: BorderRadius.circular(18),
            child: const SizedBox(
              width: 49,
              height: 49,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: ink,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kosakata Saya',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Flashcard dan review adaptif',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TARGET BELAJAR HARIAN
  // ==========================================

  Widget _buildDailyTarget() {
    final goal = _data?.dailyGoal;

    final today = _data?.learnedToday ?? 0;

    final progress = _data?.progress ?? 0.0;

    final completed = goal != null && today >= goal;

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Target hari ini',
                style: TextStyle(
                  color: muted,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              goal == null ? 'Belum dipilih' : '$today / $goal kata',
              style: TextStyle(
                color: completed ? green : ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: const Color(0xFFE2E7F3),
            valueColor: AlwaysStoppedAnimation<Color>(
              completed ? green : primary,
            ),
          ),
        ),
        if (goal == null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickerOpen ? null : _chooseGoal,
              icon: const Icon(
                Icons.flag_rounded,
              ),
              label: const Text(
                'Pilih target belajar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: primary,
              ),
            ),
          ),
        ],
        if (completed) ...[
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: green,
                size: 18,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Target belajar hari ini tercapai!',
                  style: TextStyle(
                    color: green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ==========================================
  // TOMBOL FILTER
  // ==========================================

  Widget _filterButton({
    required int index,
    required String label,
    required int count,
  }) {
    final active = _selectedFilter == index;

    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? primary : Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: _saving ? null : () => _changeFilter(index),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: active ? primary : border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : muted,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(
                            alpha: 0.20,
                          )
                        : const Color(0xFFF0F2FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: active ? Colors.white : muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final data = _data;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterButton(
            index: 0,
            label: 'Semua',
            count: data?.savedCount ?? 0,
          ),
          const SizedBox(width: 9),
          _filterButton(
            index: 1,
            label: 'Perlu Review',
            count: data?.reviewCount ?? 0,
          ),
          const SizedBox(width: 9),
          _filterButton(
            index: 2,
            label: 'Dikuasai',
            count: data?.masteredCount ?? 0,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  //
  // Membedakan:
  // - Belum ada kosakata
  // - Filter kosong
  // - Semua kata sudah dikuasai
  // ==========================================

  Widget _buildEmptyCard() {
    final completelyEmpty = _data?.words.isEmpty ?? true;

    String title;
    String description;
    IconData icon;

    String? actionLabel;
    IconData? actionIcon;
    VoidCallback? onAction;

    if (completelyEmpty) {
      title = 'Belum ada kosakata';

      description = 'Tambahkan kosakata yang ingin kamu '
          'pelajari untuk membuat flashcard '
          'pertamamu.';

      icon = Icons.style_outlined;

      actionLabel = 'Buka Library';

      actionIcon = Icons.menu_book_rounded;

      onAction = _openDictionary;
    } else if (_selectedFilter == 1) {
      title = 'Belum ada kata untuk direview';

      description = 'Kosakata yang perlu diulang akan '
          'muncul di sini. Kamu bisa mempelajari '
          'koleksi kata lainnya.';

      icon = Icons.refresh_rounded;

      actionLabel = 'Lihat semua kosakata';

      actionIcon = Icons.menu_book_rounded;

      onAction = () => _changeFilter(0);
    } else if (_selectedFilter == 2) {
      title = 'Belum ada kata yang dikuasai';

      description = 'Kata yang sudah kamu hafal akan '
          'muncul di sini setelah latihan.';

      icon = Icons.verified_outlined;

      actionLabel = 'Mulai belajar';

      actionIcon = Icons.play_arrow_rounded;

      onAction = () => _changeFilter(0);
    } else {
      title = 'Belum ada kosakata';

      description = 'Kosakata yang kamu simpan '
          'akan muncul di sini.';

      icon = Icons.style_outlined;

      actionLabel = 'Buka Library';

      actionIcon = Icons.menu_book_rounded;

      onAction = _openDictionary;
    }

    return _buildStateCard(
      title: title,
      description: description,
      icon: icon,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onAction: onAction,
    );
  }

  // ==========================================
  // TARGET BELUM DIPILIH
  //
  // Kosakata tersedia, tetapi pengguna
  // belum menentukan target harian.
  // ==========================================

  Widget _buildGoalRequiredCard() {
    return _buildStateCard(
      title: 'Tentukan target belajarmu',
      description: 'Kosakata sudah tersedia. Pilih target '
          'harian untuk memulai latihan '
          'dan mencatat progres belajarmu.',
      icon: Icons.flag_rounded,
      actionLabel: 'Pilih target belajar',
      actionIcon: Icons.arrow_forward_rounded,
      onAction: _pickerOpen ? null : _chooseGoal,
    );
  }

  // ==========================================
  // ERROR STATE
  // ==========================================

  Widget _buildErrorCard() {
    return _buildStateCard(
      title: 'Kosakata belum berhasil dimuat',
      description: 'Terjadi kendala saat membaca '
          'data belajar. Silakan coba kembali.',
      icon: Icons.sync_problem_rounded,
      actionLabel: 'Muat ulang',
      actionIcon: Icons.refresh_rounded,
      onAction: _retryLoad,
    );
  }

  // ==========================================
  // REUSABLE STATE CARD
  // ==========================================

  Widget _buildStateCard({
    required String title,
    required String description,
    required IconData icon,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 345,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 35,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF4F0FF),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8593C5).withValues(alpha: 0.12),
            blurRadius: 23,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: Color(0xFFE9E9FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 39,
              color: primary,
            ),
          ),
          const SizedBox(height: 23),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(
                actionIcon ?? Icons.arrow_forward_rounded,
                size: 20,
              ),
              label: Text(
                actionLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // STATUS FLASHCARD
  // ==========================================

  String _statusLabel(WordLevel level) {
    switch (level) {
      case WordLevel.newWord:
        return 'Kata baru';

      case WordLevel.review:
        return 'Perlu review';

      case WordLevel.mastered:
        return 'Dikuasai';
    }
  }

  Color _statusColor(WordLevel level) {
    switch (level) {
      case WordLevel.newWord:
        return primary;

      case WordLevel.review:
        return orange;

      case WordLevel.mastered:
        return green;
    }
  }

  // ==========================================
  // FLASHCARD COUNTER
  // ==========================================

  Widget _buildCardCounter() {
    final words = _filteredWords;

    if (words.isEmpty) {
      return const SizedBox.shrink();
    }

    final index = _currentIndex.clamp(0, words.length - 1).toInt();

    return Row(
      children: [
        const Text(
          'Flashcard',
          style: TextStyle(
            color: ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${index + 1} / ${words.length}',
            style: const TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SPEAKER BUTTON
  // ==========================================

  Widget _buildSpeakerButton(StudyWord word) {
    return IconButton.filledTonal(
      tooltip: _speaking ? 'Hentikan pelafalan' : 'Dengarkan pelafalan',
      onPressed: _saving ? null : () => _speakWord(word),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFE9EEFF),
        foregroundColor: primary,
      ),
      icon: Icon(
        _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
      ),
    );
  }

  // ==========================================
  // FLASHCARD
  //
  // Bagian depan:
  // - Kata bahasa Inggris
  // - Pelafalan jika tersedia
  // - Jenis kata jika tersedia
  //
  // Bagian belakang:
  // - Arti Bahasa Indonesia
  // - Kata bahasa Inggris
  // - Contoh kalimat jika tersedia
  //
  // Jawaban tidak diperlihatkan sebelum
  // pengguna membalik kartu.
  // ==========================================

  Widget _buildFlashcard(StudyWord word) {
    final status = word.level;

    final statusLabel = _statusLabel(status);

    final statusColor = _statusColor(status);

    final mainText = _flipped ? word.meaning : word.word;

    return Stack(
      children: [
        // ==================================
        // LAPISAN KARTU BELAKANG
        // ==================================

        Positioned(
          left: 16,
          right: 16,
          bottom: 4,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E5F7),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),

        Positioned(
          left: 8,
          right: 8,
          bottom: 14,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFEBEEFC),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),

        // ==================================
        // KARTU UTAMA
        // ==================================

        Padding(
          padding: const EdgeInsets.only(
            bottom: 25,
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              minHeight: 340,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF5F1FF),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8C98BD).withValues(alpha: 0.13),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(21),
              child: Column(
                children: [
                  // ==========================
                  // STATUS + AUDIO
                  // ==========================

                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: 0.13,
                            ),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildSpeakerButton(word),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ==========================
                  // LANGUAGE LABEL
                  // ==========================

                  Text(
                    _flipped ? 'BAHASA INDONESIA' : 'BAHASA INGGRIS',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ==========================
                  // KATA UTAMA
                  // ==========================

                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 240,
                    ),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (
                      child,
                      animation,
                    ) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.96,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      mainText,
                      key: ValueKey(
                        '${word.id}-$_flipped',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _flipped ? primary : ink,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        height: 1.2,
                      ),
                    ),
                  ),

                  // ==========================
                  // PRONUNCIATION
                  // HANYA DATA ASLI
                  // ==========================

                  if (!_flipped && word.pronunciation.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      word.pronunciation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 16,
                      ),
                    ),
                  ],

                  // ==========================
                  // WORD TYPE
                  // ==========================

                  if (word.wordType.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF0FA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        word.wordType,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ==========================
                  // BALIK KARTU
                  // ==========================

                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: border,
                          thickness: 1.5,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Balik kartu',
                        onPressed: _saving ? null : _flipCard,
                        icon: const Icon(
                          Icons.swap_horiz_rounded,
                          color: primary,
                          size: 28,
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: border,
                          thickness: 1.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ==========================
                  // JAWABAN
                  // ==========================

                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 220,
                    ),
                    child: _flipped
                        ? _buildRevealedAnswer(word)
                        : _buildHiddenAnswer(),
                  ),

                  // ==========================
                  // NAVIGASI FLASHCARD
                  // ==========================

                  if (_filteredWords.length > 1) ...[
                    const SizedBox(height: 20),
                    _buildCardNavigation(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // JAWABAN TERSEMBUNYI
  // ==========================================

  Widget _buildHiddenAnswer() {
    return Column(
      key: const ValueKey('hiddenAnswer'),
      children: [
        const Text(
          'Apa arti kata ini?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Coba ingat jawabannya terlebih dahulu.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _flipCard,
            icon: const Icon(
              Icons.visibility_outlined,
              size: 20,
            ),
            label: const Text(
              'Lihat jawaban',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // JAWABAN DITAMPILKAN
  // ==========================================

  Widget _buildRevealedAnswer(StudyWord word) {
    return Column(
      key: ValueKey(
        'revealedAnswer-${word.id}',
      ),
      children: [
        const Text(
          'BAHASA INGGRIS',
          style: TextStyle(
            color: muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          word.word,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        if (word.exampleEnglish.trim().isNotEmpty ||
            word.exampleIndonesia.trim().isNotEmpty) ...[
          const SizedBox(height: 23),
          _buildExampleCard(word),
        ],
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: _saving ? null : _flipCard,
          icon: const Icon(
            Icons.swap_horiz_rounded,
            size: 18,
          ),
          label: const Text(
            'Balik kembali',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: primary,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CONTOH KALIMAT
  //
  // Hanya tampil apabila tersedia
  // pada data StudyWord.
  // ==========================================

  Widget _buildExampleCard(StudyWord word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: primary,
                size: 20,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'CONTOH KALIMAT',
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (word.exampleEnglish.trim().isNotEmpty)
            Text(
              word.exampleEnglish,
              style: const TextStyle(
                color: ink,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          if (word.exampleIndonesia.trim().isNotEmpty) ...[
            if (word.exampleEnglish.trim().isNotEmpty)
              const SizedBox(height: 6),
            Text(
              word.exampleIndonesia,
              style: const TextStyle(
                color: muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // NAVIGASI KARTU
  // ==========================================

  Widget _buildCardNavigation() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _previousCard,
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 20,
            ),
            label: const Text(
              'Sebelumnya',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: const BorderSide(
                color: border,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : _nextCard,
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: const BorderSide(
                color: border,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Berikutnya',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TOMBOL REVIEW
  // ==========================================

  Widget _answerButton({
    required String title,
    required String subtitle,
    required Color fill,
    required Color textColor,
    required WordLevel result,
    bool repeatImmediately = false,
  }) {
    final enabled = !_saving && _flipped && !_loadFailed;

    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(23),
          child: InkWell(
            onTap: enabled
                ? () {
                    _reviewWord(
                      result,
                      repeatImmediately: repeatImmediately,
                    );
                  }
                : null,
            borderRadius: BorderRadius.circular(23),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 81,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 14,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: textColor.withValues(
                    alpha: 0.23,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REVIEW ACTIONS
  //
  // Tombol penilaian baru muncul
  // setelah jawaban diperlihatkan.
  // ==========================================

  Widget _buildReviewActions() {
    if (!_flipped) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              color: primary,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lihat jawaban terlebih dahulu '
                'untuk menilai penguasaan kata.',
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Text(
          'Seberapa kamu ingat kata ini?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 13),
        if (_saving)
          const SizedBox(
            height: 81,
            child: Center(
              child: CircularProgressIndicator(
                color: primary,
                strokeWidth: 2.5,
              ),
            ),
          )
        else
          Row(
            children: [
              _answerButton(
                title: 'Lagi',
                subtitle: 'Ulangi',
                fill: const Color(0xFFFFE8ED),
                textColor: red,
                result: WordLevel.review,
                repeatImmediately: true,
              ),
              const SizedBox(width: 10),
              _answerButton(
                title: 'Sulit',
                subtitle: 'Perlu review',
                fill: const Color(0xFFFFF0DA),
                textColor: const Color(0xFFD67A00),
                result: WordLevel.review,
              ),
              const SizedBox(width: 10),
              _answerButton(
                title: 'Hafal',
                subtitle: 'Dikuasai',
                fill: green,
                textColor: Colors.white,
                result: WordLevel.mastered,
              ),
            ],
          ),
      ],
    );
  }

  // ==========================================
  // NAVIGASI BAWAH CADANGAN
  //
  // Desain navigasi asli dipertahankan.
  // ==========================================

  Widget _buildBottomNavigation() {
    const icons = [
      Icons.translate_rounded,
      Icons.document_scanner_outlined,
      Icons.school_outlined,
      Icons.menu_book_outlined,
      Icons.settings_outlined,
    ];

    const labels = [
      'Translate',
      'Scan',
      'Learn',
      'Library',
      'Settings',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        8,
        9,
        8,
        8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: border,
          ),
        ),
      ),
      child: Row(
        children: List.generate(
          5,
          (index) {
            final active = index == 2;

            return Expanded(
              child: InkWell(
                onTap: _saving
                    ? null
                    : () async {
                        await _stopSpeaking();

                        if (!mounted) return;

                        openTab(
                          context,
                          index,
                        );
                      },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 51,
                      height: 35,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(
                                0xFFE9EEFF,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        icons[index],
                        color: active ? primary : muted,
                        size: 23,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[index],
                        style: TextStyle(
                          color: active ? primary : muted,
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // KONTEN HALAMAN
  // ==========================================

  Widget _buildContent() {
    final currentWord = _currentWord;

    final goal = _data?.dailyGoal;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        30,
      ),
      children: [
        // ==================================
        // HEADER
        // ==================================

        _buildHeader(),

        const SizedBox(height: 24),

        // ==================================
        // GAGAL MEMUAT DATA
        // ==================================

        if (_loadFailed || _data == null)
          _buildErrorCard()
        else ...[
          // ================================
          // TARGET HARIAN
          // ================================

          _buildDailyTarget(),

          const SizedBox(height: 23),

          // ================================
          // FILTER
          // ================================

          _buildFilters(),

          const SizedBox(height: 24),

          // ================================
          // KONDISI KOSONG
          // ================================

          if (currentWord == null)
            _buildEmptyCard()

          // ================================
          // TARGET BELUM DIPILIH
          // ================================

          else if (goal == null)
            _buildGoalRequiredCard()

          // ================================
          // FLASHCARD ASLI
          // ================================

          else ...[
            _buildCardCounter(),
            const SizedBox(height: 14),
            _buildFlashcard(currentWord),
            const SizedBox(height: 22),
            _buildReviewActions(),
          ],
        ],
      ],
    );
  }

  // ==========================================
  // HALAMAN UTAMA
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final embedded = MainTabShell.isEmbedded(context);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: primary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _buildContent(),
              ),

              // Jangan menampilkan
              // bottom navigation ganda.
              if (!embedded) _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }
}
