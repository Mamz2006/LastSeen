import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lastseen/widgets/bottom_nav.dart';
import '../nav.dart';

// ==========================================
// LASTSEEN - VOCABULARY LIBRARY
// CONSISTENT SMART LEARNING DESIGN SYSTEM
// EMPTY STATE - NO DUMMY DATA
// ==========================================

class S13Vocabulary extends StatefulWidget {
  const S13Vocabulary({super.key});

  @override
  State<S13Vocabulary> createState() => _S13VocabularyState();
}

class _S13VocabularyState extends State<S13Vocabulary> {
  // ==========================================
  // DESIGN SYSTEM - SMART LEARNING
  // ==========================================

  static const Color primary = Color(0xFF4664F2);
  static const Color purple = Color(0xFF704CF7);
  static const Color ink = Color(0xFF171C31);
  static const Color muted = Color(0xFF8791AC);
  static const Color background = Color(0xFFF5F7FD);
  static const Color border = Color(0xFFE3E8F5);

  static const Color orange = Color(0xFFEC8C00);
  static const Color green = Color(0xFF15A879);

  static const Color masteredColor = green;
  static const Color learningColor = primary;
  static const Color reviewColor = orange;

  static const String _storageKey = 'lastseen_vocabulary_v1';

  // ==========================================
  // TYPOGRAPHY
  // MENGIKUTI SMART LEARNING
  // ==========================================

  static const TextStyle pageTitleStyle = TextStyle(
    color: ink,
    fontSize: 27,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.15,
  );

