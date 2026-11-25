import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ==========================================
// LASTSEEN - FULLSCREEN CAMERA
// GLASS UI + GLASS ZOOM + SAFE EXIT
// ==========================================

class S04BCameraCapture extends StatefulWidget {
  const S04BCameraCapture({super.key});

  @override
  State<S04BCameraCapture> createState() => _S04BCameraCaptureState();
}

enum _FrameCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _S04BCameraCaptureState extends State<S04BCameraCapture> {
  // ========================================
  // WARNA
  // ========================================

  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);
  static const Color glassColor = Color(0xFF454B61);

  // ========================================
  // CAMERA CONTROLLER
  // ========================================

  CameraController? _controller;

  bool _initializing = false;
  bool _busy = false;
  bool _flashOn = false;
  bool _changingFlash = false;
  bool _closing = false;
  bool _showHint = true;

  String? _error;

  // ========================================
  // BAHASA
  // ========================================

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Indonesia';

  // ========================================
  // ZOOM
  // ========================================

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;
  double _pinchStartZoom = 1.0;

  // ========================================
  // POSISI BINGKAI
  // ========================================

  double _left = 0.09;
  double _top = 0.34;
  double _right = 0.91;
  double _bottom = 0.69;

  bool get _ready =>
      !_closing && _controller != null && _controller!.value.isInitialized;

  @override
  void initState() {
    super.initState();

    unawaited(_initializeCamera());
  }

  // ========================================
  // MEMBUKA KAMERA
  // PREVIEW DITAMPILKAN SEBELUM SETUP ZOOM
  // ========================================

  Future<void> _initializeCamera() async {
    if (_initializing || _closing || _controller != null) {
      return;
    }

    _initializing = true;

    CameraController? candidate;

    try {
      final cameras = await availableCameras();

      if (!mounted || _closing) return;

      if (cameras.isEmpty) {
        throw StateError('Kamera tidak ditemukan.');
      }

      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final activeCamera = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      candidate = activeCamera;

      // Inisialisasi kamera.
      await activeCamera.initialize();

      if (!mounted || _closing) {
        await activeCamera.dispose();
        return;
      }

      // Tampilkan preview segera setelah siap.
      setState(() {
        _controller = activeCamera;
        _error = null;
      });

      // Siapkan batas zoom setelah preview tampil.
      try {
        final zoomLimits = await Future.wait<double>([
          activeCamera.getMinZoomLevel(),
          activeCamera.getMaxZoomLevel(),
        ]);

        if (!mounted || _closing || !identical(_controller, activeCamera)) {
          return;
        }

        final minZoom = zoomLimits[0];
        final maxZoom = zoomLimits[1];

        final initialZoom = 1.0.clamp(minZoom, maxZoom).toDouble();

        setState(() {
          _minZoom = minZoom;
          _maxZoom = maxZoom;
          _zoom = initialZoom;
        });

        if (initialZoom != 1.0) {
          await activeCamera.setZoomLevel(
            initialZoom,
          );
        }
      } catch (_) {
        // Preview tetap berjalan jika
        // pengaturan zoom gagal.
      }
    } on CameraException catch (e) {
      if (candidate != null && !identical(_controller, candidate)) {
        try {
          await candidate.dispose();
        } catch (_) {}
      }

      if (mounted && !_closing) {
        setState(() {
          _error = e.description ?? 'Kamera gagal dibuka. Coba lagi.';
        });
      }
    } catch (_) {
      if (candidate != null && !identical(_controller, candidate)) {
        try {
          await candidate.dispose();
        } catch (_) {}
      }

      if (mounted && !_closing) {
        setState(() {
          _error = 'Kamera gagal dibuka. Periksa izin kamera.';
        });
      }
    } finally {
      _initializing = false;
    }
  }

  // ========================================
  // TUKAR BAHASA
  // ========================================

  void _swapLanguage() {
    if (_busy || _closing) return;

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
    if (_busy || _closing) return;

    setState(() {
      _sourceLanguage = source;
      _targetLanguage = target;
    });
  }

  // ========================================
  // MODAL PILIH BAHASA
  // ========================================

  void _showLanguagePicker() {
    if (_busy || _closing) return;

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
                  'Tentukan arah bahasa yang digunakan.',
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

  // ========================================
  // PILIHAN BAHASA
  // ========================================

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

  // ========================================
  // PEMILIH BAHASA BERGAYA GLASS
  // ========================================

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
              color: Colors.white.withValues(
                alpha: 0.28,
              ),
              width: 1,
            ),
          ),
          child: Row(
            children: [
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

              // Tombol tukar tanpa garis pemisah.
              IconButton(
                tooltip: 'Tukar bahasa',
                onPressed: _busy || _closing ? null : _swapLanguage,
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

  // ========================================
  // TOMBOL LINGKARAN BERGAYA GLASS
  // ========================================

  Widget _glassCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 15,
            sigmaY: 15,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: glassColor.withValues(
                    alpha: 0.43,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.28,
                    ),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: onTap == null ? Colors.white54 : Colors.white,
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

  // ========================================
  // HEADER KAMERA FULLSCREEN
  // ========================================

  Widget _buildHeader() {
    return Row(
      children: [
        // Kembali.
        _glassCircleButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Kembali',
          onTap: _busy || _closing
              ? null
              : () {
                  unawaited(_close(null));
                },
        ),

        const SizedBox(width: 9),

        // Pilihan bahasa.
        Expanded(
          child: _buildGlassLanguagePicker(),
        ),

        const SizedBox(width: 9),

        // Flash.
        _glassCircleButton(
          icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          tooltip: _flashOn ? 'Matikan flash' : 'Nyalakan flash',
          onTap: _ready && !_busy && !_changingFlash && !_closing
              ? () {
                  unawaited(_toggleFlash());
                }
              : null,
        ),
      ],
    );
  }

  // ========================================
  // FLASH ON / OFF
  // ========================================

  Future<void> _toggleFlash() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _changingFlash ||
        _closing) {
      return;
    }

    setState(() {
      _changingFlash = true;
    });

    try {
      final turnOn = !_flashOn;

      await controller.setFlashMode(
        turnOn ? FlashMode.torch : FlashMode.off,
      );

      if (!mounted || _closing) return;

      setState(() {
        _flashOn = turnOn;
      });
    } catch (_) {
      if (mounted && !_closing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Flash tidak tersedia pada kamera ini.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && !_closing) {
        setState(() {
          _changingFlash = false;
        });
      }
    }
  }

  // ========================================
  // ZOOM CAMERA
  // ========================================

  void _changeZoom(double value) {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _closing) {
      return;
    }

    final next = value.clamp(_minZoom, _maxZoom).toDouble();

    setState(() {
      _zoom = next;
    });

    unawaited(
      controller.setZoomLevel(next).catchError(
        (Object error) {
          // Abaikan perubahan zoom jika
          // kamera sudah ditutup.
        },
      ),
    );
  }

  // ========================================
  // SAFE EXIT:
  // HILANGKAN PREVIEW SEBELUM DISPOSE
  // ========================================

  Future<void> _releaseCamera() async {
    final controller = _controller;

    // Hilangkan CameraPreview dari widget tree.
    if (mounted) {
      setState(() {
        _controller = null;
      });

      // Tunggu frame tanpa preview selesai.
      await WidgetsBinding.instance.endOfFrame;
    } else {
      _controller = null;
    }

    // Baru lepaskan resource native kamera.
    if (controller != null) {
      try {
        await controller.setFlashMode(
          FlashMode.off,
        );
      } catch (_) {}

      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  // ========================================
  // TUTUP FULLSCREEN
  // ========================================

  Future<void> _close(String? result) async {
    if (_closing) return;

    _closing = true;

    await _releaseCamera();

    if (!mounted) return;

    Navigator.of(context).pop(result);
  }

  // ========================================
  // OCR / PINDAI
  // ========================================

  Future<void> _capture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _changingFlash ||
        _closing) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final photo = await controller.takePicture();

      final result = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );

      final scannedText = result.text.trim();

      if (!mounted) return;

      if (scannedText.isEmpty) {
        setState(() {
          _error = 'Tidak ada teks terdeteksi. '
              'Arahkan kamera lebih dekat.';
        });
      } else {
        await _close(scannedText);
      }
    } catch (_) {
      if (mounted && !_closing) {
        setState(() {
          _error = 'Gagal membaca teks. Coba lagi.';
        });
      }
    } finally {
      await recognizer.close();

      if (mounted && !_closing) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ========================================
  // GESER SELURUH BINGKAI
  // ========================================

  void _moveFrame(Offset delta, Size size) {
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;

    final frameWidth = _right - _left;
    final frameHeight = _bottom - _top;

    final newLeft = (_left + dx).clamp(0.05, 0.95 - frameWidth).toDouble();

    final newTop = (_top + dy).clamp(0.10, 0.90 - frameHeight).toDouble();

    setState(() {
      _left = newLeft;
      _top = newTop;
      _right = newLeft + frameWidth;
      _bottom = newTop + frameHeight;
      _showHint = false;
    });
  }

  // ========================================
  // TARIK SUDUT BINGKAI
  // ========================================

  void _resizeFrame(
    _FrameCorner corner,
    Offset delta,
    Size size,
  ) {
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;

    setState(() {
      switch (corner) {
        case _FrameCorner.topLeft:
          _left = (_left + dx).clamp(0.05, _right - 0.26).toDouble();

          _top = (_top + dy).clamp(0.10, _bottom - 0.18).toDouble();
          break;

        case _FrameCorner.topRight:
          _right = (_right + dx).clamp(_left + 0.26, 0.95).toDouble();

          _top = (_top + dy).clamp(0.10, _bottom - 0.18).toDouble();
          break;

        case _FrameCorner.bottomLeft:
          _left = (_left + dx).clamp(0.05, _right - 0.26).toDouble();

          _bottom = (_bottom + dy).clamp(_top + 0.18, 0.90).toDouble();
          break;

        case _FrameCorner.bottomRight:
          _right = (_right + dx).clamp(_left + 0.26, 0.95).toDouble();

          _bottom = (_bottom + dy).clamp(_top + 0.18, 0.90).toDouble();
          break;
      }

      _showHint = false;
    });
  }

  // ========================================
  // HANDLE SENTUH SUDUT
  // ========================================

  Widget _cornerHandle({
    required Offset position,
    required Size screenSize,
    required _FrameCorner corner,
  }) {
    return Positioned(
      left: position.dx - 28,
      top: position.dy - 28,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) {
          _resizeFrame(
            corner,
            details.delta,
            screenSize,
          );
        },
        child: const SizedBox(
          width: 56,
          height: 56,
        ),
      ),
    );
  }

  // ========================================
  // BINGKAI SCAN YANG BISA DIGESER
  // ========================================

  Widget _buildAdjustableFrame() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          final left = _left * screenSize.width;
          final top = _top * screenSize.height;
          final right = _right * screenSize.width;
          final bottom = _bottom * screenSize.height;

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: right - left,
                height: bottom - top,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) {
                    _moveFrame(
                      details.delta,
                      screenSize,
                    );
                  },
                  child: CustomPaint(
                    painter: _CameraCornersPainter(),
                  ),
                ),
              ),
              _cornerHandle(
                position: Offset(left, top),
                screenSize: screenSize,
                corner: _FrameCorner.topLeft,
              ),
              _cornerHandle(
                position: Offset(right, top),
                screenSize: screenSize,
                corner: _FrameCorner.topRight,
              ),
              _cornerHandle(
                position: Offset(left, bottom),
                screenSize: screenSize,
                corner: _FrameCorner.bottomLeft,
              ),
              _cornerHandle(
                position: Offset(right, bottom),
                screenSize: screenSize,
                corner: _FrameCorner.bottomRight,
              ),
              if (_showHint)
                Positioned(
                  top: (top + bottom) / 2 - 18,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Geser bingkai • Tarik sudut',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ========================================
  // PREVIEW KAMERA FULLSCREEN
  // ========================================

  Widget _buildPreview() {
    // Jangan tampilkan preview saat menutup.
    if (_closing) {
      return const ColoredBox(
        color: navy,
      );
    }

    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return ColoredBox(
        color: navy,
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator(
                  color: primary,
                )
              : const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
        ),
      );
    }

    final previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(controller),
      ),
    );
  }

  // ========================================
  // ZOOM BAR GLASSMORPHISM
  // BAGIAN YANG BARU DIPERBARUI
  // ========================================

  Widget _buildZoom() {
    final zoomReady = _ready && !_busy && !_closing && _maxZoom > _minZoom;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            // Warna sama dengan glass header.
            color: glassColor.withValues(
              alpha: 0.43,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.28,
              ),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // ANGKA ZOOM
              SizedBox(
                width: 58,
                child: Text(
                  '${_zoom.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // SLIDER ZOOM
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primary,
                    inactiveTrackColor: Colors.white.withValues(
                      alpha: 0.25,
                    ),
                    thumbColor: primary,
                    overlayColor: primary.withValues(
                      alpha: 0.15,
                    ),
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 11,
                    ),
                  ),
                  child: Slider(
                    min: _minZoom,
                    max: zoomReady ? _maxZoom : _minZoom + 1,
                    value: zoomReady
                        ? _zoom
                            .clamp(
                              _minZoom,
                              _maxZoom,
                            )
                            .toDouble()
                        : _minZoom,
                    onChanged: zoomReady ? _changeZoom : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // TOMBOL PINDAI
  // ========================================

  Widget _buildCaptureButton() {
    return Column(
      children: [
        InkWell(
          onTap: _ready && !_busy && !_closing
              ? () {
                  unawaited(_capture());
                }
              : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 88,
            height: 88,
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
                      padding: EdgeInsets.all(21),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 31,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _busy ? 'Membaca teks...' : 'Ketuk untuk memindai',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ========================================
  // HALAMAN KAMERA FULLSCREEN
  // ========================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy && !_closing) {
          unawaited(_close(null));
        }
      },
      child: Scaffold(
        backgroundColor: navy,
        body: Stack(
          children: [
            // KAMERA
            Positioned.fill(
              child: _buildPreview(),
            ),

            // PINCH ZOOM
            if (!_closing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onScaleStart: (_) {
                    _pinchStartZoom = _zoom;
                  },
                  onScaleUpdate: (details) {
                    if (details.pointerCount >= 2) {
                      _changeZoom(
                        _pinchStartZoom * details.scale,
                      );
                    }
                  },
                  child: const SizedBox.expand(),
                ),
              ),

            // BINGKAI SCAN
            if (_ready) _buildAdjustableFrame(),

            // KONTROL KAMERA
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  22,
                ),
                child: Column(
                  children: [
                    // GLASS HEADER
                    _buildHeader(),

                    const Spacer(),

                    // ERROR MESSAGE
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBC4057),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // GLASS ZOOM BAR
                    _buildZoom(),

                    const SizedBox(height: 24),

                    // TOMBOL PINDAI
                    _buildCaptureButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // MEMBERSIHKAN CAMERA CONTROLLER
  // ========================================

  @override
  void dispose() {
    _closing = true;

    final controller = _controller;
    _controller = null;

    if (controller != null) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }
}

// ==========================================
// GARIS EMPAT SUDUT SCANNER
// ==========================================

class _CameraCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8095FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double length = 34;
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
