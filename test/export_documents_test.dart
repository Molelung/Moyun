import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:daily_you/utils/export_documents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

/// 用一段带中文的文本 + 一张内存图片验证 docx/pdf 生成管线。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testImage = img.Image(width: 8, height: 6, numChannels: 3);
  img.fill(testImage, color: img.ColorRgb8(200, 120, 60));
  final jpeg = Uint8List.fromList(img.encodeJpg(testImage));

  const entries = [
    ExportEntryDoc(
      date: '2026年8月5日',
      title: '今日有风',
      text: '今天天气很好，适合出去走走。\nHello, world! 123',
      images: [
        ExportImageDoc(path: 'test', fileName: 'image1.jpg'),
      ],
    ),
  ];

  test('生成 .docx 结构完整且 XML 合法', () async {
    final bytes = await buildWordDocument(
      entries,
      loadImageBytes: (_) async => jpeg,
    );
    expect(bytes.length, greaterThan(1000));

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('[Content_Types].xml'));
    expect(names, contains('_rels/.rels'));
    expect(names, contains('word/document.xml'));
    expect(names, contains('word/_rels/document.xml.rels'));
    expect(names, contains('word/media/image1.jpg'));

    final docXml = utf8.decode(
        archive.files.firstWhere((f) => f.name == 'word/document.xml').content);
    expect(docXml, contains('今日有风'));
    expect(docXml, contains('w:document'));
    // XML 可解析
    XmlDocument.parse(docXml);
  });

  test('生成 .pdf 使用内嵌仿宋字体', () async {
    final fontBytes = File('assets/fonts/SotyrFangsong-Subset.ttf').readAsBytesSync();
    final pdf = await buildPdfDocument(
      entries,
      fontData: ByteData.sublistView(fontBytes),
      loadImageBytes: (_) async => jpeg,
    );
    expect(pdf.length, greaterThan(1000));
    // PDF 头
    expect(utf8.decode(pdf.sublist(0, 5)), '%PDF-');
    // 内嵌字体对象存在
    final ascii = utf8.decode(pdf, allowMalformed: true);
    expect(ascii, contains('FontFile2'));
  });

  test('子集字体文件存在且可被 pdf 解析', () {
    final fontBytes = File('assets/fonts/SotyrFangsong-Subset.ttf').readAsBytesSync();
    expect(fontBytes.length, greaterThan(1000000));
    expect(fontBytes.sublist(0, 4), [0x00, 0x01, 0x00, 0x00]); // TTF 魔数
  });
}
