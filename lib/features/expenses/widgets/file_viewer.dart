import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../models/expense_file.dart';

class FileViewer extends StatelessWidget {
  final List<ExpenseFile> files;

  const FileViewer({super.key, required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64),
            SizedBox(height: 8),
            Text('No bill attached'),
          ],
        ),
      );
    }

    return PageView(
      children: files.map((file) {
        final remote =
            file.url.startsWith('http://') || file.url.startsWith('https://');

        if (file.type == 'image') {
          return PhotoView(
            imageProvider: remote
                ? NetworkImage(file.url)
                : FileImage(File(file.url)) as ImageProvider,
          );
        }

        return remote
            ? SfPdfViewer.network(file.url)
            : SfPdfViewer.file(File(file.url));
      }).toList(),
    );
  }
}
