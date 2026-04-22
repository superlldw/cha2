import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/offline/local_db.dart';
import '../../core/offline/local_structure_store.dart';

class LocalExportService {
  LocalExportService(this._localDb);

  final LocalDb _localDb;

  Future<String> exportPhotoPackage(String taskId) async {
    final task = await _requireTask(taskId);
    final projectId = task['project_id']?.toString() ?? '';
    final structures = await _listReportStructures(projectId);
    final captures = await _localDb.listTaskCaptures(taskId, reviewStatus: 'confirmed');
    final structureMap = {
      for (final row in structures) row['instance_id']?.toString() ?? '': row,
    };

    final exportDir = await _ensureTaskExportDir(taskId);
    final fileName = '照片打包导出_${_safeName(task['reservoir_name']?.toString() ?? taskId, maxLength: 24)}_${_nowSuffix()}.zip';
    final file = File(p.join(exportDir.path, fileName));

    final archive = Archive();
    var exportedCount = 0;

    for (final capture in captures) {
      final captureId = capture['capture_id']?.toString() ?? '';
      final structureId = capture['structure_instance_id']?.toString() ?? '';
      final structure = structureMap[structureId];
      if (captureId.isEmpty || structure == null) {
        continue;
      }

      final medias = await _localDb.listCaptureMedia(captureId);
      final instanceName = structure['instance_name']?.toString() ?? '未命名对象';
      final templateSourceType =
          structure['template_source_type']?.toString() ?? 'main_dam';
      final partCode = capture['part_code']?.toString() ?? '';
      final partName = LocalStructureStore.getPartName(
            templateSourceType,
            partCode,
          ) ??
          (partCode.isEmpty ? '未命名部位' : partCode);
      final folderName = _safeName(instanceName, maxLength: 40);
      final note = _shortNote(
        capture['speech_text']?.toString(),
        capture['raw_note']?.toString(),
      );

      var index = 0;
      for (final media in medias) {
        if ((media['media_type']?.toString() ?? 'photo') != 'photo') {
          continue;
        }
        final localPath = media['local_path']?.toString();
        if (localPath == null || localPath.trim().isEmpty) {
          continue;
        }
        final source = File(localPath);
        if (!await source.exists()) {
          continue;
        }
        final bytes = await source.readAsBytes();
        final ext = p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
        final baseName = [
          _safeName(instanceName, maxLength: 18),
          _safeName(partName, maxLength: 18),
          _safeName(note, maxLength: 18),
        ].join('_');
        final suffix = index > 0 ? '_${index + 1}' : '';
        archive.addFile(
          ArchiveFile(
            '$folderName/$baseName$suffix$ext',
            bytes.length,
            bytes,
          ),
        );
        index += 1;
        exportedCount += 1;
      }
    }

    if (exportedCount == 0) {
      final content = utf8.encode('当前任务还没有可导出的已归档照片，或照片文件已经不存在。');
      archive.addFile(ArchiveFile('导出说明.txt', content.length, content));
    }

    final output = ZipEncoder().encode(archive);
    if (output == null) {
      throw Exception('照片打包失败');
    }
    await file.writeAsBytes(output, flush: true);
    return file.path;
  }

