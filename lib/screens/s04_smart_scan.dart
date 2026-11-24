import 'dart:async';

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

// ==========================================
// SMART SCAN LASTSEEN
// LIVE CAMERA + FULLSCREEN + OCR
// ==========================================

class S04SmartScan extends StatefulWidget {
  const S04SmartScan({super.key});

  @override
  State<S04SmartScan> createState() => _S04SmartScanState();
}

class _S04SmartScanState extends State<S04SmartScan>
    with WidgetsBindingObserver {
  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);
  static const Color muted = Color(0xFF8089A1);
  static const Color background = Color(0xFFF8F9FD);
  static const Color border = Color(0xFFDDE3F0);

  CameraController? _cameraController;

  Future<void>? _startingCamera;
  Future<void>? _stoppingCamera;

  final ImagePicker _imagePicker = ImagePicker();

  int _cameraToken = 0;

  bool _tabVisible = false;
  bool _appVisible = true;
  bool _suspended = false;
  bool _busy = false;

  String? _error;

  bool get _shouldRunCamera =>
      !kIsWeb && mounted && _tabVisible && _appVisible && !_suspended;

  bool _isCurrentCamera(int token) {
    return _shouldRunCamera && token == _cameraToken;
  }

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

    // MainTabShell menggunakan TickerMode.
    // Kamera hanya aktif pada tab Scan.
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
  // SINKRONISASI STATUS KAMERA
  // ==========================================

  void _syncCamera() {
    if (!mounted || kIsWeb) return;

    if (!_shouldRunCamera) {
      if (_cameraController != null || _startingCamera != null) {
        unawaited(_stopCamera());
      }
      return;
    }

    // Jangan buka kamera baru ketika
    // kamera sebelumnya masih dilepas.
    if (_stoppingCamera != null) return;

    // Jangan membuat dua controller.
    if (_cameraController != null || _startingCamera != null) {
      return;
    }

    unawaited(_startCamera());
  }

  // ==========================================
  // MEMULAI KAMERA REAL-TIME
  // ==========================================

  Future<void> _startCamera() async {
    if (!_shouldRunCamera ||
        _cameraController != null ||
        _startingCamera != null ||
        _stoppingCamera != null) {
      return;
    }

    final token = ++_cameraToken;

    final request = _initializeCamera(token);
    _startingCamera = request;

    try {
      await request;
    } finally {
      if (identical(_startingCamera, request)) {
        _startingCamera = null;
      }
    }
  }

  // ==========================================
  // INISIALISASI + RETRY
  // ==========================================

  Future<void> _initializeCamera(int token) async {
    try {
      final cameras = await availableCameras();

      if (!_isCurrentCamera(token)) {
        return;
      }

      if (cameras.isEmpty) {
        throw StateError(
          'Tidak ada kamera pada perangkat.',
        );
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Coba maksimal tiga kali.
      // Berguna saat kamera fullscreen
      // baru saja ditutup.
      for (int attempt = 0; attempt < 3; attempt++) {
        if (!_isCurrentCamera(token)) {
          return;
        }

        CameraController? created;

        try {
          created = CameraController(
            backCamera,
            ResolutionPreset.high,
            enableAudio: false,
          );

          await created.initialize();

          // Jika pengguna sudah pindah tab
          // atau membuka fullscreen,
          // controller ini tidak boleh dipakai.
          if (!_isCurrentCamera(token)) {
            await created.dispose();
            return;
          }

          setState(() {
            _cameraController = created;
            _error = null;
          });

          return;
        } catch (_) {
          if (created != null) {
            try {
              await created.dispose();
            } catch (_) {}
          }

          if (!_isCurrentCamera(token)) {
            return;
          }

          if (attempt < 2) {
            // Tunggu kamera Android siap lagi.
            await Future<void>.delayed(
              Duration(
                milliseconds: 400 + attempt * 250,
              ),
            );
          } else {
            if (mounted) {
              setState(() {
                _error = 'Kamera gagal dibuka. '
                    'Tekan Coba lagi.';
              });
            }
          }
        }
      }
    } catch (_) {
      if (_isCurrentCamera(token)) {
        setState(() {
          _error = 'Tidak dapat mengakses kamera. '
              'Periksa izin kamera.';
        });
      }
    }
  }

  // ==========================================
  // MENGHENTIKAN KAMERA DENGAN AMAN
  // ==========================================

  Future<void> _stopCamera() async {
    // Batalkan semua inisialisasi lama.
    _cameraToken++;

    // Jika sedang ada proses stop,
    // tunggu proses itu selesai.
    final ongoingStop = _stoppingCamera;

    if (ongoingStop != null) {
      await ongoingStop;
      return;
    }

    final request = _releaseCamera();
    _stoppingCamera = request;

    try {
      await request;
    } finally {
      if (identical(_stoppingCamera, request)) {
        _stoppingCamera = null;
      }

      // Jika tab kembali aktif selama
      // kamera lama sedang dilepas,
      // hidupkan kamera setelah aman.
      if (mounted && _shouldRunCamera) {
        _syncCamera();
      }
    }
  }

  // ==========================================
  // MELEPAS RESOURCE KAMERA
  // ==========================================

  Future<void> _releaseCamera() async {
    // Tunggu inisialisasi sebelumnya
    // berhenti dan membuang controllernya.
    final starting = _startingCamera;

    if (starting != null) {
      try {
        await starting;
      } catch (_) {}
    }

    final oldController = _cameraController;
    _cameraController = null;

    if (oldController != null) {
      if (mounted) {
        setState(() {});
      }

      try {
        await oldController.dispose();
      } catch (_) {}
    }
  }

  // ==========================================
  // PESAN
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
  // OCR
  // ==========================================

  Future<String> _recognizeImage(String path) async {
    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final image = InputImage.fromFilePath(path);

      final result = await recognizer.processImage(image);

      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  // ==========================================
  // HALAMAN HASIL OCR
  // ==========================================

  Future<void> _openOcrResult(String text) async {
    if (!mounted || text.trim().isEmpty) return;

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

      // Tunggu animasi penutupan halaman OCR.
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
  // PINDAI LANGSUNG
  // ==========================================

  Future<void> _captureInline() async {
    if (_busy || _suspended) return;

    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
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
      final photo = await controller.takePicture();

      final text = await _recognizeImage(
        photo.path,
      );

      if (!mounted) return;

      if (text.isEmpty) {
        _showMessage(
          'Tidak ada teks terdeteksi. '
          'Coba arahkan kamera lebih dekat.',
        );
      } else {
        await _openOcrResult(text);
      }
    } catch (_) {
      _showMessage(
        'Gagal memindai gambar. Coba lagi.',
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
  // MODE KAMERA PENUH
  // PERBAIKAN KAMERA TIDAK KEMBALI
  // ==========================================

  Future<void> _openFullCamera() async {
    if (_busy || _suspended) return;

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

    // 1. Lepaskan kamera kecil sepenuhnya.
    await _stopCamera();

    if (!mounted) return;

    final cameraRoute = MaterialPageRoute<String>(
      builder: (_) => const S04BCameraCapture(),
    );

    try {
      // 2. Buka kamera mode penuh.
      final scannedText = await Navigator.of(context).push<String>(
        cameraRoute,
      );

      // 3. Tunggu hingga route kamera
      // selesai ditutup, termasuk animasinya.
      await cameraRoute.completed;

      if (!mounted) return;

      // 4. Jika OCR berhasil,
      // tampilkan hasil pemindaian.
      if (scannedText != null && scannedText.trim().isNotEmpty) {
        final resultRoute = MaterialPageRoute<void>(
          builder: (_) => S05OcrReview(
            initialText: scannedText,
          ),
        );

        await Navigator.of(context).push<void>(
          resultRoute,
        );

        await resultRoute.completed;
      }
    } catch (_) {
      _showMessage(
        'Mode kamera penuh gagal dibuka.',
      );
    } finally {
      // 5. Beri kesempatan kamera native
      // menyelesaikan pelepasan resource.
      await Future<void>.delayed(
        const Duration(milliseconds: 350),
      );

      if (mounted) {
        setState(() {
          _suspended = false;
          _error = null;
        });

        // 6. Periksa kembali apakah tab Scan
        // masih terlihat.
        _tabVisible = TickerMode.of(context);

        // 7. Nyalakan kamera kecil kembali.
        _syncCamera();
      }
    }
  }

  // ==========================================
  // GALERI
  // ==========================================

  Future<void> _openGallery() async {
    if (_busy || _suspended) return;

    if (kIsWeb) {
      _showMessage(
        'OCR galeri tersedia di Android.',
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
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null || !mounted) return;

      final text = await _recognizeImage(
        image.path,
      );

      if (!mounted) return;

      if (text.isEmpty) {
        _showMessage(
          'Tidak ada teks ditemukan pada gambar.',
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
        'Gagal membaca gambar dari galeri.',
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
  // IMPORT DOKUMEN
  // ==========================================

  Future<void> _openImport() async {
    if (_busy || _suspended) return;

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

            // NAVIGASI BAWAH TETAP DIAM
            // DAN TIDAK MUNCUL DUA KALI.
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
          // LIVE CAMERA
          Positioned.fill(
            child: _buildLivePreview(),
          ),

          // OVERLAY TRANSPARAN
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.10,
                ),
              ),
            ),
          ),

          // GARIS EMPAT SUDUT
          Positioned(
            top: height * 0.19,
            bottom: height * 0.18,
            left: 34,
            right: 34,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScannerCornersPainter(),
              ),
            ),
          ),

          // HEADER
          Positioned(
            top: 17,
            left: 17,
            right: 17,
            child: _buildScannerHeader(),
          ),

          // PETUNJUK
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
  // KAMERA REAL-TIME
  // ==========================================

  Widget _buildLivePreview() {
    final controller = _cameraController;

    if (controller != null && controller.value.isInitialized) {
      final previewSize = controller.value.previewSize;

      if (previewSize != null) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        );
      }

      return CameraPreview(controller);
    }

    if (kIsWeb) {
      return const Center(
        child: Text(
          'Preview kamera tersedia di Android',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      );
    }

    // TOMBOL COBA LAGI
    if (_error != null && _shouldRunCamera) {
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

    // LOADING KAMERA
    if (_shouldRunCamera) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8095FF),
          strokeWidth: 2.5,
        ),
      );
    }

    return const SizedBox.expand();
  }

  // ==========================================
  // HEADER SCAN
  // ==========================================

  Widget _buildScannerHeader() {
    return Row(
      children: [
        _headerIcon(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Kembali ke Translate',
          onTap: () => openTab(context, 0),
        ),

        const Expanded(
          child: Text(
            'Scan teks',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // IKON PERBESAR
        _headerIcon(
          icon: Icons.open_in_full_rounded,
          tooltip: 'Perbesar kamera',
          onTap: _openFullCamera,
        ),
      ],
    );
  }

  Widget _headerIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        color: Colors.white,
        size: 23,
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(
          alpha: 0.35,
        ),
        minimumSize: const Size(48, 48),
      ),
    );
  }

  // ==========================================
  // GALERI - PINDAI - IMPOR
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
  // TOMBOL SAMPING
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

    // Batalkan seluruh proses start lama.
    _cameraToken++;

    // Tutup kamera jika masih aktif.
    final controller = _cameraController;
    _cameraController = null;

    if (controller != null) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }
}

// ==========================================
// GARIS SCANNER EMPAT SUDUT
// ==========================================

class _ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8095FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double length = 33;
    const double radius = 13;

    final double w = size.width;
    final double h = size.height;

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
