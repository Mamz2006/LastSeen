import 'package:flutter/material.dart';
import 'package:lastseen/widgets/app_widgets.dart';
import 'package:lastseen/widgets/bottom_nav.dart';
import '../nav.dart';

class S13Vocabulary extends StatefulWidget {
  const S13Vocabulary({super.key});

  @override
  State<S13Vocabulary> createState() => _S13VocabularyState();
}

class _S13VocabularyState extends State<S13Vocabulary> {
  int filterIndex = 0;
  int cardIndex = 0;
  bool showFront = true;

  final List<VocabCard> _vocab = [
    VocabCard('OPPORTUNITY', 'Peluang', 'An opportunity to learn.'),
    VocabCard('ACHIEVEMENT', 'Pencapaian', 'Great achievement today.'),
  ];

  @override
  Widget build(BuildContext context) {
    final card = _vocab[cardIndex];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const ScreenHeader(label: 'LASTSEEN   /   VOCABULARY'),
                  const SizedBox(height: 5),
                  const Text(
                    'Kosakata Saya',
                    style: TextStyle(
                      color: Color(0xFF202640),
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Flashcard dan review adaptif.',
                    style: TextStyle(color: Color(0xFF7B839B), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildFilterChip('Semua', 0)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFilterChip('Perlu Review', 1)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFilterChip('Dikuasai', 2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => showFront = !showFront),
                    child: Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1ECFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showFront ? card.english : card.indonesia,
                            style: const TextStyle(
                              color: Color(0xFF7E66D9),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            showFront
                                ? '${card.indonesia} • ${card.example}'
                                : card.example,
                            style: const TextStyle(
                              color: Color(0xFF202640),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNavButton(
                          '‹ Prev',
                          cardIndex > 0 ? () => setState(() => cardIndex--) : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildNavButton(
                          'Balik',
                          () => setState(() => showFront = !showFront),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildNavButton(
                          'Next ›',
                          cardIndex < _vocab.length - 1
                              ? () => setState(() => cardIndex++)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InfoCard(
                    title: card.english,
                    body: '${card.indonesia} • perlu review',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4365E8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Mulai Review',
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
            BottomNav(currentIndex: 3, onChanged: (i) => openTab(context, i)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final active = filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => filterIndex = index),
      child: Container(
        height: 37,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE9EEFF) : Colors.white,
          border: Border.all(
            color: active ? const Color(0xFF4365E8) : const Color(0xFFE6EAF3),
          ),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF4365E8) : const Color(0xFF7B839B),
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 37,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE6EAF3)),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? const Color(0xFFE6EAF3) : const Color(0xFF7B839B),
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class VocabCard {
  final String english;
  final String indonesia;
  final String example;
  VocabCard(this.english, this.indonesia, this.example);
}
