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

  final ImagePicker _imagePicker = ImagePicker();

  int _cameraToken = 0;

  bool _tabVisible = false;
  bool _appVisible = true;
  bool _suspended = false;
  bool _busy = false;

  String? _error;

  bool get _shouldRunCamera =>
      _tabVisible && _appVisible && !_suspended && !kIsWeb;

  // ==========================================
  // LIFECYCLE
  // ==========================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // Kamera hanya aktif ketika tab Scan terlihat.
  // Ini penting karena MainTabShell menyimpan
  // halaman lain di dalam Stack.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final visible = TickerMode.of(context);

    if (_tabVisible != visible) {
      _tabVisible = visible;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncCamera();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  // ==========================================
  // MEMULAI / MENGHENTIKAN KAMERA
  // ==========================================

  void _syncCamera() {
    if (!mounted || kIsWeb) return;

    if (_shouldRunCamera) {
      if (_cameraController == null && _startingCamera == null) {
        final token = ++_cameraToken;
        _startingCamera = _startCamera(token);
      }
    } else {
      if (_cameraController != null || _startingCamera != null) {
        _stopCamera();
      }
    }
  }

  Future<void> _startCamera(int token) async {
    CameraController? created;

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw StateError('Kamera tidak ditemukan.');
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      created = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await created.initialize();

      // Jika pengguna sudah pindah tab atau
      // membuka kamera fullscreen, jangan
      // mengambil alih kamera lagi.
      if (!mounted || token != _cameraToken || !_shouldRunCamera) {
        await created.dispose();
        return;
      }

      setState(() {
        _cameraController = created;
        _error = null;
      });
    } catch (_) {
      if (created != null) {
        try {
          await created.dispose();
        } catch (_) {}
      }

      if (mounted && token == _cameraToken && _shouldRunCamera) {
        setState(() {
          _error = 'Kamera tidak dapat dibuka. Periksa izin kamera.';
        });
      }
    } finally {
      if (token == _cameraToken) {
        _startingCamera = null;
      }
    }
  }

  Future<void> _stopCamera() async {
    // Batalkan proses inisialisasi yang lama.
    _cameraToken++;

    final pending = _startingCamera;

    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }

    _startingCamera = null;

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

    // Jika tab aktif lagi sebelum proses stop
    // selesai, kamera boleh dimulai ulang.
    if (mounted && _shouldRunCamera) {
      _syncCamera();
    }
  }

  // ==========================================
  // OCR FOTO
  // ==========================================

  Future<String> _recognizeImage(String path) async {
    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final inputImage = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(inputImage);
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ==========================================
  // TAMPILKAN HASIL OCR
  // ==========================================

  Future<void> _openOcrResult(String text) async {
    if (!mounted || text.trim().isEmpty) return;

    setState(() {
      _suspended = true;
    });

    await _stopCamera();

    if (!mounted) return;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => S05OcrReview(
            initialText: text,
          ),
        ),
      );
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
  // PINDAI LANGSUNG DARI HALAMAN SCAN
  // ==========================================

  Future<void> _captureInline() async {
    if (_busy || _suspended) return;

    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      _showMessage('Kamera sedang disiapkan.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final photo = await controller.takePicture();

      final text = await _recognizeImage(photo.path);

      if (!mounted) return;

      if (text.isEmpty) {
        _showMessage(
          'Tidak ada teks terdeteksi. Coba arahkan kamera lebih dekat.',
        );
      } else {
        await _openOcrResult(text);
      }
    } catch (_) {
      _showMessage(
        'Gagal memindai foto. Coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // ==========================================
  // TOMBOL PERBESAR KAMERA
  // ==========================================

  Future<void> _openFullCamera() async {
    if (_busy || _suspended) return;

    if (kIsWeb) {
      _showMessage(
        'Gunakan aplikasi Android untuk membuka kamera.',
      );
      return;
    }

    setState(() {
      _suspended = true;
      _error = null;
    });

    // WAJIB: lepaskan kamera kecil dulu
    // agar kamera fullscreen tidak bentrok.
    await _stopCamera();

    if (!mounted) return;

    try {
      final scannedText = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const S04BCameraCapture(),
        ),
      );

      if (!mounted) return;

      // Mode kamera lama mengembalikan
      // hasil OCR melalui Navigator.pop.
      if (scannedText != null && scannedText.trim().isNotEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => S05OcrReview(
              initialText: scannedText,
            ),
          ),
        );
      }
    } catch (_) {
      _showMessage(
        'Mode kamera penuh gagal dibuka.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _suspended = false;
        });

        // Kamera kecil aktif lagi
        // setelah kembali ke halaman Scan.
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
        'OCR galeri tersedia pada aplikasi Android.',
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

      final text = await _recognizeImage(image.path);

      if (!mounted) return;

      if (text.isEmpty) {
        _showMessage(
          'Tidak ada teks ditemukan pada gambar.',
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => S05OcrReview(
              initialText: text,
            ),
          ),
        );
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
  // IMPOR DOKUMEN
  // ==========================================

  Future<void> _openImport() async {
    if (_busy || _suspended) return;

    setState(() {
      _suspended = true;
    });

    await _stopCamera();

    if (!mounted) return;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const S06ImportDocument(),
        ),
      );
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
  // UI HALAMAN SCAN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    final scanHeight = (screenHeight * 0.60).clamp(360.0, 600.0).toDouble();

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

            // Navigasi bawah hanya ditampilkan
            // oleh MainTabShell ketika berada
            // dalam navigasi utama.
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
  // PANEL SCANNER DENGAN LIVE PREVIEW
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

          // Lapisan tipis agar ikon terlihat
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.10,
                ),
              ),
            ),
          ),

          // EMPAT GARIS SUDUT
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
  // TAMPILAN KAMERA LANGSUNG
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

    if (_error != null && _shouldRunCamera) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() => _error = null);
            _syncCamera();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba lagi'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF8095FF),
        strokeWidth: 2.5,
      ),
    );
  }

  // ==========================================
  // HEADER: BACK - JUDUL - PERBESAR
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

        // IKON INFO DIGANTI IKON PERBESAR
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

  Widget _buildCameraButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(60),
      onTap: _busy ? null : _captureInline,
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

  Widget _sideAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _cameraToken++;

    // Jangan biarkan kamera tetap aktif
    // setelah halaman dibuang.
    final controller = _cameraController;
    _cameraController = null;
    controller?.dispose();

    super.dispose();
  }
}

// ==========================================
// GARIS EMPAT SUDUT SCANNER
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
