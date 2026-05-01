import 'dart:convert';
import 'dart:typed_data';

import 'package:catchline/data/sync/drive_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _ok(Object body) => http.Response(
      body is String ? body : jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('listAll', () {
    test('walks pages until nextPageToken is gone', () async {
      var call = 0;
      final client = DriveClient(MockClient((req) async {
        call++;
        expect(req.url.queryParameters['spaces'], 'appDataFolder');
        if (call == 1) {
          expect(req.url.queryParameters.containsKey('pageToken'), isFalse);
          return _ok({
            'nextPageToken': 'p2',
            'files': [
              {
                'id': 'f1',
                'name': 'manifest.json',
                'headRevisionId': 'rev1',
                'size': '12',
              },
            ],
          });
        }
        expect(req.url.queryParameters['pageToken'], 'p2');
        return _ok({
          'files': [
            {
              'id': 'f2',
              'name': 'items/abc.json',
              'headRevisionId': 'rev2',
              'size': '34',
            },
          ],
        });
      }));

      final files = await client.listAll();
      expect(call, 2);
      expect(files.map((f) => f.id), ['f1', 'f2']);
      expect(files.first.size, 12);
    });

    test('throws DriveApiException on non-2xx', () async {
      final client = DriveClient(MockClient((req) async {
        return http.Response('boom', 500);
      }));
      await expectLater(
        client.listAll(),
        throwsA(isA<DriveApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          500,
        )),
      );
    });
  });

  group('findByName', () {
    test('returns null when no files match', () async {
      final client = DriveClient(MockClient((req) async {
        expect(req.url.queryParameters['q'], contains("name = 'manifest.json'"));
        return _ok({'files': []});
      }));
      final hit = await client.findByName('manifest.json');
      expect(hit, isNull);
    });

    test('escapes single quotes in the name', () async {
      String? seenQ;
      final client = DriveClient(MockClient((req) async {
        seenQ = req.url.queryParameters['q'];
        return _ok({'files': []});
      }));
      await client.findByName("don't.json");
      expect(seenQ, contains(r"don\'t.json"));
    });

    test('returns the first file when one matches', () async {
      final client = DriveClient(MockClient((req) async {
        return _ok({
          'files': [
            {
              'id': 'fid',
              'name': 'manifest.json',
              'headRevisionId': 'r',
              'size': '7',
            },
          ],
        });
      }));
      final hit = await client.findByName('manifest.json');
      expect(hit, isNotNull);
      expect(hit!.id, 'fid');
      expect(hit.size, 7);
    });
  });

  group('downloadJson', () {
    test('GETs the file with alt=media and decodes JSON', () async {
      Uri? seen;
      final client = DriveClient(MockClient((req) async {
        seen = req.url;
        return _ok({'hello': 'world'});
      }));
      final out = await client.downloadJson('file-abc');
      expect(out, {'hello': 'world'});
      expect(seen!.path, endsWith('/files/file-abc'));
      expect(seen!.queryParameters['alt'], 'media');
    });
  });

  group('downloadBytes', () {
    test('returns the response body bytes', () async {
      final client = DriveClient(MockClient((req) async {
        return http.Response.bytes([0x01, 0x02, 0x03], 200);
      }));
      final out = await client.downloadBytes('id');
      expect(out, Uint8List.fromList([0x01, 0x02, 0x03]));
    });
  });

  group('createJson', () {
    test('POSTs multipart and returns parsed metadata', () async {
      late http.Request seen;
      final client = DriveClient(MockClient((req) async {
        seen = req;
        return _ok({
          'id': 'newid',
          'name': 'manifest.json',
          'headRevisionId': 'rev9',
          'size': '5',
        });
      }));

      final out = await client.createJson(
        name: 'manifest.json',
        content: {'k': 'v'},
      );

      expect(seen.method, 'POST');
      expect(seen.url.toString(), contains('uploadType=multipart'));
      expect(
        seen.headers['content-type'] ?? seen.headers['Content-Type'],
        startsWith('multipart/related'),
      );
      // Body should embed both the metadata JSON and the content payload.
      expect(seen.body, contains('"name":"manifest.json"'));
      expect(seen.body, contains('"k":"v"'));
      expect(out.id, 'newid');
      expect(out.headRevisionId, 'rev9');
    });
  });

  group('updateJson', () {
    test('PATCHes with If-Match header and returns parsed metadata', () async {
      late http.Request seen;
      final client = DriveClient(MockClient((req) async {
        seen = req;
        return _ok({
          'id': 'fid',
          'name': 'manifest.json',
          'headRevisionId': 'rev2',
          'size': '11',
        });
      }));

      final out = await client.updateJson(
        fileId: 'fid',
        content: {'a': 1},
        ifMatch: 'rev1',
      );

      expect(seen.method, 'PATCH');
      expect(seen.url.toString(), contains('/files/fid'));
      expect(seen.url.queryParameters['uploadType'], 'media');
      expect(seen.headers['If-Match'], 'rev1');
      expect(out.headRevisionId, 'rev2');
    });

    test('throws DriveEtagMismatch on 412', () async {
      final client = DriveClient(MockClient((req) async {
        return http.Response('precondition failed', 412);
      }));
      await expectLater(
        client.updateJson(
          fileId: 'fid',
          content: const {},
          ifMatch: 'stale',
        ),
        throwsA(isA<DriveEtagMismatch>()),
      );
    });

    test('omits If-Match when not provided', () async {
      late http.Request seen;
      final client = DriveClient(MockClient((req) async {
        seen = req;
        return _ok({
          'id': 'fid',
          'name': 'manifest.json',
          'headRevisionId': 'rev2',
          'size': '11',
        });
      }));
      await client.updateJson(fileId: 'fid', content: const {});
      expect(seen.headers.containsKey('If-Match'), isFalse);
    });
  });

  group('deleteFile', () {
    test('treats a 404 as success', () async {
      final client = DriveClient(MockClient((req) async {
        expect(req.method, 'DELETE');
        return http.Response('', 404);
      }));
      await client.deleteFile('gone');
    });

    test('throws on a non-2xx that is not 404', () async {
      final client = DriveClient(MockClient((req) async {
        return http.Response('forbidden', 403);
      }));
      await expectLater(
        client.deleteFile('id'),
        throwsA(isA<DriveApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          403,
        )),
      );
    });
  });

  group('DriveFile.fromJson', () {
    test('parses size as int and tolerates missing optional fields', () {
      final f = DriveFile.fromJson({
        'id': 'x',
        'name': 'n',
        'size': '42',
      });
      expect(f.size, 42);
      expect(f.headRevisionId, isNull);
    });

    test('falls back to 0 when size is absent or unparseable', () {
      final f = DriveFile.fromJson({'id': 'x'});
      expect(f.size, 0);
      expect(f.name, '');
    });
  });
}
