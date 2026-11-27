import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// LASTSEEN - FULLSCREEN CAMERA
// MINI GLASS ZOOM + SAFE CAMERA EXIT + OCR CROP

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
  // WARNA
  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);
  static const Color glassColor = Color(0xFF454B61);

  // CAMERA
  CameraController? _controller;
  Future<void>? _initializationFuture;

  bool _busy = false;
  bool _flashOn = false;
  bool _changingFlash = false;
  bool _closing = false;
  bool _showHint = true;

  String? _error;

  // BAHASA
  String _sourceLanguage = 'English';
  String _targetLanguage = 'Indonesia';

  // ZOOM
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;

  bool _zoomPanelOpen = false;
  bool _zoomDragging = false;

  Timer? _zoomHideTimer;

  final Set<Future<void>> _zoomOperations = {};

  // BINGKAI SCAN
  final GlobalKey _previewKey = GlobalKey();

  double _left = 0.09;
  double _top = 0.34;
  double _right = 0.91;
  double _bottom = 0.69;

  bool get _ready =>
      mounted &&
      !_closing &&
      _controller != null &&
      _controller!.value.isInitialized;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeCamera();
  }

  // ========================================
  // MEMBUKA KAMERA
  // ========================================

  Future<void> _initializeCamera() async {
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

      candidate = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await candidate.initialize();

      if (!mounted || _closing) {
        await candidate.dispose();
        return;
      }

      setState(() {
        _controller = candidate;
        _error = null;
      });

      try {
        final limits = await Future.wait<double>([
          candidate.getMinZoomLevel(),
          candidate.getMaxZoomLevel(),
        ]);

        if (!mounted || _closing || !identical(_controller, candidate)) {
          return;
        }

        final minZoom = limits[0];
        final maxZoom = limits[1];

        final initialZoom = 1.0.clamp(minZoom, maxZoom).toDouble();

        setState(() {
          _minZoom = minZoom;
          _maxZoom = maxZoom;
          _zoom = initialZoom;
        });

        if (initialZoom != 1.0) {
          await candidate.setZoomLevel(initialZoom);
        }
      } catch (_) {
        // Preview tetap berjalan jika zoom tidak tersedia.
      }
    } on CameraException catch (e) {
      if (candidate != null && !identical(_controller, candidate)) {
        try {
          await candidate.dispose();
        } catch (_) {}
      }

      if (mounted && !_closing) {
        setState(() {
          _error = e.description ?? 'Kamera gagal dibuka.';
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
          _error = 'Tidak dapat membuka kamera. Periksa izin kamera.';
        });
      }
    }
  }

  // ========================================
  // MINI ZOOM GLASS
  // ========================================

  void _toggleZoomPanel() {
    if (!_ready || _busy) return;

    _zoomHideTimer?.cancel();

    setState(() {
      _zoomPanelOpen = !_zoomPanelOpen;
      _zoomDragging = false;
    });

    if (_zoomPanelOpen) {
      _scheduleZoomHide();
    }
  }

  // ========================================
  // TUTUP ZOOM OTOMATIS
  // ========================================

  void _scheduleZoomHide() {
    _zoomHideTimer?.cancel();

    if (!_zoomPanelOpen || _zoomDragging || _closing) {
      return;
    }

    _zoomHideTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (!mounted || _closing || _zoomDragging || !_zoomPanelOpen) {
          return;
        }

        setState(() {
          _zoomPanelOpen = false;
        });
      },
    );
  }

  // ========================================
  // ZOOM SLIDER
  // ========================================

  void _changeZoom(double value) {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _closing ||
        _maxZoom <= _minZoom) {
      return;
    }

    final next = value.clamp(_minZoom, _maxZoom).toDouble();

    setState(() {
      _zoom = next;
    });

    final operation = controller.setZoomLevel(next).catchError((Object _) {});

    _zoomOperations.add(operation);

    unawaited(
      operation.whenComplete(() {
        _zoomOperations.remove(operation);
      }),
    );
  }

  String _formatZoom(double zoom) {
    return zoom.toStringAsFixed(1);
  }

  // ========================================
  // TOMBOL MINI ZOOM
  // ========================================

  Widget _buildMiniZoomButton() {
    return ClipRRect(
      key: const ValueKey('miniZoom'),
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _ready ? _toggleZoomPanel : null,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              decoration: BoxDecoration(
                color: glassColor.withValues(alpha: 0.43),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${_formatZoom(_zoom)}×',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

  // ========================================
  // SLIDER ZOOM GLASS
  // ========================================

  Widget _buildZoomSlider() {
    final zoomReady = _ready && !_busy && _maxZoom > _minZoom;

    return ClipRRect(
      key: const ValueKey('zoomSlider'),
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: glassColor.withValues(alpha: 0.43),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 6),
              SizedBox(
                width: 52,
                child: Text(
                  '${_formatZoom(_zoom)}×',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                    thumbColor: primary,
                    overlayColor: primary.withValues(alpha: 0.15),
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                  ),
                  child: Slider(
                    min: _minZoom,
                    max: zoomReady ? _maxZoom : _minZoom + 1.0,
                    value: zoomReady
                        ? _zoom.clamp(_minZoom, _maxZoom).toDouble()
                        : _minZoom,
                    onChangeStart: zoomReady
                        ? (_) {
                            _zoomHideTimer?.cancel();
                            _zoomDragging = true;
                          }
                        : null,
                    onChanged: zoomReady ? _changeZoom : null,
                    onChangeEnd: zoomReady
                        ? (_) {
                            _zoomDragging = false;
                            _scheduleZoomHide();
                          }
                        : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tutup zoom',
                onPressed: _toggleZoomPanel,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // TAMPILAN ZOOM
  // ========================================

  Widget _buildZoomControl() {
    return SizedBox(
      height: 54,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _zoomPanelOpen
              ? SizedBox(
                  key: const ValueKey('openZoom'),
                  width: double.infinity,
                  child: _buildZoomSlider(),
                )
              : _buildMiniZoomButton(),
        ),
      ),
    );
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

  void _changeLanguage(
    String source,
    String target,
  ) {
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
                      'English',
                      'Indonesia',
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
                      'Indonesia',
                      'English',
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
  // GLASS LANGUAGE PICKER
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
            color: glassColor.withValues(alpha: 0.43),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
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
  // TOMBOL GLASS BULAT
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
                  color: glassColor.withValues(alpha: 0.43),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
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
  // HEADER FULLSCREEN
  // ========================================

  Widget _buildHeader() {
    return Row(
      children: [
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
        Expanded(
          child: _buildGlassLanguagePicker(),
        ),
        const SizedBox(width: 9),
        _glassCircleButton(
          icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          tooltip: _flashOn ? 'Matikan flash' : 'Nyalakan flash',
          onTap: _ready && !_busy && !_changingFlash
              ? () {
                  unawaited(_toggleFlash());
                }
              : null,
        ),
      ],
    );
  }

  // ========================================
  // FLASH
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
  // MELEPAS KAMERA DENGAN AMAN
  // ========================================

  Future<void> _releaseCamera() async {
    _zoomHideTimer?.cancel();

    _zoomDragging = false;
    _zoomPanelOpen = false;

    final controller = _controller;

    if (mounted) {
      setState(() {
        _controller = null;
      });

      await WidgetsBinding.instance.endOfFrame;
    } else {
      _controller = null;
    }

    final initialization = _initializationFuture;

    if (initialization != null) {
      try {
        await initialization;
      } catch (_) {}
    }

    final operations = _zoomOperations.toList();

    if (operations.isNotEmpty) {
      try {
        await Future.wait(operations);
      } catch (_) {}
    }

    if (controller != null) {
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  // ========================================
  // KEMBALI KE REAL-TIME CAMERA
  // ========================================

  Future<void> _close(String? result) async {
    if (_closing) return;

    _closing = true;

    await _releaseCamera();

    if (!mounted) return;

    Navigator.of(context).pop(result);
  }

  // ========================================
  // CROP GAMBAR SESUAI BINGKAI SCAN
  // ========================================

  Future<File> _cropScanFrame(
    XFile photo,
    Rect frame,
    Size viewport,
    Size preview,
    bool mirrored,
  ) async {
    final bytes = await photo.readAsBytes();

    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw StateError('Gambar tidak dapat dibaca.');
    }

    // Sesuaikan orientasi foto berdasarkan EXIF.
    final image = img.bakeOrientation(decodedImage);

    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    if (viewport.isEmpty || preview.isEmpty) {
      throw StateError('Ukuran preview tidak valid.');
    }

    // Hitung area preview dengan BoxFit.cover.
    final scale = math.max(
      viewport.width / preview.width,
      viewport.height / preview.height,
    );

    final renderedWidth = preview.width * scale;
    final renderedHeight = preview.height * scale;

    final offsetX = (renderedWidth - viewport.width) / 2;

    final offsetY = (renderedHeight - viewport.height) / 2;

    // Ubah koordinat layar menjadi koordinat relatif preview.
    double normalizedLeft = (frame.left + offsetX) / renderedWidth;

    double normalizedRight = (frame.right + offsetX) / renderedWidth;

    final normalizedTop = (frame.top + offsetY) / renderedHeight;

    final normalizedBottom = (frame.bottom + offsetY) / renderedHeight;

    // Penyesuaian jika menggunakan kamera depan.
    if (mirrored) {
      final previousLeft = normalizedLeft;

      normalizedLeft = 1.0 - normalizedRight;
      normalizedRight = 1.0 - previousLeft;
    }

    // Sesuaikan perbedaan rasio preview dan foto.
    final previewRatio = preview.width / preview.height;
    final imageRatio = imageWidth / imageHeight;

    double visibleWidth = imageWidth;
    double visibleHeight = imageHeight;

    double imageOffsetX = 0;
    double imageOffsetY = 0;

    if (imageRatio > previewRatio) {
      visibleWidth = imageHeight * previewRatio;

      imageOffsetX = (imageWidth - visibleWidth) / 2;
    } else if (imageRatio < previewRatio) {
      visibleHeight = imageWidth / previewRatio;

      imageOffsetY = (imageHeight - visibleHeight) / 2;
    }

    // Konversi koordinat menjadi piksel foto.
    final cropLeft = (imageOffsetX + normalizedLeft * visibleWidth)
        .ceil()
        .clamp(0, image.width - 1)
        .toInt();

    final cropTop = (imageOffsetY + normalizedTop * visibleHeight)
        .ceil()
        .clamp(0, image.height - 1)
        .toInt();

    final cropRight = (imageOffsetX + normalizedRight * visibleWidth)
        .floor()
        .clamp(cropLeft + 1, image.width)
        .toInt();

    final cropBottom = (imageOffsetY + normalizedBottom * visibleHeight)
        .floor()
        .clamp(cropTop + 1, image.height)
        .toInt();

    final cropWidth = cropRight - cropLeft;
    final cropHeight = cropBottom - cropTop;

    if (cropWidth <= 0 || cropHeight <= 0) {
      throw StateError('Area bingkai tidak valid.');
    }

    // Potong gambar hanya pada area bingkai.
    final croppedImage = img.copyCrop(
      image,
      x: cropLeft,
      y: cropTop,
      width: cropWidth,
      height: cropHeight,
    );

    // Simpan hasil crop sebagai file sementara.
    final croppedFile = File(
      '${photo.path}_scan_crop.jpg',
    );

    try {
      await croppedFile.writeAsBytes(
        img.encodeJpg(
          croppedImage,
          quality: 95,
        ),
        flush: true,
      );

      return croppedFile;
    } catch (_) {
      if (await croppedFile.exists()) {
        await croppedFile.delete();
      }

      rethrow;
    }
  }

  // ========================================
  // OCR / PINDAI TEKS
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

    final previewContext = _previewKey.currentContext;
    final renderObject = previewContext?.findRenderObject();

    final previewSize = controller.value.previewSize;

    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        previewSize == null) {
      setState(() {
        _error = 'Preview kamera belum siap.';
      });

      return;
    }

    final viewport = renderObject.size;

    // Preview menggunakan orientasi portrait.
    final preview = Size(
      previewSize.height,
      previewSize.width,
    );

    // Simpan posisi bingkai saat tombol scan ditekan.
    final frame = Rect.fromLTRB(
      _left * viewport.width,
      _top * viewport.height,
      _right * viewport.width,
      _bottom * viewport.height,
    );

    setState(() {
      _busy = true;
      _error = null;
    });

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    File? croppedFile;
    XFile? photo;

    try {
      // Tunggu inisialisasi dan operasi zoom selesai.
      final initialization = _initializationFuture;

      if (initialization != null) {
        await initialization;
      }

      final operations = _zoomOperations.toList();

      if (operations.isNotEmpty) {
        await Future.wait(operations);
      }

      if (!mounted || _closing) return;

      // Ambil foto.
      photo = await controller.takePicture();

      // Crop foto sesuai area bingkai.
      croppedFile = await _cropScanFrame(
        photo,
        frame,
        viewport,
        preview,
        controller.description.lensDirection == CameraLensDirection.front,
      );

      // OCR hanya membaca gambar hasil crop.
      final result = await recognizer.processImage(
        InputImage.fromFilePath(croppedFile.path),
      );

      final scannedText = result.text.trim();

      if (!mounted || _closing) return;

      if (scannedText.isEmpty) {
        setState(() {
          _error = 'Tidak ada teks di dalam bingkai. '
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
      try {
        await recognizer.close();
      } catch (_) {}

      // Hapus gambar sementara hasil crop.
      if (croppedFile != null) {
        try {
          if (await croppedFile.exists()) {
            await croppedFile.delete();
          }
        } catch (_) {}
      }

      // Hapus foto asli sementara.
      if (photo != null) {
        try {
          final originalFile = File(photo.path);

          if (await originalFile.exists()) {
            await originalFile.delete();
          }
        } catch (_) {}
      }

      if (mounted && !_closing) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ========================================
  // GESER BINGKAI SCAN
  // ========================================

  void _moveFrame(
    Offset delta,
    Size size,
  ) {
    if (_busy || _closing) return;

    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;

    final frameWidth = _right - _left;
    final frameHeight = _bottom - _top;

    final newLeft = (_left + dx)
        .clamp(
          0.05,
          0.95 - frameWidth,
        )
        .toDouble();

    final newTop = (_top + dy)
        .clamp(
          0.10,
          0.90 - frameHeight,
        )
        .toDouble();

    setState(() {
      _left = newLeft;
      _top = newTop;

      _right = newLeft + frameWidth;
      _bottom = newTop + frameHeight;

      _showHint = false;
    });
  }

  // ========================================
  // UBAH UKURAN BINGKAI SCAN
  // ========================================

  void _resizeFrame(
    _FrameCorner corner,
    Offset delta,
    Size size,
  ) {
    if (_busy || _closing) return;

    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;

    setState(() {
      switch (corner) {
        case _FrameCorner.topLeft:
          _left = (_left + dx)
              .clamp(
                0.05,
                _right - 0.26,
              )
              .toDouble();

          _top = (_top + dy)
              .clamp(
                0.10,
                _bottom - 0.18,
              )
              .toDouble();

          break;

        case _FrameCorner.topRight:
          _right = (_right + dx)
              .clamp(
                _left + 0.26,
                0.95,
              )
              .toDouble();

          _top = (_top + dy)
              .clamp(
                0.10,
                _bottom - 0.18,
              )
              .toDouble();

          break;

        case _FrameCorner.bottomLeft:
          _left = (_left + dx)
              .clamp(
                0.05,
                _right - 0.26,
              )
              .toDouble();

          _bottom = (_bottom + dy)
              .clamp(
                _top + 0.18,
                0.90,
              )
              .toDouble();

          break;

        case _FrameCorner.bottomRight:
          _right = (_right + dx)
              .clamp(
                _left + 0.26,
                0.95,
              )
              .toDouble();

          _bottom = (_bottom + dy)
              .clamp(
                _top + 0.18,
                0.90,
              )
              .toDouble();

          break;
      }

      _showHint = false;
    });
  }

  // ========================================
  // HANDLE SUDUT BINGKAI
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
  // BINGKAI SCAN
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
                  left: 0,
                  right: 0,
                  top: (top + bottom) / 2 - 18,
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
  // CAMERA PREVIEW
  // ========================================

  Widget _buildPreview() {
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

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
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
  // HALAMAN FULLSCREEN
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
            // PREVIEW KAMERA
            Positioned.fill(
              child: SizedBox.expand(
                key: _previewKey,
                child: _buildPreview(),
              ),
            ),

            // BINGKAI SCAN
            if (_ready) _buildAdjustableFrame(),

            // HEADER DAN KONTROL
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
                    _buildHeader(),

                    const Spacer(),

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

                    // MINI ZOOM GLASS
                    _buildZoomControl(),

                    const SizedBox(height: 17),

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
  // MEMBERSIHKAN RESOURCE
  // ========================================

  @override
  void dispose() {
    _closing = true;

    _zoomHideTimer?.cancel();

    final controller = _controller;
    _controller = null;

    if (controller != null) {
      unawaited(
        controller.dispose(),
      );
    }

    super.dispose();
  }
}

// ==========================================
// GARIS EMPAT SUDUT SCANNER
// ==========================================

class _CameraCornersPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
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
      ..quadraticBezierTo(
        0,
        0,
        radius,
        0,
      )
      ..lineTo(length, 0)

      // KANAN ATAS
      ..moveTo(w - length, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(
        w,
        0,
        w,
        radius,
      )
      ..lineTo(w, length)

      // KIRI BAWAH
      ..moveTo(0, h - length)
      ..lineTo(0, h - radius)
      ..quadraticBezierTo(
        0,
        h,
        radius,
        h,
      )
      ..lineTo(length, h)

      // KANAN BAWAH
      ..moveTo(w - length, h)
      ..lineTo(w - radius, h)
      ..quadraticBezierTo(
        w,
        h,
        w,
        h - radius,
      )
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
