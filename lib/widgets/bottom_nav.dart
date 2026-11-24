import 'package:flutter/material.dart';
import '../nav.dart';

// ==========================================
// BOTTOM NAVIGATION LASTSEEN
// ==========================================
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const Color primary = Color(0xFF4361EE);
  static const Color inactive = Color(0xFF9BA5BF);
  static const Color activeBackground = Color(0xFFE9EEFF);

  static const List<IconData> icons = [
    Icons.translate_rounded,
    Icons.document_scanner_outlined,
    Icons.school_outlined,
    Icons.menu_book_outlined,
    Icons.settings_outlined,
  ];

  static const List<String> labels = [
    'Translate',
    'Scan',
    'Learn',
    'Library',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    // ======================================
    // PERBAIKAN NAVIGASI GANDA
    // ======================================
    //
    // Jika BottomNav dipanggil dari halaman
    // Translate, Scan, Learn, dan lainnya
    // yang berada DI DALAM MainTabShell,
    // sembunyikan BottomNav halaman tersebut.
    //
    // MainTabShell akan menampilkan satu
    // BottomNav utama yang tetap diam.
    //
    if (MainTabShell.isEmbedded(context)) {
      return const SizedBox.shrink();
    }

    // ======================================
    // BOTTOM NAVIGATION UTAMA
    // ======================================
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE7EAF2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(
          labels.length,
          (index) {
            final bool isActive = currentIndex == index;

            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),

                // PINDAH HALAMAN
                onTap: () {
                  if (index != currentIndex) {
                    onChanged(index);
                  }
                },

                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 3,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ====================
                      // IKON + INDIKATOR
                      // ====================
                      AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 260,
                        ),
                        curve: Curves.easeInOutCubic,
                        width: isActive ? 56 : 48,
                        height: 35,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              isActive ? activeBackground : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            22,
                          ),
                        ),
                        child: AnimatedScale(
                          scale: isActive ? 1.08 : 1.0,
                          duration: const Duration(
                            milliseconds: 260,
                          ),
                          curve: Curves.easeInOutCubic,
                          child: Icon(
                            icons[index],
                            size: 23,
                            color: isActive ? primary : inactive,
                          ),
                        ),
                      ),

                      const SizedBox(height: 5),

                      // ====================
                      // LABEL MENU
                      // ====================
                      AnimatedDefaultTextStyle(
                        duration: const Duration(
                          milliseconds: 260,
                        ),
                        curve: Curves.easeInOutCubic,
                        style: TextStyle(
                          color: isActive ? primary : inactive,
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                        child: Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
