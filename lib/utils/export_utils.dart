import 'dart:convert';
import 'dart:io';

import 'package:daily_you/database/image_storage.dart';
import 'package:daily_you/utils/export_documents.dart';
import 'package:daily_you/utils/file_layer.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/providers/entry_images_provider.dart';
import 'package:daily_you/time_manager.dart';
import 'package:daily_you/utils/zip_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';

enum ExportFormat {
  none,
  markdown,
  word,
  pdf,
}

class ExportUtils {
  static Future<bool> exportToMarkdown(
      BuildContext context, void Function(String) updateStatus) async {
    updateStatus("(1/2) 0%");

    String? exportFolder;
    try {
      exportFolder = await FileLayer.pickDirectory();
    } catch (e) {
      updateStatus("$e");
      await Future.delayed(Duration(seconds: 5));
      return false;
    }
    if (exportFolder == null) return false;

    bool success = true;

    var tempDir = await getTemporaryDirectory();
    final tempExportFolder = Directory(join(tempDir.path, "logs"));
    await tempExportFolder.create(recursive: true);
    final tempExportImageFolder =
        Directory(join(tempExportFolder.path, "Images"));
    await tempExportImageFolder.create(recursive: true);
    final exportedZipName =
        "daily_you_markdown_export_${DateTime.now().toIso8601String().replaceAll(':', '-')}.zip";

    try {
      final entries = EntriesProvider.instance.entries;
      final totalLogs = entries.length;
      int processedLogs = 0;
      final Map<String, int> timestampCount = {};
      for (Entry entry in entries) {
        final images = EntryImagesProvider.instance.getForEntry(entry);
        StringBuffer noteBody = StringBuffer();

        final timestamp =
            DateFormat("yyyy-MM-dd", TimeManager.currentLocale(context))
                .format(entry.timeCreate);
        timestampCount[timestamp] = (timestampCount[timestamp] ?? 0) + 1;
        final index = timestampCount[timestamp]!;
        final indexSuffix = index > 1 ? "_$index" : "";

        for (EntryImage image in images) {
          final bytes = await ImageStorage.instance.getBytes(image.imgPath);
          final prettyName =
              "image_$timestamp${indexSuffix}_${image.imgRank}${extension(image.imgPath)}";
          if (bytes != null) {
            noteBody.writeln('![](Images/$prettyName)');

            await FileLayer.createFile(
                tempExportImageFolder.path, prettyName, bytes,
                useExternalPath: false);
          }
        }

        noteBody.writeln(
            "${DateFormat.yMMMEd(TimeManager.currentLocale(context)).format(entry.timeCreate)}\n${entry.text}");

        await FileLayer.createFile(tempExportFolder.path,
            "log_$timestamp$indexSuffix.md", utf8.encode(noteBody.toString()),
            useExternalPath: false);

        processedLogs++;
        updateStatus("(1/2) ${((processedLogs / totalLogs) * 100).round()}%");
      }

      // Zip export folder
      await ZipUtils.compress(
          join(tempDir.path, exportedZipName), [], [tempExportFolder.path],
          onProgress: (percent) {
        updateStatus("(2/2) ${percent.round()}%");
      });

      // Save archive
      updateStatus(AppLocalizations.of(context)!.tranferStatus("0"));
      await FileLayer.copyToExternalLocation(
          join(tempDir.path, exportedZipName), exportFolder, exportedZipName,
          onProgress: (percent) {
        updateStatus(
            AppLocalizations.of(context)!.tranferStatus("${percent.round()}"));
      });
    } catch (e) {
      updateStatus("$e");
      await Future.delayed(Duration(seconds: 5));
      success = false;
    }

    // Delete temp files
    updateStatus(AppLocalizations.of(context)!.cleanUpStatus);
    final exportedZip = File(join(tempDir.path, exportedZipName));
    if (await exportedZip.exists()) {
      await exportedZip.delete();
    }
    if (await tempExportFolder.exists()) {
      await tempExportFolder.delete(recursive: true);
    }

    return success;
  }

  /// 全量导出所有日记为单个 Word（.docx）文档。
  static Future<bool> exportToWord(
          BuildContext context, void Function(String) updateStatus) =>
      _exportDocument(context, updateStatus, asWord: true);

  /// 全量导出所有日记为单个 PDF 文档。
  static Future<bool> exportToPdf(
          BuildContext context, void Function(String) updateStatus) =>
      _exportDocument(context, updateStatus, asWord: false);

  static Future<bool> _exportDocument(BuildContext context,
      void Function(String) updateStatus, {required bool asWord}) async {
    updateStatus("(1/2) 0%");

    String? exportFolder;
    try {
      exportFolder = await FileLayer.pickDirectory();
    } catch (e) {
      updateStatus("$e");
      await Future.delayed(const Duration(seconds: 5));
      return false;
    }
    if (exportFolder == null) return false;

    final entries = EntriesProvider.instance.entries;
    if (entries.isEmpty) {
      updateStatus("暂无日记可导出");
      await Future.delayed(const Duration(seconds: 2));
      return false;
    }

    final docs = <ExportEntryDoc>[];
    final locale = TimeManager.currentLocale(context);
    final timestampCount = <String, int>{};
    for (Entry entry in entries) {
      final images = EntryImagesProvider.instance.getForEntry(entry);
      final timestamp =
          DateFormat("yyyy-MM-dd", locale).format(entry.timeCreate);
      timestampCount[timestamp] = (timestampCount[timestamp] ?? 0) + 1;
      final index = timestampCount[timestamp]!;
      final indexSuffix = index > 1 ? "_$index" : "";
      docs.add(ExportEntryDoc(
        date: DateFormat.yMMMEd(locale).format(entry.timeCreate),
        title: entry.title,
        text: entry.text,
        images: [
          for (EntryImage image in images)
            ExportImageDoc(
              path: image.imgPath,
              fileName:
                  "image_$timestamp${indexSuffix}_${image.imgRank}${extension(image.imgPath)}",
            ),
        ],
      ));
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final ext = asWord ? 'docx' : 'pdf';
      final fileName = "daily_you_export_$stamp.$ext";
      final tempFile = join(tempDir.path, fileName);

      Uint8List bytes;
      void onProgress(int done, int total) {
        updateStatus("(1/2) ${((done / total) * 100).round()}%");
      }

      if (asWord) {
        bytes = await buildWordDocument(docs,
            loadImageBytes: (p) => ImageStorage.instance.getBytes(p),
            onProgress: onProgress);
      } else {
        final fontData = await rootBundle
            .load('assets/fonts/SotyrFangsong-Subset.ttf');
        bytes = await buildPdfDocument(docs,
            fontData: fontData,
            loadImageBytes: (p) => ImageStorage.instance.getBytes(p),
            onProgress: onProgress);
      }

      await File(tempFile).writeAsBytes(bytes);

      // Save to the picked folder
      updateStatus(AppLocalizations.of(context)!.tranferStatus("0"));
      await FileLayer.copyToExternalLocation(
          tempFile, exportFolder, fileName,
          mimeType: asWord
              ? "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
              : "application/pdf",
          onProgress: (percent) {
        updateStatus(
            AppLocalizations.of(context)!.tranferStatus("${percent.round()}"));
      });

      // Clean up temp file
      final exportedFile = File(tempFile);
      if (await exportedFile.exists()) {
        await exportedFile.delete();
      }
      return true;
    } catch (e) {
      updateStatus("$e");
      await Future.delayed(const Duration(seconds: 5));
      return false;
    }
  }
}
