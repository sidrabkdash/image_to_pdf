import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image to PDF',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Image to PDF'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  XFile? _image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            ElevatedButton(
              onPressed: () async {
                final picker = ImagePicker();
                final image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() {
                    _image = image;
                  });
                }
              },
              child: const Text('Choose Image from Gallery'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                final picker = ImagePicker();
                final image = await picker.pickImage(source: ImageSource.camera);
                if (image != null) {
                  setState(() {
                    _image = image;
                  });
                }
              },
              child: const Text('Take Photo'),
            ),

            const SizedBox(height: 20),

            if (_image != null)
              Image.network(
                _image!.path,
                height: 300,
              ),

            const SizedBox(height: 20),

            
            ElevatedButton(
              onPressed: () async {
                if (_image == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select an image first!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                final pdf = pw.Document();
                final imageFile = File(_image!.path);
                final imageBytes = await imageFile.readAsBytes();
                final pdfImage = pw.MemoryImage(imageBytes);

                pdf.addPage(
                  pw.Page(
                    build: (context) => pw.Center(child: pw.Image(pdfImage)),
                  ),
                );

                
                final desktop = Directory('${Platform.environment['USERPROFILE']}\\Desktop');
                final file = File("${desktop.path}\\my_document.pdf");
                await file.writeAsBytes(await pdf.save());

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('PDF saved on Desktop: ${file.path}'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('Convert to PDF'),
            ),
          ],
        ),
      ),
    );
  }
}