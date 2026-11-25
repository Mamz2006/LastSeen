import 'package:flutter/material.dart';

import '../nav.dart';
import 's09_quiz_setup.dart';
import 's13_vocabulary.dart';

// =============================================
// LASTSEEN - SMART LEARNING DASHBOARD
// REDESIGN + INITIAL PROGRESS 0
// =============================================

class S08LearnDashboard extends StatelessWidget {
  const S08LearnDashboard({super.key});

  // ===========================================
  // DATA AWAL PENGGUNA
  //
  // Semua statistik dimulai dari 0.
  // Angka ini masih data awal sementara.
  // Nantinya disambungkan ke data asli
  // dari Kamus, Phrasebook, dan Quiz.
  // ===========================================

  static const int dailyTarget = 20;
  static const int learnedToday = 0;
  static const int streakDays = 0;

  static const int savedWords = 0;
  static const int masteredWords = 0;
  static const int reviewWords = 0;

  // ===========================================
  // WARNA
  // ===========================================

  static const Color primary = Color(0xFF4664F2);
  static const Color purple = Color(0xFF704CF7);
  static const Color ink = Color(0xFF171C31);
  static const Color muted = Color(0xFF8791AC);
  static const Color background = Color(0xFFF5F7FD);
  static const Color border = Color(0xFFE3E8F5);

  static const Color orange = Color(0xFFEC8C00);
  static const Color green = Color(0xFF15A879);
  static const Color cyan = Color(0xFF12A4B7);

  // ===========================================
  // MENGHITUNG PROGRES HARIAN
  // ===========================================

  double get progress {
    if (dailyTarget <= 0) {
      return 0.0;
    }

    return (learnedToday / dailyTarget).clamp(0.0, 1.0).toDouble();
  }

  // ===========================================
  // NAVIGASI
  // ===========================================

  void _openVocabulary(BuildContext context) {
    pushScreen(
      context,
      const S13Vocabulary(),
    );
  }

  void _openQuiz(BuildContext context) {
    pushScreen(
      context,
      const S09QuizSetup(),
    );
  }

  // ===========================================
  // HEADER SMART LEARNING
  // ===========================================

