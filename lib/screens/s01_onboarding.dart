import 'dart:async';

import 'package:flutter/material.dart';
import '../nav.dart';

// ==========================================
// SPLASH SCREEN LASTSEEN
// ==========================================

class S01Onboarding extends StatefulWidget {
  const S01Onboarding({super.key});

  @override
  State<S01Onboarding> createState() => _S01OnboardingState();
}

class _S01OnboardingState extends State<S01Onboarding>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  Timer? _navigationTimer;

  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);

  // ======================================
  // INISIALISASI SPLASH SCREEN
  // ======================================
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // Animasi muncul perlahan
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Animasi logo membesar secara halus
    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    // Animasi konten bergerak ke atas
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Jalankan animasi
    _controller.forward();

    // Setelah 1,8 detik masuk halaman utama
    _navigationTimer = Timer(
      const Duration(milliseconds: 1800),
      _openMainPage,
    );
  }

  // ======================================
  // MEMBUKA NAVIGASI UTAMA LASTSEEN
  // ======================================
  void _openMainPage() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => const MainTabShell(
          initialIndex: 0,
        ),
      ),
    );
  }

  // ======================================
  // TAMPILAN SPLASH SCREEN
  // ======================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF7F9FF),
                Color(0xFFEEF2FF),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // =========================
                // LOGO DAN NAMA APLIKASI
                // =========================
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // LOGO LASTSEEN
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(27),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    blurRadius: 35,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(27),
                                child: Image.asset(
                                  'assets/Logo/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // NAMA APLIKASI
                            const Text(
                              'LastSeen',
                              style: TextStyle(
                                color: navy,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
                              ),
                            ),

                            const SizedBox(height: 9),

                            // DESKRIPSI
                            const Text(
                              'Scan • Translate • Learn',
                              style: TextStyle(
                                color: Color(0xFF828CA6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // =========================
                // LOADING DI BAWAH
                // =========================
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 45,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primary,
                            ),
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Memuat...',
                          style: TextStyle(
                            color: Color(0xFF8C95AD),
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  // ======================================
  // MEMBERSIHKAN RESOURCE
  // ======================================
  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