  Future<String> exportInspectionDoc(String taskId) async {
    final task = await _requireTask(taskId);
    final projectId = task['project_id']?.toString() ?? '';
    final project = await _localDb.getProject(projectId);
    if (project == null) {
      throw Exception('未找到所属项目');
    }

    final structures = await _listReportStructures(projectId);
    final captures = await _localDb.listTaskCaptures(taskId, reviewStatus: 'confirmed');
    final notesByPart = <String, List<String>>{};
    final abnormalNotes = <String>[];

    for (final capture in captures) {
      final structureId = capture['structure_instance_id']?.toString() ?? '';
      final partCode = capture['part_code']?.toString() ?? '';
      final note = _combineNote(
        capture['speech_text']?.toString(),
        capture['raw_note']?.toString(),
      );
      if (structureId.isEmpty || partCode.isEmpty || note.isEmpty) {
        continue;
      }
      final key = '$structureId::$partCode';
      notesByPart.putIfAbsent(key, () => <String>[]).add(note);
      if ((capture['quick_status']?.toString() ?? '') == 'abnormal') {
        abnormalNotes.add(note);
      }
    }

    final documentXml = _buildDocumentXml(
      reservoirName: project['reservoir_name']?.toString() ?? '',
      task: task,
      structures: structures,
      notesByPart: notesByPart,
      abnormalNotes: abnormalNotes,
    );

    final exportDir = await _ensureTaskExportDir(taskId);
    final fileName = '检查表导出_${_safeName(project['reservoir_name']?.toString() ?? taskId, maxLength: 24)}_${_nowSuffix()}.docx';
    final file = File(p.join(exportDir.path, fileName));

    final contentTypesBytes = utf8.encode(_contentTypesXml);
    final relsBytes = utf8.encode(_relsXml);
    final appBytes = utf8.encode(_appXml);
    final coreBytes = utf8.encode(_coreXml);
    final stylesBytes = utf8.encode(_stylesXml);
    final documentBytes = utf8.encode(documentXml);
    final documentRelsBytes = utf8.encode(_documentRelsXml);

    final archive = Archive()
      ..addFile(ArchiveFile(
        '[Content_Types].xml',
        contentTypesBytes.length,
        contentTypesBytes,
      ))
      ..addFile(ArchiveFile(
        '_rels/.rels',
        relsBytes.length,
        relsBytes,
      ))
      ..addFile(ArchiveFile(
        'docProps/app.xml',
        appBytes.length,
        appBytes,
      ))
      ..addFile(ArchiveFile(
        'docProps/core.xml',
        coreBytes.length,
        coreBytes,
      ))
      ..addFile(ArchiveFile(
        'word/styles.xml',
        stylesBytes.length,
        stylesBytes,
      ))
      ..addFile(ArchiveFile(
        'word/document.xml',
        documentBytes.length,
        documentBytes,
      ))
      ..addFile(ArchiveFile(
        'word/_rels/document.xml.rels',
        documentRelsBytes.length,
        documentRelsBytes,
      ));

    final output = ZipEncoder().encode(archive);
    if (output == null) {
      throw Exception('检查表生成失败');
    }
    await file.writeAsBytes(output, flush: true);
    return file.path;
  }

  Future<Map<String, dynamic>> _requireTask(String taskId) async {
    final task = await _localDb.getTask(taskId);
    if (task == null) {
      throw Exception('未找到离线任务');
    }
    return task;
  }

  Future<List<Map<String, dynamic>>> _listReportStructures(String projectId) async {
    final rows = await _localDb.listStructureInstances(projectId);
    return rows
        .where((row) => (row['enabled_for_report'] as int? ?? 1) == 1)
        .toList()
      ..sort((a, b) => ((a['sort_order'] as int? ?? 9999))
          .compareTo(b['sort_order'] as int? ?? 9999));
  }

