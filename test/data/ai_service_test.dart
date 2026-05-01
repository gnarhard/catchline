import 'dart:convert';

import 'package:catchline/data/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _ok(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200, headers: {
      'content-type': 'application/json',
    });

http.Response _err(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status, headers: {
      'content-type': 'application/json',
    });

Map<String, dynamic> _textBody(String text) => {
  'content': [
    {'type': 'text', 'text': text},
  ],
};

void main() {
  group('generateJournalSynopsis', () {
    test('returns the text block trimmed', () async {
      late http.Request seen;
      final svc = AiService(
        client: MockClient((req) async {
          seen = req;
          return _ok(_textBody('   tight summary.   '));
        }),
      );

      final out = await svc.generateJournalSynopsis(
        apiKey: 'sk-test',
        entryBody: 'Today felt long but full.',
      );

      expect(out, 'tight summary.');
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(seen.headers['x-api-key'], 'sk-test');
      expect(seen.headers['anthropic-version'], '2023-06-01');
      final json = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(json['model'], 'claude-sonnet-4-6');
      final messages = json['messages'] as List;
      expect(
        (messages.first as Map)['content'],
        contains('Today felt long but full.'),
      );
    });

    test('rejects empty entry body without hitting the network', () async {
      var called = false;
      final svc = AiService(
        client: MockClient((req) async {
          called = true;
          return _ok(_textBody('nope'));
        }),
      );

      await expectLater(
        svc.generateJournalSynopsis(apiKey: 'sk', entryBody: '   '),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('Write something'),
        )),
      );
      expect(called, isFalse);
    });

    test('maps 401 to an "Invalid API key" message', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _err(401, {
            'error': {'type': 'authentication_error', 'message': 'bad key'},
          });
        }),
      );

      await expectLater(
        svc.generateJournalSynopsis(apiKey: 'sk', entryBody: 'hi'),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('Invalid API key'),
        )),
      );
    });

    test('maps 429 to a rate-limit message', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _err(429, {
            'error': {'type': 'rate_limit_error', 'message': 'slow down'},
          });
        }),
      );

      await expectLater(
        svc.generateJournalSynopsis(apiKey: 'sk', entryBody: 'hi'),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('Rate limited'),
        )),
      );
    });

    test('falls back to a generic message when the body is unparseable',
        () async {
      final svc = AiService(
        client: MockClient((req) async {
          return http.Response('<html>oops</html>', 500);
        }),
      );

      await expectLater(
        svc.generateJournalSynopsis(apiKey: 'sk', entryBody: 'hi'),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('Anthropic API error (500)'),
        )),
      );
    });

    test('throws when the response shape is unexpected', () async {
      final svc = AiService(
        client: MockClient((req) async => _ok({'no_content': true})),
      );
      await expectLater(
        svc.generateJournalSynopsis(apiKey: 'sk', entryBody: 'hi'),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('Unexpected response shape'),
        )),
      );
    });

    test('throws when the model returns an empty text block', () async {
      final svc = AiService(
        client: MockClient((req) async => _ok(_textBody(''))),
      );
      await expectLater(
        svc.generateJournalSynopsis(apiKey: 'sk', entryBody: 'hi'),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('Empty response'),
        )),
      );
    });
  });

  group('rephraseInStyles', () {
    test('parses a clean JSON object and keeps only requested styles',
        () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody(jsonEncode({
            'Hozier': 'A whisper through the rushes.',
            'Plato': 'A form glimpsed beyond the veil.',
            'Extra': 'should be filtered out',
          })));
        }),
      );

      final result = await svc.rephraseInStyles(
        apiKey: 'sk',
        phrase: 'love finds a way',
        styles: ['Hozier', 'Plato'],
      );

      expect(result.keys, ['Hozier', 'Plato']);
      expect(result['Hozier'], 'A whisper through the rushes.');
      expect(result['Plato'], 'A form glimpsed beyond the veil.');
    });

    test('strips ```json fences before parsing', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(
            _textBody('```json\n{"Hozier": "in green hush"}\n```'),
          );
        }),
      );

      final result = await svc.rephraseInStyles(
        apiKey: 'sk',
        phrase: 'p',
        styles: ['Hozier'],
      );
      expect(result['Hozier'], 'in green hush');
    });

    test('tolerates leading/trailing prose around the JSON object', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody(
              'Sure, here you go: {"Hozier": "the moor remembers"} cheers'));
        }),
      );

      final result = await svc.rephraseInStyles(
        apiKey: 'sk',
        phrase: 'p',
        styles: ['Hozier'],
      );
      expect(result['Hozier'], 'the moor remembers');
    });

    test('skips empty/whitespace style values', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody(jsonEncode({
            'Hozier': '   ',
            'Plato': 'wisdom',
          })));
        }),
      );

      final result = await svc.rephraseInStyles(
        apiKey: 'sk',
        phrase: 'p',
        styles: ['Hozier', 'Plato'],
      );
      expect(result.containsKey('Hozier'), isFalse);
      expect(result['Plato'], 'wisdom');
    });

    test('throws when no requested styles match the response', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody(jsonEncode({'Other': 'x'})));
        }),
      );
      await expectLater(
        svc.rephraseInStyles(
          apiKey: 'sk',
          phrase: 'p',
          styles: ['Hozier'],
        ),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('did not return any rephrasings'),
        )),
      );
    });

    test('throws if the model returns text without a JSON object', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('I cannot help with that.'));
        }),
      );
      await expectLater(
        svc.rephraseInStyles(
          apiKey: 'sk',
          phrase: 'p',
          styles: ['Hozier'],
        ),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('Could not parse JSON'),
        )),
      );
    });

    test('rejects empty phrase before hitting the network', () async {
      var called = false;
      final svc = AiService(
        client: MockClient((req) async {
          called = true;
          return _ok(_textBody('{}'));
        }),
      );
      await expectLater(
        svc.rephraseInStyles(
          apiKey: 'sk',
          phrase: '   ',
          styles: ['Hozier'],
        ),
        throwsA(isA<AiException>()),
      );
      expect(called, isFalse);
    });

    test('rejects empty styles list before hitting the network', () async {
      var called = false;
      final svc = AiService(
        client: MockClient((req) async {
          called = true;
          return _ok(_textBody('{}'));
        }),
      );
      await expectLater(
        svc.rephraseInStyles(
          apiKey: 'sk',
          phrase: 'phrase',
          styles: const [],
        ),
        throwsA(isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('at least one style'),
        )),
      );
      expect(called, isFalse);
    });
  });
}
