import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nav.dart';
import '../widgets/app_widgets.dart';
import 's06_import_document.dart';
import 's09_quiz_setup.dart';

class S02TranslateHome extends StatefulWidget {
  const S02TranslateHome({
    super.key,
    this.initialText,
  });

  final String? initialText;

  @override
  State<S02TranslateHome> createState() => _S02TranslateHomeState();
}

class _S02TranslateHomeState extends State<S02TranslateHome> {
  // WARNA APLIKASI
  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);
  static const Color muted = Color(0xFF8089A1);
  static const Color background = Color(0xFFF8F9FD);
  static const Color border = Color(0xFFDDE3F0);
  static const Color lightBlue = Color(0xFFE9EEFF);

  late final TextEditingController _textController;

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Indonesia';

  final List<String> _languages = [
    'English',
    'Indonesia',
  ];

  bool _translating = false;
  bool _translated = false;
  bool _audioLoading = false;
  bool _audioPlaying = false;
  bool _saved = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.initialText,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // PROSES TERJEMAHAN DEMO
  Future<void> _translate() async {
    if (_translating) return;

    if (_textController.text.trim().isEmpty) {
      setState(() {
        _error = 'Tulis atau tempel teks terlebih dahulu.';
      });
      return;
    }

    setState(() {
      _error = null;
      _translating = true;
      _translated = false;
    });

    await Future.delayed(
      const Duration(milliseconds: 900),
    );

    if (!mounted) return;

    setState(() {
      _translating = false;
      _translated = true;
    });
  }

  // SIMULASI AUDIO
  Future<void> _toggleAudio() async {
    if (_audioLoading) return;

    if (_audioPlaying) {
      setState(() {
        _audioPlaying = false;
      });
      return;
    }

    setState(() {
      _audioLoading = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    setState(() {
      _audioLoading = false;
      _audioPlaying = true;
    });
  }

  // TEMPEL TEKS
  Future<void> _pasteText() async {
    final data = await Clipboard.getData(
      Clipboard.kTextPlain,
    );

    if (!mounted) return;

    final pastedText = data?.text;

    if (pastedText == null || pastedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada teks di clipboard.'),
        ),
      );
      return;
    }

    setState(() {
      _textController.text = pastedText;
      _error = null;
      _translated = false;
    });
  }

  // ==========================================
  // HALAMAN UTAMA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 26),

                      _buildHeader(),

                      const SizedBox(height: 32),

                      const Text(
                        'Mau terjemahin apa hari ini?',
                        style: TextStyle(
                          color: navy,
                          fontSize: 32,
                          height: 1.16,
                          letterSpacing: -0.7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // PILIHAN BAHASA
                      _buildLanguageSelector(),

                      const SizedBox(height: 20),

                      // INPUT TERJEMAHAN
                      _buildTranslationInput(),

                      if (_translating) ...[
                        const SizedBox(height: 14),
                        const StateBanner(
                          kind: StateKind.loading,
                          text: 'Memproses terjemahan...',
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        StateBanner(
                          kind: StateKind.error,
                          text: _error!,
                          onAction: () {
                            setState(() {
                              _error = null;
                            });
                          },
                        ),
                      ],

                      if (_translated) ...[
                        const SizedBox(height: 16),
                        _buildTranslationResult(),
                      ],

                      const SizedBox(height: 20),

                      // KARTU SCAN DAN PDF
                      _buildQuickActions(),

                      const SizedBox(height: 25),

                      // RIWAYAT
                      _buildRecentSection(),

                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
            ),

            // ==================================
            // PERBAIKAN BOTTOM NAVIGATION GANDA
            // ==================================
            // Jika berada dalam MainTabShell,
            // halaman Translate tidak membuat
            // navigasi bawah tambahan.
            if (!MainTabShell.isEmbedded(context)) _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HEADER LASTSEEN
  // ==========================================
  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.asset(
            'assets/Logo/logo.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 13),
        const Text(
          'LastSeen',
          style: TextStyle(
            color: navy,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PILIHAN BAHASA TANPA IKON TUKAR
  // ==========================================
  Widget _buildLanguageSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _languageCard(
            label: 'Dari',
            language: _sourceLanguage,
            onSelected: (value) {
              setState(() {
                _sourceLanguage = value;

                if (_sourceLanguage == _targetLanguage) {
                  _targetLanguage =
                      value == 'English' ? 'Indonesia' : 'English';
                }
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _languageCard(
            label: 'Ke',
            language: _targetLanguage,
            onSelected: (value) {
              setState(() {
                _targetLanguage = value;

                if (_targetLanguage == _sourceLanguage) {
                  _sourceLanguage =
                      value == 'English' ? 'Indonesia' : 'English';
                }
              });
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // KARTU BAHASA RESPONSIF
  // ==========================================
  Widget _languageCard({
    required String label,
    required String language,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Pilih bahasa $label',
      initialValue: language,
      onSelected: onSelected,
      itemBuilder: (context) {
        return _languages.map((item) {
          return PopupMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList();
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 76,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFD9DEEB),
            width: 1.4,
          ),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: muted,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Text(
                    language,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // KOTAK INPUT TERJEMAHAN
  // ==========================================
  Widget _buildTranslationInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: border,
          width: 1.3,
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _textController,
            minLines: 3,
            maxLines: 4,
            style: const TextStyle(
              color: navy,
              fontSize: 16,
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Tulis atau tempel teks yang ingin diterjemahkan...',
              hintStyle: TextStyle(
                color: Color(0xFF99A2B8),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            onChanged: (_) {
              if (_error != null || _translated) {
                setState(() {
                  _error = null;
                  _translated = false;
                });
              }
            },
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _circleButton(
                icon: Icons.content_paste_rounded,
                tooltip: 'Tempel teks',
                onTap: _pasteText,
              ),
              const SizedBox(width: 9),
              _circleButton(
                icon: Icons.close_rounded,
                tooltip: 'Hapus teks',
                onTap: () {
                  setState(() {
                    _textController.clear();
                    _translated = false;
                    _error = null;
                  });
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _translating ? null : _translate,
                    icon: _translating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome_rounded,
                            size: 17,
                          ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _translating ? 'Memproses' : 'Terjemahkan',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF9DACF4),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOMBOL BULAT
  // ==========================================
  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF0F2FC),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 43,
            height: 43,
            child: Icon(
              icon,
              color: primary,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HASIL TERJEMAHAN DEMO
  // ==========================================
  Widget _buildTranslationResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contoh hasil terjemahan',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mempelajari bahasa baru membuka peluang baru.',
            style: TextStyle(
              color: primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _toggleAudio,
                icon: Icon(
                  _audioLoading
                      ? Icons.hourglass_empty
                      : _audioPlaying
                          ? Icons.pause_rounded
                          : Icons.volume_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    _saved = !_saved;
                  });
                },
                icon: Icon(
                  _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: primary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  pushScreen(
                    context,
                    const S09QuizSetup(),
                  );
                },
                icon: const Icon(
                  Icons.quiz_outlined,
                  size: 19,
                ),
                label: const Text('Coba Quiz'),
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // KARTU SCAN DAN PDF
  // ==========================================
  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _quickActionCard(
            title: 'Scan',
            subtitle: 'Arahkan kamera',
            icon: Icons.document_scanner_outlined,
            dark: true,
            onTap: () => openTab(context, 1),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _quickActionCard(
            title: 'PDF',
            subtitle: 'Pilih dokumen',
            icon: Icons.picture_as_pdf_outlined,
            dark: false,
            onTap: () {
              pushScreen(
                context,
                const S06ImportDocument(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool dark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: dark ? navy : lightBlue,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          height: 154,
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: dark ? primary : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: dark ? Colors.white : primary,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: dark ? Colors.white : navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      dark ? const Color(0xFFADB6CE) : const Color(0xFF66749B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RIWAYAT TERAKHIR
  // ==========================================
  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Terakhir',
              style: TextStyle(
                color: navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _showExampleHistory,
              child: const Text(
                'Lihat semua',
                style: TextStyle(
                  color: primary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: border,
              width: 1.3,
            ),
          ),
          child: Column(
            children: [
              _recentItem(
                'Where is the station?',
                'Di mana stasiunnya?',
              ),
              const Divider(
                color: border,
                height: 1,
              ),
              _recentItem(
                'Thank you very much',
                'Terima kasih banyak',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ITEM RIWAYAT
  // ==========================================
  Widget _recentItem(
    String original,
    String translation,
  ) {
    return InkWell(
      onTap: () {
        _textController.text = original;

        setState(() {
          _translated = false;
          _error = null;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 17,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                original,
                style: const TextStyle(
                  color: navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                translation,
                style: const TextStyle(
                  color: muted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RIWAYAT CONTOH
  // ==========================================
  void _showExampleHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contoh riwayat',
                  style: TextStyle(
                    color: navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _recentItem(
                  'Where is the station?',
                  'Di mana stasiunnya?',
                ),
                const Divider(),
                _recentItem(
                  'Thank you very much',
                  'Terima kasih banyak',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION CADANGAN
  // ==========================================
  // Ini hanya digunakan apabila halaman Translate
  // dibuka tanpa MainTabShell.
  Widget _buildBottomNavigation() {
    const icons = [
      Icons.translate_rounded,
      Icons.document_scanner_outlined,
      Icons.school_outlined,
      Icons.menu_book_outlined,
      Icons.settings_outlined,
    ];

    const labels = [
      'Translate',
      'Scan',
      'Learn',
      'Library',
      'Settings',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        9,
        12,
        8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(5, (index) {
          final selected = index == 0;

          return Expanded(
            child: InkWell(
              onTap: () => openTab(context, index),
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 35,
                    width: 51,
                    decoration: BoxDecoration(
                      color: selected ? lightBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      icons[index],
                      color: selected ? primary : const Color(0xFF9BA5BF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: selected ? primary : muted,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