  Future<Directory> _ensureTaskExportDir(String taskId) async {
    final root = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'cha2_exports', taskId));
    await dir.create(recursive: true);
    return dir;
  }

  String _combineNote(String? speechText, String? rawNote) {
    final text = (speechText ?? '').trim();
    if (text.isNotEmpty) {
      return text;
    }
    return (rawNote ?? '').trim();
  }

  String _shortNote(String? speechText, String? rawNote) {
    final text = _combineNote(speechText, rawNote).replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) {
      return '无描述';
    }
    return text.length > 18 ? text.substring(0, 18) : text;
  }

  String _safeName(String value, {int maxLength = 24}) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n]+'), '_')
        .replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) {
      return '未命名';
    }
    return cleaned.length > maxLength ? cleaned.substring(0, maxLength) : cleaned;
  }

  String _nowSuffix() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _buildDocumentXml({
    required String reservoirName,
    required Map<String, dynamic> task,
    required List<Map<String, dynamic>> structures,
    required Map<String, List<String>> notesByPart,
    required List<String> abnormalNotes,
  }) {
    final body = StringBuffer();
    body.write(_paragraph('附录A 现场安全检查表',
        align: 'center', bold: true, sizeHalfPoints: 32));
    body.write(_paragraph('A.1 现场安全检查基本情况',
        align: 'center', bold: true, sizeHalfPoints: 28));

    final hubMainStructures = structures
        .map((row) => row['instance_name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .join('、');
    final basicRows = <List<String>>[
      ['水库名称及基本情况描述', reservoirName],
      ['枢纽工程主要建筑物', hubMainStructures],
      ['水库防洪保护对象', task['description']?.toString() ?? ''],
      ['检查时间', task['inspection_date']?.toString() ?? ''],
      ['天气', task['weather']?.toString() ?? ''],
      ['检查人员', ''],
      ['现场检查发现的主要问题描述',
        abnormalNotes.isEmpty ? '无' : abnormalNotes.take(8).join('；')],
    ];
    body.write(_table(
      rows: [
        for (final row in basicRows)
          [
            _cell(row[0], widthTwips: 3400, align: 'center'),
            _cell(row[1], widthTwips: 5600, align: 'left'),
          ],
      ],
    ));
    body.write(_paragraph('注：可根据工程实际情况增减表中内容。'));

    for (var index = 0; index < structures.length; index++) {
      final structure = structures[index];
      final instanceName = structure['instance_name']?.toString() ?? '未命名对象';
      final templateSourceType =
          structure['template_source_type']?.toString() ?? 'main_dam';
      body.write(_paragraph(
        'A.${index + 2} $instanceName现场安全检查情况',
        align: 'center',
        bold: true,
        sizeHalfPoints: 28,
      ));

      final partTemplates =
          LocalStructureStore.listStructurePartTemplates(templateSourceType);
      final rows = <List<String>>[
        [
          _cell('对象实例', widthTwips: 1800, align: 'center', bold: true),
          _cell('检查部位', widthTwips: 3200, align: 'center', bold: true),
          _cell('检查情况记录', widthTwips: 4200, align: 'center', bold: true),
        ],
      ];
      for (final part in partTemplates) {
        final partCode = part['part_code']?.toString() ?? '';
        final partName = part['part_name']?.toString() ?? partCode;
        final key = '${structure['instance_id']}::$partCode';
        final notes = notesByPart[key] ?? const <String>[];
        rows.add([
          _cell(instanceName, widthTwips: 1800, align: 'center'),
          _cell(partName, widthTwips: 3200, align: 'center'),
          _cell(notes.isEmpty ? '未检查' : notes.join('；'),
              widthTwips: 4200, align: 'left'),
        ]);
      }
      body.write(_table(rows: rows));
    }

    const section = '<w:sectPr>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1417" w:bottom="1440" w:left="1417" w:header="708" w:footer="708" w:gutter="0"/>'
        '</w:sectPr>';

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" '
        'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" '
        'xmlns:o="urn:schemas-microsoft-com:office:office" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" '
        'xmlns:v="urn:schemas-microsoft-com:vml" '
        'xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:w10="urn:schemas-microsoft-com:office:word" '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" '
        'xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" '
        'xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk" '
        'xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" '
        'xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" '
        'mc:Ignorable="w14 wp14">'
        '<w:body>$body$section</w:body>'
        '</w:document>';
  }

  String _table({required List<List<String>> rows}) {
    final rowsXml = rows
        .map((row) => '<w:tr>'
            '<w:trPr><w:trHeight w:val="454" w:hRule="atLeast"/></w:trPr>'
            '${row.join()}'
            '</w:tr>')
        .join();
    return '<w:tbl>'
        '<w:tblPr>'
        '<w:tblW w:w="5000" w:type="pct"/>'
        '<w:tblBorders>'
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
        '</w:tblBorders>'
        '<w:tblLayout w:type="fixed"/>'
        '</w:tblPr>'
        '$rowsXml'
        '</w:tbl>';
  }

  String _cell(
    String text, {
    required int widthTwips,
    String align = 'left',
    bool bold = false,
  }) {
    return '<w:tc>'
        '<w:tcPr>'
        '<w:tcW w:w="$widthTwips" w:type="dxa"/>'
        '<w:vAlign w:val="center"/>'
        '</w:tcPr>'
        '${_paragraph(text, align: align, bold: bold, insideTable: true)}'
        '</w:tc>';
  }

  String _paragraph(
    String text, {
    String align = 'left',
    bool bold = false,
    int sizeHalfPoints = 24,
    bool insideTable = false,
  }) {
    final paragraphTag = insideTable ? 'w:p' : 'w:p';
    final escaped = _xml(text);
    final boldTag = bold ? '<w:b/>' : '';
    return '<$paragraphTag>'
        '<w:pPr>'
        '<w:jc w:val="$align"/>'
        '<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>'
        '</w:pPr>'
        '<w:r>'
        '<w:rPr>'
        '$boldTag'
        '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="宋体"/>'
        '<w:sz w:val="$sizeHalfPoints"/>'
        '<w:szCs w:val="$sizeHalfPoints"/>'
        '</w:rPr>'
        '<w:t xml:space="preserve">$escaped</w:t>'
        '</w:r>'
        '</$paragraphTag>';
  }

  String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

const String _contentTypesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
    '</Types>';

const String _relsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
    '</Relationships>';

const String _appXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
    '<Application>cha2</Application>'
    '</Properties>';

const String _coreXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:dcterms="http://purl.org/dc/terms/" '
    'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    '<dc:title>现场安全检查表</dc:title>'
    '<dc:creator>cha2</dc:creator>'
    '</cp:coreProperties>';

const String _stylesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:docDefaults>'
    '<w:rPrDefault><w:rPr>'
    '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="宋体"/>'
    '<w:sz w:val="24"/><w:szCs w:val="24"/>'
    '</w:rPr></w:rPrDefault>'
    '<w:pPrDefault><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:pPrDefault>'
    '</w:docDefaults>'
    '</w:styles>';

const String _documentRelsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';
