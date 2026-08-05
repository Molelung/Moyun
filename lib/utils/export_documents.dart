import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 供 Word/PDF 导出使用的单篇日记数据（图片按需读取）。
class ExportEntryDoc {
  final String date;
  final String? title;
  final String text;
  final List<ExportImageDoc> images;

  const ExportEntryDoc({
    required this.date,
    this.title,
    required this.text,
    this.images = const [],
  });
}

class ExportImageDoc {
  final String path;
  final String fileName;

  const ExportImageDoc({required this.path, required this.fileName});
}

/// 仅解码图片头部获取像素宽高（不加载完整像素）。
Future<(int, int)?> _imagePixelSize(Uint8List bytes) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final w = descriptor.width;
    final h = descriptor.height;
    descriptor.dispose();
    buffer.dispose();
    if (w <= 0 || h <= 0) return null;
    return (w, h);
  } catch (_) {
    return null;
  }
}

String _xmlEscape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// 生成 .docx（Word 文档）：每篇日记一页，含日期、标题、正文与图片。
/// 中文不内嵌字体，由 Word 使用系统字体（正文仿宋）渲染。
Future<Uint8List> buildWordDocument(
  List<ExportEntryDoc> entries, {
  required Future<Uint8List?> Function(String path) loadImageBytes,
  void Function(int done, int total)? onProgress,
}) async {
  final archive = Archive();
  var mediaIndex = 0;
  final rels = StringBuffer();
  final body = StringBuffer();
  var relId = 2; // rId1 保留给 document.xml 自身

  body.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<w:body>');

  for (int e = 0; e < entries.length; e++) {
    final entry = entries[e];
    if (e > 0) {
      body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
    }

    // 日期（居中，灰色小字）
    body.write(
        '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
        '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:eastAsia="仿宋"/>'
        '<w:color w:val="808080"/><w:sz w:val="22"/></w:rPr>'
        '<w:t>${_xmlEscape(entry.date)}</w:t></w:r></w:p>');

    if (entry.title != null && entry.title!.isNotEmpty) {
      body.write(
          '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
          '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:eastAsia="仿宋"/>'
          '<w:b/><w:sz w:val="32"/></w:rPr>'
          '<w:t>${_xmlEscape(entry.title!)}</w:t></w:r></w:p>');
    }

    for (final line in entry.text.split('\n')) {
      body.write(
          '<w:p><w:pPr><w:spacing w:line="360" w:lineRule="auto"/></w:pPr>'
          '<w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:eastAsia="仿宋"/>'
          '<w:sz w:val="24"/></w:rPr>'
          '<w:t>${_xmlEscape(line)}</w:t></w:r></w:p>');
    }

    // 图片（居中，宽不超过 5.8 英寸）
    const maxWidthEmu = 5535989; // 5.8in * 914400
    for (final img in entry.images) {
      final bytes = await loadImageBytes(img.path);
      if (bytes == null) continue;
      final size = await _imagePixelSize(bytes);
      if (size == null) continue;
      mediaIndex++;
      final ext = _imageExtension(img.fileName);
      final mediaName = 'image$mediaIndex.$ext';

      var extentW = size.$1 * 9525; // px -> EMU (96dpi)
      var extentH = size.$2 * 9525;
      if (extentW > maxWidthEmu) {
        extentH = (extentH * maxWidthEmu / extentW).round();
        extentW = maxWidthEmu;
      }
      body.write(
          '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing>'
          '<wp:inline distT="0" distB="0" distL="0" distR="0">'
          '<wp:extent cx="$extentW" cy="$extentH"/>'
          '<wp:docPr id="$relId" name="Picture $relId"/>'
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
          '<pic:pic><pic:nvPicPr><pic:cNvPr id="$relId" name="Picture $relId"/><pic:cNvPicPr/></pic:nvPicPr>'
          '<pic:blipFill><a:blip r:embed="rId$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
          '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$extentW" cy="$extentH"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
          '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>');
      rels.writeln(
          '<Relationship Id="rId$relId" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
          'Target="media/$mediaName"/>');
      archive.addFile(ArchiveFile('word/media/$mediaName', bytes.length, bytes));
      relId++;
    }
    onProgress?.call(e + 1, entries.length);
  }

  body.write(
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" '
      'w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>'
      '</w:body></w:document>');

  final documentXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="jpg" ContentType="image/jpeg"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Default Extension="gif" ContentType="image/gif"/>'
      '<Default Extension="bmp" ContentType="image/bmp"/>'
      '<Default Extension="webp" ContentType="image/webp"/>'
      '<Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';

  final rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/></Relationships>';

  final docRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${rels.toString()}</Relationships>';

  archive.addFile(ArchiveFile('[Content_Types].xml', documentXml.length,
      utf8.encode(documentXml)));
  archive.addFile(ArchiveFile('_rels/.rels', rootRels.length,
      utf8.encode(rootRels)));
  archive.addFile(ArchiveFile('word/document.xml', body.length,
      utf8.encode(body.toString())));
  archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRels.length,
      utf8.encode(docRels)));

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// 生成 .pdf：每篇日记一页，内嵌子集化仿宋字体，含日期、标题、正文与图片。
Future<Uint8List> buildPdfDocument(
  List<ExportEntryDoc> entries, {
  required ByteData fontData,
  required Future<Uint8List?> Function(String path) loadImageBytes,
  void Function(int done, int total)? onProgress,
}) async {
  final font = pw.Font.ttf(fontData);
  final doc = pw.Document();

  for (int e = 0; e < entries.length; e++) {
    final entry = entries[e];
    final blocks = <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 18),
        child: pw.Text(
          entry.date,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: font,
            fontSize: 10.5,
            color: const PdfColor.fromInt(0xFF808080),
          ),
        ),
      ),
    ];
    if (entry.title != null && entry.title!.isNotEmpty) {
      blocks.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Text(
          entry.title!,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: font,
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ));
    }
    for (final line in entry.text.split('\n')) {
      blocks.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          line,
          style: pw.TextStyle(font: font, fontSize: 11.5, lineSpacing: 1.8),
        ),
      ));
    }
    for (final img in entry.images) {
      final bytes = await loadImageBytes(img.path);
      if (bytes == null) continue;
      final size = await _imagePixelSize(bytes);
      if (size == null) continue;
      final fit = _fitSize(
        size.$1,
        size.$2,
        PdfPageFormat.a4.availableWidth - 40,
        480,
      );
      blocks.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        child: pw.Center(
          child: pw.Image(
            pw.MemoryImage(bytes),
            width: fit.$1,
            height: fit.$2,
          ),
        ),
      ));
    }
    // 每篇日记从新的一页开始；内容过长时自动续页。
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(56),
      maxPages: 10000,
      build: (_) => blocks,
    ));
    onProgress?.call(e + 1, entries.length);
  }

  return doc.save();
}

(double, double) _fitSize(int w, int h, double maxW, double maxH) {
  var scale = 1.0;
  if (w > maxW) scale = maxW / w;
  if (h * scale > maxH) scale = maxH / h;
  return (w * scale, h * scale);
}

String _imageExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return 'jpg';
  var ext = fileName.substring(dot + 1).toLowerCase();
  if (!['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
    ext = 'jpg';
  }
  return ext == 'jpeg' ? 'jpg' : ext;
}
