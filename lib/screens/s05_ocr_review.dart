import 'package:flutter/material.dart';
import '../nav.dart';
import '../widgets/app_widgets.dart';
import '../widgets/bottom_nav.dart';
import 's02_translate_home.dart';

class S05OcrReview extends StatefulWidget {
  const S05OcrReview({super.key, this.initialText});

  /// Teks asli dari OCR kamera / PDF. Kosong = contoh bawaan.
  final String? initialText;

  @override
  State<S05OcrReview> createState() => _S05OcrReviewState();
}

class _S05OcrReviewState extends State<S05OcrReview> {
  late final _textController = TextEditingController(
    text: widget.initialText ??
        'Learn Every Day\nI 1ove learning new languages.',
  );
  bool _corrected = false;
  bool _translating = false;

  bool get _hasSuggestion => _textController.text.contains('1');

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _applyCorrection() {
    _textController.text = _textController.text.replaceAll('1ove', 'love');
    setState(() => _corrected = true);
  }

  Future<void> _translate() async {
    if (_translating) return;
    setState(() => _translating = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _translating = false);
    replaceScreen(
      context,
      S02TranslateHome(initialText: _textController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ScreenHeader(
                        label: 'LASTSEEN   /   OCR REVIEW',
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Periksa Hasil Scan',
                        style: TextStyle(
                          color: Color(0xFF202640),
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Periksa teks sebelum diterjemahkan.',
                        style: TextStyle(
                          color: Color(0xFF7B839B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE6EAF3)),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Teks hasil scan',
                              style: TextStyle(
                                color: Color(0xFF202640),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _textController,
                              maxLines: null,
                              style: const TextStyle(
                                color: Color(0xFF7B839B),
                                fontSize: 12,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_corrected && _hasSuggestion) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E4),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠ Saran koreksi',
                                style: TextStyle(
                                  color: Color(0xFF202640),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                "Angka '1' kemungkinan huruf 'l'.\nKetuk untuk perbaiki otomatis.",
                                style: TextStyle(
                                  color: Color(0xFF202640),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _applyCorrection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE9EEFF),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '✓ Terapkan Koreksi',
                              style: TextStyle(
                                color: Color(0xFF4365E8),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _translating ? null : _translate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4365E8),
                            disabledBackgroundColor: const Color(0xFFB9C4E9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _translating
                                ? 'Menerjemahkan…'
                                : 'Lanjut Terjemahkan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (_translating) ...[
                        const SizedBox(height: 12),
                        const StateBanner(
                          kind: StateKind.loading,
                          text: 'Menerjemahkan teks…',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            BottomNav(
              currentIndex: 1,
              onChanged: (i) => openTab(context, i),
            ),
          ],
        ),
      ),
    );
  }
}
