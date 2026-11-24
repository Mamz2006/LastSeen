import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// PREFERENSI BAHASA SELAMA APLIKASI BERJALAN
class ScanLanguageSettings {
  static String fromLanguage = 'English';
  static String toLanguage = 'Indonesia';
}

class S04BCameraCapture extends StatefulWidget {
  const S04BCameraCapture({super.key});

  @override
  State<S04BCameraCapture> createState() => _S04BCameraCaptureState();
}

enum _FrameHandle {
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _S04BCameraCaptureState extends State<S04BCameraCapture> {
  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);

  CameraController? _controller;

  bool _busy = false;
  bool _flashOn = false;
  bool _changingFlash = false;
  bool _showFrameHint = true;

  String? _error;

  // BAHASA
  late String _fromLanguage;
  late String _toLanguage;

  // ZOOM
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;
  double _zoomAtScaleStart = 1.0;

  // BINGKAI SCANNER
  Rect _scanFrame = const Rect.fromLTWH(
    0.09,
    0.33,
    0.82,
    0.32,
  );

  @override
  void initState() {
    super.initState();

    _fromLanguage = ScanLanguageSettings.fromLanguage;
    _toLanguage = ScanLanguageSettings.toLanguage;

    _initCamera();
  }

  // =====================================
  // INISIALISASI KAMERA
  // =====================================
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Kamera tidak ditemukan.';
        });
        return;
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await controller.initialize();
      } catch (_) {
        await controller.dispose();
        rethrow;
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      double minZoom = 1.0;
      double maxZoom = 1.0;

      try {
        minZoom = await controller.getMinZoomLevel();
        maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {
        // Zoom tidak tersedia pada kamera tertentu.
      }

      maxZoom = math.max(
        minZoom,
        math.min(maxZoom, 6.0),
      );

      try {
        await controller.setFlashMode(
          FlashMode.off,
        );
      } catch (_) {
        // Flash mungkin tidak didukung.
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = minZoom;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.description ?? 'Gagal membuka kamera.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Kamera tidak dapat dijalankan.';
      });
    }
  }

  // =====================================
  // MENYIMPAN PILIHAN BAHASA
  // =====================================
  void _saveLanguages(
    String source,
    String target,
  ) {
    if (source == target) return;

    setState(() {
      _fromLanguage = source;
      _toLanguage = target;

      ScanLanguageSettings.fromLanguage = source;
      ScanLanguageSettings.toLanguage = target;
    });
  }

  // =====================================
  // TUKAR BAHASA
  // =====================================
  void _swapLanguage() {
    _saveLanguages(
      _toLanguage,
      _fromLanguage,
    );
  }

  // =====================================
  // PILIH BAHASA MELALUI BOTTOM SHEET
  // =====================================
  Future<void> _showLanguageSheet() async {
    if (_busy) return;

    String tempFrom = _fromLanguage;
    String tempTo = _toLanguage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F9FD),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  22,
                  22,
                  28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4D9E8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 23),
                    const Center(
                      child: Text(
                        'Pilih Bahasa',
                        style: TextStyle(
                          color: navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Bahasa sumber',
                      style: TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _languageChoices(
                      selected: tempFrom,
                      onSelected: (language) {
                        setSheetState(() {
                          tempFrom = language;

                          if (tempFrom == tempTo) {
                            tempTo =
                                language == 'English' ? 'Indonesia' : 'English';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Terjemahkan ke',
                      style: TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _languageChoices(
                      selected: tempTo,
                      onSelected: (language) {
                        setSheetState(() {
                          tempTo = language;

                          if (tempFrom == tempTo) {
                            tempFrom =
                                language == 'English' ? 'Indonesia' : 'English';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          _saveLanguages(
                            tempFrom,
                            tempTo,
                          );
                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Simpan Bahasa',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =====================================
  // TOMBOL PILIH BAHASA
  // =====================================
  Widget _languageChoices({
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    const languages = [
      'English',
      'Indonesia',
    ];

    return Row(
      children: languages.map((language) {
        final active = selected == language;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onSelected(language),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 49,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE9EEFF) : Colors.white,
                  border: Border.all(
                    color: active ? primary : const Color(0xFFDDE3F0),
                    width: active ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  language,
                  style: TextStyle(
                    color: active ? primary : navy,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // =====================================
  // GLASS LANGUAGE BAR
  // =====================================
  Widget _glassLanguageBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.16,
            ),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.25,
              ),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              // KLIK UNTUK MEMILIH BAHASA
              Expanded(
                child: InkWell(
                  onTap: _showLanguageSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$_fromLanguage  →  $_toLanguage',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 3),

              // TUKAR BAHASA
              IconButton(
                tooltip: 'Tukar bahasa',
                onPressed: _swapLanguage,
                constraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // ZOOM
  // =====================================
  Future<void> _setZoom(double value) async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized || _busy) {
      return;
    }

    final newZoom = value
        .clamp(
          _minZoom,
          _maxZoom,
        )
        .toDouble();

    setState(() => _zoom = newZoom);

    try {
      await controller.setZoomLevel(newZoom);
    } catch (_) {
      // Zoom mungkin tidak didukung.
    }
  }

  // =====================================
  // FLASH
  // =====================================
  Future<void> _toggleFlash() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _changingFlash) {
      return;
    }

    setState(() => _changingFlash = true);

    try {
      final turnOn = !_flashOn;

      await controller.setFlashMode(
        turnOn ? FlashMode.torch : FlashMode.off,
      );

      if (!mounted) return;

      setState(() => _flashOn = turnOn);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Flash tidak tersedia pada kamera ini.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _changingFlash = false);
      }
    }
  }

  Future<void> _turnOffFlash() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized || !_flashOn) {
      return;
    }

    try {
      await controller.setFlashMode(FlashMode.off);
      _flashOn = false;
    } catch (_) {
      // Kamera akan dilepas saat keluar.
    }
  }

  // =====================================
  // TOMBOL KEMBALI
  // =====================================
  Future<void> _goBack() async {
    if (_busy || _changingFlash) return;

    await _turnOffFlash();

    if (!mounted) return;

    Navigator.pop(context);
  }

  // =====================================
  // HILANGKAN PETUNJUK BINGKAI
  // =====================================
  void _hideFrameHint() {
    if (!_showFrameHint || !mounted) return;

    setState(() {
      _showFrameHint = false;
    });
  }

  // =====================================
  // ATUR BINGKAI SCANNER
  // =====================================
  void _adjustFrame(
    Offset delta,
    Size screenSize,
    _FrameHandle handle,
  ) {
    final bounds = Rect.fromLTRB(
      16,
      screenSize.height * 0.17,
      screenSize.width - 16,
      screenSize.height * 0.77,
    );

    final current = Rect.fromLTRB(
      _scanFrame.left * screenSize.width,
      _scanFrame.top * screenSize.height,
      _scanFrame.right * screenSize.width,
      _scanFrame.bottom * screenSize.height,
    );

    double left = current.left;
    double top = current.top;
    double right = current.right;
    double bottom = current.bottom;

    const double minWidth = 130;
    const double minHeight = 110;

    if (handle == _FrameHandle.move) {
      final dx = delta.dx
          .clamp(
            bounds.left - left,
            bounds.right - right,
          )
          .toDouble();

      final dy = delta.dy
          .clamp(
            bounds.top - top,
            bounds.bottom - bottom,
          )
          .toDouble();

      left += dx;
      right += dx;
      top += dy;
      bottom += dy;
    } else {
      if (handle == _FrameHandle.topLeft || handle == _FrameHandle.bottomLeft) {
        left = (left + delta.dx)
            .clamp(
              bounds.left,
              right - minWidth,
            )
            .toDouble();
      }

      if (handle == _FrameHandle.topRight ||
          handle == _FrameHandle.bottomRight) {
        right = (right + delta.dx)
            .clamp(
              left + minWidth,
              bounds.right,
            )
            .toDouble();
      }

      if (handle == _FrameHandle.topLeft || handle == _FrameHandle.topRight) {
        top = (top + delta.dy)
            .clamp(
              bounds.top,
              bottom - minHeight,
            )
            .toDouble();
      }

      if (handle == _FrameHandle.bottomLeft ||
          handle == _FrameHandle.bottomRight) {
        bottom = (bottom + delta.dy)
            .clamp(
              top + minHeight,
              bounds.bottom,
            )
            .toDouble();
      }
    }

    setState(() {
      _scanFrame = Rect.fromLTRB(
        left / screenSize.width,
        top / screenSize.height,
        right / screenSize.width,
        bottom / screenSize.height,
      );
    });
  }

  // =====================================
  // MEMOTRET DAN MEMBACA OCR
  // =====================================
  Future<void> _capture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _changingFlash) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    String scannedText = '';

    try {
      final photo = await controller.takePicture();

      final result = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );

      scannedText = result.text.trim();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error = 'Gagal membaca teks. Coba lagi.';
      });
      return;
    } finally {
      await recognizer.close();
    }

    if (!mounted) return;

    if (scannedText.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Tidak ada teks terbaca. Dekatkan kamera.';
      });
      return;
    }

    await _turnOffFlash();

    if (!mounted) return;

    // KEMBALIKAN STRING AGAR KOMPATIBEL
    // DENGAN HALAMAN OCR REVIEW
    Navigator.pop(context, scannedText);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // =====================================
  // TAMPILAN KAMERA UTAMA
  // =====================================
  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final cameraReady = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: navy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return Stack(
            children: [
              // ==============================
              // PREVIEW KAMERA
              // ==============================
              if (cameraReady)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) {
                      _zoomAtScaleStart = _zoom;
                    },
                    onScaleUpdate: (details) {
                      if (details.pointerCount >= 2) {
                        _setZoom(
                          _zoomAtScaleStart * details.scale,
                        );
                      }
                    },
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.previewSize?.height ?? 1,
                        height: controller.value.previewSize?.width ?? 1,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                )
              else if (_error == null)
                const Center(
                  child: CircularProgressIndicator(
                    color: primary,
                  ),
                ),

              // ==============================
              // BINGKAI FLEKSIBEL
              // ==============================
              if (cameraReady)
                Positioned.fill(
                  child: _buildAdjustableFrame(screenSize),
                ),

              // ==============================
              // KONTROL ATAS DAN BAWAH
              // ==============================
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    18,
                  ),
                  child: Column(
                    children: [
                      // HEADER GLASS
                      Row(
                        children: [
                          _headerButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Kembali',
                            onPressed: _busy || _changingFlash ? null : _goBack,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _glassLanguageBar(),
                          ),
                          const SizedBox(width: 10),
                          _headerButton(
                            icon: _flashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            tooltip:
                                _flashOn ? 'Matikan Flash' : 'Nyalakan Flash',
                            backgroundColor:
                                _flashOn ? primary : Colors.black54,
                            onPressed: cameraReady && !_busy && !_changingFlash
                                ? _toggleFlash
                                : null,
                          ),
                        ],
                      ),

                      const Spacer(),

                      // PESAN ERROR
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE45E73,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],

                      // ==============================
                      // ZOOM TANPA IKON TAMBAHAN
                      // ==============================
                      if (cameraReady && _maxZoom > _minZoom)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 52,
                                child: Text(
                                  '${_zoom.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  min: _minZoom,
                                  max: _maxZoom,
                                  value: _zoom
                                      .clamp(
                                        _minZoom,
                                        _maxZoom,
                                      )
                                      .toDouble(),
                                  activeColor: primary,
                                  inactiveColor: Colors.white38,
                                  onChanged: _busy ? null : _setZoom,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // ==============================
                      // TOMBOL PINDAI
                      // ==============================
                      GestureDetector(
                        onTap: cameraReady && !_busy && !_changingFlash
                            ? _capture
                            : null,
                        child: Container(
                          width: 84,
                          height: 84,
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
                              color: primary,
                              shape: BoxShape.circle,
                            ),
                            child: _busy
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        _busy ? 'Membaca teks...' : 'Ketuk untuk memindai',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =====================================
  // BINGKAI SCANNER YANG BISA DIGESER
  // =====================================
  Widget _buildAdjustableFrame(
    Size screenSize,
  ) {
    final frame = Rect.fromLTRB(
      _scanFrame.left * screenSize.width,
      _scanFrame.top * screenSize.height,
      _scanFrame.right * screenSize.width,
      _scanFrame.bottom * screenSize.height,
    );

    return Stack(
      children: [
        Positioned.fromRect(
          rect: frame,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (_) => _hideFrameHint(),
            onTapDown: (_) => _hideFrameHint(),
            onPanUpdate: (details) {
              _adjustFrame(
                details.delta,
                screenSize,
                _FrameHandle.move,
              );
            },
            child: CustomPaint(
              painter: _CameraCornerPainter(),
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showFrameHint ? 1.0 : 0.0,
                  duration: const Duration(
                    milliseconds: 220,
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Geser bingkai • Tarik sudut',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _cornerHandle(
          x: frame.left,
          y: frame.top,
          screenSize: screenSize,
          handle: _FrameHandle.topLeft,
        ),
        _cornerHandle(
          x: frame.right,
          y: frame.top,
          screenSize: screenSize,
          handle: _FrameHandle.topRight,
        ),
        _cornerHandle(
          x: frame.left,
          y: frame.bottom,
          screenSize: screenSize,
          handle: _FrameHandle.bottomLeft,
        ),
        _cornerHandle(
          x: frame.right,
          y: frame.bottom,
          screenSize: screenSize,
          handle: _FrameHandle.bottomRight,
        ),
      ],
    );
  }

  // =====================================
  // AREA SENTUH SUDUT TRANSPARAN
  // =====================================
  Widget _cornerHandle({
    required double x,
    required double y,
    required Size screenSize,
    required _FrameHandle handle,
  }) {
    return Positioned(
      left: x - 24,
      top: y - 24,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (_) => _hideFrameHint(),
        onTapDown: (_) => _hideFrameHint(),
        onPanUpdate: (details) {
          _adjustFrame(
            details.delta,
            screenSize,
            handle,
          );
        },
        child: const SizedBox(
          width: 48,
          height: 48,
        ),
      ),
    );
  }

  // =====================================
  // TOMBOL KEMBALI DAN FLASH
  // =====================================
  Widget _headerButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color backgroundColor = Colors.black54,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        disabledBackgroundColor: Colors.black26,
        minimumSize: const Size(46, 46),
      ),
      icon: Icon(
        icon,
        color: Colors.white,
        size: 23,
      ),
    );
  }
}

// =====================================
// GARIS SCANNER EMPAT SUDUT
// =====================================
class _CameraCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8095FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double length = 34;
    const double radius = 12;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(length, 0)
      ..moveTo(w - length, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(w, 0, w, radius)
      ..lineTo(w, length)
      ..moveTo(0, h - length)
      ..lineTo(0, h - radius)
      ..quadraticBezierTo(0, h, radius, h)
      ..lineTo(length, h)
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
