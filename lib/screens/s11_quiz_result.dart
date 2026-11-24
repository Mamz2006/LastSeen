import 'package:flutter/material.dart';
import 'package:lastseen/widgets/app_widgets.dart';
import 'package:lastseen/widgets/bottom_nav.dart';
import '../nav.dart';
import 's13_vocabulary.dart';

class S11QuizResult extends StatelessWidget {
  const S11QuizResult({
    super.key,
    required this.score,
    required this.total,
    required this.wrongWords,
  });

  final int score;
  final int total;
  final List<String> wrongWords;

  @override
  Widget build(BuildContext context) {
    final percentage = ((score / total) * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const ScreenHeader(label: 'LASTSEEN   /   QUIZ RESULT'),
                  const SizedBox(height: 5),
                  const Text(
                    'Hasil Quiz',
                    style: TextStyle(
                      color: Color(0xFF202640),
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ringkasan latihan dan materi yang perlu ditinjau.',
                    style: TextStyle(color: Color(0xFF7B839B), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1ECFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latihan selesai! ✨',
                          style: TextStyle(
                            color: Color(0xFF7E66D9),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$score dari $total soal benar pada simulasi demo ini.',
                          style: const TextStyle(
                            color: Color(0xFF202640),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatChip('$percentage%', active: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatChip('$score Benar')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatChip('${total - score} Review'),
                      ),
                    ],
                  ),
                  if (wrongWords.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InfoCard(
                      title: 'Perlu ditinjau',
                      body: wrongWords.join('\n'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const InfoCard(
                    title: 'Rekomendasi',
                    body: 'Ulangi kata yang belum dikuasai.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        pushScreen(context, const S13Vocabulary()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4365E8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Review Kosakata',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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
                      'Kembali ke Learn',
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

  Widget _buildStatChip(String text, {bool active = false}) {
    return Container(
      height: 37,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE9EEFF) : Colors.white,
        border: Border.all(
          color: active ? const Color(0xFF4365E8) : const Color(0xFFE6EAF3),
        ),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? const Color(0xFF4365E8) : const Color(0xFF7B839B),
          fontSize: 10,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}
