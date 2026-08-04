import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

/// Argument bundle passed to the compression isolate.
class CompressRequest {
  final String outputFile;
  final List<String> inputFiles;
  final List<String> inputFolders;
  final SendPort progressPort;

  const CompressRequest({
    required this.outputFile,
    required this.inputFiles,
    required this.inputFolders,
    required this.progressPort,
  });
}

/// Argument bundle passed to the extraction isolate.
class ExtractRequest {
  final String inputFile;
  final String outputFolder;
  final SendPort progressPort;

  const ExtractRequest({
    required this.inputFile,
    required this.outputFolder,
    required this.progressPort,
  });
}

class ZipUtils {
  static Future<void> compress(
      String outputFile, List<String> inputFiles, List<String> inputFolders,
      {Function(double percent)? onProgress}) async {
    final rxPort = ReceivePort();
    rxPort.listen((data) {
      if (onProgress != null) {
        onProgress(data);
      }
    });

    await compute(_encodeArchive, CompressRequest(
      outputFile: outputFile,
      inputFiles: inputFiles,
      inputFolders: inputFolders,
      progressPort: rxPort.sendPort,
    ));

    rxPort.close();
  }

  static Future<void> extract(String inputFile, String outputFolder,
      {Function(double percent)? onProgress}) async {
    final rxPort = ReceivePort();
    rxPort.listen((data) {
      if (onProgress != null) {
        onProgress(data);
      }
    });

    await compute(_decodeArchive, ExtractRequest(
      inputFile: inputFile,
      outputFolder: outputFolder,
      progressPort: rxPort.sendPort,
    ));

    rxPort.close();
  }

  static Future<void> _encodeArchive(CompressRequest request) async {
    final encoder = ZipFileEncoder();
    encoder.createWithStream(OutputFileStream(request.outputFile));
    for (final file in request.inputFiles) {
      await encoder.addFile(File(file));
    }
    for (final folder in request.inputFolders) {
      // TODO: Progress is not accurate and only works for a single folder
      await encoder.addDirectory(Directory(folder), onProgress: (progress) {
        request.progressPort.send(progress * 100);
      });
    }
    await encoder.close();
  }

  static Future<void> _decodeArchive(ExtractRequest request) async {
    final decoder =
        ZipDecoder().decodeStream(InputFileStream(request.inputFile));

    // Track number of files for progress indication
    final totalFileCount = decoder.numberOfFiles();
    var processedFileCount = 0;

    for (final entry in decoder) {
      if (entry.isFile) {
        final bytes = entry.readBytes();
        if (bytes == null) continue;
        // Zip paths must be relative; some archives prefix paths with '/'
        final fileName = entry.name.startsWith('/')
            ? entry.name.substring(1)
            : entry.name;
        final file = File(join(request.outputFolder, fileName));
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);

        processedFileCount += 1;
        request.progressPort.send((processedFileCount / totalFileCount) * 100);
      } else {
        await Directory(join(request.outputFolder, entry.name))
            .create(recursive: true);
      }
    }
  }
}
