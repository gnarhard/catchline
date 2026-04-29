import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thrown when an `If-Match` precondition fails on a conditional manifest
/// write. The sync engine catches this to re-merge and retry.
class DriveEtagMismatch implements Exception {
  const DriveEtagMismatch(this.message);
  final String message;
  @override
  String toString() => 'DriveEtagMismatch: $message';
}

class DriveApiException implements Exception {
  DriveApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'DriveApiException($statusCode): $message';
}

/// Minimal projection of a Drive file we care about.
class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.headRevisionId,
    required this.size,
  });

  final String id;
  final String name;

  /// Per-file revision identifier. Used as the value for `If-Match` on
  /// conditional updates. `null` for newly-listed files that haven't been
  /// queried for revision metadata.
  final String? headRevisionId;
  final int size;

  static DriveFile fromJson(Map<String, dynamic> json) => DriveFile(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    headRevisionId: json['headRevisionId'] as String?,
    size: int.tryParse((json['size'] as String?) ?? '') ?? 0,
  );
}

/// Drive REST v3 client scoped to the app's `appDataFolder`. Only the
/// endpoints Catchline needs.
///
/// All requests go through the auth-injecting `http.Client` produced by
/// [GoogleAuth.getAuthedClient]. We bypass the `googleapis` package because
/// it does not expose per-request headers (notably `If-Match`).
class DriveClient {
  DriveClient(this._client);

  final http.Client _client;

  static const String _filesEndpoint =
      'https://www.googleapis.com/drive/v3/files';
  static const String _uploadEndpoint =
      'https://www.googleapis.com/upload/drive/v3/files';
  static const String _appDataParent = 'appDataFolder';

  static const String _metaFields = 'id,name,headRevisionId,size';

  /// Lists every file in the app's `appDataFolder`. Pages through results.
  Future<List<DriveFile>> listAll() async {
    final out = <DriveFile>[];
    String? pageToken;
    do {
      final uri = Uri.parse(_filesEndpoint).replace(
        queryParameters: {
          'spaces': _appDataParent,
          'pageSize': '1000',
          'fields': 'nextPageToken,files($_metaFields)',
          'pageToken': ?pageToken,
        },
      );
      final resp = await _client.get(uri);
      _check(resp);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final files = (body['files'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(DriveFile.fromJson);
      out.addAll(files);
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null);
    return out;
  }

  /// Looks up a single file by exact name within the appdata folder. Returns
  /// the most recently modified match, or `null` if none exist.
  Future<DriveFile?> findByName(String name) async {
    final escaped = name.replaceAll("'", r"\'");
    final uri = Uri.parse(_filesEndpoint).replace(
      queryParameters: {
        'spaces': _appDataParent,
        'q': "name = '$escaped' and trashed = false",
        'orderBy': 'modifiedTime desc',
        'pageSize': '1',
        'fields': 'files($_metaFields)',
      },
    );
    final resp = await _client.get(uri);
    _check(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = (body['files'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    if (files.isEmpty) return null;
    return DriveFile.fromJson(files.first);
  }

  /// Downloads the bytes of a file.
  Future<Uint8List> downloadBytes(String fileId) async {
    final uri = Uri.parse(
      '$_filesEndpoint/$fileId',
    ).replace(queryParameters: {'alt': 'media'});
    final resp = await _client.get(uri);
    _check(resp);
    return Uint8List.fromList(resp.bodyBytes);
  }

  /// Convenience: downloads a file and decodes UTF-8 JSON.
  Future<Map<String, dynamic>> downloadJson(String fileId) async {
    final bytes = await downloadBytes(fileId);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  /// Creates a new file in the appdata folder with the given JSON content.
  /// Returns the new file's metadata.
  Future<DriveFile> createJson({
    required String name,
    required Map<String, dynamic> content,
  }) {
    return _createFile(
      name: name,
      mimeType: 'application/json',
      bytes: utf8.encode(jsonEncode(content)),
    );
  }

  /// Creates a new file in the appdata folder with the given binary content.
  Future<DriveFile> createBinary({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) {
    return _createFile(name: name, mimeType: mimeType, bytes: bytes);
  }

  Future<DriveFile> _createFile({
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final boundary = 'catchline_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': name,
      'parents': [_appDataParent],
    });
    final body = <int>[];
    body.addAll(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: $mimeType\r\n\r\n',
      ),
    );
    body.addAll(bytes);
    body.addAll(utf8.encode('\r\n--$boundary--'));

    final uri = Uri.parse(_uploadEndpoint).replace(
      queryParameters: {'uploadType': 'multipart', 'fields': _metaFields},
    );
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'multipart/related; boundary=$boundary'},
      body: body,
    );
    _check(resp);
    return DriveFile.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Replaces the content of an existing file. If [ifMatch] is provided, the
  /// update is conditional on the file's current `headRevisionId`; mismatch
  /// throws [DriveEtagMismatch] so the caller can re-merge and retry.
  Future<DriveFile> updateJson({
    required String fileId,
    required Map<String, dynamic> content,
    String? ifMatch,
  }) {
    return _updateFileContent(
      fileId: fileId,
      mimeType: 'application/json',
      bytes: utf8.encode(jsonEncode(content)),
      ifMatch: ifMatch,
    );
  }

  Future<DriveFile> _updateFileContent({
    required String fileId,
    required String mimeType,
    required List<int> bytes,
    String? ifMatch,
  }) async {
    final uri = Uri.parse(
      '$_uploadEndpoint/$fileId',
    ).replace(queryParameters: {'uploadType': 'media', 'fields': _metaFields});
    final headers = <String, String>{
      'Content-Type': mimeType,
      'If-Match': ?ifMatch,
    };
    final resp = await _client.patch(uri, headers: headers, body: bytes);
    if (resp.statusCode == 412) {
      throw const DriveEtagMismatch(
        'Manifest changed on Drive since last read; re-merge required.',
      );
    }
    _check(resp);
    return DriveFile.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> deleteFile(String fileId) async {
    final uri = Uri.parse('$_filesEndpoint/$fileId');
    final resp = await _client.delete(uri);
    if (resp.statusCode == 404) return; // already gone, fine
    _check(resp);
  }

  void _check(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw DriveApiException(
      resp.statusCode,
      resp.body.isEmpty ? resp.reasonPhrase ?? '' : resp.body,
    );
  }
}
