import 'package:flutter/material.dart';
import '../nav.dart';
import '../widgets/app_widgets.dart';
import '../widgets/bottom_nav.dart';
import 's10_quiz_player.dart';

class S09QuizSetup extends StatefulWidget {
  const S09QuizSetup({super.key});

  @override
  State<S09QuizSetup> createState() => _S09QuizSetupState();
}

class _S09QuizSetupState extends State<S09QuizSetup> {
  static const _sourceCount = 12;
  String selectedQuizType = 'pilihan_ganda';
  int selectedQuestionCount = 5;
  bool _generating = false;
  String? _error;

  Future<void> _startQuiz() async {
    if (_generating) return;
    if (_sourceCount == 0) {
      setState(() => _error = 'Materi quiz kosong. Scan atau simpan kosakata dulu.');
      return;
    }
    setState(() {
      _error = null;
      _generating = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _generating = false);
    pushScreen(context, const S10QuizPlayer());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE6EAF3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chevron_left, color: Color(0xFF202640)),
          ),
        ),
        title: const Text(
          'LASTSEEN   /   QUIZ SETUP',
          style: TextStyle(
            color: Color(0xFF7B839B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Atur Quiz',
            style: TextStyle(
              color: Color(0xFF202640),
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Buat latihan dari kosakata dan hasil scan.',
            style: TextStyle(
              color: Color(0xFF7B839B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Quiz Personal',
            subtitle: 'Sistem memprioritaskan kosakata yang masih sulit.',
            bgColor: const Color(0xFFF1ECFF),
            titleColor: const Color(0xFF7E66D9),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Sumber soal',
            subtitle: '12 kosakata • Hasil scan terakhir',
            bgColor: Colors.white,
            titleColor: const Color(0xFF202640),
            border: true,
          ),
          const SizedBox(height: 12),
          const Text(
            'Jenis latihan',
            style: TextStyle(
              color: Color(0xFF202640),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildChipGroup(
            options: const ['Pilihan Ganda', 'Isi Kata', 'Matching'],
            values: const ['pilihan_ganda', 'isi_kata', 'matching'],
            selected: selectedQuizType,
            onChanged: (value) => setState(() => selectedQuizType = value),
          ),
          const SizedBox(height: 12),
          const Text(
            'Jumlah soal',
            style: TextStyle(
              color: Color(0xFF202640),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildChipGroup(
            options: const ['5 Soal', '10 Soal', '15 Soal'],
            values: const [5, 10, 15],
            selected: selectedQuestionCount,
            onChanged: (value) => setState(() => selectedQuestionCount = value),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Materi adaptif',
            subtitle: 'Kata yang sebelumnya salah akan mendapat prioritas.',
            bgColor: Colors.white,
            titleColor: const Color(0xFF202640),
            border: true,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _generating ? null : _startQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4365E8),
              disabledBackgroundColor: const Color(0xFFB9C4E9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _generating ? 'Menyusun pertanyaan…' : 'Mulai Quiz →',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          if (_generating) ...[
            const SizedBox(height: 12),
            const StateBanner(
              kind: StateKind.loading,
              text: 'Menyusun pertanyaan dari kosakata…',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            StateBanner(
              kind: StateKind.error,
              text: _error!,
              action: 'Tutup',
              onAction: () => setState(() => _error = null),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 2,
        onChanged: (i) => openTab(context, i),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color titleColor,
    bool border = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgColor,
        border: border ? Border.all(color: const Color(0xFFE6EAF3)) : null,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF7B839B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipGroup<T>({
    required List<String> options,
    required List<T> values,
    required T selected,
    required ValueChanged<T> onChanged,
  }) {
    return Row(
      children: List.generate(
        options.length,
        (i) => Expanded(
          child: GestureDetector(
            onTap: () => onChanged(values[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: values[i] == selected
                    ? const Color(0xFFE9EEFF)
                    : Colors.white,
                border: Border.all(
                  color: values[i] == selected
                      ? const Color(0xFF4365E8)
                      : const Color(0xFFE6EAF3),
                ),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Text(
                options[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: values[i] == selected
                      ? const Color(0xFF4365E8)
                      : const Color(0xFF7B839B),
                  fontSize: 12,
                  fontWeight: values[i] == selected
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
