import 'package:flutter/material.dart';

import 'screens/s02_translate_home.dart';
import 'screens/s04_smart_scan.dart';
import 'screens/s08_learn_dashboard.dart';
import 'screens/s13_vocabulary.dart';
import 'widgets/bottom_nav.dart';

// ==========================================
// NAVIGASI KE HALAMAN DETAIL
// ==========================================
void pushScreen(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => screen,
    ),
  );
}

// ==========================================
// MENGGANTI HALAMAN
// ==========================================
void replaceScreen(BuildContext context, Widget screen) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => screen,
    ),
  );
}

// ==========================================
// NAVIGASI ANTAR TAB
// ==========================================
void openTab(BuildContext context, int index) {
  final shell = context.findAncestorStateOfType<MainTabShellState>();

  // JIKA SUDAH ADA DI HALAMAN UTAMA
  if (shell != null) {
    shell.goToTab(index);
    return;
  }

  // JIKA DIPANGGIL DARI HALAMAN LAIN
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => MainTabShell(
        initialIndex: index.clamp(0, 4).toInt(),
      ),
    ),
    (route) => false,
  );
}

// ==========================================
// MAIN TAB SHELL
// ==========================================
class MainTabShell extends StatefulWidget {
  const MainTabShell({
    super.key,
    this.initialIndex = 0,
  }) : assert(
          initialIndex >= 0 && initialIndex <= 4,
        );

  final int initialIndex;

  // MEMERIKSA APAKAH HALAMAN
  // BERADA DALAM MAIN TAB SHELL
  static bool isEmbedded(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TabShellScope>() != null;
  }

  @override
  State<MainTabShell> createState() => MainTabShellState();
}

// ==========================================
// STATE NAVIGASI UTAMA
// ==========================================
class MainTabShellState extends State<MainTabShell>
    with SingleTickerProviderStateMixin {
  // DURASI ANIMASI
  static const Duration transitionDuration = Duration(milliseconds: 260);

  late final AnimationController _controller;
  late final Animation<double> _animation;

  late final List<Widget> _pages;

  late int _selectedIndex;
  late int _previousIndex;

  int? _queuedIndex;

  // ======================================
  // INISIALISASI
  // ======================================
  @override
  void initState() {
    super.initState();

    _selectedIndex = widget.initialIndex;
    _previousIndex = _selectedIndex;

    // HALAMAN UTAMA
    _pages = const [
      S02TranslateHome(),
      S04SmartScan(),
      S08LearnDashboard(),
      S13Vocabulary(),
      _SettingsPlaceholder(),
    ];

    // ANIMATION CONTROLLER
    _controller = AnimationController(
      vsync: this,
      duration: transitionDuration,
    );

    // ANIMASI SMOOTH
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // MENDENGARKAN STATUS ANIMASI
    _controller.addStatusListener(
      _onAnimationStatus,
    );
  }

  // ======================================
  // PINDAH TAB
  // ======================================
  void goToTab(int index) {
    if (!mounted) return;

    if (index < 0 || index >= _pages.length) {
      return;
    }

    // JANGAN ANIMASIKAN TAB YANG SAMA
    if (index == _selectedIndex) {
      return;
    }

    // JIKA MASIH ANIMASI, SIMPAN
    // PILIHAN TAB TERAKHIR
    if (_controller.isAnimating) {
      _queuedIndex = index;
      return;
    }

    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });

    // MULAI TRANSISI DARI AWAL
    _controller.forward(from: 0);
  }

  // ======================================
  // SETELAH ANIMASI SELESAI
  // ======================================
  void _onAnimationStatus(
    AnimationStatus status,
  ) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }

    setState(() {
      _previousIndex = _selectedIndex;
    });

    final nextIndex = _queuedIndex;
    _queuedIndex = null;

    // JIKA PENGGUNA MENEKAN TAB
    // LAIN SAAT ANIMASI BERJALAN
    if (nextIndex != null && nextIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (mounted) {
            goToTab(nextIndex);
          }
        },
      );
    }
  }

  // ======================================
  // MENGHITUNG ARAH SLIDE
  // ======================================
  double _getPageOffset(
    int pageIndex,
    double progress,
    double width,
  ) {
    // TIDAK ADA PERPINDAHAN
    if (_previousIndex == _selectedIndex) {
      return 0;
    }

    // MENU KE KANAN:
    // KONTEN BERGESER KE KIRI
    //
    // MENU KE KIRI:
    // KONTEN BERGESER KE KANAN
    final direction = _selectedIndex > _previousIndex ? 1.0 : -1.0;

    // HALAMAN LAMA KELUAR
    if (pageIndex == _previousIndex) {
      return -direction * progress * width;
    }

    // HALAMAN BARU MASUK
    if (pageIndex == _selectedIndex) {
      return direction * (1 - progress) * width;
    }

    return 0;
  }

  // ======================================
  // MEMBANGUN ANIMASI HALAMAN
  // ======================================
  Widget _buildAnimatedContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Stack(
                fit: StackFit.expand,
                children: List.generate(
                  _pages.length,
                  (index) {
                    // HANYA HALAMAN AKTIF DAN
                    // HALAMAN LAMA YANG DITAMPILKAN
                    final visible =
                        index == _selectedIndex || index == _previousIndex;

                    final offset = _getPageOffset(
                      index,
                      _animation.value,
                      constraints.maxWidth,
                    );

                    return Offstage(
                      offstage: !visible,
                      child: TickerMode(
                        enabled: visible,
                        child: Transform.translate(
                          offset: Offset(offset, 0),
                          child: _pages[index],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ======================================
  // TAMPILAN UTAMA
  // ======================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),

      // HANYA KONTEN YANG BERGERAK
      body: _TabShellScope(
        child: _buildAnimatedContent(),
      ),

      // BOTTOM NAVIGATION TETAP DIAM
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNav(
          currentIndex: _selectedIndex,
          onChanged: goToTab,
        ),
      ),
    );
  }

  // ======================================
  // MEMBERSIHKAN CONTROLLER
  // ======================================
  @override
  void dispose() {
    _controller.removeStatusListener(
      _onAnimationStatus,
    );

    // PERBAIKAN:
    // _animation.dispose() DIHAPUS.
    // YANG DI-DISPOSE ADALAH CONTROLLER.
    _controller.dispose();

    super.dispose();
  }
}

// ==========================================
// PENANDA MAIN TAB SHELL
// ==========================================
class _TabShellScope extends InheritedWidget {
  const _TabShellScope({
    required super.child,
  });

  @override
  bool updateShouldNotify(
    covariant _TabShellScope oldWidget,
  ) {
    return false;
  }
}

// ==========================================
// HALAMAN SETTINGS SEMENTARA
// ==========================================
class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F9FD),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF4361EE),
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Color(0xFF15192D),
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Pengaturan LastSeen sedang disiapkan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8089A1),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