  Widget _buildHeader() {
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

            // ============================
            // STREAK BERGAYA DUOLINGO
            // ============================

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
                    '$streakDays hari',
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
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ===========================================
  // CIRCULAR PROGRESS
  // ===========================================

  Widget _buildCircularProgress() {
    final percentage = (progress * 100).round();

    return SizedBox(
      width: 89,
      height: 89,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.23),
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
                  fontSize: 25,
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
  // KARTU TARGET HARI INI
  // ===========================================

  Widget _buildDailyTarget(BuildContext context) {
    final remaining = (dailyTarget - learnedToday).clamp(0, dailyTarget);

    String motivationText;

    if (learnedToday == 0) {
      motivationText = 'Mulai belajar untuk mencapai target harianmu!';
    } else if (remaining > 0) {
      motivationText = 'Tinggal $remaining kata lagi, kamu pasti bisa!';
    } else {
      motivationText = 'Hebat! Target hari ini tercapai!';
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4265F0),
            Color(0xFF5654F2),
            Color(0xFF7448F8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.23),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // DEKORASI LINGKARAN KANAN
          Positioned(
            right: -80,
            top: -105,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // DEKORASI LINGKARAN KIRI
          Positioned(
            left: -90,
            bottom: -140,
            child: Container(
              width: 235,
              height: 235,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.06,
                ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$learnedToday',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 51,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                    letterSpacing: -2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 6,
                                  ),
                                  child: Text(
                                    '/ $dailyTarget kosakata',
                                    style: const TextStyle(
                                      color: Color(0xFFDCE3FF),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            motivationText,
                            style: const TextStyle(
                              color: Color(0xFFE8ECFF),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildCircularProgress(),
                  ],
                ),

                const SizedBox(height: 23),

                // LANJUT BELAJAR
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    onTap: () => _openVocabulary(context),
                    borderRadius: BorderRadius.circular(30),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lanjut belajar',
                            style: TextStyle(
                              color: primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 18),
                          Icon(
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

  Widget _buildStatCard({
    required IconData icon,
    required int value,
    required String label,
    required Color accent,
    required Color iconBackground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 122,
          ),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8D9AB7).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
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
                '$value',
                style: const TextStyle(
                  color: ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
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
    );
  }

  // ===========================================
  // TIGA STATISTIK AWAL 0
  // ===========================================

  Widget _buildStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.bookmark_border_rounded,
            value: savedWords,
            label: 'Disimpan',
            accent: primary,
            iconBackground: const Color(0xFFE9EEFF),
            onTap: () => _openVocabulary(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline_rounded,
            value: masteredWords,
            label: 'Dikuasai',
            accent: green,
            iconBackground: const Color(0xFFDDF7EB),
            onTap: () => _showLearningProgress(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.refresh_rounded,
            value: reviewWords,
            label: 'Review',
            accent: orange,
            iconBackground: const Color(0xFFFFEFD7),
            onTap: () => _openVocabulary(context),
          ),
        ),
      ],
    );
  }

  // ===========================================
  // JUDUL REKOMENDASI
  // ===========================================

  Widget _buildRecommendationTitle() {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Rekomendasi adaptif',
            style: TextStyle(
              color: ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        Icon(
          Icons.auto_awesome_rounded,
          color: purple,
          size: 21,
        ),
      ],
    );
  }

  // ===========================================
  // KARTU REKOMENDASI
  // ===========================================

  Widget _buildRecommendationCard({
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
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8592B2).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // ICON REKOMENDASI
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

              // TEKS REKOMENDASI
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 5,
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
                              color: const Color(
                                0xFFFFEFD5,
                              ),
                              borderRadius: BorderRadius.circular(
                                20,
                              ),
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

              const SizedBox(width: 9),

              // PANAH
              Container(
                width: 35,
                height: 35,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F2FA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: muted,
                  size: 26,
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

  void _showLearningProgress(
    BuildContext context,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              23,
              14,
              23,
              28,
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
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Learning Progress',
                  style: TextStyle(
                    color: ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Ringkasan perkembangan belajar kosakatamu.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: purple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Target Hari Ini',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '$learnedToday / $dailyTarget',
                      style: const TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE9EDFA),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      primary,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                _buildProgressRow(
                  icon: Icons.bookmark_rounded,
                  label: 'Kosakata disimpan',
                  value: '$savedWords kata',
                  color: primary,
                ),
                const SizedBox(height: 15),
                _buildProgressRow(
                  icon: Icons.check_circle_rounded,
                  label: 'Kosakata dikuasai',
                  value: '$masteredWords kata',
                  color: green,
                ),
                const SizedBox(height: 15),
                _buildProgressRow(
                  icon: Icons.refresh_rounded,
                  label: 'Perlu review',
                  value: '$reviewWords kata',
                  color: orange,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openQuiz(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          17,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Lanjutkan Latihan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================
  // DETAIL STATISTIK
  // ===========================================

  Widget _buildProgressRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ===========================================
  // TOMBOL MULAI QUIZ
  // ===========================================

  Widget _buildStartQuizButton(
    BuildContext context,
  ) {
    return Container(
      height: 58,
      width: double.infinity,
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
            color: primary.withValues(
              alpha: 0.25,
            ),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () => _openQuiz(context),
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
                  size: 23,
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
  // BOTTOM NAVIGATION CADANGAN
  // ===========================================

  Widget _buildBottomNavigation(
    BuildContext context,
  ) {
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
        9,
        9,
        9,
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
        children: List.generate(5, (index) {
          final selected = index == 2;

          return Expanded(
            child: InkWell(
              onTap: () => openTab(context, index),
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 51,
                    height: 35,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(
                              0xFFE9EEFF,
                            )
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      icons[index],
                      color: selected
                          ? primary
                          : const Color(
                              0xFF9BA5BF,
                            ),
                      size: 23,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: selected ? primary : muted,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11,
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
  // HALAMAN UTAMA LEARN
  // ===========================================

  @override
  Widget build(BuildContext context) {
    final embedded = MainTabShell.isEmbedded(context);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  25,
                ),
                children: [
                  // HEADER
                  _buildHeader(),

                  const SizedBox(height: 22),

                  // TARGET HARIAN 0 / 20
                  _buildDailyTarget(context),

                  const SizedBox(height: 18),

                  // STATISTIK AWAL 0
                  _buildStats(context),

                  const SizedBox(height: 23),

                  // REKOMENDASI ADAPTIF
                  _buildRecommendationTitle(),

                  const SizedBox(height: 13),

                  // REVIEW KOSAKATA
                  _buildRecommendationCard(
                    icon: Icons.refresh_rounded,
                    title: 'Review $reviewWords kata',
                    subtitle: reviewWords == 0
                        ? 'Belum ada kosakata yang perlu diulang'
                        : 'Kosakata yang perlu diulang',
                    accent: orange,
                    iconBackground: const Color(0xFFFFEFD6),
                    priority: reviewWords > 0,
                    onTap: () => _openVocabulary(context),
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // QUIZ KAMUS / PHRASEBOOK
                  // ICON YANG DIPILIH
                  // =========================

                  _buildRecommendationCard(
                    icon: Icons.quiz_rounded,
                    title: 'Quiz dari Kamus/Phrasebook',
                    subtitle: 'Latihan kosakata dan frasa pilihanmu',
                    accent: purple,
                    iconBackground: const Color(0xFFF0E8FF),
                    onTap: () => _openQuiz(context),
                  ),

                  const SizedBox(height: 12),

                  // LEARNING PROGRESS
                  _buildRecommendationCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Learning Progress',
                    subtitle: 'Pantau statistik dan kelemahan',
                    accent: cyan,
                    iconBackground: const Color(0xFFDFF5F7),
                    onTap: () => _showLearningProgress(context),
                  ),

                  const SizedBox(height: 20),

                  // MULAI QUIZ
                  _buildStartQuizButton(context),
                ],
              ),
            ),

            // Hindari bottom nav ganda.
            if (!embedded) _buildBottomNavigation(context),
          ],
        ),
      ),
    );
  }
}
