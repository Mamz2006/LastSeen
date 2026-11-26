import 'package:flutter/material.dart';

import '../nav.dart';
import '../services/learning_store.dart';
import 's13_vocabulary.dart';

// ==============================================
// LASTSEEN - KOSAKATA SAYA
//
// - Target mengikuti pilihan pengguna
// - Semua statistik mulai dari 0
// - Flashcard memakai data asli
// - Review tersimpan melalui LearningStore
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
  static const Color primary = Color(0xFF4664F2);
  static const Color ink = Color(0xFF171C31);
  static const Color muted = Color(0xFF8791AC);
  static const Color background = Color(0xFFF6F7FD);
  static const Color border = Color(0xFFE2E7F5);

  LearningSnapshot? _data;

  bool _loading = true;
  bool _saving = false;
  bool _flipped = false;
  bool _pickerOpen = false;

  late int _selectedFilter;
  int _currentIndex = 0;

  // ==========================================
  // LIFECYCLE
  // ==========================================

  @override
  void initState() {
    super.initState();

    _selectedFilter = widget.initialFilter;

    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ==========================================
  // DATA PENGGUNA
  // ==========================================

  Future<void> _reload() async {
    try {
      final snapshot = await LearningStore.load();

      if (!mounted) return;

      setState(() {
        _data = snapshot;
        _loading = false;

        final total = _filteredWords.length;

        if (total == 0) {
          _currentIndex = 0;
        } else if (_currentIndex >= total) {
          _currentIndex = total - 1;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Gagal membaca kosakata: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // TARGET HARIAN
  // ==========================================

  Future<void> _chooseGoal() async {
    if (_pickerOpen) return;

    _pickerOpen = true;

    try {
      final existing = await LearningStore.getDailyGoal();

      if (!mounted) return;

      if (existing != null) {
        await _reload();
        return;
      }

      final selected = await showDailyGoalPicker(context);

      if (!mounted || selected == null) return;

      await LearningStore.chooseGoalOnce(selected);
      await _reload();
    } catch (error) {
      _showMessage('Gagal menyimpan target: $error');
    } finally {
      _pickerOpen = false;
    }
  }

  // ==========================================
  // FILTER KOSAKATA
  // ==========================================

  List<StudyWord> get _filteredWords {
    final words = _data?.words ?? const <StudyWord>[];

    if (_selectedFilter == 1) {
      return words.where((word) {
        return word.level == WordLevel.review;
      }).toList();
    }

    if (_selectedFilter == 2) {
      return words.where((word) {
        return word.level == WordLevel.mastered;
      }).toList();
    }

    return words;
  }

  StudyWord? get _currentWord {
    final words = _filteredWords;

    if (words.isEmpty) return null;

    final index = _currentIndex.clamp(
      0,
      words.length - 1,
    );

    return words[index];
  }

  void _changeFilter(int filter) {
    setState(() {
      _selectedFilter = filter;
      _currentIndex = 0;
      _flipped = false;
    });
  }

  void _nextCard() {
    final words = _filteredWords;

    if (words.length <= 1) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % words.length;
      _flipped = false;
    });
  }

  // ==========================================
  // SIMPAN HASIL REVIEW
  // ==========================================

  Future<void> _reviewWord(WordLevel level) async {
    final word = _currentWord;

    if (word == null || _saving) return;

    final previousIndex = _currentIndex;
    final previousCount = _filteredWords.length;

    setState(() {
      _saving = true;
    });

    try {
      await LearningStore.reviewWord(
        wordId: word.id,
        level: level,
      );

      if (!mounted) return;

      await _reload();

      if (!mounted) return;

      setState(() {
        final newCount = _filteredWords.length;

        if (newCount == 0) {
          _currentIndex = 0;
        } else if (newCount < previousCount) {
          // Jika kata keluar dari filter,
          // tampilkan kata berikutnya.
          _currentIndex = previousIndex.clamp(
            0,
            newCount - 1,
          );
        } else {
          _currentIndex = (previousIndex + 1) % newCount;
        }

        _flipped = false;
      });
    } catch (error) {
      _showMessage(
        'Gagal menyimpan hasil belajar: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================
  // NAVIGASI
  // ==========================================

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      openTab(context, 2);
    }
  }

  Future<void> _openDictionary() async {
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
            onTap: _goBack,
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
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Flashcard dan review adaptif',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TARGET SESUAI PILIHAN PENGGUNA
  // ==========================================

  Widget _buildDailyTarget() {
    final goal = _data?.dailyGoal;
    final today = _data?.learnedToday ?? 0;
    final progress = _data?.progress ?? 0.0;

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
              style: const TextStyle(
                color: ink,
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
            valueColor: const AlwaysStoppedAnimation<Color>(
              primary,
            ),
          ),
        ),
        if (goal == null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _chooseGoal,
              icon: const Icon(
                Icons.flag_rounded,
              ),
              label: const Text(
                'Pilih target belajar',
              ),
            ),
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

    return Material(
      color: active ? primary : Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: () => _changeFilter(index),
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
                  color: active ? Colors.white : const Color(0xFF616C8B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final data = _data;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
  // TAMPILAN KOSONG PENGGUNA BARU
  // ==========================================

  Widget _buildEmptyCard() {
    String title;
    String description;
    IconData icon;

    if (_selectedFilter == 1) {
      title = 'Belum ada kata untuk direview';
      description = 'Kosakata yang perlu diulang akan muncul di sini.';
      icon = Icons.refresh_rounded;
    } else if (_selectedFilter == 2) {
      title = 'Belum ada kata yang dikuasai';
      description = 'Kata yang sudah kamu hafal akan muncul di sini.';
      icon = Icons.verified_outlined;
    } else {
      title = 'Belum ada kosakata';
      description = 'Mulai simpan kata dari Kamus atau Phrasebook '
          'untuk membuat flashcard pertamamu.';
      icon = Icons.style_outlined;
    }

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
          if (_selectedFilter == 0) ...[
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: _openDictionary,
              icon: const Icon(
                Icons.menu_book_rounded,
                size: 20,
              ),
              label: const Text(
                'Buka Kamus',
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
  // FLASHCARD
  // HANYA MUNCUL JIKA ADA KOSAKATA
  // ==========================================

  Widget _buildFlashcard(StudyWord word) {
    final status = word.level;

    final statusLabel = status == WordLevel.mastered
        ? 'Dikuasai'
        : status == WordLevel.review
            ? 'Perlu review'
            : 'Kata baru';

    final statusColor = status == WordLevel.mastered
        ? const Color(0xFF11A772)
        : status == WordLevel.review
            ? const Color(0xFFE98600)
            : primary;

    final mainText = _flipped ? word.meaning : word.word;

    final translatedText = _flipped ? word.word : word.meaning;

    return Stack(
      children: [
        // LAPISAN KARTU BELAKANG
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

        // KARTU UTAMA
        Padding(
          padding: const EdgeInsets.only(bottom: 25),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(21),
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
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
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
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Dengarkan kata',
                      onPressed: () {
                        _showMessage(
                          'Audio pengucapan belum terhubung.',
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE9EEFF),
                        foregroundColor: primary,
                      ),
                      icon: const Icon(
                        Icons.volume_up_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Text(
                  mainText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!_flipped && word.pronunciation.isNotEmpty) ...[
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
                if (word.wordType.isNotEmpty) ...[
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
                      onPressed: () {
                        setState(() {
                          _flipped = !_flipped;
                        });
                      },
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
                const Text(
                  'ARTI',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  translatedText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (word.exampleEnglish.isNotEmpty ||
                    word.exampleIndonesia.isNotEmpty) ...[
                  const SizedBox(height: 23),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (word.exampleEnglish.isNotEmpty)
                          Text(
                            word.exampleEnglish,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 14,
                            ),
                          ),
                        if (word.exampleIndonesia.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            word.exampleIndonesia,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_filteredWords.length > 1) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _nextCard,
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Kata berikutnya',
                    ),
                  ),
                ],
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
  }) {
    return Expanded(
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: _saving ? null : () => _reviewWord(result),
          borderRadius: BorderRadius.circular(23),
          child: Container(
            height: 81,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewActions() {
    return Column(
      children: [
        const Text(
          'Seberapa kamu ingat kata ini?',
          style: TextStyle(
            color: muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            _answerButton(
              title: 'Lagi',
              subtitle: 'Ulangi',
              fill: const Color(0xFFFFE8ED),
              textColor: const Color(0xFFE73752),
              result: WordLevel.review,
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
              fill: const Color(0xFF14A779),
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
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: List.generate(5, (index) {
          final active = index == 2;

          return Expanded(
            child: InkWell(
              onTap: () => openTab(context, index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 51,
                    height: 35,
                    decoration: BoxDecoration(
                      color:
                          active ? const Color(0xFFE9EEFF) : Colors.transparent,
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
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // HALAMAN UTAMA
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final embedded = MainTabShell.isEmbedded(context);
    final currentWord = _currentWord;
    final goal = _data?.dailyGoal;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: primary,
                      ),
                    )
                  : _data == null
                      ? Center(
                          child: TextButton(
                            onPressed: _reload,
                            child: const Text(
                              'Coba muat ulang',
                            ),
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            30,
                          ),
                          children: [
                            // HEADER
                            _buildHeader(),

                            const SizedBox(height: 24),

                            // TARGET HARIAN
                            _buildDailyTarget(),

                            const SizedBox(height: 23),

                            // SEMUA / REVIEW / DIKUASAI
                            _buildFilters(),

                            const SizedBox(height: 24),

                            // KARTU KOSAKATA
                            if (currentWord == null || goal == null)
                              _buildEmptyCard()
                            else
                              _buildFlashcard(currentWord),

                            const SizedBox(height: 22),

                            // TOMBOL REVIEW
                            if (currentWord != null && goal != null)
                              _buildReviewActions(),
                          ],
                        ),
            ),
            if (!embedded) _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }
}
