import 'package:flutter/material.dart';

import '../nav.dart';
import 's05_ocr_review.dart';
import 's07_pdf_reader.dart';

class S06ImportDocument extends StatefulWidget {
  const S06ImportDocument({super.key});

  @override
  State<S06ImportDocument> createState() => _S06ImportDocumentState();
}

class _S06ImportDocumentState extends State<S06ImportDocument> {
  // WARNA APLIKASI
  static const Color primary = Color(0xFF4361EE);
  static const Color navy = Color(0xFF15192D);
  static const Color muted = Color(0xFF747E94);
  static const Color background = Color(0xFFF8F9FD);
  static const Color border = Color(0xFFDCE2F0);
  static const Color lightBlue = Color(0xFFE9EEFF);

  bool _busy = false;

  // ==========================================
  // IMPORT FOTO - SIMULASI
  // ==========================================
  Future<void> _importPhoto() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 600),
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
    });

    // MENUJU HALAMAN PERIKSA HASIL SCAN
    pushScreen(
      context,
      const S05OcrReview(),
    );
  }

  // ==========================================
  // IMPORT PDF - SIMULASI
  // ==========================================
  Future<void> _importPdf() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 600),
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
    });

    // MENUJU HALAMAN PDF READER
    pushScreen(
      context,
      const S07PdfReader(),
    );
  }

  // ==========================================
  // PILIH JENIS FILE
  // ==========================================
  void _showImportOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih jenis dokumen',
                  style: TextStyle(
                    color: navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 20),

                // PILIH FOTO
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: primary,
                    size: 25,
                  ),
                  title: const Text(
                    'Foto dari galeri',
                    style: TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: muted,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _importPhoto();
                  },
                ),

                const SizedBox(height: 8),

                // PILIH PDF
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  leading: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: primary,
                    size: 25,
                  ),
                  title: const Text(
                    'Dokumen PDF',
                    style: TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: muted,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _importPdf();
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
  // TOMBOL KEMBALI
  // ==========================================
  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      openTab(context, 1);
    }
  }

  // ==========================================
  // NOTIFIKASI FILE CONTOH
  // ==========================================
  void _showDemoNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'File terakhir masih berupa data contoh.',
        ),
      ),
    );
  }

  // ==========================================
  // HALAMAN UTAMA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      26,
                      24,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        _buildHeader(),

                        const SizedBox(height: 28),

                        // AREA UPLOAD UTAMA
                        _buildUploadArea(),

                        // LOADING
                        if (_busy) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(
                            color: primary,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // INFORMASI OCR
                        _buildTip(),

                        const SizedBox(height: 32),

                        // JUDUL FILE TERAKHIR
                        const Text(
                          'File terakhir',
                          style: TextStyle(
                            color: navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // DAFTAR FILE TERAKHIR
                        _buildRecentFiles(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // NAVIGASI BAWAH
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HEADER IMPORT DOKUMEN
  // ==========================================
  Widget _buildHeader() {
    return Row(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(
              color: border,
              width: 1.5,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _goBack,
            child: const SizedBox(
              height: 48,
              width: 48,
              child: Icon(
                Icons.arrow_back_rounded,
                color: navy,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: Text(
            'Import dokumen',
            style: TextStyle(
              color: navy,
              fontSize: 27,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // AREA UPLOAD UTAMA
  // ==========================================
  Widget _buildUploadArea() {
    return Material(
      color: const Color(0xFFF1F3FF),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: _busy ? null : _showImportOptions,
        borderRadius: BorderRadius.circular(30),
        child: CustomPaint(
          foregroundPainter: _DashedBorderPainter(),
          child: SizedBox(
            width: double.infinity,
            height: 226,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // IKON UPLOAD
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),

                const SizedBox(height: 21),

                // JUDUL
                const Text(
                  'Pilih file dari perangkat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 7),

                // FORMAT FILE
                const Text(
                  'JPG, PNG, atau PDF',
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
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
  // INFORMASI OCR
  // ==========================================
  Widget _buildTip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: primary,
            size: 22,
          ),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              'Pastikan teks tidak buram. '
              'PDF hasil scan akan diproses OCR.',
              style: TextStyle(
                color: Color(0xFF475477),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FILE TERAKHIR
  // ==========================================
  Widget _buildRecentFiles() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: border,
          width: 1.3,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          // FILE PDF CONTOH
          _recentFile(
            icon: Icons.picture_as_pdf_outlined,
            name: 'english-notes.pdf',
            detail: '12 halaman',
          ),

          const Divider(
            height: 1,
            color: border,
          ),

          // FILE FOTO CONTOH
          _recentFile(
            icon: Icons.image_outlined,
            name: 'menu-cafe.jpg',
            detail: 'Foto',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ITEM FILE TERAKHIR
  // ==========================================
  Widget _recentFile({
    required IconData icon,
    required String name,
    required String detail,
  }) {
    return InkWell(
      onTap: _showDemoNotice,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: primary,
              size: 24,
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: muted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // NAVIGASI BAWAH
  // ==========================================
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: border,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8,
      ),
      child: Row(
        children: List.generate(
          labels.length,
          (index) {
            final selected = index == 1;

            return Expanded(
              child: InkWell(
                onTap: () => openTab(context, index),
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // IKON NAVIGASI
                    Container(
                      width: 49,
                      height: 35,
                      decoration: BoxDecoration(
                        color: selected ? lightBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        icons[index],
                        color: selected ? primary : const Color(0xFF9BA5BF),
                        size: 22,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // LABEL NAVIGASI
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
          },
        ),
      ),
    );
  }
}

// ==========================================
// BORDER PUTUS-PUTUS AREA UPLOAD
// ==========================================
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFA3B4FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            1,
            1,
            size.width - 2,
            size.height - 2,
          ),
          const Radius.circular(29),
        ),
      );

    for (final metric in outline.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final end = distance + 6 < metric.length ? distance + 6 : metric.length;

        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );

        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
