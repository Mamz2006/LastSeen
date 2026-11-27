import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';

import '../nav.dart';
import '../services/learning_store.dart';

// ==================================================
// LASTSEEN - HASIL SCAN
//
// 1. Menerima teks OCR dari kamera lama.
// 2. Membacakan teks asli menggunakan TTS.
// 3. Menampilkan terjemahan jika data sudah ada.
// 4. Membacakan hasil terjemahan.
// 5. Menyimpan kata ke Kosakata Saya.
// 6. Tidak menggunakan Google ML Kit Translation.
// ==================================================

class S05OcrReview extends StatefulWidget {
  final String? initialText;
  final String? imagePath;
  final bool englishToIndonesian;

  // Diisi dari sistem penerjemahan temanmu nanti.
  final String? translatedText;

  // Arti kata yang diberikan sistem temanmu.
  final Map<String, String> wordMeanings;

  const S05OcrReview({
    super.key,
    this.initialText,
    this.imagePath,
    this.englishToIndonesian = true,
    this.translatedText,
    this.wordMeanings = const {},
  });

  @override
  State<S05OcrReview> createState() => _S05OcrReviewState();
}

class _S05OcrReviewState extends State<S05OcrReview> {
  static const Color primary = Color(0xFF4664F2);
  static const Color purple = Color(0xFF704CF7);
  static const Color navy = Color(0xFF171B34);
  static const Color muted = Color(0xFF8791AC);
  static const Color background = Color(0xFFF5F7FD);
  static const Color border = Color(0xFFE1E7F4);

  final FlutterTts _tts = FlutterTts();

  final Set<String> _savedIds = {};

  late final String _originalText;

  bool _saving = false;
  bool _sentenceSaved = false;
  bool _speaking = false;

  String get _translatedText => widget.translatedText?.trim() ?? '';

  bool get _hasTranslation => _translatedText.isNotEmpty;

  String get _sourceLanguage =>
      widget.englishToIndonesian ? 'English' : 'Indonesia';

  String get _targetLanguage =>
      widget.englishToIndonesian ? 'Indonesia' : 'English';

  String get _sourceCode => widget.englishToIndonesian ? 'en' : 'id';

  @override
  void initState() {
    super.initState();

    _originalText = widget.initialText?.trim() ?? '';

    _setupAudio();
    _loadSavedWords();
  }

  // ==================================================
  // AUDIO
  // ==================================================

