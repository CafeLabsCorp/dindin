import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';

import '../models/db.dart';
import 'firestore_service.dart';

/// Backup/restore for a user's data as a `.json` file in the same shape as
/// the Next.js app's `data/db.json` (see `next/src/lib/schemas.ts`).
class ImportExportService {
  final FirestoreService firestore;

  ImportExportService(this.firestore);

  Future<void> exportToFile() async {
    final db = await firestore.fetchAll();
    final json = const JsonEncoder.withIndent('  ').convert(db.toJson());
    final bytes = Uint8List.fromList(utf8.encode(json));
    await FileSaver.instance.saveFile(
      name: 'dindin-backup',
      bytes: bytes,
      fileExtension: 'json',
      mimeType: MimeType.json,
    );
  }

  /// Returns null if the user cancelled the file picker.
  Future<AppDb?> pickAndParseFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (file == null) return null;
    final content = await file.readAsString();
    return AppDb.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }

  Future<void> importFromFile(AppDb db) => firestore.replaceAll(db);
}
