import 'package:flutter/material.dart';
import 'package:lastseen/widgets/app_widgets.dart';
import 'package:lastseen/widgets/bottom_nav.dart';
import '../nav.dart';
import 's11_quiz_result.dart';
import 's12_exit_confirm.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.answers,
    required this.correct,
  });

  final String prompt;
  final List<(String, String)> answers;
  final String correct;
}

class S10QuizPlayer extends StatefulWidget {
  const S10QuizPlayer({super.key});

  @override
  State<S10QuizPlayer> createState() => _S10QuizPlayerState();
}

class _S10QuizPlayerState extends State<S10QuizPlayer> {
  static const _questions = [
    QuizQuestion(
      prompt: 'Apa arti kata “opportunity”?',
      correct: 'A',
      answers: [
        ('A', 'Peluang'),
        ('B', 'Kesulitan'),
        ('C', 'Keberhasilan'),
        ('D', 'Perbedaan'),
      ],
    ),
    QuizQuestion(
      prompt: 'Apa arti kata “achievement”?',
      correct: 'B',
      answers: [
        ('A', 'Tantangan'),
        ('B', 'Pencapaian'),
        ('C', 'Kesempatan'),
        ('D', 'Kebiasaan'),
      ],
    ),
    QuizQuestion(
      prompt: 'Apa arti kata “improve”?',
      correct: 'A',
      answers: [
        ('A', 'Meningkatkan'),
        ('B', 'Menghindari'),
        ('C', 'Mengambil'),
        ('D', 'Mengurangi'),
      ],
    ),
    QuizQuestion(
      prompt: 'Apa arti kata "knowledge"?',
      correct: 'C',
      answers: [
        ('A', 'Keterampilan'),
        ('B', 'Perhatian'),
        ('C', 'Pengetahuan'),
        ('D', 'Kesempatan'),
      ],
    ),
    QuizQuestion(
      prompt: 'Apa arti kata "feedback"?',
      correct: 'B',
      answers: [
        ('A', 'Percakapan'),
        ('B', 'Umpan balik'),
        ('C', 'Pengumuman'),
        ('D', 'Penjelasan'),
      ],
    ),
  ];

  int index = 0;
  int score = 0;
  String? selected;

  QuizQuestion get question => _questions[index];
  bool get isLast => index == _questions.length - 1;

  void _select(String option) {
    if (selected != null) return;
    setState(() {
      selected = option;
      if (option == question.correct) score++;
    });
  }

  void _next() {
    if (isLast) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => S11QuizResult(
            score: score,
            total: _questions.length,
            wrongWords: _getWrongWords(),
          ),
        ),
      );
    } else {
      setState(() {
        selected = null;
        index++;
      });
    }
  }

  List<String> _getWrongWords() {
    final wrong = <String>[];
    // ponytail: manual tracking jika perlu history jawaban; sekarang hardcoded
    if (score < _questions.length) {
      wrong.add('Achievement = pencapaian');
    }
    return wrong;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: S12ExitConfirm(
              onStay: () {},
              onExit: () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FC),
        body: SafeArea(
          child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const ScreenHeader(label: 'LASTSEEN   /   QUIZ PLAYER'),
                  const SizedBox(height: 5),
                  Text(
                    'Pertanyaan ${index + 1} / ${_questions.length}',
                    style: const TextStyle(
                      color: Color(0xFF202640),
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.prompt,
                    style:
                        const TextStyle(color: Color(0xFF7B839B), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _buildStatsRow(),
                  const SizedBox(height: 12),
                  ...question.answers.map(_buildAnswerTile),
                  if (selected != null) ...[
                    const SizedBox(height: 4),
                    _buildFeedbackCard(),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4365E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isLast ? 'Selesai' : 'Lanjut  →',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
            BottomNav(currentIndex: 2, onChanged: (i) => openTab(context, i)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            '${index + 1} / ${_questions.length}',
            active: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildStatChip('Skor $score')),
      ],
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

  Widget _buildAnswerTile((String, String) answer) {
    final (letter, label) = answer;
    final reveal = selected != null;
    final isCorrect = letter == question.correct;
    final isSelected = selected == letter;

    final Color bg;
    final Color border;
    if (!reveal) {
      bg = Colors.white;
      border = const Color(0xFFE6EAF3);
    } else if (isCorrect) {
      bg = const Color(0xFFE5F8F3);
      border = const Color(0xFF18A891);
    } else if (isSelected) {
      bg = const Color(0xFFFFF0F2);
      border = const Color(0xFFE45E73);
    } else {
      bg = Colors.white;
      border = const Color(0xFFE6EAF3);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _select(letter),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '$letter    $label',
            style: const TextStyle(
              color: Color(0xFF202640),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final correct = selected == question.correct;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? '✓ Pilihan tepat' : '✗ Belum tepat',
            style: const TextStyle(
              color: Color(0xFF7E66D9),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pertanyaan ${index + 1} dari ${_questions.length}',
            style: const TextStyle(color: Color(0xFF202640), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