  Future<void> _setupAudio() async {
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _speaking = false);
        }
      });

      _tts.setErrorHandler((message) {
        if (mounted) {
          setState(() => _speaking = false);
        }
      });

      _tts.setCancelHandler(() {
        if (mounted) {
          setState(() => _speaking = false);
        }
      });
    } catch (_) {
      // Pengaturan audio tidak tersedia di perangkat.
    }
  }

  Future<void> _playAudio({
    required String text,
    required bool isOriginal,
  }) async {
    if (text.trim().isEmpty) {
      _showMessage('Belum ada teks untuk dibacakan.');
      return;
    }

    final bool english =
        isOriginal ? widget.englishToIndonesian : !widget.englishToIndonesian;

    final languageCode = english ? 'en-US' : 'id-ID';

    try {
      await _tts.stop();

      await _tts.setLanguage(languageCode);
      await _tts.setSpeechRate(0.48);

      if (!mounted) return;

      setState(() => _speaking = true);

      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() => _speaking = false);
      }

      _showMessage(
        'Gagal memutar audio. '
        'Periksa pengaturan suara HP.',
      );
    }
  }

  Future<void> _stopAudio() async {
    await _tts.stop();

    if (mounted) {
      setState(() => _speaking = false);
    }
  }

  // ==================================================
  // PESAN
  // ==================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================================================
  // DATA KOSAKATA YANG SUDAH TERSIMPAN
  // ==================================================

  Future<void> _loadSavedWords() async {
    try {
      final snapshot = await LearningStore.load();

      if (!mounted) return;

      setState(() {
        _savedIds.addAll(
          snapshot.words.map((word) => word.id),
        );

        _sentenceSaved = _savedIds.contains(
          _sentenceId,
        );
      });
    } catch (_) {
      // Halaman hasil tetap dapat dibuka.
    }
  }

  // ==================================================
  // MEMILIH KATA DARI HASIL OCR
  // ==================================================

  List<String> get _scannedWords {
    final words = <String>[];
    final unique = <String>{};

    final matches = RegExp(
      r'[A-Za-zÀ-ÖØ-öø-ÿ]+',
    ).allMatches(_originalText);

    for (final match in matches) {
      final word = match.group(0)!.toLowerCase();

      if (word.length < 3) continue;

      if (!unique.add(word)) continue;

      words.add(word);

      // Maksimal tiga kata seperti desain.
      if (words.length == 3) break;
    }

    return words;
  }

  String _getMeaning(String word) {
    final normalized = word.toLowerCase().trim();

    for (final entry in widget.wordMeanings.entries) {
      if (entry.key.toLowerCase().trim() == normalized) {
        return entry.value.trim();
      }
    }

    return '';
  }

  String _wordId(String word) {
    return 'scan:$_sourceCode:${word.toLowerCase()}';
  }

  String get _sentenceId => 'scan:sentence:$_sourceCode:'
      '${_originalText.toLowerCase()}';

  // ==================================================
  // SIMPAN SATU KATA
  // ==================================================

  Future<void> _saveWord(String word) async {
    if (_saving) return;

    final meaning = _getMeaning(word);

    if (meaning.isEmpty) {
      _showMessage(
        'Arti kata belum tersedia. '
        'Menunggu sistem penerjemahan.',
      );
      return;
    }

    final id = _wordId(word);

    if (_savedIds.contains(id)) {
      _showMessage('Kata sudah disimpan.');
      return;
    }

    setState(() => _saving = true);

    try {
      await LearningStore.saveWord(
        StudyWord(
          id: id,
          word: word,
          meaning: meaning,
        ),
      );

      if (!mounted) return;

      setState(() {
        _savedIds.add(id);
      });

      _showMessage(
        '"$word" berhasil disimpan ke Kosakata Saya.',
      );
    } catch (_) {
      _showMessage('Gagal menyimpan kosakata.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ==================================================
  // SIMPAN SEMUA KATA YANG SUDAH ADA ARTINYA
  // ==================================================

  Future<void> _saveAllWords() async {
    if (_saving) return;

    final availableWords =
        _scannedWords.where((word) => _getMeaning(word).isNotEmpty).toList();

    if (availableWords.isEmpty) {
      _showMessage(
        'Belum ada arti kata yang tersedia.',
      );
      return;
    }

    setState(() => _saving = true);

    int count = 0;

    try {
      for (final word in availableWords) {
        final id = _wordId(word);

        if (_savedIds.contains(id)) continue;

        await LearningStore.saveWord(
          StudyWord(
            id: id,
            word: word,
            meaning: _getMeaning(word),
          ),
        );

        _savedIds.add(id);
        count++;
      }

      if (!mounted) return;

      setState(() {});

      _showMessage(
        count == 0
            ? 'Semua kata sudah disimpan.'
            : '$count kata berhasil disimpan.',
      );
    } catch (_) {
      _showMessage('Ada kata yang gagal disimpan.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ==================================================
  // SIMPAN HASIL TERJEMAHAN KE FLASHCARD
  // ==================================================

  Future<void> _saveSentence() async {
    if (!_hasTranslation) {
      _showMessage(
        'Terjemahan belum tersedia. '
        'Menunggu data/model penerjemahan.',
      );
      return;
    }

    if (_saving || _sentenceSaved) return;

    setState(() => _saving = true);

    try {
      await LearningStore.saveWord(
        StudyWord(
          id: _sentenceId,
          word: _originalText,
          meaning: _translatedText,
        ),
      );

      if (!mounted) return;

      setState(() {
        _sentenceSaved = true;
        _savedIds.add(_sentenceId);
      });

      _showMessage(
        'Hasil scan berhasil disimpan '
        'ke Kosakata Saya.',
      );
    } catch (_) {
      _showMessage(
        'Gagal menyimpan hasil terjemahan.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ==================================================
  // SALIN HASIL TERJEMAHAN
  // ==================================================

  Future<void> _copyTranslation() async {
    if (!_hasTranslation) {
      _showMessage('Terjemahan belum tersedia.');
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: _translatedText),
    );

    _showMessage('Terjemahan berhasil disalin.');
  }

  // ==================================================
  // BAGIKAN HASIL TERJEMAHAN
  // ==================================================

  Future<void> _shareTranslation() async {
    if (!_hasTranslation) {
      _showMessage('Terjemahan belum tersedia.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Teks asli:\n'
              '$_originalText\n\n'
              'Terjemahan:\n'
              '$_translatedText',
        ),
      );
    } catch (_) {
      _showMessage('Gagal membagikan terjemahan.');
    }
  }

  // ==================================================
  // TOMBOL IKON
  // ==================================================

  Widget _circleButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool white = false,
  }) {
    return Material(
      shape: const CircleBorder(),
      color: white
          ? Colors.white.withValues(alpha: 0.18)
          : const Color(0xFFF0F3FB),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: white ? Colors.white : primary,
          size: 22,
        ),
      ),
    );
  }

  // ==================================================
  // HEADER
  // ==================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(18),
            child: const SizedBox(
              width: 49,
              height: 49,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: navy,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hasil Terjemahan',
                style: TextStyle(
                  color: navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Dari hasil scan kamera',
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================================================
  // LABEL PADA FOTO
  // ==================================================

  Widget _photoLabel({
    required String title,
    required Color color,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // PREVIEW FOTO ASLI ATAU TEKS OCR
  // ==================================================

  Widget _buildPhotoPreview() {
    final path = widget.imagePath;

    final hasPhoto =
        !kIsWeb && path != null && path.isNotEmpty && File(path).existsSync();

    return Container(
      width: double.infinity,
      height: 185,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF252C50),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          if (hasPhoto)
            Positioned.fill(
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
              ),
            )
          else
            Center(
              child: Container(
                width: 230,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _originalText.isEmpty
                      ? 'Belum ada hasil scan.'
                      : _originalText,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF29335D),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 14,
            left: 14,
            child: _photoLabel(
              title: hasPhoto ? 'Foto asli' : 'Teks OCR',
              color: const Color(0xFF202745),
              textColor: Colors.white,
              icon: Icons.circle,
            ),
          ),
          if (_originalText.isNotEmpty)
            Positioned(
              top: 14,
              right: 14,
              child: _photoLabel(
                title: 'Terbaca',
                color: const Color(0xFFDEF8E9),
                textColor: const Color(0xFF148F62),
                icon: Icons.check_rounded,
              ),
            ),
        ],
      ),
    );
  }

  // ==================================================
  // PILIHAN BAHASA
  // ==================================================

  Widget _buildLanguageBar() {
    return Container(
      height: 59,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                _sourceLanguage,
                style: const TextStyle(
                  color: navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Arah bahasa',
            onPressed: () {
              _showMessage(
                'Pilihan bahasa mengikuti halaman Scan.',
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE9EEFF),
            ),
            icon: const Icon(
              Icons.sync_alt_rounded,
              color: primary,
              size: 25,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _targetLanguage,
                style: const TextStyle(
                  color: navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // KARTU TEKS ASLI + AUDIO
  // ==================================================

  Widget _buildOriginalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceLanguage.toUpperCase(),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  _originalText.isEmpty
                      ? 'Tidak ada teks yang terbaca.'
                      : _originalText,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _circleButton(
            icon: _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
            onPressed: _originalText.isEmpty
                ? null
                : () {
                    if (_speaking) {
                      _stopAudio();
                    } else {
                      _playAudio(
                        text: _originalText,
                        isOriginal: true,
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  // ==================================================
  // KARTU HASIL TERJEMAHAN + AUDIO
  // ==================================================

  Widget _buildTranslationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(29),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✦  ${_targetLanguage.toUpperCase()}',
            style: const TextStyle(
              color: Color(0xFFE2E6FF),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (_hasTranslation)
            Text(
              _translatedText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            )
          else
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 29,
                ),
                SizedBox(height: 12),
                Text(
                  'Terjemahan belum tersedia',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  'Teks sudah berhasil dibaca. '
                  'Hasil terjemahan akan muncul '
                  'setelah data atau model '
                  'penerjemahan terhubung.',
                  style: TextStyle(
                    color: Color(0xFFE4E8FF),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              _circleButton(
                icon: Icons.volume_up_rounded,
                white: true,
                onPressed: () {
                  if (!_hasTranslation) {
                    _showMessage(
                      'Belum ada hasil terjemahan '
                      'untuk dibacakan.',
                    );
                    return;
                  }

                  _playAudio(
                    text: _translatedText,
                    isOriginal: false,
                  );
                },
              ),
              const SizedBox(width: 10),
              _circleButton(
                icon: Icons.copy_rounded,
                white: true,
                onPressed: _copyTranslation,
              ),
              const SizedBox(width: 10),
              _circleButton(
                icon: Icons.ios_share_rounded,
                white: true,
                onPressed: _shareTranslation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================================================
  // KARTU KOSAKATA
  // ==================================================

  Widget _buildWordCard(String word) {
    final meaning = _getMeaning(word);
    final saved = _savedIds.contains(_wordId(word));

    return Container(
      width: 143,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: InkWell(
              onTap: _saving ? null : () => _saveWord(word),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9EEFF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  saved ? Icons.check_rounded : Icons.add_rounded,
                  color: primary,
                  size: 21,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            word,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            meaning.isEmpty ? 'Arti belum tersedia' : meaning,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // KATA YANG BISA DIPELAJARI
  // ==================================================

  Widget _buildLearnableWords() {
    final words = _scannedWords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Kata yang bisa dipelajari',
                style: TextStyle(
                  color: navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: _saving || words.isEmpty ? null : _saveAllWords,
              child: const Text(
                'Simpan semua',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (words.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Belum ada kosakata hasil scan.',
              style: TextStyle(color: muted),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: words.map(_buildWordCard).toList(),
            ),
          ),
      ],
    );
  }

  // ==================================================
  // TOMBOL SCAN LAGI DAN SIMPAN
  // ==================================================

  Widget _buildBottomActions() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.camera_alt_outlined,
              size: 19,
            ),
            label: const FittedBox(
              child: Text('Scan lagi'),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 59),
              backgroundColor: Colors.white,
              foregroundColor: navy,
              side: const BorderSide(color: border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 7,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _saveSentence,
            icon: Icon(
              _sentenceSaved
                  ? Icons.check_rounded
                  : Icons.bookmark_border_rounded,
              size: 21,
            ),
            label: FittedBox(
              child: Text(
                _sentenceSaved ? 'Tersimpan' : 'Simpan ke Kosakata',
              ),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 59),
              foregroundColor: Colors.white,
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================================================
  // NAVIGASI BAWAH
  // ==================================================

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
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
      color: Colors.white,
      child: Row(
        children: List.generate(5, (index) {
          final active = index == 1;

          return Expanded(
            child: InkWell(
              onTap: () => openTab(context, index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 34,
                    decoration: BoxDecoration(
                      color:
                          active ? const Color(0xFFE8EDFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      icons[index],
                      color: active ? primary : muted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: active ? primary : muted,
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
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

  // ==================================================
  // TAMPILAN UTAMA
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final embedded = MainTabShell.isEmbedded(context);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  25,
                ),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  _buildPhotoPreview(),
                  const SizedBox(height: 17),
                  _buildLanguageBar(),
                  const SizedBox(height: 17),
                  _buildOriginalCard(),
                  const SizedBox(height: 17),
                  _buildTranslationCard(),
                  const SizedBox(height: 23),
                  _buildLearnableWords(),
                  const SizedBox(height: 23),
                  _buildBottomActions(),
                ],
              ),
            ),
            if (!embedded) _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