  static const TextStyle pageSubtitleStyle = TextStyle(
    color: muted,
    fontSize: 13,
    height: 1.4,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    color: ink,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle vocabularyTitleStyle = TextStyle(
    color: ink,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  static const TextStyle vocabularySubtitleStyle = TextStyle(
    color: muted,
    fontSize: 13,
    height: 1.4,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  // ==========================================
  // CONTROLLER
  // ==========================================

  final PageController _pageController = PageController(
    viewportFraction: 0.91,
  );

  final TextEditingController _searchController = TextEditingController();

  final FlutterTts _flutterTts = FlutterTts();

  // ==========================================
  // STATE
  // ==========================================

  int filterIndex = 0;
  int cardIndex = 0;

  bool showFront = true;

  bool _searchOpen = false;
  bool _loading = true;
  bool _speaking = false;
  bool _reviewing = false;

  String _searchQuery = '';

  Future<void> _saveQueue = Future<void>.value();

  // ==========================================
  // VOCABULARY DATA
  // ==========================================

  // Tidak menggunakan data dummy.
  //
  // Kondisi awal aplikasi benar-benar kosong.
  // Kosakata hanya muncul setelah pengguna
  // menambahkan data atau memuat data yang
  // sebelumnya telah disimpan.
  //
  // Tidak ada kata bawaan, terjemahan palsu,
  // maupun progres belajar fiktif.

  final List<VocabCard> _vocab = [];

  // ==========================================
  // STATISTIK KOSAKATA
  // ==========================================

  int get _totalWords => _vocab.length;

  int get _masteredWords => _vocab
      .where(
        (word) => word.status == VocabStatus.mastered,
      )
      .length;

  int get _learningWords => _vocab
      .where(
        (word) => word.status == VocabStatus.learning,
      )
      .length;

  int get _reviewWords => _vocab
      .where(
        (word) => word.status == VocabStatus.review,
      )
      .length;

  int get _masteredPercent {
    if (_totalWords == 0) return 0;

    return ((_masteredWords / _totalWords) * 100).round();
  }

  int get _estimatedReviewMinutes {
    return math.max(
      1,
      (_reviewWords * 15 / 60).ceil(),
    );
  }

  // ==========================================
  // FILTER + SEARCH
  // ==========================================

  List<VocabCard> get _filteredVocab {
    final query = _searchQuery.trim().toLowerCase();

    return _vocab.where((word) {
      bool matchesFilter = true;

      if (filterIndex == 1) {
        matchesFilter = word.status == VocabStatus.review;
      } else if (filterIndex == 2) {
        matchesFilter = word.status == VocabStatus.mastered;
      }

      final matchesSearch = query.isEmpty ||
          word.english.toLowerCase().contains(query) ||
          word.indonesia.toLowerCase().contains(query) ||
          word.example.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  // ==========================================
  // LIFECYCLE
  // ==========================================

  @override
  void initState() {
    super.initState();

    _loadVocabulary();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();

    _flutterTts.stop();

    super.dispose();
  }

  // ==========================================
  // LOAD VOCABULARY
  // ==========================================

  Future<void> _loadVocabulary() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      final saved = preferences.getString(
        _storageKey,
      );

      // Jika belum ada data yang tersimpan,
      // daftar kosakata tetap kosong.
      if (saved == null || saved.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(saved);

      if (decoded is! List) {
        throw const FormatException(
          'Format kosakata tidak valid.',
        );
      }

      final restored = decoded.map((item) {
        return VocabCard.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _vocab
          ..clear()
          ..addAll(restored);

        cardIndex = 0;
        showFront = true;
      });
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Data kosakata belum berhasil dimuat.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================
  // SAVE VOCABULARY
  // ==========================================

  Future<bool> _saveVocabulary() {
    final snapshot = jsonEncode(
      _vocab.map((word) => word.toJson()).toList(),
    );

    final operation = _saveQueue.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();

        final saved = await preferences.setString(
          _storageKey,
          snapshot,
        );

        if (!saved) {
          throw StateError(
            'Kosakata gagal disimpan.',
          );
        }

        return true;
      } catch (_) {
        if (mounted) {
          _showMessage(
            'Perubahan kosakata belum berhasil disimpan.',
          );
        }

        return false;
      }
    });

    _saveQueue = operation.then<void>((_) {});

    return operation;
  }

  // ==========================================
  // SNACKBAR
  // ==========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ==========================================
  // FORMAT DISPLAY WORD
  // ==========================================

  String _displayWord(String value) {
    final text = value.trim();

    if (text.isEmpty) return '';

    if (text == text.toUpperCase()) {
      final lower = text.toLowerCase();

      return lower[0].toUpperCase() + lower.substring(1);
    }

    return text;
  }

  // ==========================================
  // TEXT TO SPEECH
  // ==========================================

  Future<void> _speak(
    String text, {
    String language = 'en-US',
  }) async {
    if (_speaking || text.trim().isEmpty) {
      return;
    }

    setState(() {
      _speaking = true;
    });

    try {
      await _flutterTts.stop();

      final available = await _flutterTts.isLanguageAvailable(
        language,
      );

      if (!mounted) return;

      if (available != true) {
        _showMessage(
          'Bahasa pelafalan belum tersedia di perangkat.',
        );

        return;
      }

      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(0.42);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.awaitSpeakCompletion(true);

      if (!mounted) return;

      await _flutterTts.speak(text);
    } catch (_) {
      _showMessage(
        'Pelafalan tidak dapat diputar.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  // ==========================================
  // SEARCH CONTROL
  // ==========================================

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;

      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });

    if (!_searchOpen) {
      FocusScope.of(context).unfocus();
    }
  }

  // ==========================================
  // STATUS DESIGN
  // ==========================================

  Color _statusColor(VocabStatus status) {
    switch (status) {
      case VocabStatus.mastered:
        return const Color(0xFF07875B);

      case VocabStatus.learning:
        return primary;

      case VocabStatus.review:
        return const Color(0xFFC77900);
    }
  }

  Color _statusBackground(VocabStatus status) {
    switch (status) {
      case VocabStatus.mastered:
        return const Color(0xFFDDF7EB);

      case VocabStatus.learning:
        return const Color(0xFFE9EEFF);

      case VocabStatus.review:
        return const Color(0xFFFFEFD7);
    }
  }

  Color _avatarBackground(VocabStatus status) {
    switch (status) {
      case VocabStatus.mastered:
        return const Color(0xFFDDF7EB);

      case VocabStatus.learning:
        return const Color(0xFFE9EEFF);

      case VocabStatus.review:
        return const Color(0xFFFFEFD7);
    }
  }

  String _statusLabel(VocabStatus status) {
    switch (status) {
      case VocabStatus.mastered:
        return 'Hafal';

      case VocabStatus.learning:
        return 'Belajar';

      case VocabStatus.review:
        return 'Review';
    }
  }

  // ==========================================
  // HEADER ACTION BUTTON
  // ==========================================

  Widget _buildHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: filled ? primary : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: filled
              ? null
              : Border.all(
                  color: border,
                  width: 1.2,
                ),
          boxShadow: [
            BoxShadow(
              color: filled
                  ? primary.withValues(alpha: 0.20)
                  : ink.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Icon(
              icon,
              color: filled ? Colors.white : ink,
              size: filled ? 28 : 23,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HEADER - SAME AS SMART LEARNING
  // ==========================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kosakata Saya',
                maxLines: 2,
                style: pageTitleStyle,
              ),
              const SizedBox(height: 4),
              Text(
                '$_totalWords kata tersimpan',
                style: pageSubtitleStyle,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildHeaderButton(
          icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
          tooltip: _searchOpen ? 'Tutup pencarian' : 'Cari kosakata',
          onTap: _loading ? null : _toggleSearch,
        ),
        const SizedBox(width: 10),
        _buildHeaderButton(
          icon: Icons.add_rounded,
          tooltip: 'Tambah kosakata',
          filled: true,
          onTap: _loading ? null : () => _openWordEditor(),
        ),
      ],
    );
  }

  // ==========================================
  // SEARCH FIELD
  // ==========================================

  Widget _buildSearchField() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !_searchOpen
          ? const SizedBox.shrink(
              key: ValueKey('searchClosed'),
            )
          : Padding(
              key: const ValueKey('searchOpen'),
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(
                  color: ink,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari kata atau terjemahan...',
                  hintStyle: const TextStyle(
                    color: muted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: muted,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: muted,
                            size: 19,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: border,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ==========================================
  // FLASHCARD CAROUSEL
  // ==========================================

  Widget _buildFlashcardCarousel() {
    // Jangan menampilkan flashcard apabila
    // pengguna belum memiliki kosakata.

    if (_vocab.isEmpty) {
      return _buildEmptyFlashcard();
    }

    return Column(
      children: [
        SizedBox(
          height: 224,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _vocab.length,
            padEnds: false,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                cardIndex = index;
                showFront = true;
              });
            },
            itemBuilder: (context, index) {
              final word = _vocab[index];
              final active = cardIndex == index;

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  3,
                  4,
                  11,
                  14,
                ),
                child: AnimatedScale(
                  scale: active ? 1.0 : 0.95,
                  duration: const Duration(
                    milliseconds: 260,
                  ),
                  curve: Curves.easeOutCubic,
                  child: _buildFlashcard(
                    word,
                    index,
                  ),
                ),
              );
            },
          ),
        ),
        _buildCarouselIndicator(),
      ],
    );
  }

  // ==========================================
  // FLASHCARD
  // SAME GRADIENT AS SMART LEARNING
  // ==========================================

  Widget _buildFlashcard(
    VocabCard word,
    int index,
  ) {
    final front = cardIndex == index ? showFront : true;

    final gradientColors = index.isEven
        ? const [
            Color(0xFF4265F0),
            Color(0xFF5654F2),
            Color(0xFF7448F8),
          ]
        : const [
            Color(0xFF5654F2),
            Color(0xFF704CF7),
            Color(0xFF8958F6),
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.22),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              if (cardIndex != index) {
                if (_pageController.hasClients) {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(
                      milliseconds: 280,
                    ),
                    curve: Curves.easeOutCubic,
                  );
                }

                return;
              }

              setState(() {
                showFront = !showFront;
              });
            },
            child: Stack(
              children: [
                // Dekorasi kanan atas.
                Positioned(
                  top: -105,
                  right: -80,
                  child: IgnorePointer(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.10,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                // Dekorasi kiri bawah.
                Positioned(
                  bottom: -130,
                  left: -90,
                  child: IgnorePointer(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.06,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    21,
                    15,
                    17,
                    17,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      index == 0 ? 'Kata pilihan' : 'Flashcard',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFDCE4FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          _buildSpeakButton(
                            text: front ? word.english : word.indonesia,
                            language: front ? 'en-US' : 'id-ID',
                          ),
                        ],
                      ),
                      const Spacer(),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(
                          '${word.english}-$front',
                        ),
                        tween: Tween<double>(
                          begin: 0,
                          end: 1,
                        ),
                        duration: const Duration(
                          milliseconds: 260,
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (
                          context,
                          value,
                          child,
                        ) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                8 * (1 - value),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kata utama.
                            // Mengikuti font tema LastSeen.

                            Text(
                              _displayWord(
                                front ? word.english : word.indonesia,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 29,
                                height: 1.12,
                                letterSpacing: -0.7,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 7),

                            Text(
                              front
                                  ? word.example.isNotEmpty
                                      ? word.example
                                      : 'English vocabulary'
                                  : _displayWord(
                                      word.english,
                                    ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE8ECFF),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              front ? word.indonesia : 'Bahasa Indonesia',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Ketuk untuk balik',
                            style: TextStyle(
                              color: Color(0xFFDCE4FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SPEAK BUTTON
  // ==========================================

  Widget _buildSpeakButton({
    required String text,
    required String language,
  }) {
    return Tooltip(
      message: 'Dengarkan pelafalan',
      child: Material(
        color: Colors.white.withValues(
          alpha: 0.13,
        ),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _speaking
              ? null
              : () {
                  _speak(
                    text,
                    language: language,
                  );
                },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: _speaking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 1.8,
                      ),
                    )
                  : const Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CAROUSEL INDICATOR
  // ==========================================

  Widget _buildCarouselIndicator() {
    const maxIndicators = 7;

    final total = _vocab.length;

    final visibleCount = math.min(
      total,
      maxIndicators,
    );

    final start = math.max(
      0,
      math.min(
        cardIndex - 3,
        total - visibleCount,
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Kartu sebelumnya',
          visualDensity: VisualDensity.compact,
          onPressed: cardIndex > 0
              ? () {
                  if (!_pageController.hasClients) {
                    return;
                  }

                  _pageController.previousPage(
                    duration: const Duration(
                      milliseconds: 280,
                    ),
                    curve: Curves.easeOutCubic,
                  );
                }
              : null,
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 20,
          ),
        ),
        ...List.generate(
          visibleCount,
          (position) {
            final index = start + position;
            final active = cardIndex == index;

            return AnimatedContainer(
              duration: const Duration(
                milliseconds: 220,
              ),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(
                horizontal: 3,
              ),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? purple : const Color(0xFFDAD1FA),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Kartu berikutnya',
          visualDensity: VisualDensity.compact,
          onPressed: cardIndex < total - 1
              ? () {
                  if (!_pageController.hasClients) {
                    return;
                  }

                  _pageController.nextPage(
                    duration: const Duration(
                      milliseconds: 280,
                    ),
                    curve: Curves.easeOutCubic,
                  );
                }
              : null,
          icon: const Icon(
            Icons.chevron_right_rounded,
            size: 20,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // EMPTY FLASHCARD
  // ==========================================

  Widget _buildEmptyFlashcard() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4265F0),
            Color(0xFF5654F2),
            Color(0xFF7448F8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.22),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dekorasi konsisten dengan Smart Learning.
          Positioned(
            top: -105,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -130,
            left: -90,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.06,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              23,
              22,
              23,
            ),
            child: Column(
              children: [
                Container(
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.17,
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.style_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Mulai koleksi kosakatamu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tambahkan kosakata yang ingin '
                  'kamu pelajari.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE8ECFF),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    onTap: () => _openWordEditor(),
                    borderRadius: BorderRadius.circular(30),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 19,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: primary,
                            size: 21,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Tambah kosakata',
                            style: TextStyle(
                              color: primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VOCABULARY PROGRESS
  // ==========================================

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progres kosakata',
                  style: sectionTitleStyle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_masteredPercent% dikuasai',
                style: TextStyle(
                  color: _totalWords == 0 ? muted : const Color(0xFF07875B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildProgressBar(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 15,
            runSpacing: 8,
            children: [
              _buildProgressLegend(
                color: masteredColor,
                label: 'Dikuasai',
                count: _masteredWords,
              ),
              _buildProgressLegend(
                color: learningColor,
                label: 'Belajar',
                count: _learningWords,
              ),
              _buildProgressLegend(
                color: reviewColor,
                label: 'Review',
                count: _reviewWords,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SEGMENTED PROGRESS BAR
  // ==========================================

  Widget _buildProgressBar() {
    // Jika belum ada data, progress bar
    // tidak menampilkan warna penguasaan.

    if (_totalWords == 0) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E7F3),
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    return Row(
      children: [
        if (_masteredWords > 0)
          Expanded(
            flex: _masteredWords,
            child: _progressSegment(
              masteredColor,
            ),
          ),
        if (_masteredWords > 0 && (_learningWords > 0 || _reviewWords > 0))
          const SizedBox(width: 4),
        if (_learningWords > 0)
          Expanded(
            flex: _learningWords,
            child: _progressSegment(
              learningColor,
            ),
          ),
        if (_learningWords > 0 && _reviewWords > 0) const SizedBox(width: 4),
        if (_reviewWords > 0)
          Expanded(
            flex: _reviewWords,
            child: _progressSegment(
              reviewColor,
            ),
          ),
      ],
    );
  }

  Widget _progressSegment(Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  // ==========================================
  // PROGRESS LEGEND
  // ==========================================

  Widget _buildProgressLegend({
    required Color color,
    required String label,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $count',
          style: const TextStyle(
            color: muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // FILTER CHIPS
  // ==========================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(
            'Semua',
            0,
            _totalWords,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Perlu Review',
            1,
            _reviewWords,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Dikuasai',
            2,
            _masteredWords,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    int index,
    int count,
  ) {
    final active = filterIndex == index;

    return Semantics(
      button: true,
      selected: active,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: active ? primary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: active ? primary : border,
            width: 1.2,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: primary.withValues(
                      alpha: 0.18,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: () {
              setState(() {
                filterIndex = index;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : muted,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(
                              alpha: 0.20,
                            )
                          : const Color(0xFFF0F2FA),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: active ? Colors.white : muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VOCABULARY LIST
  // ==========================================

  Widget _buildVocabularyList() {
    final words = _filteredVocab;

    if (words.isEmpty) {
      return _buildEmptyList();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.white,
          child: Column(
            children: [
              for (int i = 0; i < words.length; i++) ...[
                _buildVocabularyTile(words[i]),
                if (i < words.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 17,
                    ),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEDF0F7),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VOCABULARY TILE
  // ==========================================

  Widget _buildVocabularyTile(VocabCard word) {
    final title = _displayWord(word.english);

    final initial = title.isEmpty
        ? '?'
        : String.fromCharCode(
            title.runes.first,
          ).toUpperCase();

    return InkWell(
      onTap: () => _openWordDetails(word),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        child: Row(
          children: [
            // Avatar.
            Container(
              width: 49,
              height: 49,
              decoration: BoxDecoration(
                color: _avatarBackground(
                  word.status,
                ),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: _statusColor(
                      word.status,
                    ),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Kata dan terjemahan.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: vocabularyTitleStyle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    word.indonesia,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: vocabularySubtitleStyle,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 9),

            // Status penguasaan.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: _statusBackground(
                  word.status,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(word.status),
                style: TextStyle(
                  color: _statusColor(word.status),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================

  Widget _buildEmptyList() {
    final searching = _searchQuery.trim().isNotEmpty;

    final completelyEmpty = _vocab.isEmpty;

    final title = searching
        ? 'Kosakata tidak ditemukan'
        : completelyEmpty
            ? 'Belum ada kosakata'
            : filterIndex == 1
                ? 'Tidak ada kata yang perlu review'
                : filterIndex == 2
                    ? 'Belum ada kata yang dikuasai'
                    : 'Koleksi kosakata masih kosong';

    final description = searching
        ? 'Coba gunakan kata kunci yang berbeda.'
        : completelyEmpty
            ? 'Kosakata yang kamu tambahkan '
                'akan muncul di sini.'
            : filterIndex == 1
                ? 'Kamu bisa melanjutkan belajar '
                    'kosakata lainnya.'
                : filterIndex == 2
                    ? 'Lakukan latihan untuk meningkatkan '
                        'penguasaan kosakata.'
                    : 'Tambahkan kosakata untuk '
                        'memulai belajar.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 23,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: border,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.menu_book_rounded,
              color: primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: vocabularyTitleStyle,
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODAL HANDLE
  // ==========================================

  Widget _buildSheetHandle() {
    return Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFDDE1EC),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ==========================================
  // WORD DETAILS
  // ==========================================

  Future<void> _openWordDetails(
    VocabCard word,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  23,
                  12,
                  23,
                  26,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: _buildSheetHandle(),
                    ),
                    const SizedBox(height: 23),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayWord(word.english),
                            style: pageTitleStyle,
                          ),
                        ),
                        _buildHeaderButton(
                          icon: Icons.volume_up_rounded,
                          tooltip: 'Dengarkan pelafalan',
                          onTap: () {
                            _speak(word.english);
                          },
                          filled: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      word.indonesia,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (word.example.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEFF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONTOH KALIMAT',
                              style: TextStyle(
                                color: primary,
                                fontSize: 12,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              word.example,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Status penguasaan',
                      style: sectionTitleStyle,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: VocabStatus.values.map(
                        (status) {
                          final selected = word.status == status;

                          return ChoiceChip(
                            selected: selected,
                            showCheckmark: false,
                            label: Text(
                              _statusLabel(status),
                            ),
                            selectedColor: _statusBackground(status),
                            backgroundColor: background,
                            labelStyle: TextStyle(
                              color: selected ? _statusColor(status) : muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? _statusColor(status).withValues(
                                      alpha: 0.4,
                                    )
                                  : border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (_) {
                              setState(() {
                                word.status = status;
                              });

                              setSheetState(() {});

                              _saveVocabulary();
                            },
                          );
                        },
                      ).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                                'edit',
                              );
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                            ),
                            label: const Text('Edit kata'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: const BorderSide(
                                color: border,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                                'delete',
                              );
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                            ),
                            label: const Text('Hapus'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD64B5D),
                              side: const BorderSide(
                                color: Color(0xFFF1D5DC),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == 'edit') {
      await _openWordEditor(existing: word);
    } else if (action == 'delete') {
      await _confirmDelete(word);
    }
  }

  // ==========================================
  // ADD / EDIT WORD
  // ==========================================

  Future<void> _openWordEditor({
    VocabCard? existing,
  }) async {
    final result = await showModalBottomSheet<VocabCard>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (sheetContext) {
        return _VocabularyEditorSheet(
          existing: existing,
          vocabulary: _vocab,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      if (existing == null) {
        _vocab.add(result);
      } else {
        final index = _vocab.indexOf(existing);

        if (index >= 0) {
          _vocab[index] = result;
        }
      }

      filterIndex = 0;
      showFront = true;
    });

    final saved = await _saveVocabulary();

    if (!mounted || !saved) return;

    _showMessage(
      existing == null
          ? 'Kosakata baru ditambahkan.'
          : 'Kosakata berhasil diperbarui.',
    );
  }

  // ==========================================
  // DELETE WORD
  // ==========================================

  Future<void> _confirmDelete(
    VocabCard word,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Hapus kosakata?',
            style: sectionTitleStyle,
          ),
          content: Text(
            '"${_displayWord(word.english)}" '
            'akan dihapus dari koleksi kosakatamu.',
            style: const TextStyle(
              color: muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Hapus',
                style: TextStyle(
                  color: Color(0xFFD64B5D),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _vocab.remove(word);

      cardIndex = _vocab.isEmpty
          ? 0
          : cardIndex
              .clamp(
                0,
                _vocab.length - 1,
              )
              .toInt();

      showFront = true;
    });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (mounted && _vocab.isNotEmpty && _pageController.hasClients) {
          _pageController.jumpToPage(cardIndex);
        }
      },
    );

    final saved = await _saveVocabulary();

    if (!mounted || !saved) return;

    _showMessage(
      'Kosakata telah dihapus.',
    );
  }

  // ==========================================
  // FLOATING REVIEW BUTTON
  // SAME STYLE AS SMART LEARNING
  // ==========================================

  Widget _buildReviewButton() {
    // Tombol tidak aktif apabila belum
    // terdapat kosakata yang perlu review.

    final enabled = !_loading && !_reviewing && _reviewWords > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: enabled
            ? const LinearGradient(
                colors: [
                  Color(0xFF4365F2),
                  Color(0xFF7249F8),
                ],
              )
            : null,
        color: enabled ? null : const Color(0xFFE3E8F5),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: primary.withValues(
                    alpha: 0.25,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: enabled ? _startReview : null,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: enabled
                      ? Colors.white.withValues(
                          alpha: 0.23,
                        )
                      : const Color(0xFFD5DCEC),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: enabled ? Colors.white : muted,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    _reviewWords > 0
                        ? 'Mulai Review · $_reviewWords kata'
                        : 'Mulai Review',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: enabled ? TextAlign.start : TextAlign.center,
                    style: buttonTextStyle.copyWith(
                      color: enabled ? Colors.white : muted,
                    ),
                  ),
                ),
                if (_reviewWords > 0) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.21,
                      ),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Text(
                      '± $_estimatedReviewMinutes mnt',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(width: 45),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // START REVIEW
  // ==========================================

  Future<void> _startReview() async {
    if (_reviewing || _vocab.isEmpty || _reviewWords == 0) {
      return;
    }

    final reviewCards = _vocab
        .where(
          (word) => word.status == VocabStatus.review,
        )
        .toList();

    if (reviewCards.isEmpty) return;

    setState(() {
      _reviewing = true;
    });

    try {
      await _flutterTts.stop();

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) {
            return _VocabularyReviewSession(
              cards: reviewCards,
              onRated: (word, status) async {
                if (!mounted) return;

                setState(() {
                  word.status = status;
                });

                await _saveVocabulary();
              },
            );
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reviewing = false;
        });
      }
    }
  }

  // ==========================================
  // MAIN SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final embedded = MainTabShell.isEmbedded(context);

    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: primary,
                      ),
                    )
                  : Stack(
                      children: [
                        // Background lembut.
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFECEFFD),
                                  background,
                                  background,
                                ],
                                stops: [
                                  0.0,
                                  0.42,
                                  1.0,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // Content.
                        Positioned.fill(
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              20,
                              18,
                              20,
                              keyboardVisible ? 25 : 110,
                            ),
                            children: [
                              // Header.
                              _buildHeader(),

                              // Pencarian.
                              _buildSearchField(),

                              const SizedBox(height: 22),

                              // Flashcard atau empty state.
                              _buildFlashcardCarousel(),

                              const SizedBox(height: 18),

                              // Statistik berdasarkan data asli.
                              _buildProgressCard(),

                              const SizedBox(height: 18),

                              // Filter koleksi.
                              _buildFilters(),

                              const SizedBox(height: 17),

                              // Daftar kosakata.
                              _buildVocabularyList(),
                            ],
                          ),
                        ),

                        // Bottom fade.
                        if (!keyboardVisible)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Container(
                                height: 108,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      background.withValues(
                                        alpha: 0,
                                      ),
                                      background,
                                      background,
                                    ],
                                    stops: const [
                                      0.0,
                                      0.65,
                                      1.0,
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Floating review.
                        if (!keyboardVisible)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 18,
                            child: _buildReviewButton(),
                          ),
                      ],
                    ),
            ),

            // Bottom navigation LastSeen.
            if (!embedded)
              BottomNav(
                currentIndex: 3,
                onChanged: (index) {
                  _flutterTts.stop();

                  openTab(context, index);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// VOCABULARY STATUS
// ==========================================

enum VocabStatus {
  review,
  learning,
  mastered,
}

// ==========================================
// VOCABULARY MODEL
// ==========================================

class VocabCard {
  final String english;
  final String indonesia;
  final String example;

  VocabStatus status;

  VocabCard(
    this.english,
    this.indonesia,
    this.example, {
    this.status = VocabStatus.review,
  });

  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'indonesia': indonesia,
      'example': example,
      'status': status.name,
    };
  }

  factory VocabCard.fromJson(
    Map<String, dynamic> json,
  ) {
    final statusName = json['status']?.toString() ?? 'review';

    final status = VocabStatus.values.firstWhere(
      (item) => item.name == statusName,
      orElse: () => VocabStatus.review,
    );

    return VocabCard(
      json['english']?.toString() ?? '',
      json['indonesia']?.toString() ?? '',
      json['example']?.toString() ?? '',
      status: status,
    );
  }
}

// ==========================================
// VOCABULARY EDITOR SHEET
// ==========================================

class _VocabularyEditorSheet extends StatefulWidget {
  final VocabCard? existing;
  final List<VocabCard> vocabulary;

  const _VocabularyEditorSheet({
    required this.existing,
    required this.vocabulary,
  });

  @override
  State<_VocabularyEditorSheet> createState() => _VocabularyEditorSheetState();
}

class _VocabularyEditorSheetState extends State<_VocabularyEditorSheet> {
  static const Color primary = Color(0xFF4664F2);
  static const Color ink = Color(0xFF171C31);
  static const Color muted = Color(0xFF8791AC);
  static const Color background = Color(0xFFF5F7FD);
  static const Color border = Color(0xFFE3E8F5);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _englishController;
  late final TextEditingController _indonesiaController;
  late final TextEditingController _exampleController;

  String? _duplicateError;

  @override
  void initState() {
    super.initState();

    _englishController = TextEditingController(
      text: widget.existing?.english ?? '',
    );

    _indonesiaController = TextEditingController(
      text: widget.existing?.indonesia ?? '',
    );

    _exampleController = TextEditingController(
      text: widget.existing?.example ?? '',
    );
  }

  @override
  void dispose() {
    _englishController.dispose();
    _indonesiaController.dispose();
    _exampleController.dispose();

    super.dispose();
  }

  // ==========================================
  // SAVE
  // ==========================================

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final english = _englishController.text.trim();

    final indonesia = _indonesiaController.text.trim();

    final duplicate = widget.vocabulary.any(
      (word) =>
          !identical(word, widget.existing) &&
          word.english.trim().toLowerCase() == english.toLowerCase() &&
          word.indonesia.trim().toLowerCase() == indonesia.toLowerCase(),
    );

    if (duplicate) {
      setState(() {
        _duplicateError = 'Kosakata tersebut sudah tersimpan.';
      });

      return;
    }

    // Kosakata baru hanya dibuat dari
    // input asli yang diberikan pengguna.

    Navigator.pop(
      context,
      VocabCard(
        english,
        indonesia,
        _exampleController.text.trim(),
        status: widget.existing?.status ?? VocabStatus.learning,
      ),
    );
  }

  // ==========================================
  // INPUT FIELD
  // ==========================================

  Widget _buildEditorField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool requiredField = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.none,
      onChanged: (_) {
        if (_duplicateError != null) {
          setState(() {
            _duplicateError = null;
          });
        }
      },
      style: const TextStyle(
        color: ink,
        fontSize: 13,
      ),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bagian ini wajib diisi.';
              }

              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: muted,
          fontSize: 12,
        ),
        hintStyle: const TextStyle(
          color: muted,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          icon,
          color: muted,
          size: 20,
        ),
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BUILD EDITOR
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          23,
          12,
          23,
          24 + keyboardHeight,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE1EC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.existing == null ? 'Tambah kosakata' : 'Edit kosakata',
                style: const TextStyle(
                  color: ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Perluas koleksi kata yang ingin kamu pelajari.',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 23),
              _buildEditorField(
                controller: _englishController,
                label: 'Bahasa Inggris',
                hint: 'Masukkan kata bahasa Inggris',
                icon: Icons.translate_rounded,
                requiredField: true,
              ),
              const SizedBox(height: 14),
              _buildEditorField(
                controller: _indonesiaController,
                label: 'Arti dalam Bahasa Indonesia',
                hint: 'Masukkan arti kata',
                icon: Icons.text_fields_rounded,
                requiredField: true,
              ),
              const SizedBox(height: 14),
              _buildEditorField(
                controller: _exampleController,
                label: 'Contoh kalimat (opsional)',
                hint: 'Masukkan contoh penggunaan kata',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              if (_duplicateError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _duplicateError!,
                  style: const TextStyle(
                    color: Color(0xFFD64B5D),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(
                    Icons.check_rounded,
                  ),
                  label: const Text(
                    'Simpan kosakata',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// VOCABULARY REVIEW SESSION
// ==========================================

class _VocabularyReviewSession extends StatefulWidget {
  final List<VocabCard> cards;

  final Future<void> Function(
    VocabCard word,
    VocabStatus status,
  ) onRated;

  const _VocabularyReviewSession({
    required this.cards,
    required this.onRated,
  });

  @override
  State<_VocabularyReviewSession> createState() =>
      _VocabularyReviewSessionState();
}

class _VocabularyReviewSessionState extends State<_VocabularyReviewSession> {
  static const Color primary = Color(0xFF4664F2);
  static const Color ink = Color(0xFF171C31);
  static const Color muted = Color(0xFF8791AC);
  static const Color background = Color(0xFFF5F7FD);
  static const Color border = Color(0xFFE3E8F5);

  int _index = 0;
  int _mastered = 0;
  int _learning = 0;
  int _review = 0;

  bool _revealed = false;
  bool _saving = false;

  bool get _finished => _index >= widget.cards.length;

  // ==========================================
  // REVIEW RATING
  // ==========================================

  Future<void> _rate(
    VocabStatus status,
  ) async {
    if (_saving || !_revealed || _finished) {
      return;
    }

    final word = widget.cards[_index];

    setState(() {
      _saving = true;
    });

    try {
      await widget.onRated(
        word,
        status,
      );

      if (!mounted) return;

      setState(() {
        switch (status) {
          case VocabStatus.mastered:
            _mastered++;
            break;

          case VocabStatus.learning:
            _learning++;
            break;

          case VocabStatus.review:
            _review++;
            break;
        }

        _index++;
        _revealed = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================
  // FORMAT WORD
  // ==========================================

  String _displayWord(String value) {
    final text = value.trim();

    if (text.isEmpty) return '';

    if (text == text.toUpperCase()) {
      final lower = text.toLowerCase();

      return lower[0].toUpperCase() + lower.substring(1);
    }

    return text;
  }

  // ==========================================
  // REVIEW FLASHCARD
  // ==========================================

  Widget _buildReviewCard(VocabCard word) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 280,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.22),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4265F0),
                Color(0xFF5654F2),
                Color(0xFF7448F8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: _saving
                ? null
                : () {
                    setState(() {
                      _revealed = !_revealed;
                    });
                  },
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFDCE4FF),
                    size: 25,
                  ),
                  const SizedBox(height: 25),
                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 250,
                    ),
                    child: Text(
                      _displayWord(
                        _revealed ? word.indonesia : word.english,
                      ),
                      key: ValueKey(
                        '${word.english}-$_revealed',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _revealed ? word.example : 'Apa arti kata ini?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE8ECFF),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 27),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.flip_camera_android_outlined,
                        color: Color(0xFFDCE4FF),
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _revealed
                              ? 'Ketuk untuk kembali'
                              : 'Ketuk untuk melihat jawaban',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFDCE4FF),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RATING BUTTON
  // ==========================================

  Widget _buildRatingButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color fill,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: _saving ? null : onTap,
          borderRadius: BorderRadius.circular(19),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 18,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REVIEW RESULT
  // ==========================================

  Widget _buildCompleted() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFDDF7EB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFF15A879),
                size: 53,
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Review selesai!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 27,
                letterSpacing: -0.9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Terus berlatih untuk memperkuat '
              'penguasaan kosakatamu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: border,
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  _buildResultRow(
                    'Dikuasai',
                    _mastered,
                    const Color(0xFF15A879),
                  ),
                  const Divider(
                    height: 23,
                    color: Color(0xFFEDF0F7),
                  ),
                  _buildResultRow(
                    'Sedang belajar',
                    _learning,
                    primary,
                  ),
                  const Divider(
                    height: 23,
                    color: Color(0xFFEDF0F7),
                  ),
                  _buildResultRow(
                    'Perlu review lagi',
                    _review,
                    const Color(0xFFEC8C00),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Kembali ke Library',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // RESULT ROW
  // ==========================================

  Widget _buildResultRow(
    String label,
    int value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$value kata',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BUILD REVIEW SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final total = widget.cards.length;

    final progress = total == 0 ? 0.0 : _index / total;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ink,
        title: const Text(
          'Review Kosakata',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: total == 0
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.style_outlined,
                        color: muted,
                        size: 48,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Belum ada kosakata',
                        style: TextStyle(
                          color: ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tambahkan kosakata terlebih dahulu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Kembali ke Library',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _finished
                ? _buildCompleted()
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Kartu ${_index + 1} dari $total',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                color: primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            color: primary,
                            backgroundColor: const Color(0xFFE2E7F3),
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildReviewCard(
                          widget.cards[_index],
                        ),
                        const SizedBox(height: 30),
                        if (!_revealed)
                          SizedBox(
                            width: double.infinity,
                            height: 53,
                            child: ElevatedButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      setState(() {
                                        _revealed = true;
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Lihat jawaban',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          const Center(
                            child: Text(
                              'Seberapa baik kamu mengingatnya?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildRatingButton(
                                label: 'Belum hafal',
                                icon: Icons.refresh_rounded,
                                color: const Color(0xFFC77900),
                                fill: const Color(0xFFFFEFD7),
                                onTap: () {
                                  _rate(
                                    VocabStatus.review,
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              _buildRatingButton(
                                label: 'Masih belajar',
                                icon: Icons.school_outlined,
                                color: primary,
                                fill: const Color(0xFFE9EEFF),
                                onTap: () {
                                  _rate(
                                    VocabStatus.learning,
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              _buildRatingButton(
                                label: 'Sudah hafal',
                                icon: Icons.check_circle_outline,
                                color: const Color(0xFF07875B),
                                fill: const Color(0xFFDDF7EB),
                                onTap: () {
                                  _rate(
                                    VocabStatus.mastered,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
