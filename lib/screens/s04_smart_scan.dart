import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../nav.dart';
import 's04b_camera_capture.dart';
import 's05_ocr_review.dart';
import 's06_import_document.dart';

// ==========================================
// LASTSEEN - SMART SCAN REAL-TIME
// MINI ZOOM GLASS + FLASH + OCR CROP
// ==========================================

class S04SmartScan extends StatefulWidget {
  const S04SmartScan({super.key});

  @override
  State<S04SmartScan> createState() => _S04SmartScanState();
}

class _S04SmartScanState extends State<S04SmartScan>
    with WidgetsBindingObserver {
  // ========================================
  // WARNA
  // ========================================

  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);
  static const Color background = Color(0xFFF8F9FD);
  static const Color muted = Color(0xFF8089A1);
  static const Color lightBlue = Color(0xFFE9EEFF);
  static const Color glassColor = Color(0xFF454B61);
  static const Color borderGrey = Color(0xFFDDE3F0);

  // ========================================
  // CAMERA
  // ========================================

  CameraController? _camera;

  Future<void>? _starting;
  Future<void>? _stopping;

  int _cameraVersion = 0;

  bool _tabVisible = false;
  bool _appVisible = true;
  bool _suspended = false;
  bool _busy = false;
  bool _disposing = false;

  String? _error;

  final ImagePicker _imagePicker = ImagePicker();

  // ========================================
  // FLASH / TORCH
  // ========================================

  bool _flashOn = false;
  bool _changingFlash = false;

  Future<void>? _flashOperation;

  // ========================================
  // BATAS AREA SCAN
  // ========================================

  final GlobalKey _previewKey = GlobalKey();
  final GlobalKey _scanFrameKey = GlobalKey();

  static const double _frameHorizontal = 34.0;
  static const double _frameTop = 0.23;
  static const double _frameBottom = 0.22;

  // ========================================
  // BAHASA
  // ========================================

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Indonesia';

  // ========================================
  // MINI ZOOM GLASS
  // ========================================

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;

  bool _zoomPanelOpen = false;
  bool _zoomDragging = false;
  bool _zoomLoading = false;

  String? _zoomError;

  Timer? _zoomHideTimer;

  final Set<Future<void>> _zoomOperations = {};

  // ========================================
  // KONDISI KAMERA
  // ========================================

  bool get _shouldRun =>
      mounted &&
      !_disposing &&
      !kIsWeb &&
      _tabVisible &&
      _appVisible &&
      !_suspended;

  bool get _cameraReady =>
      _shouldRun && _camera != null && _camera!.value.isInitialized;

  bool get _zoomAvailable => _cameraReady && _maxZoom > _minZoom;

  bool get _flashAvailable =>
      _cameraReady && !_busy && !_suspended && !_changingFlash && !_disposing;

  // ========================================
  // LIFECYCLE
  // ========================================

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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncCamera();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    _appVisible = state == AppLifecycleState.resumed;

    _syncCamera();
  }

  // ========================================
  // MENGATUR CAMERA LIFECYCLE
  // ========================================

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

  bool _isCurrent(int version) {
    return _shouldRun && _cameraVersion == version;
  }

  // ========================================
  // MEMBUKA KAMERA REAL-TIME
  // ========================================

  Future<void> _initializeCamera(
    int version,
  ) async {
    CameraController? candidate;

    try {
      final cameras = await availableCameras();

      if (!_isCurrent(version)) {
        return;
      }

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

      if (!_isCurrent(version)) {
        await candidate.dispose();
        return;
      }

      // Pastikan flash mati ketika kamera dibuka.
      try {
        await candidate.setFlashMode(
          FlashMode.off,
        );
      } catch (_) {
        // Kamera tetap dapat digunakan jika
        // perangkat tidak mendukung flash.
      }

      if (!_isCurrent(version)) {
        await candidate.dispose();
        return;
      }

      // Preview tampil setelah kamera siap.
      setState(() {
        _camera = candidate;
        _error = null;

        _minZoom = 1.0;
        _maxZoom = 1.0;
        _zoom = 1.0;

        _zoomLoading = false;
        _zoomError = null;

        _flashOn = false;
        _changingFlash = false;
      });

      // Membaca kemampuan zoom tanpa
      // menahan tampilan preview.
      unawaited(_readZoomLimits());
    } on CameraException catch (e) {
      if (candidate != null && !identical(candidate, _camera)) {
        try {
          await candidate.dispose();
        } catch (_) {}
      }

      if (_isCurrent(version)) {
        setState(() {
          _error = e.description ?? 'Kamera gagal dibuka.';
        });
      }
    } catch (_) {
      if (candidate != null && !identical(candidate, _camera)) {
        try {
          await candidate.dispose();
        } catch (_) {}
      }

      if (_isCurrent(version)) {
        setState(() {
          _error = 'Kamera tidak dapat dibuka. '
              'Periksa izin kamera.';
        });
      }
    }
  }

  // ========================================
  // MEMBACA BATAS ZOOM KAMERA
  // ========================================

  Future<void> _readZoomLimits() async {
    final controller = _camera;

    if (controller == null ||
        !controller.value.isInitialized ||
        _zoomLoading ||
        _disposing) {
      return;
    }

    setState(() {
      _zoomLoading = true;
      _zoomError = null;
    });

    try {
      final values = await Future.wait<double>([
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
      ]);

      if (!mounted || _disposing || !identical(_camera, controller)) {
        return;
      }

      final minZoom = values[0];
      final maxZoom = values[1];

      if (!minZoom.isFinite || !maxZoom.isFinite || maxZoom < minZoom) {
        throw StateError(
          'Batas zoom tidak valid.',
        );
      }

      final initialZoom = _zoom.clamp(minZoom, maxZoom).toDouble();

      setState(() {
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = initialZoom;

        _zoomLoading = false;

        if (maxZoom <= minZoom) {
          _zoomError = 'Kamera tidak menyediakan rentang zoom.';
        }
      });

      // Jika slider sedang terbuka,
      // mulai timer setelah zoom siap.
      if (_zoomPanelOpen && _zoomAvailable) {
        _scheduleZoomHide();
      }
    } catch (_) {
      if (!mounted || _disposing || !identical(_camera, controller)) {
        return;
      }

      setState(() {
        _zoomLoading = false;
        _zoomError = 'Batas zoom belum berhasil dibaca.';
      });
    }
  }

  // ========================================
  // MENGHENTIKAN KAMERA
  // ========================================

  Future<void> _stopCamera() async {
    ++_cameraVersion;

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

  // ========================================
  // MELEPAS KAMERA DENGAN AMAN
  // ========================================

  Future<void> _releaseCamera() async {
    _zoomHideTimer?.cancel();

    _zoomPanelOpen = false;
    _zoomDragging = false;

    // Jika kamera masih dibuka,
    // selesaikan proses tersebut dahulu.
    final starting = _starting;

    if (starting != null) {
      try {
        await starting;
      } catch (_) {}
    }

    final controller = _camera;

    _camera = null;

    _zoomLoading = false;
    _zoomError = null;

    _flashOn = false;
    _changingFlash = false;

    if (controller != null && mounted && !_disposing) {
      // Hilangkan CameraPreview
      // sebelum CameraController di-dispose.
      setState(() {});

      await WidgetsBinding.instance.endOfFrame;
    }

    if (controller != null) {
      await _disposeCameraSafely(controller);
    }
  }

  // ========================================
  // DISPOSE CONTROLLER DENGAN AMAN
  // ========================================

  Future<void> _disposeCameraSafely(
    CameraController controller,
  ) async {
    // Tunggu zoom yang sedang berjalan.
    final operations = _zoomOperations.toList();

    if (operations.isNotEmpty) {
      try {
        await Future.wait(operations);
      } catch (_) {}
    }

    // Pastikan flash mati sebelum kamera dilepas.
    await _turnOffFlash(controller);

    try {
      await controller.dispose();
    } catch (_) {}
  }

  // ========================================
  // FLASH / TORCH CAMERA
  // ========================================

  Future<void> _toggleFlash() async {
    final controller = _camera;

    if (controller == null || !_flashAvailable) {
      return;
    }

    final nextFlash = !_flashOn;

    setState(() {
      _changingFlash = true;
    });

    Future<void>? operation;

    try {
      // Torch membuat lampu menyala terus
      // selama pengguna mengarahkan kamera.
      operation = controller.setFlashMode(
        nextFlash ? FlashMode.torch : FlashMode.off,
      );

      _flashOperation = operation;

      await operation;

      if (!mounted || _disposing || !identical(_camera, controller)) {
        return;
      }

      setState(() {
        _flashOn = nextFlash;
      });
    } catch (_) {
      if (mounted && !_disposing && identical(_camera, controller)) {
        _showMessage(
          'Flash tidak tersedia pada kamera ini.',
        );
      }
    } finally {
      if (identical(_flashOperation, operation)) {
        _flashOperation = null;
      }

      if (mounted && !_disposing && identical(_camera, controller)) {
        setState(() {
          _changingFlash = false;
        });
      }
    }
  }

  // ========================================
  // MEMATIKAN FLASH DENGAN AMAN
  // ========================================

  Future<void> _turnOffFlash(
    CameraController controller,
  ) async {
    final operation = _flashOperation;

    if (operation != null) {
      try {
        await operation;
      } catch (_) {}
    }

    try {
      if (controller.value.isInitialized) {
        await controller.setFlashMode(
          FlashMode.off,
        );
      }
    } catch (_) {
      // Abaikan jika kamera tidak mendukung
      // flash atau sudah tidak tersedia.
    }
  }

  // ========================================
  // MEMBUKA / MENUTUP MINI ZOOM GLASS
  // ========================================

  void _toggleZoomPanel() {
    if (_busy || _suspended) {
      return;
    }

    if (!_cameraReady) {
      _showMessage(
        'Kamera belum siap. Coba lagi setelah preview muncul.',
      );

      return;
    }

    _zoomHideTimer?.cancel();

    setState(() {
      _zoomPanelOpen = !_zoomPanelOpen;
      _zoomDragging = false;
    });

    if (_zoomPanelOpen) {
      // Panel selalu terbuka jika kamera siap.
      // Tidak diblokir oleh batas zoom.
      if (!_zoomLoading && !_zoomAvailable) {
        unawaited(_readZoomLimits());
      } else if (_zoomAvailable) {
        _scheduleZoomHide();
      }
    }
  }

  // ========================================
  // TIMER MENUTUP ZOOM OTOMATIS
  // ========================================

  void _scheduleZoomHide() {
    _zoomHideTimer?.cancel();

    if (!_zoomPanelOpen || _zoomDragging || _zoomLoading || !_zoomAvailable) {
      return;
    }

    _zoomHideTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (!mounted || _disposing || _zoomDragging || !_zoomPanelOpen) {
          return;
        }

        setState(() {
          _zoomPanelOpen = false;
        });
      },
    );
  }

  // ========================================
  // ZOOM MENGGUNAKAN SLIDER LANGSUNG
  // ========================================

  void _changeZoom(double value) {
    final controller = _camera;

    if (controller == null || !_cameraReady || _busy || !_zoomAvailable) {
      return;
    }

    final next = value.clamp(_minZoom, _maxZoom).toDouble();

    // Sama seperti metode slider
    // sebelumnya, tanpa gestur cubit.
    setState(() {
      _zoom = next;
    });

    final Future<void> operation = controller.setZoomLevel(next).catchError(
          (Object _) {},
        );

    _zoomOperations.add(operation);

    unawaited(
      operation.whenComplete(() {
        _zoomOperations.remove(operation);
      }),
    );
  }

  // ========================================
  // MINI FLASH GLASS BUTTON
  // SAME DESIGN AS FULLSCREEN CAMERA
  //
  // FLASH ON  : IKON PETIR PUTIH
  // FLASH OFF : IKON PETIR PUTIH DICORET
  // ========================================

  Widget _buildMiniFlashButton() {
    final enabled = _flashAvailable;

    final tooltip = _flashOn ? 'Matikan flash' : 'Nyalakan flash';

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: _flashOn,
      label: tooltip,
      child: Tooltip(
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
                onTap: enabled
                    ? () {
                        unawaited(_toggleFlash());
                      }
                    : null,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
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
                    child: _changingFlash
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 1.6,
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(
                              milliseconds: 150,
                            ),
                            child: Icon(
                              _flashOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              key: ValueKey(_flashOn),
                              color: enabled ? Colors.white : Colors.white54,
                              size: 19,
                            ),
                          ),
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
  // TOMBOL MINI ZOOM
  // ========================================

  Widget _buildMiniZoomButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // Tetap bisa ditekan.
            // Fungsi memberikan pesan
            // jika kamera belum siap.
            onTap: _toggleZoomPanel,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                color: glassColor.withValues(
                  alpha: 0.43,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: 0.28,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_zoom.toStringAsFixed(1)}×',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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
  // PANEL ZOOM GLASS
  // ========================================

  Widget _buildZoomSlider() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            color: glassColor.withValues(
              alpha: 0.43,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.28,
              ),
            ),
          ),
          child: Row(
            children: [
              if (_zoomLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Menyiapkan zoom...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else if (!_zoomAvailable) ...[
                Expanded(
                  child: Text(
                    _zoomError ?? 'Zoom belum tersedia.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  tooltip: 'Coba baca zoom lagi',
                  onPressed: _busy
                      ? null
                      : () {
                          unawaited(_readZoomLimits());
                        },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 5),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${_zoom.toStringAsFixed(1)}×',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: Slider(
                      min: _minZoom,
                      max: _maxZoom,
                      value: _zoom
                          .clamp(
                            _minZoom,
                            _maxZoom,
                          )
                          .toDouble(),
                      onChangeStart: (_) {
                        _zoomHideTimer?.cancel();
                        _zoomDragging = true;
                      },
                      onChanged: _busy ? null : _changeZoom,
                      onChangeEnd: (_) {
                        _zoomDragging = false;
                        _scheduleZoomHide();
                      },
                    ),
                  ),
                ),
              ],

              // Tombol tutup zoom.
              IconButton(
                tooltip: 'Tutup zoom',
                onPressed: _busy ? null : _toggleZoomPanel,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 19,
                ),
                constraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
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
  // KONTROL MINI ZOOM DALAM AREA KAMERA
  // ========================================

  Widget _buildZoomControl() {
    return Align(
      alignment: Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: const Duration(
          milliseconds: 180,
        ),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _zoomPanelOpen
            ? SizedBox(
                key: const ValueKey(
                  'zoomSlider',
                ),
                width: double.infinity,
                child: _buildZoomSlider(),
              )
            : SizedBox(
                key: const ValueKey(
                  'miniZoom',
                ),
                child: _buildMiniZoomButton(),
              ),
      ),
    );
  }

  // ========================================
  // FLASH + MINI ZOOM GLASS
  // ========================================

  Widget _buildCameraBottomControls() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Flash tetap berada di kiri.
        _buildMiniFlashButton(),

        const SizedBox(width: 12),

        // Zoom tetap berada di kanan.
        // Slider menggunakan ruang yang tersedia.
        Expanded(
          child: _buildZoomControl(),
        ),
      ],
    );
  }

  // ========================================
  // BAHASA
  // ========================================

  void _swapLanguage() {
    if (_busy || _suspended) return;

    setState(() {
      final previous = _sourceLanguage;

      _sourceLanguage = _targetLanguage;
      _targetLanguage = previous;
    });
  }

  void _setLanguage(
    String source,
    String target,
  ) {
    if (!mounted) return;

    setState(() {
      _sourceLanguage = source;
      _targetLanguage = target;
    });
  }

  void _showLanguagePicker() {
    if (_busy || _suspended) return;

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
                    _setLanguage(
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
                    _setLanguage(
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
                  color: glassColor.withValues(
                    alpha: 0.43,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.28,
                    ),
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
  // PEMILIH BAHASA GLASS
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
                onPressed: _busy || _suspended ? null : _swapLanguage,
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
  // HEADER SCANNER
  // ========================================

  Widget _buildScannerHeader() {
    return Row(
      children: [
        _glassCircleButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Kembali',
          onTap: _busy || _suspended ? null : () => openTab(context, 0),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _buildGlassLanguagePicker(),
        ),
        const SizedBox(width: 9),
        _glassCircleButton(
          icon: Icons.fullscreen_rounded,
          tooltip: 'Kamera fullscreen',
          onTap: _busy || _suspended
              ? null
              : () {
                  unawaited(_openFullCamera());
                },
        ),
      ],
    );
  }

  // ========================================
  // MENAMPILKAN PESAN
  // ========================================

  void _showMessage(String message) {
    if (!mounted || _disposing) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ========================================
  // HASIL OCR
  // ========================================

  Future<void> _openOcrResult(
    String text,
  ) async {
    if (!mounted || text.trim().isEmpty) {
      return;
    }

    final route = MaterialPageRoute<void>(
      builder: (_) => S05OcrReview(
        initialText: text,
      ),
    );

    await Navigator.of(context).push<void>(route);

    await route.completed;
  }

  // ========================================
  // BUKA KAMERA FULLSCREEN
  // ========================================

  Future<void> _openFullCamera() async {
    if (_busy || _suspended) return;

    if (kIsWeb) {
      _showMessage(
        'Kamera fullscreen tersedia di HP Android.',
      );

      return;
    }

    setState(() {
      _suspended = true;
      _error = null;
    });

    try {
      // Flash otomatis dimatikan ketika
      // kamera Smart Scan dihentikan.
      await _stopCamera();

      if (!mounted) return;

      final route = MaterialPageRoute<String>(
        builder: (_) => const S04BCameraCapture(),
      );

      final scannedText = await Navigator.of(context).push<String>(route);

      await route.completed;

      if (!mounted) return;

      if (scannedText != null && scannedText.trim().isNotEmpty) {
        await _openOcrResult(scannedText);
      }
    } catch (_) {
      _showMessage(
        'Mode kamera fullscreen gagal dibuka.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _suspended = false;
          _error = null;
        });

        _tabVisible = TickerMode.of(context);

        _syncCamera();
      }
    }
  }

  // ========================================
  // MENGAMBIL KOORDINAT BINGKAI SCAN
  // ========================================

  Rect? _getScanFrame() {
    final previewContext = _previewKey.currentContext;
    final frameContext = _scanFrameKey.currentContext;

    if (previewContext == null || frameContext == null) {
      return null;
    }

    final previewObject = previewContext.findRenderObject();

    final frameObject = frameContext.findRenderObject();

    if (previewObject is! RenderBox ||
        frameObject is! RenderBox ||
        !previewObject.hasSize ||
        !frameObject.hasSize) {
      return null;
    }

    if (previewObject.size.isEmpty || frameObject.size.isEmpty) {
      return null;
    }

    // Ambil posisi bingkai yang benar-benar
    // ditampilkan pada layar.
    final globalTopLeft = frameObject.localToGlobal(
      Offset.zero,
    );

    final globalBottomRight = frameObject.localToGlobal(
      Offset(
        frameObject.size.width,
        frameObject.size.height,
      ),
    );

    // Konversi posisi bingkai ke dalam
    // koordinat lokal preview kamera.
    final localTopLeft = previewObject.globalToLocal(
      globalTopLeft,
    );

    final localBottomRight = previewObject.globalToLocal(
      globalBottomRight,
    );

    final frame = Rect.fromPoints(
      localTopLeft,
      localBottomRight,
    );

    final previewRect = Offset.zero & previewObject.size;

    final clippedFrame = frame.intersect(
      previewRect,
    );

    if (clippedFrame.isEmpty) {
      return null;
    }

    return clippedFrame;
  }

  // ========================================
  // CROP GAMBAR SESUAI BINGKAI SMART SCAN
  // ========================================

  Future<File> _cropScanFrame({
    required XFile photo,
    required Rect frame,
    required Size viewport,
    required Size preview,
    required bool mirrored,
  }) async {
    final bytes = await photo.readAsBytes();

    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw StateError(
        'Gambar tidak dapat dibaca.',
      );
    }

    // Sesuaikan orientasi foto berdasarkan EXIF.
    final image = img.bakeOrientation(
      decodedImage,
    );

    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    if (viewport.isEmpty || preview.isEmpty) {
      throw StateError(
        'Ukuran preview kamera tidak valid.',
      );
    }

    // ======================================
    // HITUNG BOXFIT.COVER
    // ======================================

    final scale = math.max(
      viewport.width / preview.width,
      viewport.height / preview.height,
    );

    final renderedWidth = preview.width * scale;
    final renderedHeight = preview.height * scale;

    final offsetX = (renderedWidth - viewport.width) / 2;

    final offsetY = (renderedHeight - viewport.height) / 2;

    // ======================================
    // NORMALISASI KOORDINAT BINGKAI
    // ======================================

    double normalizedLeft = (frame.left + offsetX) / renderedWidth;

    double normalizedRight = (frame.right + offsetX) / renderedWidth;

    final normalizedTop = (frame.top + offsetY) / renderedHeight;

    final normalizedBottom = (frame.bottom + offsetY) / renderedHeight;

    // Penyesuaian jika kamera depan digunakan.
    if (mirrored) {
      final previousLeft = normalizedLeft;

      normalizedLeft = 1.0 - normalizedRight;
      normalizedRight = 1.0 - previousLeft;
    }

    // ======================================
    // SESUAIKAN RASIO PREVIEW DAN FOTO
    // ======================================

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

    // ======================================
    // KONVERSI KE PIKSEL GAMBAR
    // ======================================

    final cropLeft = (imageOffsetX + normalizedLeft * visibleWidth)
        .ceil()
        .clamp(
          0,
          image.width - 1,
        )
        .toInt();

    final cropTop = (imageOffsetY + normalizedTop * visibleHeight)
        .ceil()
        .clamp(
          0,
          image.height - 1,
        )
        .toInt();

    final cropRight = (imageOffsetX + normalizedRight * visibleWidth)
        .floor()
        .clamp(
          cropLeft + 1,
          image.width,
        )
        .toInt();

    final cropBottom = (imageOffsetY + normalizedBottom * visibleHeight)
        .floor()
        .clamp(
          cropTop + 1,
          image.height,
        )
        .toInt();

    final cropWidth = cropRight - cropLeft;
    final cropHeight = cropBottom - cropTop;

    if (cropWidth <= 0 || cropHeight <= 0) {
      throw StateError(
        'Area bingkai scan tidak valid.',
      );
    }

    // ======================================
    // POTONG GAMBAR
    // ======================================

    final croppedImage = img.copyCrop(
      image,
      x: cropLeft,
      y: cropTop,
      width: cropWidth,
      height: cropHeight,
    );

    // ======================================
    // SIMPAN HASIL CROP SEMENTARA
    // ======================================

    final croppedFile = File(
      '${photo.path}_smart_scan_crop.jpg',
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
      try {
        if (await croppedFile.exists()) {
          await croppedFile.delete();
        }
      } catch (_) {}

      rethrow;
    }
  }

  // ========================================
  // MEMBERSIHKAN FOTO SEMENTARA
  // ========================================

  Future<void> _deleteTemporaryFile(
    File? file,
  ) async {
    if (file == null) return;

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Abaikan jika file sudah dihapus
      // atau tidak dapat diakses.
    }
  }

  // ========================================
  // PINDAI KAMERA REAL-TIME
  // OCR HANYA MEMBACA AREA BINGKAI
  // ========================================

  Future<void> _scanCamera() async {
    final controller = _camera;

    if (controller == null || !_cameraReady || _busy || _changingFlash) {
      return;
    }

    final previewObject = _previewKey.currentContext?.findRenderObject();

    final previewSize = controller.value.previewSize;

    final frame = _getScanFrame();

    if (previewObject is! RenderBox ||
        !previewObject.hasSize ||
        previewSize == null ||
        frame == null) {
      _showMessage(
        'Area scan belum siap. Coba lagi.',
      );

      return;
    }

    // Ukuran area preview kamera.
    final viewport = previewObject.size;

    // Preview menggunakan orientasi portrait.
    final preview = Size(
      previewSize.height,
      previewSize.width,
    );

    final mirrored =
        controller.description.lensDirection == CameraLensDirection.front;

    setState(() {
      _busy = true;
      _error = null;
    });

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    XFile? photo;
    File? croppedFile;

    try {
      // ====================================
      // TUNGGU OPERASI ZOOM SELESAI
      // ====================================

      final operations = _zoomOperations.toList();

      if (operations.isNotEmpty) {
        await Future.wait(operations);
      }

      // ====================================
      // TUNGGU OPERASI FLASH SELESAI
      // ====================================

      final flashOperation = _flashOperation;

      if (flashOperation != null) {
        await flashOperation;
      }

      if (!mounted ||
          _disposing ||
          !_cameraReady ||
          !identical(_camera, controller)) {
        return;
      }

      // ====================================
      // AMBIL FOTO
      // ====================================

      // Flash tetap menyala jika sebelumnya
      // diaktifkan oleh pengguna.
      photo = await controller.takePicture();

      if (!mounted ||
          _disposing ||
          !_cameraReady ||
          !identical(_camera, controller)) {
        return;
      }

      // ====================================
      // CROP SESUAI BINGKAI SMART SCAN
      // ====================================

      croppedFile = await _cropScanFrame(
        photo: photo,
        frame: frame,
        viewport: viewport,
        preview: preview,
        mirrored: mirrored,
      );

      if (!mounted ||
          _disposing ||
          !_cameraReady ||
          !identical(_camera, controller)) {
        return;
      }

      // ====================================
      // OCR HANYA MEMBACA HASIL CROP
      // ====================================

      final result = await recognizer.processImage(
        InputImage.fromFilePath(
          croppedFile.path,
        ),
      );

      if (!mounted ||
          _disposing ||
          !_cameraReady ||
          !identical(_camera, controller)) {
        return;
      }

      final text = result.text.trim();

      if (text.isEmpty) {
        _showMessage(
          'Tidak ada teks di dalam bingkai. '
          'Coba dekatkan kamera.',
        );

        return;
      }

      // Hapus foto sementara setelah OCR selesai.
      await _deleteTemporaryFile(croppedFile);

      croppedFile = null;

      await _deleteTemporaryFile(
        File(photo.path),
      );

      photo = null;

      if (!mounted ||
          _disposing ||
          !_cameraReady ||
          !identical(_camera, controller)) {
        return;
      }

      // ====================================
      // HENTIKAN KAMERA SEBELUM HASIL OCR
      // ====================================

      _suspended = true;

      // Flash otomatis dimatikan melalui
      // proses penghentian kamera.
      await _stopCamera();

      if (!mounted) return;

      await _openOcrResult(text);
    } catch (_) {
      _showMessage(
        'Gagal memindai teks. Coba lagi.',
      );
    } finally {
      try {
        await recognizer.close();
      } catch (_) {}

      // Pastikan file sementara dibersihkan
      // meskipun proses OCR gagal.
      await _deleteTemporaryFile(
        croppedFile,
      );

      if (photo != null) {
        await _deleteTemporaryFile(
          File(photo.path),
        );
      }

      if (mounted) {
        setState(() {
          _busy = false;
          _suspended = false;
        });

        _syncCamera();
      }
    }
  }

  // ========================================
  // AMBIL FOTO DARI GALERI
  // TETAP MEMBACA SELURUH FOTO
  // ========================================

  Future<void> _openGallery() async {
    if (_busy || _suspended) return;

    if (kIsWeb) {
      _showMessage(
        'OCR foto tersedia di aplikasi Android.',
      );

      return;
    }

    setState(() {
      _busy = true;
      _suspended = true;
    });

    TextRecognizer? recognizer;

    try {
      // Flash otomatis dimatikan ketika
      // kamera dihentikan.
      await _stopCamera();

      if (!mounted) return;

      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (!mounted || photo == null) {
        return;
      }

      recognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      // Galeri tidak menggunakan bingkai kamera,
      // sehingga seluruh foto tetap dibaca.
      final result = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );

      if (!mounted) return;

      final text = result.text.trim();

      if (text.isEmpty) {
        _showMessage(
          'Tidak ditemukan teks pada foto.',
        );

        return;
      }

      await _openOcrResult(text);
    } catch (_) {
      _showMessage(
        'Gagal membaca foto dari galeri.',
      );
    } finally {
      if (recognizer != null) {
        try {
          await recognizer.close();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _busy = false;
          _suspended = false;
        });

        _syncCamera();
      }
    }
  }

  // ========================================
  // IMPOR DOKUMEN / PDF
  // ========================================

  Future<void> _openImport() async {
    if (_busy || _suspended) return;

    setState(() {
      _suspended = true;
    });

    try {
      // Flash otomatis dimatikan sebelum
      // membuka halaman impor.
      await _stopCamera();

      if (!mounted) return;

      final route = MaterialPageRoute<void>(
        builder: (_) => const S06ImportDocument(),
      );

      await Navigator.of(context).push<void>(route);

      await route.completed;
    } catch (_) {
      _showMessage(
        'Gagal membuka impor dokumen.',
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

  // ========================================
  // LIVE CAMERA PREVIEW
  // ========================================

  Widget _buildLivePreview() {
    final controller = _camera;

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: navy,
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator(
                  color: primary,
                  strokeWidth: 2.5,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white54,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                        });

                        _syncCamera();
                      },
                      child: const Text(
                        'Coba Lagi',
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    final size = controller.value.previewSize;

    if (size == null) {
      return CameraPreview(controller);
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  // ========================================
  // AREA SCANNER
  // FLASH + MINI ZOOM GLASS
  // ========================================

  Widget _buildScanner(
    double scanHeight,
  ) {
    return Container(
      width: double.infinity,
      height: scanHeight,
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ==================================
          // KAMERA REAL-TIME
          // ==================================

          Positioned.fill(
            child: SizedBox.expand(
              key: _previewKey,
              child: _buildLivePreview(),
            ),
          ),

          // ==================================
          // EMPAT SUDUT SCAN
          // SEKALIGUS BATAS AREA OCR
          // ==================================

          Positioned(
            left: _frameHorizontal,
            right: _frameHorizontal,
            top: scanHeight * _frameTop,
            bottom: scanHeight * _frameBottom,
            child: IgnorePointer(
              child: CustomPaint(
                key: _scanFrameKey,
                painter: _ScannerCornersPainter(),
              ),
            ),
          ),

          // ==================================
          // HEADER GLASS
          // ==================================

          Positioned(
            top: 17,
            left: 17,
            right: 17,
            child: _buildScannerHeader(),
          ),

          // ==================================
          // PETUNJUK SCAN
          // ==================================

          Positioned(
            left: 20,
            right: 20,
            bottom: 87,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Arahkan kamera ke teks yang jelas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ==================================
          // FLASH + MINI ZOOM GLASS
          // FLASH KIRI - ZOOM KANAN
          // ==================================

          Positioned(
            left: 17,
            right: 17,
            bottom: 16,
            child: _buildCameraBottomControls(),
          ),
        ],
      ),
    );
  }

  // ========================================
  // GALERI / PINDAI / IMPOR
  // ========================================

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _sideAction(
          icon: Icons.photo_library_outlined,
          label: 'Galeri',
          onTap: _busy || _suspended
              ? null
              : () {
                  unawaited(_openGallery());
                },
        ),
        _buildScanButton(),
        _sideAction(
          icon: Icons.file_upload_outlined,
          label: 'Impor',
          onTap: _busy || _suspended
              ? null
              : () {
                  unawaited(_openImport());
                },
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(60),
          onTap: _cameraReady && !_busy && !_changingFlash
              ? () {
                  unawaited(_scanCamera());
                }
              : null,
          child: Container(
            width: 82,
            height: 82,
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
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.document_scanner_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Pindai',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _sideAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: borderGrey,
                width: 1.3,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: onTap == null ? Colors.grey : primary,
              size: 25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // NAVIGASI BAWAH
  // ========================================

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
            color: borderGrey,
          ),
        ),
      ),
      child: Row(
        children: List.generate(5, (index) {
          final selected = index == 1;

          return Expanded(
            child: InkWell(
              onTap: () => openTab(context, index),
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 51,
                    height: 35,
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
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11,
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

  // ========================================
  // HALAMAN UTAMA
  // ========================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    final scanHeight = (screenHeight * 0.59)
        .clamp(
          360.0,
          530.0,
        )
        .toDouble();

    final embedded = MainTabShell.isEmbedded(context);

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
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
            if (!embedded) _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // ========================================
  // DISPOSE
  // ========================================

  @override
  void dispose() {
    _disposing = true;
    ++_cameraVersion;

    _zoomHideTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    final controller = _camera;

    _camera = null;

    // Tunggu operasi kamera sebelum dispose.
    // Flash juga dimatikan melalui fungsi ini.
    if (controller != null) {
      unawaited(
        _disposeCameraSafely(controller),
      );
    }

    super.dispose();
  }
}

// ==========================================
// PAINTER EMPAT SUDUT SCANNER
// ==========================================

class _ScannerCornersPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = const Color(0xFF8095FF)
      ..strokeWidth = 2.5
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
