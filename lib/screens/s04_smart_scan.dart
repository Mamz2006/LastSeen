import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../nav.dart';
import '../widgets/bottom_nav.dart';

import 's04b_camera_capture.dart';
import 's05_ocr_review.dart';
import 's06_import_document.dart';

// =============================================
// LASTSEEN - SMART SCAN
// CAMERA REAL-TIME + GLASSMORPHISM
// =============================================

class S04SmartScan extends StatefulWidget {
  const S04SmartScan({super.key});

  @override
  State<S04SmartScan> createState() => _S04SmartScanState();
}

class _S04SmartScanState extends State<S04SmartScan>
    with WidgetsBindingObserver {
  // ==========================================
  // WARNA APLIKASI
  // ==========================================

  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);
  static const Color muted = Color(0xFF8089A1);
  static const Color background = Color(0xFFF8F9FD);
  static const Color border = Color(0xFFDDE3F0);

  // Warna glass untuk semua tombol header.
  static const Color glassColor = Color(0xFF454B61);
  static const Color glassBorder = Color(0xFFFFFFFF);

  // ==========================================
  // KAMERA
  // ==========================================

  CameraController? _camera;

  Future<void>? _starting;
  Future<void>? _stopping;

  final ImagePicker _picker = ImagePicker();

  int _cameraVersion = 0;

  bool _tabVisible = false;
  bool _appVisible = true;
  bool _suspended = false;
  bool _busy = false;
  bool _disposing = false;

  String? _error;

  // ==========================================
  // PILIHAN BAHASA
  // ==========================================

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Indonesia';

  void _swapLanguage() {
    setState(() {
      final previous = _sourceLanguage;

      _sourceLanguage = _targetLanguage;
      _targetLanguage = previous;
    });
  }

  void _changeLanguage({
    required String source,
    required String target,
  }) {
    setState(() {
      _sourceLanguage = source;
      _targetLanguage = target;
    });
  }

  // ==========================================
  // MODAL PILIH BAHASA
  // ==========================================

  void _showLanguagePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              22,
              14,
              22,
              28,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF191E32),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pilih bahasa pemindaian',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tentukan arah bahasa yang ingin digunakan.',
                  style: TextStyle(
                    color: Color(0xFFA6AEC8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                _languageOption(
                  title: 'English → Indonesia',
                  selected: _sourceLanguage == 'English',
                  onTap: () {
                    _changeLanguage(
                      source: 'English',
                      target: 'Indonesia',
                    );

                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 12),
                _languageOption(
                  title: 'Indonesia → English',
                  selected: _sourceLanguage == 'Indonesia',
                  onTap: () {
                    _changeLanguage(
                      source: 'Indonesia',
                      target: 'English',
                    );

                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // ITEM PILIHAN BAHASA
  // ==========================================

  Widget _languageOption({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
          selected ? primary.withValues(alpha: 0.24) : const Color(0xFF2B3045),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 17,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFF8FA0FF) : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF91A1FF),
                  size: 23,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // GLASS LANGUAGE PICKER
  // TANPA GARIS PEMISAH
  // ==========================================

  Widget _buildGlassLanguagePicker() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          height: 49,
          decoration: BoxDecoration(
            color: glassColor.withValues(
              alpha: 0.43,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: glassBorder.withValues(
                alpha: 0.28,
              ),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // NAMA BAHASA
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showLanguagePicker,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$_sourceLanguage  →  $_targetLanguage',
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // TOMBOL TUKAR BAHASA
              // TANPA GARIS VERTIKAL
              IconButton(
                tooltip: 'Tukar bahasa',
                onPressed: _swapLanguage,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 42,
                ),
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOMBOL LINGKARAN GLASS
  // DIPAKAI UNTUK BACK DAN PERBESAR
  // ==========================================

  Widget _glassCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 15,
            sigmaY: 15,
          ),
          child: Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: glassColor.withValues(
                alpha: 0.43,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: glassBorder.withValues(
                  alpha: 0.28,
                ),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // KONDISI KAMERA
  // ==========================================

  bool get _shouldRun =>
      mounted &&
      !_disposing &&
      !kIsWeb &&
      _tabVisible &&
      _appVisible &&
      !_suspended;

  bool _isCurrent(int version) => _shouldRun && _cameraVersion == version;

  // ==========================================
  // LIFECYCLE
  // ==========================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final visible = TickerMode.of(context);

    if (_tabVisible != visible) {
      _tabVisible = visible;

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (mounted) {
            _syncCamera();
          }
        },
      );
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    _appVisible = state == AppLifecycleState.resumed;

    _syncCamera();
  }

  // ==========================================
  // SINKRONISASI KAMERA REAL-TIME
  // ==========================================

  void _syncCamera() {
    if (!mounted || _disposing || kIsWeb) {
      return;
    }

    if (!_shouldRun) {
      if (_camera != null || _starting != null) {
        unawaited(_stopCamera());
      }

      return;
    }

    if (_camera != null || _starting != null || _stopping != null) {
      return;
    }

    final version = ++_cameraVersion;

    final task = _initializeCamera(version);
    _starting = task;

    unawaited(
      task.whenComplete(() {
        if (identical(_starting, task)) {
          _starting = null;
        }
      }),
    );
  }

  // ==========================================
  // INISIALISASI KAMERA
  // ==========================================

  Future<void> _initializeCamera(int version) async {
    try {
      final cameras = await availableCameras();

      if (!_isCurrent(version)) {
        return;
      }

      if (cameras.isEmpty) {
        throw StateError(
          'Kamera tidak ditemukan.',
        );
      }

      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // COBA MEMBUKA KAMERA MAKSIMAL 3 KALI
      for (int attempt = 0; attempt < 3; attempt++) {
        if (!_isCurrent(version)) {
          return;
        }

        CameraController? candidate;

        try {
          candidate = CameraController(
            rearCamera,
            ResolutionPreset.high,
            enableAudio: false,
          );

          await candidate.initialize();

          if (!_isCurrent(version)) {
            await candidate.dispose();
            return;
          }

          setState(() {
            _camera = candidate;
            _error = null;
          });

          return;
        } catch (_) {
          if (candidate != null) {
            try {
              await candidate.dispose();
            } catch (_) {}
          }

          if (!_isCurrent(version)) {
            return;
          }

          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(
                milliseconds: 400 + attempt * 300,
              ),
            );
          }
        }
      }

      if (_isCurrent(version)) {
        setState(() {
          _error = 'Kamera belum tersedia. Tekan Coba lagi.';
        });
      }
    } catch (_) {
      if (_isCurrent(version)) {
        setState(() {
          _error = 'Tidak dapat membuka kamera. Periksa izin kamera.';
        });
      }
    }
  }

  // ==========================================
  // MENGHENTIKAN KAMERA
  // ==========================================

  Future<void> _stopCamera() async {
    _cameraVersion++;

    final ongoingStop = _stopping;

    if (ongoingStop != null) {
      await ongoingStop;
      return;
    }

    final task = _releaseCamera();
    _stopping = task;

    try {
      await task;
    } finally {
      if (identical(_stopping, task)) {
        _stopping = null;
      }

      if (_shouldRun) {
        _syncCamera();
      }
    }
  }

  // ==========================================
  // MELEPAS CAMERA CONTROLLER
  // ==========================================

  Future<void> _releaseCamera() async {
    final starting = _starting;

    if (starting != null) {
      try {
        await starting;
      } catch (_) {}

      if (identical(_starting, starting)) {
        _starting = null;
      }
    }

    final oldCamera = _camera;
    _camera = null;

    if (oldCamera != null) {
      if (mounted && !_disposing) {
        setState(() {});
      }

      try {
        await oldCamera.dispose();
      } catch (_) {}
    }
  }

  // ==========================================
  // TAMPILKAN PESAN
  // ==========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==========================================
  // MEMBACA TEKS DARI GAMBAR
  // ==========================================

  Future<String> _readText(String path) async {
    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );

      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  // ==========================================
  // HALAMAN HASIL OCR
  // ==========================================

  Future<void> _showResult(String text) async {
    if (!mounted || text.isEmpty) {
      return;
    }

    setState(() {
      _suspended = true;
    });

    await _stopCamera();

    if (!mounted) return;

    try {
      final route = MaterialPageRoute<void>(
        builder: (_) => S05OcrReview(
          initialText: text,
        ),
      );

      await Navigator.of(context).push<void>(
        route,
      );

      await route.completed;
    } finally {
      if (mounted) {
        setState(() {
          _suspended = false;
        });

        _syncCamera();
      }
    }
  }

  // ==========================================
  // PINDAI LANGSUNG DARI KAMERA REAL-TIME
  // ==========================================

  Future<void> _captureInline() async {
    if (_busy || _suspended) {
      return;
    }

    final camera = _camera;

    if (camera == null || !camera.value.isInitialized) {
      _showMessage(
        'Kamera sedang disiapkan.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final picture = await camera.takePicture();

      final text = await _readText(
        picture.path,
      );

      if (!mounted) return;

      if (text.isEmpty) {
        _showMessage(
          'Teks tidak terdeteksi. Coba lebih dekat.',
        );
      } else {
        await _showResult(text);
      }
    } catch (_) {
      _showMessage(
        'Gagal memindai. Coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ==========================================
  // MEMBUKA KAMERA FULLSCREEN
  // ==========================================

  Future<void> _openFullCamera() async {
    if (_busy || _suspended) {
      return;
    }

    if (kIsWeb) {
      _showMessage(
        'Gunakan Android untuk membuka kamera.',
      );
      return;
    }

    setState(() {
      _suspended = true;
      _error = null;
    });

    // LEPASKAN KAMERA REAL-TIME DULU
    await _stopCamera();

    if (!mounted) return;

    final route = MaterialPageRoute<String>(
      builder: (_) => const S04BCameraCapture(),
    );

    try {
      final text = await Navigator.of(context).push<String>(
        route,
      );

      // TUNGGU FULLSCREEN BENAR-BENAR DITUTUP
      await route.completed;

      if (!mounted) return;

      if (text != null && text.trim().isNotEmpty) {
        final resultRoute = MaterialPageRoute<void>(
          builder: (_) => S05OcrReview(
            initialText: text,
          ),
        );

        await Navigator.of(context).push<void>(
          resultRoute,
        );

        await resultRoute.completed;
      }
    } catch (_) {
      _showMessage(
        'Mode kamera gagal dibuka.',
      );
    } finally {
      // TUNGGU RESOURCE KAMERA ANDROID SIAP
      await Future<void>.delayed(
        const Duration(milliseconds: 350),
      );

      if (mounted) {
        setState(() {
          _suspended = false;
          _error = null;
        });

        _tabVisible = TickerMode.of(context);

        // AKTIFKAN KEMBALI KAMERA REAL-TIME
        _syncCamera();
      }
    }
  }

  // ==========================================
  // GALERI
  // ==========================================

  Future<void> _openGallery() async {
    if (_busy || _suspended) {
      return;
    }

    if (kIsWeb) {
      _showMessage(
        'Gunakan Android untuk OCR galeri.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _suspended = true;
    });

    await _stopCamera();

    if (!mounted) return;

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null || !mounted) {
        return;
      }

      final text = await _readText(
        image.path,
      );

      if (!mounted) return;

      if (text.isEmpty) {
        _showMessage(
          'Tidak ada teks pada gambar.',
        );
      } else {
        final route = MaterialPageRoute<void>(
          builder: (_) => S05OcrReview(
            initialText: text,
          ),
        );

        await Navigator.of(context).push<void>(
          route,
        );

        await route.completed;
      }
    } catch (_) {
      _showMessage(
        'Gagal membaca gambar.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _suspended = false;
        });

        _syncCamera();
      }
    }
  }

  // ==========================================
  // IMPOR DOKUMEN
  // ==========================================

  Future<void> _openImport() async {
    if (_busy || _suspended) {
      return;
    }

    setState(() {
      _suspended = true;
    });

    await _stopCamera();

    if (!mounted) return;

    try {
      final route = MaterialPageRoute<void>(
        builder: (_) => const S06ImportDocument(),
      );

      await Navigator.of(context).push<void>(
        route,
      );

      await route.completed;
    } finally {
      if (mounted) {
        setState(() {
          _suspended = false;
        });

        _syncCamera();
      }
    }
  }

  // ==========================================
  // HALAMAN UTAMA
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    final scanHeight = (screenHeight * 0.60)
        .clamp(
          360.0,
          600.0,
        )
        .toDouble();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  16,
                ),
                child: Column(
                  children: [
                    _buildScanner(scanHeight),
                    const SizedBox(height: 22),
                    _buildActions(),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // MENCEGAH BOTTOM NAV GANDA
            if (!MainTabShell.isEmbedded(context))
              BottomNav(
                currentIndex: 1,
                onChanged: (index) => openTab(context, index),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PANEL SCANNER
  // ==========================================

  Widget _buildScanner(double height) {
    return Container(
      width: double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        children: [
          // KAMERA REAL-TIME
          Positioned.fill(
            child: _buildLivePreview(),
          ),

          // OVERLAY TIPIS
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0x18000000),
              ),
            ),
          ),

          // BINGKAI PEMINDAI
          Positioned(
            top: height * 0.19,
            bottom: height * 0.18,
            left: 34,
            right: 34,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScanCornersPainter(),
              ),
            ),
          ),

          // HEADER GLASS BARU
          Positioned(
            top: 17,
            left: 17,
            right: 17,
            child: _buildScannerHeader(),
          ),

          // PETUNJUK PEMINDAIAN
          Positioned(
            bottom: 24,
            left: 12,
            right: 12,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 19,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'Arahkan ke teks yang jelas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAMPILAN KAMERA REAL-TIME
  // ==========================================

  Widget _buildLivePreview() {
    final controller = _camera;

    if (controller != null && controller.value.isInitialized) {
      final size = controller.value.previewSize;

      if (size == null) {
        return CameraPreview(controller);
      }

      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      );
    }

    if (kIsWeb) {
      return const Center(
        child: Text(
          'Kamera tersedia pada Android',
          style: TextStyle(
            color: Colors.white70,
          ),
        ),
      );
    }

    if (_error != null && _shouldRun) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _error = null;
            });

            _syncCamera();
          },
          icon: const Icon(
            Icons.refresh_rounded,
          ),
          label: const Text('Coba lagi'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (_shouldRun) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8195FF),
        ),
      );
    }

    return const SizedBox.expand();
  }

  // ==========================================
  // HEADER SCAN REAL-TIME
  // SEMUA MENGGUNAKAN GLASSMORPHISM
  // ==========================================

  Widget _buildScannerHeader() {
    return Row(
      children: [
        // TOMBOL KEMBALI BERGAYA GLASS
        _glassCircleButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Kembali ke Translate',
          onTap: () => openTab(context, 0),
        ),

        const SizedBox(width: 9),

        // PILIHAN BAHASA BERGAYA GLASS
        Expanded(
          child: _buildGlassLanguagePicker(),
        ),

        const SizedBox(width: 9),

        // IKON PERBESAR BERGAYA GLASS
        _glassCircleButton(
          icon: Icons.open_in_full_rounded,
          tooltip: 'Perbesar kamera',
          onTap: _openFullCamera,
        ),
      ],
    );
  }

  // ==========================================
  // TOMBOL GALERI, PINDAI, IMPOR
  // ==========================================

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _sideAction(
          icon: Icons.photo_library_outlined,
          label: 'Galeri',
          onTap: _openGallery,
        ),
        _buildCameraButton(),
        _sideAction(
          icon: Icons.upload_file_rounded,
          label: 'Impor',
          onTap: _openImport,
        ),
      ],
    );
  }

  // ==========================================
  // TOMBOL PINDAI
  // ==========================================

  Widget _buildCameraButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(60),
      onTap: _busy || _suspended ? null : _captureInline,
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: primary,
                width: 3,
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: primary,
              ),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(23),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Pindai',
            style: TextStyle(
              color: primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOMBOL GALERI DAN IMPOR
  // ==========================================

  Widget _sideAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy || _suspended ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: border,
                width: 1.3,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MEMBERSIHKAN RESOURCE
  // ==========================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _disposing = true;
    _cameraVersion++;

    final controller = _camera;
    _camera = null;

    if (controller != null) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }
}

// =============================================
// GARIS EMPAT SUDUT SCANNER
// =============================================

class _ScanCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8195FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double length = 33;
    const double radius = 13;

    final w = size.width;
    final h = size.height;

    final path = Path()

      // KIRI ATAS
      ..moveTo(0, length)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(length, 0)

      // KANAN ATAS
      ..moveTo(w - length, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(w, 0, w, radius)
      ..lineTo(w, length)

      // KIRI BAWAH
      ..moveTo(0, h - length)
      ..lineTo(0, h - radius)
      ..quadraticBezierTo(0, h, radius, h)
      ..lineTo(length, h)

      // KANAN BAWAH
      ..moveTo(w - length, h)
      ..lineTo(w - radius, h)
      ..quadraticBezierTo(w, h, w, h - radius)
      ..lineTo(w, h - length);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
