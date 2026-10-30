
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'database_helper.dart';

void main() {
  runApp(const ImageToPdfApp());
}

class ImageToPdfApp extends StatelessWidget {
  const ImageToPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Image to PDF',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  final List<File> _images = [];
  File? _pdfFile;
  bool _isConverting = false;

  // Select multiple images from gallery
  Future<void> pickImages() async {
    try {
      final selectedImages = await _picker.pickMultiImage();

      if (selectedImages.isNotEmpty) {
        setState(() {
          _images.addAll(
            selectedImages.map((image) => File(image.path)),
          );
          _pdfFile = null;
        });
      }
    } catch (e) {
      showMessage('Error selecting images: $e');
    }
  }

  // Take a photo using camera
  Future<void> takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
      );

      if (photo != null) {
        setState(() {
          _images.add(File(photo.path));
          _pdfFile = null;
        });
      }
    } catch (e) {
      showMessage('Error taking photo: $e');
    }
  }

  // Remove an image from the selected list
  void removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _pdfFile = null;
    });
  }

  // Convert selected images into one PDF file
  Future<void> convertToPdf() async {
    if (_images.isEmpty) {
      showMessage('Please select at least one image.');
      return;
    }

    setState(() {
      _isConverting = true;
    });

    try {
      final pdf = pw.Document();

      for (final imageFile in _images) {
        final imageBytes = await imageFile.readAsBytes();
        final pdfImage = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            build: (context) {
              return pw.Center(
                child: pw.Image(
                  pdfImage,
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }

      final fileName =
          'document_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      // Save PDF information in SQLite
      await DatabaseHelper.instance.insertPdf({
        'file_name': fileName,
        'file_path': file.path,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      setState(() {
        _pdfFile = file;
        _isConverting = false;
      });

      showMessage('PDF created successfully!');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      showMessage('Error creating PDF: $e');
    }
  }

  // Preview a PDF file
  Future<void> previewPdf(File file) async {
    try {
      if (!await file.exists()) {
        showMessage('PDF file not found.');
        return;
      }

      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewPage(
            pdfBytes: bytes,
          ),
        ),
      );
    } catch (e) {
      showMessage('Error opening PDF: $e');
    }
  }

  // Share the newly created PDF
  Future<void> sharePdf() async {
    if (_pdfFile == null) return;

    try {
      final bytes = await _pdfFile!.readAsBytes();

      await Printing.sharePdf(
        bytes: bytes,
        filename: _pdfFile!.uri.pathSegments.last,
      );
    } catch (e) {
      showMessage('Error sharing PDF: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image to PDF'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'PDF History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Convert Your Images to PDF',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text('Selected images: ${_images.length}'),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Expanded(
              child: _images.isEmpty
                  ? const Center(
                      child: Text('No images selected yet'),
                    )
                  : GridView.builder(
                      itemCount: _images.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _images[index],
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: IconButton(
                                onPressed: () => removeImage(index),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConverting ? null : convertToPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isConverting
                      ? 'Creating PDF...'
                      : 'Convert to PDF',
                ),
              ),
            ),

            if (_pdfFile != null) ...[
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => previewPdf(_pdfFile!),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Preview PDF'),
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: sharePdf,
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF'),
                ),
              ),
            ],

            const SizedBox(height: 8),

            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryPage(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('View PDF History'),
            ),
          ],
        ),
      ),
    );
  }
}

// PDF Preview Page
class PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;

  const PdfPreviewPage({
    super.key,
    required this.pdfBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Preview'),
      ),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}

// PDF History Page
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  // Load PDF history from SQLite
  Future<void> loadHistory() async {
    try {
      final data =
          await DatabaseHelper.instance.getAllPdfs();

      if (!mounted) return;

      setState(() {
        _history = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    }
  }

  // Preview a PDF from history
  Future<void> previewHistoryPdf(String path) async {
    try {
      final file = File(path);

      if (!await file.exists()) {
        throw Exception('PDF file not found');
      }

      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewPage(
            pdfBytes: bytes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening PDF: $e')),
      );
    }
  }

  // Share a PDF from history
  Future<void> shareHistoryPdf(String path, String name) async {
    try {
      final file = File(path);

      if (!await file.exists()) {
        throw Exception('PDF file not found');
      }

      final bytes = await file.readAsBytes();

      await Printing.sharePdf(
        bytes: bytes,
        filename: name,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDF: $e')),
      );
    }
  }

  // Delete a PDF from device and database
  Future<void> deletePdf(int id, String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDF'),
        content: const Text(
          'Are you sure you want to delete this PDF?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }

      await DatabaseHelper.instance.deletePdf(id);
      await loadHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF deleted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF History'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _history.isEmpty
              ? const Center(
                  child: Text('No PDF files yet'),
                )
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final pdf = _history[index];

                    final id = pdf['id'] as int;
                    final name = pdf['file_name'] as String;
                    final path = pdf['file_path'] as String;

                    final date = DateTime.tryParse(
                      pdf['created_at'] as String,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                          size: 35,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          date == null
                              ? 'Unknown date'
                              : '${date.day}/${date.month}/${date.year}',
                        ),
                        onTap: () => previewHistoryPdf(path),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'preview') {
                              previewHistoryPdf(path);
                            } else if (value == 'share') {
                              shareHistoryPdf(path, name);
                            } else if (value == 'delete') {
                              deletePdf(id, path);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'preview',
                              child: Text('Preview'),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
