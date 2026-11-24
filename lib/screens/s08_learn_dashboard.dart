import 'package:flutter/material.dart';
import 'package:lastseen/widgets/app_widgets.dart';
import 'package:lastseen/widgets/bottom_nav.dart';
import '../nav.dart';
import 's09_quiz_setup.dart';
import 's13_vocabulary.dart';

class S08LearnDashboard extends StatelessWidget {
  const S08LearnDashboard({super.key});

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
                  const ScreenHeader(label: 'LASTSEEN   /   LEARN DASHBOARD', showBack: false),
                  const SizedBox(height: 5),
                  const Text(
                    'Smart Learning',
                    style: TextStyle(
                      color: Color(0xFF202640),
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Latihan yang mengikuti progres belajarmu.',
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
                          'Target Hari Ini ✦',
                          style: TextStyle(
                            color: Color(0xFF7E66D9),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '12 dari 20 kosakata telah dipelajari.',
                          style: TextStyle(color: Color(0xFF202640), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatTile('84', 'Disimpan')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatTile('32', 'Dikuasai')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatTile('12', 'Review')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Rekomendasi adaptif',
                    style: TextStyle(
                      color: Color(0xFF202640),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InfoCard(
                    title: '↺ Review 12 kata',
                    body: 'Kosakata yang perlu diulang',
                    onTap: () => pushScreen(context, const S13Vocabulary()),
                  ),
                  const SizedBox(height: 8),
                  InfoCard(
                    title: '◎ Quiz dari hasil scan',
                    body: 'Latihan berdasarkan materi terbaru',
                    onTap: () => pushScreen(context, const S09QuizSetup()),
                  ),
                  const SizedBox(height: 8),
                  const InfoCard(
                    title: '▤ Learning Progress',
                    body: 'Pantau statistik dan kelemahan',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => pushScreen(context, const S09QuizSetup()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4365E8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Mulai Quiz',
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

  Widget _buildStatTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF7E66D9),
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B839B),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}