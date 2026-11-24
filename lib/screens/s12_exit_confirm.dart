import 'package:flutter/material.dart';
import 'package:lastseen/widgets/app_widgets.dart';
import 'package:lastseen/widgets/bottom_nav.dart';
import '../nav.dart';

class S12ExitConfirm extends StatelessWidget {
  const S12ExitConfirm({super.key, required this.onStay, required this.onExit});

  final VoidCallback onStay;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const ScreenHeader(label: 'LASTSEEN   /   INTERACTIVE STATE'),
                  const SizedBox(height: 5),
                  const Text(
                    'Keluar dari Quiz?',
                    style: TextStyle(
                      color: Color(0xFF202640),
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Progres latihan saat ini akan dihentikan.',
                    style: TextStyle(color: Color(0xFF7B839B), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1ECFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Konfirmasi keluar',
                          style: TextStyle(
                            color: Color(0xFF7E66D9),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Kamu masih memiliki pertanyaan yang belum selesai.',
                          style: TextStyle(color: Color(0xFF202640), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      onStay();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4365E8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Tetap lanjut Quiz',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      onExit();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4365E8),
                      side: const BorderSide(color: Color(0xFFE6EAF3)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Keluar ke Learn',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            BottomNav(currentIndex: 2, onChanged: (i) => openTab(context, i)),
          ],
        ),
      ),
    );
  }
}
