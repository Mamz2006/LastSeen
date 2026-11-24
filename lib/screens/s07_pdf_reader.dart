import 'package:flutter/material.dart';
import '../nav.dart';
import '../widgets/app_widgets.dart';
import '../widgets/bottom_nav.dart';
import 's02_translate_home.dart';
import 's09_quiz_setup.dart';

class S07PdfReader extends StatefulWidget {
  const S07PdfReader({super.key});

  @override
  State<S07PdfReader> createState() => _S07PdfReaderState();
}

class _S07PdfReaderState extends State<S07PdfReader> {
  int _page = 1;
  bool _loadingPage = false;
  static const _totalPages = 5;

  Future<void> _goToPage(int page) async {
    if (_loadingPage || page < 1 || page > _totalPages || page == _page) return;
    setState(() => _loadingPage = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _loadingPage = false;
      _page = page;
    });
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
                        label: 'LASTSEEN   /   PDF READER',
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Pembaca PDF',
                        style: TextStyle(
                          color: Color(0xFF202640),
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pilih bagian teks yang ingin dipelajari.',
                        style: TextStyle(
                          color: Color(0xFF7B839B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const InfoCard(
                        title: 'Introduction_to_Languages.pdf',
                        body: 'PDF text • 5 halaman',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE6EAF3)),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Introduction',
                              style: TextStyle(
                                color: Color(0xFF202640),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 9),
                            Text(
                              'Language learning is a continuous process. '
                              'Students improve through practice and feedback.\n\n'
                              'Reading helps learners build new vocabulary.',
                              style: TextStyle(
                                color: Color(0xFF202640),
                                fontSize: 13,
                                height: 1.38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPagination(),
                      if (_loadingPage) ...[
                        const SizedBox(height: 12),
                        const StateBanner(
                          kind: StateKind.loading,
                          text: 'Memproses halaman PDF…',
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () =>
                              replaceScreen(context, const S02TranslateHome()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4365E8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Pilih Teks & Terjemahkan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () =>
                              pushScreen(context, const S09QuizSetup()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4365E8),
                            side: const BorderSide(color: Color(0xFFE6EAF3)),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Quiz dari Dokumen',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildPagination() {
    return Row(
      children: [
        Expanded(
          child: _pagePill(
            '‹',
            active: false,
            onTap: _page > 1 ? () => _goToPage(_page - 1) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _pagePill('$_page / $_totalPages', active: true),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _pagePill(
            '›',
            active: false,
            onTap: _page < _totalPages ? () => _goToPage(_page + 1) : null,
          ),
        ),
      ],
    );
  }

  Widget _pagePill(String label, {required bool active, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 37,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE9EEFF) : Colors.white,
          border: Border.all(
            color: active ? const Color(0xFF4365E8) : const Color(0xFFE6EAF3),
          ),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF4365E8) : const Color(0xFF7B839B),
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
