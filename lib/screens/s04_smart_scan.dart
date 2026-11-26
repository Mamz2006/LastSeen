import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../nav.dart';
import 's04b_camera_capture.dart';
import 's05_ocr_review.dart';
import 's06_import_document.dart';

// ======================================================
// LASTSEEN - SMART SCAN
// REAL TIME CAMERA + MINI ZOOM GLASS
// AUTO MAX ZOOM + DEBUG ZOOM LIMITS
// ======================================================

class S04SmartScan extends StatefulWidget {
  const S04SmartScan({super.key});

  @override
  State<S04SmartScan> createState() => _S04SmartScanState();
}

class _S04SmartScanState extends State<S04SmartScan>
    with WidgetsBindingObserver {
  // ====================================================
  // WARNA
  // ====================================================

  static const Color primary = Color(0xFF4664F2);
  static const Color purple = Color(0xFF704CF7);
  static const Color background = Color(0xFFF5F7FD);
  static const Color ink = Color(0xFF171C31);
  static const Color muted = Color(0xFF8791AC);
  static const Color navy = Color(0xFF121B35);

  // ====================================================
  // CAMERA STATE
  // ====================================================

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

  // ====================================================
  // LANGUAGE
  // ====================================================

  String _sourceLanguage = 'English';
  String _targetLanguage = 'Indonesia';

  static const List<String> _languages = [
    'English',
    'Indonesia',
    'Japanese',
    'Korean',
    'Mandarin',
    'Spanish',
    'French',
    'German',
  ];

  // ====================================================
  // ZOOM STATE
  // ====================================================

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;

  bool _zoomPanelOpen = false;
  bool _zoomLoading = false;
  bool _zoomDragging = false;

  String? _zoomError;

  Timer? _zoomHideTimer;

  final Set<Future<void>> _zoomOperations = {};

  // ====================================================
  // GETTERS
  // ====================================================

  bool get _shouldRun {
    return mounted &&
        !_disposing &&
        !kIsWeb &&
        _tabVisible &&
        _appVisible &&
        !_suspended;
  }

  bool get _cameraReady {
    final camera = _camera;

    return _shouldRun && camera != null && camera.value.isInitialized;
  }

  bool get _zoomAvailable {
    return _cameraReady && _maxZoom > _minZoom;
  }

  // ====================================================
  // LIFECYCLE
  // ====================================================

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;

    _syncCamera();
  }

  @override
  void dispose() {
    _disposing = true;

    WidgetsBinding.instance.removeObserver(this);

    _zoomHideTimer?.cancel();
    _cameraVersion++;

    unawaited(_releaseCamera());

    super.dispose();
  }

  // ====================================================
  // CAMERA MANAGER
  // ====================================================

  void _syncCamera() {
    if (_disposing || !mounted) {
      return;
    }

    if (!_shouldRun) {
      unawaited(_stopCamera());
      return;
    }

    if (_camera != null || _starting != null || _stopping != null) {
      return;
    }

    if (_error != null) {
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

  Future<void> _initializeCamera(int version) async {
    CameraController? nextCamera;

    try {
      final cameras = await availableCameras();

      // ==============================================
      // DEBUG: DAFTAR KAMERA YANG TERSEDIA
      // ==============================================

      debugPrint(
        '========== LASTSEEN CAMERA DEBUG ==========',
      );

      for (final camera in cameras) {
        debugPrint(
          'AVAILABLE CAMERA: '
          '${camera.name} | '
          'LENS: ${camera.lensDirection}',
        );
      }

      if (cameras.isEmpty) {
        throw Exception('Kamera tidak ditemukan.');
      }

      final rearCameras = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      final selectedCamera =
          rearCameras.isNotEmpty ? rearCameras.first : cameras.first;

      debugPrint(
        'LASTSEEN SELECTED CAMERA: '
        '${selectedCamera.name}',
      );

      if (!_shouldRun || version != _cameraVersion) {
        return;
      }

      nextCamera = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await nextCamera.initialize();

      if (!_shouldRun || version != _cameraVersion) {
        return;
      }

      final initializedCamera = nextCamera;

      if (!mounted) {
        return;
      }

      setState(() {
        _camera = initializedCamera;
        _error = null;

        _minZoom = 1.0;
        _maxZoom = 1.0;
        _zoom = 1.0;

        _zoomPanelOpen = false;
        _zoomLoading = false;
        _zoomError = null;
      });

      nextCamera = null;

      // Ambil batas zoom dari perangkat.
      unawaited(_readZoomLimits());
    } catch (error) {
      debugPrint(
        'LASTSEEN CAMERA ERROR: $error',
      );

      if (mounted && !_disposing && version == _cameraVersion) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (nextCamera != null) {
        try {
          await nextCamera.dispose();
        } catch (_) {}
      }
    }
  }

  Future<void> _stopCamera() async {
    if (_stopping != null) {
      return _stopping;
    }

    // Jika kamera memang sudah berhenti,
    // tidak perlu menjalankan proses ulang.
    if (_camera == null && _starting == null) {
      return;
    }

    ++_cameraVersion;

    final task = _releaseCamera();

    _stopping = task;

    try {
      await task;
    } finally {
      if (identical(_stopping, task)) {
        _stopping = null;
      }

      if (_shouldRun && _camera == null && _error == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _syncCamera();
          }
        });
      }
    }
  }

  Future<void> _releaseCamera() async {
    _zoomHideTimer?.cancel();

    final starting = _starting;

    if (starting != null) {
      try {
        await starting;
      } catch (_) {}
    }

    final camera = _camera;

    if (mounted && !_disposing) {
      setState(() {
        _camera = null;

        _zoomPanelOpen = false;
        _zoomDragging = false;
        _zoomLoading = false;
        _zoomError = null;
      });
    } else {
      _camera = null;
    }

    if (camera == null) {
      return;
    }

    // Berikan kesempatan preview lepas
    // dari widget sebelum controller di-dispose.
    await Future<void>.delayed(
      const Duration(milliseconds: 32),
    );

    if (_zoomOperations.isNotEmpty) {
      try {
        await Future.wait(
          _zoomOperations.toList(),
        );
      } catch (_) {}
    }

    try {
      await camera.dispose();
    } catch (error) {
      debugPrint(
        'LASTSEEN CAMERA DISPOSE ERROR: $error',
      );
    }
  }

  void _retryCamera() {
    if (_busy) {
      return;
    }

    setState(() {
      _error = null;
    });

    _syncCamera();
  }

  // ====================================================
  // ZOOM LIMITS
  //
  // BAGIAN UTAMA YANG DITAMBAHKAN
  // ====================================================

  Future<void> _readZoomLimits() async {
    final controller = _camera;

    if (controller == null || !controller.value.isInitialized || _zoomLoading) {
      return;
    }

    if (!mounted || _disposing) {
      return;
    }

    setState(() {
      _zoomLoading = true;
      _zoomError = null;
    });

    try {
      // Nilai langsung dari plugin kamera.
      final values = await Future.wait<double>([
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
      ]);

      final minZoom = values[0];
      final maxZoom = values[1];

      if (!mounted || _disposing || !identical(_camera, controller)) {
        return;
      }

      // ==========================================
      // DEBUG BARU:
      // LIHAT HASILNYA DI TERMINAL VS CODE
      // ==========================================

      debugPrint(
        '==========================================',
      );

      debugPrint(
        'LASTSEEN CAMERA: '
        '${controller.description.name}',
      );

      debugPrint(
        'LASTSEEN MIN ZOOM: $minZoom',
      );

      debugPrint(
        'LASTSEEN MAX ZOOM: $maxZoom',
      );

      debugPrint(
        '==========================================',
      );

      // Gunakan nilai aktual dari kamera.
      // Tidak menetapkan batas 10x atau 20x
      // secara manual.
      setState(() {
        _minZoom = minZoom;
        _maxZoom = maxZoom;

        _zoom = _zoom.clamp(_minZoom, _maxZoom).toDouble();

        _zoomLoading = false;
        _zoomError = null;
      });

      if (_zoomPanelOpen && _zoomAvailable) {
        _scheduleZoomHide();
      }
    } catch (error) {
      debugPrint(
        'LASTSEEN ZOOM ERROR: $error',
      );

      if (mounted && !_disposing && identical(_camera, controller)) {
        setState(() {
          _zoomLoading = false;
          _zoomError = 'Gagal membaca batas zoom kamera.';
        });
      }
    }
  }

  // ====================================================
  // MINI ZOOM GLASS
  // ====================================================

  void _toggleZoomPanel() {
    if (_busy || _suspended) {
      return;
    }

    if (!_cameraReady) {
      _showMessage(
        'Kamera belum siap. Tunggu preview muncul.',
      );
      return;
    }

    _zoomHideTimer?.cancel();

    setState(() {
      _zoomPanelOpen = !_zoomPanelOpen;
      _zoomDragging = false;
    });

    if (_zoomPanelOpen) {
      if (!_zoomLoading && !_zoomAvailable) {
        unawaited(_readZoomLimits());
      } else if (_zoomAvailable) {
        _scheduleZoomHide();
      }
    }
  }

  void _scheduleZoomHide() {
    _zoomHideTimer?.cancel();

    if (!_zoomPanelOpen || _zoomDragging) {
      return;
    }

    _zoomHideTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (!mounted || _disposing) {
          return;
        }

        if (_zoomPanelOpen && !_zoomDragging) {
          setState(() {
            _zoomPanelOpen = false;
          });
        }
      },
    );
  }

  void _changeZoom(double value) {
    final controller = _camera;

    if (controller == null ||
        !controller.value.isInitialized ||
        !_zoomAvailable) {
      return;
    }

    final nextZoom = value.clamp(_minZoom, _maxZoom).toDouble();

    setState(() {
      _zoom = nextZoom;
    });

    final task = controller.setZoomLevel(nextZoom).catchError((Object error) {
      debugPrint(
        'LASTSEEN SET ZOOM ERROR: $error',
      );
    });

    _zoomOperations.add(task);

    unawaited(
      task.whenComplete(() {
        _zoomOperations.remove(task);
      }),
    );
  }

  // ====================================================
  // GLASS MINI ZOOM BUTTON
  // ====================================================

  Widget _buildMiniZoomButton() {
    return ClipRRect(
      key: const ValueKey('mini-zoom'),
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Material(
          color: Colors.black.withValues(alpha: 0.43),
          child: InkWell(
            onTap: _toggleZoomPanel,
            child: Container(
              height: 43,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
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
                    size: 21,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${_zoom.toStringAsFixed(1)}×',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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

  // ====================================================
  // SLIDER ZOOM GLASS
  // ====================================================

  Widget _buildZoomSlider() {
    return ClipRRect(
      key: const ValueKey('slider-zoom'),
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 315,
          ),
          height: 60,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.59,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.28,
              ),
            ),
          ),
          child: _zoomLoading
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Menyiapkan zoom...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                )
              : !_zoomAvailable
                  ? Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Batas zoom belum tersedia',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Coba lagi',
                          onPressed: () {
                            unawaited(
                              _readZoomLimits(),
                            );
                          },
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text(
                          '${_zoom.toStringAsFixed(1)}×',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withValues(
                                alpha: 0.30,
                              ),
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                            ),
                            child: Slider(
                              value: _zoom
                                  .clamp(
                                    _minZoom,
                                    _maxZoom,
                                  )
                                  .toDouble(),
                              min: _minZoom,
                              max: _maxZoom,
                              onChangeStart: (_) {
                                _zoomHideTimer?.cancel();

                                setState(() {
                                  _zoomDragging = true;
                                });
                              },
                              onChanged: _changeZoom,
                              onChangeEnd: (_) {
                                setState(() {
                                  _zoomDragging = false;
                                });

                                _scheduleZoomHide();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${_maxZoom.toStringAsFixed(0)}×',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        InkWell(
                          onTap: _toggleZoomPanel,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildZoomControl() {
    return Align(
      alignment: Alignment.bottomRight,
      child: AnimatedSwitcher(
        duration: const Duration(
          milliseconds: 220,
        ),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _zoomPanelOpen ? _buildZoomSlider() : _buildMiniZoomButton(),
      ),
    );
  }

  // ====================================================
  // CAMERA PREVIEW
  // ====================================================

  Widget _buildCameraPreview() {
    final controller = _camera;

    if (!_cameraReady || controller == null) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white70,
                  size: 45,
                ),
                const SizedBox(height: 13),
                const Text(
                  'Kamera tidak dapat dibuka',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _retryCamera,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        );
      }

      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      );
    }

    final previewSize = controller.value.previewSize;

    if (previewSize == null) {
      return CameraPreview(controller);
    }

    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    final previewWidth = isPortrait ? previewSize.height : previewSize.width;

    final previewHeight = isPortrait ? previewSize.width : previewSize.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  // ====================================================
  // GLASS BUTTON
  // ====================================================

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    String? text,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 13,
          sigmaY: 13,
        ),
        child: Material(
          color: Colors.black.withValues(alpha: 0.34),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(25),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 42,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: 0.23,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 19,
                  ),
                  if (text != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================
  // LANGUAGE SELECTION
  // ====================================================

  Future<void> _chooseLanguage({
    required bool source,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              15,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Bahasa',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 400,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      final language = _languages[index];

                      final active = source
                          ? _sourceLanguage == language
                          : _targetLanguage == language;

                      return ListTile(
                        title: Text(language),
                        trailing: active
                            ? const Icon(
                                Icons.check_circle,
                                color: primary,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(
                            sheetContext,
                            language,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      if (source) {
        _sourceLanguage = selected;
      } else {
        _targetLanguage = selected;
      }
    });
  }

  void _swapLanguages() {
    setState(() {
      final previous = _sourceLanguage;

      _sourceLanguage = _targetLanguage;
      _targetLanguage = previous;
    });
  }

  // ====================================================
  // SCANNER HEADER
  // ====================================================

  Widget _buildScannerHeader() {
    return Row(
      children: [
        _buildGlassButton(
          icon: Icons.arrow_back_rounded,
          onTap: () {
            if (MainTabShell.isEmbedded(context)) {
              openTab(context, 0);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _buildGlassButton(
                  icon: Icons.language_rounded,
                  text: _sourceLanguage,
                  onTap: () {
                    _chooseLanguage(source: true);
                  },
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: _swapLanguages,
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: _buildGlassButton(
                  icon: Icons.language_rounded,
                  text: _targetLanguage,
                  onTap: () {
                    _chooseLanguage(source: false);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildGlassButton(
          icon: Icons.fullscreen_rounded,
          onTap: _openFullCamera,
        ),
      ],
    );
  }

  // ====================================================
  // OCR
  // ====================================================

  Future<String> _recognizeText(
    String imagePath,
  ) async {
    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final result = await recognizer.processImage(inputImage);

      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  Future<void> _openOcrResult(
    String recognizedText,
  ) async {
    if (!mounted) {
      return;
    }

    final text = recognizedText.trim();

    if (text.isEmpty) {
      _showMessage(
        'Teks tidak ditemukan. Coba pindai lagi.',
      );
      return;
    }

    _suspended = true;

    await _stopCamera();

    if (!mounted) {
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => S05OcrReview(
            initialText: text,
          ),
        ),
      );
    } finally {
      if (mounted) {
        _suspended = false;
        _syncCamera();
      }
    }
  }

  // ====================================================
  // SCAN LANGSUNG
  // ====================================================

  Future<void> _scanNow() async {
    final controller = _camera;

    if (_busy || !_cameraReady || controller == null) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final image = await controller.takePicture();

      final text = await _recognizeText(
        image.path,
      );

      if (!mounted) {
        return;
      }

      await _openOcrResult(text);
    } catch (error) {
      debugPrint('LASTSEEN OCR ERROR: $error');

      _showMessage(
        'Gagal memindai teks. Coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ====================================================
  // GALERI
  // ====================================================

  Future<void> _openGallery() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null || !mounted) {
        return;
      }

      final text = await _recognizeText(
        image.path,
      );

      if (!mounted) {
        return;
      }

      await _openOcrResult(text);
    } catch (error) {
      debugPrint(
        'LASTSEEN GALLERY ERROR: $error',
      );

      _showMessage(
        'Gagal membaca gambar dari galeri.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ====================================================
  // IMPOR DOKUMEN
  // ====================================================

  Future<void> _openImport() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _suspended = true;
    });

    try {
      await _stopCamera();

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const S06ImportDocument(),
        ),
      );
    } catch (error) {
      debugPrint(
        'LASTSEEN IMPORT ERROR: $error',
      );

      _showMessage(
        'Gagal membuka impor dokumen.',
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

  // ====================================================
  // FULLSCREEN CAMERA
  // ====================================================

  Future<void> _openFullCamera() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _suspended = true;
    });

    try {
      // Lepaskan kamera inline agar kamera
      // fullscreen bisa menggunakannya.
      await _stopCamera();

      if (!mounted) {
        return;
      }

      final route = MaterialPageRoute<String>(
        builder: (_) => const S04BCameraCapture(),
      );

      final recognizedText = await Navigator.of(context).push(route);

      // Tunggu animasi route selesai.
      await route.completed;

      if (!mounted) {
        return;
      }

      if (recognizedText != null && recognizedText.trim().isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => S05OcrReview(
              initialText: recognizedText,
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint(
        'LASTSEEN FULLSCREEN ERROR: $error',
      );

      _showMessage(
        'Gagal membuka kamera fullscreen.',
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

  // ====================================================
  // SNACKBAR
  // ====================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ====================================================
  // SCANNER PANEL
  // ====================================================

  Widget _buildScanner(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(29),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // PREVIEW KAMERA
          _buildCameraPreview(),

          // GRADIENT AGAR HEADER TERBACA
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x66000000),
                  ],
                  stops: [
                    0.0,
                    0.28,
                    0.68,
                    1.0,
                  ],
                ),
              ),
            ),
          ),

          // GARIS SUDUT SCAN BIRU
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                25,
                100,
                25,
                98,
              ),
              child: CustomPaint(
                painter: _ScannerCornersPainter(),
              ),
            ),
          ),

          // HEADER
          Positioned(
            top: 16,
            left: 13,
            right: 13,
            child: _buildScannerHeader(),
          ),

          // PETUNJUK
          const Positioned(
            left: 20,
            right: 20,
            bottom: 88,
            child: Text(
              'Arahkan kamera ke teks yang ingin dipindai',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          // MINI ZOOM GLASS
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildZoomControl(),
          ),

          // INDIKATOR MEMINDAI
          if (_busy)
            const Positioned(
              top: 78,
              right: 21,
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ====================================================
  // ACTION BUTTON
  // ====================================================

  Widget _buildAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primaryAction = false,
  }) {
    return Expanded(
      child: Material(
        color: primaryAction ? primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primaryAction ? primary : const Color(0xFFE3E8F5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: primaryAction ? Colors.white : primary,
                  size: 25,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: primaryAction ? Colors.white : ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        _buildAction(
          icon: Icons.photo_library_outlined,
          label: 'Galeri',
          onTap: _openGallery,
        ),
        const SizedBox(width: 10),
        _buildAction(
          icon: Icons.document_scanner_rounded,
          label: 'Pindai',
          onTap: _scanNow,
          primaryAction: true,
        ),
        const SizedBox(width: 10),
        _buildAction(
          icon: Icons.file_upload_outlined,
          label: 'Impor',
          onTap: _openImport,
        ),
      ],
    );
  }

  // ====================================================
  // TIPS
  // ====================================================

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.tips_and_updates_outlined,
            color: primary,
            size: 23,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Pastikan teks terlihat jelas dan kamera '
              'tidak bergerak agar hasil scan lebih akurat.',
              style: TextStyle(
                color: Color(0xFF4E5D8B),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // BOTTOM NAVIGATION
  // ====================================================

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
        8,
        9,
        8,
        8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE3E8F5),
          ),
        ),
      ),
      child: Row(
        children: List.generate(5, (index) {
          final selected = index == 1;

          return Expanded(
            child: InkWell(
              onTap: () => openTab(
                context,
                index,
              ),
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 51,
                    height: 35,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE9EEFF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      icons[index],
                      color: selected ? primary : const Color(0xFF9BA5BF),
                      size: 23,
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

  // ====================================================
  // BUILD
  // ====================================================

  @override
  Widget build(BuildContext context) {
    final embedded = MainTabShell.isEmbedded(context);

    final screenHeight = MediaQuery.sizeOf(context).height;

    final scannerHeight = (screenHeight * 0.54).clamp(280.0, 490.0).toDouble();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  18,
                  19,
                  18,
                  24,
                ),
                children: [
                  const Text(
                    'Smart Scan',
                    style: TextStyle(
                      color: ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Pindai teks dari kamera atau dokumen.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 19),
                  _buildScanner(scannerHeight),
                  const SizedBox(height: 17),
                  _buildActions(),
                  const SizedBox(height: 17),
                  _buildTips(),
                ],
              ),
            ),
            if (!embedded) _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// PAINTER SUDUT SCAN
// ======================================================

class _ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4C9BFF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const length = 28.0;
    const radius = 13.0;

    final path = Path();

    // KIRI ATAS
    path.moveTo(0, length);
    path.lineTo(0, radius);
    path.quadraticBezierTo(
      0,
      0,
      radius,
      0,
    );
    path.lineTo(length, 0);

    // KANAN ATAS
    path.moveTo(
      size.width - length,
      0,
    );
    path.lineTo(
      size.width - radius,
      0,
    );
    path.quadraticBezierTo(
      size.width,
      0,
      size.width,
      radius,
    );
    path.lineTo(
      size.width,
      length,
    );

    // KIRI BAWAH
    path.moveTo(
      0,
      size.height - length,
    );
    path.lineTo(
      0,
      size.height - radius,
    );
    path.quadraticBezierTo(
      0,
      size.height,
      radius,
      size.height,
    );
    path.lineTo(
      length,
      size.height,
    );

    // KANAN BAWAH
    path.moveTo(
      size.width - length,
      size.height,
    );
    path.lineTo(
      size.width - radius,
      size.height,
    );
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width,
      size.height - radius,
    );
    path.lineTo(
      size.width,
      size.height - length,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _ScannerCornersPainter oldDelegate,
  ) {
    return false;
  }
}
