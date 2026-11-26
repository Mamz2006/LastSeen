import 'package:flutter/material.dart';

import '../nav.dart';
import '../services/learning_store.dart';
import 's09_quiz_setup.dart';
import 's12_vocabulary_review.dart';

// ===============================================
// LASTSEEN - SMART LEARNING
// Target dipilih satu kali oleh pengguna.
// ===============================================

class S08LearnDashboard extends StatefulWidget {
  const S08LearnDashboard({super.key});

  @override
  State<S08LearnDashboard> createState() => _S08LearnDashboardState();
}

class _S08LearnDashboardState extends State<S08LearnDashboard>
    with WidgetsBindingObserver {
  static const Color primary = Color(0xFF4664F2);
  static const Color purple = Color(0xFF704CF7);
  static const Color ink = Color(0xFF171C31);
  static const Color muted = Color(0xFF8791AC);
  static const Color background = Color(0xFFF5F7FD);
  static const Color border = Color(0xFFE3E8F5);
  static const Color orange = Color(0xFFEC8C00);
  static const Color green = Color(0xFF15A879);
  static const Color cyan = Color(0xFF12A4B7);

  LearningSnapshot? _data;

  bool _loading = true;
  bool _loadingNow = false;
  bool _tabVisible = false;
  bool _goalPickerOpen = false;
  bool _firstPickerOffered = false;

  // ===========================================
  // LIFECYCLE
  // ===========================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final visible = TickerMode.of(context);

    if (visible != _tabVisible) {
      _tabVisible = visible;

      if (visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _reload();
          }
        });
      }
    }
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

  // ===========================================
  // MEMUAT DATA BELAJAR
  // ===========================================

  Future<void> _reload() async {
    if (_loadingNow) return;

    _loadingNow = true;

    try {
      final snapshot = await LearningStore.load();

      if (!mounted) return;

      setState(() {
        _data = snapshot;
        _loading = false;
      });

      _offerFirstGoalPicker();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Gagal memuat data belajar: $error');
    } finally {
      _loadingNow = false;
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

  // ===========================================
  // PILIH TARGET HANYA SATU KALI
  // ===========================================

  void _offerFirstGoalPicker() {
    if (!_tabVisible ||
        _data?.dailyGoal != null ||
        _firstPickerOffered ||
        _goalPickerOpen) {
      return;
    }

    _firstPickerOffered = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tabVisible) {
        _chooseGoal();
      }
    });
  }

  Future<void> _chooseGoal() async {
    if (_goalPickerOpen) return;

    // Jika target sudah tersimpan,
    // tidak tampilkan pilihan lagi.
    final existing = await LearningStore.getDailyGoal();

    if (!mounted) return;

    if (existing != null) {
      await _reload();
      return;
    }

    _goalPickerOpen = true;

    try {
      final selected = await showDailyGoalPicker(context);

      if (!mounted || selected == null) return;

      await LearningStore.chooseGoalOnce(selected);

      if (mounted) {
        await _reload();
      }
    } catch (error) {
      _showMessage('Gagal menyimpan target: $error');
    } finally {
      _goalPickerOpen = false;
    }
  }

  Future<bool> _ensureGoal() async {
    final existing = await LearningStore.getDailyGoal();

    if (existing != null) return true;
    if (!mounted) return false;

    await _chooseGoal();

    final selected = await LearningStore.getDailyGoal();

    return mounted && selected != null;
  }

  // ===========================================
  // NAVIGASI
  // ===========================================

  Future<void> _openFlashcards({
    int initialFilter = 0,
  }) async {
    if (!await _ensureGoal()) return;
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => S12VocabularyReview(
          initialFilter: initialFilter,
        ),
      ),
    );

    if (mounted) {
      await _reload();
    }
  }

  Future<void> _openQuiz() async {
    if (!await _ensureGoal()) return;
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const S09QuizSetup(),
      ),
    );

    if (mounted) {
      await _reload();
    }
  }

  // ===========================================
  // HEADER
  // ===========================================

  Widget _buildHeader() {
    final streak = _data?.streakDays ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Smart Learning',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1D6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFD43B),
                          Color(0xFFFF9600),
                          Color(0xFFFF7800),
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcIn,
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$streak hari',
                    style: const TextStyle(
                      color: Color(0xFFFF9600),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Latihan yang mengikuti progres belajarmu.',
          style: TextStyle(
            color: muted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ===========================================
  // CIRCULAR PROGRESS
  // ===========================================

  Widget _buildCircularProgress() {
    final progress = _data?.progress ?? 0.0;
    final percentage = (progress * 100).round();

    return SizedBox(
      width: 85,
      height: 85,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'selesai',
                style: TextStyle(
                  color: Color(0xFFE1E7FF),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================
  // KARTU TARGET HARIAN
  // ===========================================

  Widget _buildDailyTarget() {
    final goal = _data?.dailyGoal;
    final today = _data?.learnedToday ?? 0;

    String motivation;

    if (goal == null) {
      motivation = 'Pilih target belajar harianmu.';
    } else if (today == 0) {
      motivation = 'Mulai belajar untuk mencapai target harianmu!';
    } else if (today < goal) {
      motivation = 'Tinggal ${goal - today} kata lagi, kamu pasti bisa!';
    } else {
      motivation = 'Hebat! Target hari ini tercapai!';
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4265F0),
            Color(0xFF5654F2),
            Color(0xFF7448F8),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.22),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -105,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 9),
                    Text(
                      'TARGET HARI INI',
                      style: TextStyle(
                        color: Color(0xFFDCE4FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 19),
                Row(
                  children: [
                    Expanded(
                      child: goal == null
                          ? const Text(
                              'Belum ditentukan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$today',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 51,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 6,
                                    ),
                                    child: Text(
                                      '/ $goal kosakata',
                                      style: const TextStyle(
                                        color: Color(0xFFDCE3FF),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    _buildCircularProgress(),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  motivation,
                  style: const TextStyle(
                    color: Color(0xFFE8ECFF),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    onTap: goal == null ? _chooseGoal : () => _openFlashcards(),
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            goal == null
                                ? 'Pilih target belajar'
                                : 'Lanjut belajar',
                            style: const TextStyle(
                              color: primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: primary,
                            size: 21,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // KARTU STATISTIK
  // ===========================================

  Widget _statCard({
    required IconData icon,
    required int count,
    required String label,
    required Color accent,
    required Color iconBackground,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(23),
          child: Container(
            constraints: const BoxConstraints(minHeight: 122),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: border,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: accent,
                    size: 23,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildStats() {
    return Row(
      children: [
        _statCard(
          icon: Icons.bookmark_border_rounded,
          count: _data?.savedCount ?? 0,
          label: 'Disimpan',
          accent: primary,
          iconBackground: const Color(0xFFE9EEFF),
          onTap: () => _openFlashcards(),
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.check_circle_outline_rounded,
          count: _data?.masteredCount ?? 0,
          label: 'Dikuasai',
          accent: green,
          iconBackground: const Color(0xFFDDF7EB),
          onTap: () => _openFlashcards(initialFilter: 2),
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.refresh_rounded,
          count: _data?.reviewCount ?? 0,
          label: 'Review',
          accent: orange,
          iconBackground: const Color(0xFFFFEFD7),
          onTap: () => _openFlashcards(initialFilter: 1),
        ),
      ],
    );
  }

  // ===========================================
  // KARTU REKOMENDASI
  // ===========================================

  Widget _recommendation({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required Color iconBackground,
    required VoidCallback onTap,
    bool priority = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: border,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (priority)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEFD5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Prioritas',
                              style: TextStyle(
                                color: Color(0xFFC77900),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFF0F2FA),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================
  // LEARNING PROGRESS
  // ===========================================

  void _showLearningProgress() {
    final data = _data;

    if (data == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(24),
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
                const Text(
                  'Learning Progress',
                  style: TextStyle(
                    color: ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  data.dailyGoal == null
                      ? 'Target belum dipilih'
                      : 'Target: ${data.learnedToday}/${data.dailyGoal} kata',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: data.progress,
                    minHeight: 9,
                    backgroundColor: const Color(0xFFE2E7F3),
                    color: primary,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Disimpan: ${data.savedCount} kata',
                ),
                const SizedBox(height: 12),
                Text(
                  'Dikuasai: ${data.masteredCount} kata',
                ),
                const SizedBox(height: 12),
                Text(
                  'Perlu review: ${data.reviewCount} kata',
                ),
                const SizedBox(height: 12),
                Text(
                  'Streak: ${data.streakDays} hari',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================
  // TOMBOL MULAI QUIZ
  // ===========================================

  Widget _buildQuizButton() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4365F2),
            Color(0xFF7249F8),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: _openQuiz,
          borderRadius: BorderRadius.circular(30),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF8891FF),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Mulai Quiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================
  // NAVIGASI BAWAH CADANGAN
  // ===========================================

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
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
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

  // ===========================================
  // BUILD
  // ===========================================

  @override
  Widget build(BuildContext context) {
    final embedded = MainTabShell.isEmbedded(context);
    final reviewCount = _data?.reviewCount ?? 0;

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
                            18,
                            20,
                            25,
                          ),
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 22),
                            _buildDailyTarget(),
                            const SizedBox(height: 18),
                            _buildStats(),
                            const SizedBox(height: 23),
                            const Row(
                              children: [
                                Text(
                                  'Rekomendasi adaptif',
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: purple,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            _recommendation(
                              icon: Icons.refresh_rounded,
                              title: 'Review $reviewCount kata',
                              subtitle: reviewCount == 0
                                  ? 'Belum ada kata yang perlu diulang'
                                  : 'Kosakata yang perlu diulang',
                              accent: orange,
                              iconBackground: const Color(0xFFFFEFD6),
                              priority: reviewCount > 0,
                              onTap: () => _openFlashcards(
                                initialFilter: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _recommendation(
                              icon: Icons.quiz_rounded,
                              title: 'Quiz dari Kamus/Phrasebook',
                              subtitle: 'Latihan kosakata dan frasa pilihanmu',
                              accent: purple,
                              iconBackground: const Color(0xFFF0E8FF),
                              onTap: _openQuiz,
                            ),
                            const SizedBox(height: 12),
                            _recommendation(
                              icon: Icons.bar_chart_rounded,
                              title: 'Learning Progress',
                              subtitle: 'Pantau statistik dan kelemahan',
                              accent: cyan,
                              iconBackground: const Color(0xFFDFF5F7),
                              onTap: _showLearningProgress,
                            ),
                            const SizedBox(height: 20),
                            _buildQuizButton(),
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
