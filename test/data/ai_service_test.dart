import 'dart:convert';

import 'package:catchline/data/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _ok(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _err(int status, Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

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
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Write something'),
          ),
        ),
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
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Invalid API key'),
          ),
        ),
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
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Rate limited'),
          ),
        ),
      );
    });

    test(
      'falls back to a generic message when the body is unparseable',
      () async {
        final svc = AiService(
          client: MockClient((req) async {
            return http.Response('<html>oops</html>', 500);
          }),
        );

        await expectLater(
          svc.generateJournalSynopsis(apiKey: 'sk', entryBody: 'hi'),
          throwsA(
            isA<AiException>().having(
              (e) => e.message,
              'message',
              contains('Anthropic API error (500)'),
            ),
          ),
        );
      },
    );

    test('throws when the response shape is unexpected', () async {
      final svc = AiService(
        client: MockClient((req) async => _ok({'no_content': true})),
      );
      await expectLater(
        svc.generateJournalSynopsis(apiKey: 'sk', entryBody: 'hi'),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Unexpected response shape'),
          ),
        ),
      );
    });

    test('throws when the model returns an empty text block', () async {
      final svc = AiService(
        client: MockClient((req) async => _ok(_textBody(''))),
      );
      await expectLater(
        svc.generateJournalSynopsis(apiKey: 'sk', entryBody: 'hi'),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Empty response'),
          ),
        ),
      );
    });
  });

  group('rephraseInStyles', () {
    test(
      'parses a clean JSON object and keeps only requested styles',
      () async {
        final svc = AiService(
          client: MockClient((req) async {
            return _ok(
              _textBody(
                jsonEncode({
                  'Hozier': 'A whisper through the rushes.',
                  'Plato': 'A form glimpsed beyond the veil.',
                  'Extra': 'should be filtered out',
                }),
              ),
            );
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
      },
    );

    test('strips ```json fences before parsing', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('```json\n{"Hozier": "in green hush"}\n```'));
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
          return _ok(
            _textBody(
              'Sure, here you go: {"Hozier": "the moor remembers"} cheers',
            ),
          );
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
          return _ok(
            _textBody(jsonEncode({'Hozier': '   ', 'Plato': 'wisdom'})),
          );
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
        svc.rephraseInStyles(apiKey: 'sk', phrase: 'p', styles: ['Hozier']),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('did not return any rephrasings'),
          ),
        ),
      );
    });

    test('throws if the model returns text without a JSON object', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('I cannot help with that.'));
        }),
      );
      await expectLater(
        svc.rephraseInStyles(apiKey: 'sk', phrase: 'p', styles: ['Hozier']),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Could not parse JSON'),
          ),
        ),
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
        svc.rephraseInStyles(apiKey: 'sk', phrase: '   ', styles: ['Hozier']),
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
        svc.rephraseInStyles(apiKey: 'sk', phrase: 'phrase', styles: const []),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('at least one style'),
          ),
        ),
      );
      expect(called, isFalse);
    });
  });

  group('suggestPoemTitle', () {
    test('returns the trimmed title text', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('  A Slow Leak  '));
        }),
      );
      final out = await svc.suggestPoemTitle(
        apiKey: 'sk',
        poemBody: 'I am a slow leak / in a fast room',
      );
      expect(out, 'A Slow Leak');
    });

    test('strips surrounding quotes', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('"A Slow Leak"'));
        }),
      );
      final out = await svc.suggestPoemTitle(apiKey: 'sk', poemBody: 'body');
      expect(out, 'A Slow Leak');
    });

    test('strips trailing punctuation', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('Plain Hours.'));
        }),
      );
      final out = await svc.suggestPoemTitle(apiKey: 'sk', poemBody: 'body');
      expect(out, 'Plain Hours');
    });

    test('strips smart quotes', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('“For The Hours That Don\'t Count”'));
        }),
      );
      final out = await svc.suggestPoemTitle(apiKey: 'sk', poemBody: 'body');
      expect(out, 'For The Hours That Don\'t Count');
    });

    test('rejects empty body before hitting the network', () async {
      var called = false;
      final svc = AiService(
        client: MockClient((req) async {
          called = true;
          return _ok(_textBody('x'));
        }),
      );
      await expectLater(
        svc.suggestPoemTitle(apiKey: 'sk', poemBody: '   '),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Write some of the poem'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('throws if the model returns a punctuation-only title', () async {
      final svc = AiService(
        client: MockClient((req) async => _ok(_textBody('???'))),
      );
      await expectLater(
        svc.suggestPoemTitle(apiKey: 'sk', poemBody: 'body'),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Empty title'),
          ),
        ),
      );
    });
  });

  group('continuePoem', () {
    test(
      'returns the trimmed continuation, preserving inner line breaks',
      () async {
        late http.Request seen;
        final svc = AiService(
          client: MockClient((req) async {
            seen = req;
            return _ok(_textBody('\n  the walls keep moving.\n  I keep —\n'));
          }),
        );
        final out = await svc.continuePoem(
          apiKey: 'sk',
          poemBody: 'I am a slow leak in a fast room.',
        );
        expect(out, 'the walls keep moving.\n  I keep —');
        // No title -> the body content omits the title prefix.
        final json = jsonDecode(seen.body) as Map<String, dynamic>;
        final messages = json['messages'] as List;
        expect(
          (messages.first as Map)['content'],
          startsWith('Existing poem:\n\n'),
        );
      },
    );

    test('passes the title through when provided', () async {
      late http.Request seen;
      final svc = AiService(
        client: MockClient((req) async {
          seen = req;
          return _ok(_textBody('more lines'));
        }),
      );
      await svc.continuePoem(
        apiKey: 'sk',
        poemBody: 'body',
        title: 'A Slow Leak',
      );
      final json = jsonDecode(seen.body) as Map<String, dynamic>;
      final content =
          ((json['messages'] as List).first as Map)['content'] as String;
      expect(content, contains('title: A Slow Leak'));
    });

    test('omits title prefix when the title is whitespace', () async {
      late http.Request seen;
      final svc = AiService(
        client: MockClient((req) async {
          seen = req;
          return _ok(_textBody('x'));
        }),
      );
      await svc.continuePoem(apiKey: 'sk', poemBody: 'body', title: '   ');
      final json = jsonDecode(seen.body) as Map<String, dynamic>;
      final content =
          ((json['messages'] as List).first as Map)['content'] as String;
      expect(content, startsWith('Existing poem:\n\n'));
      expect(content, isNot(contains('title:')));
    });

    test('rejects empty body before hitting the network', () async {
      var called = false;
      final svc = AiService(
        client: MockClient((req) async {
          called = true;
          return _ok(_textBody('x'));
        }),
      );
      await expectLater(
        svc.continuePoem(apiKey: 'sk', poemBody: ''),
        throwsA(isA<AiException>()),
      );
      expect(called, isFalse);
    });
  });

  group('findRhymes', () {
    test('parses a JSON array, lowercases, and dedupes', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(
            _textBody(
              jsonEncode([
                'BEND',
                'tend',
                'send',
                'bend', // duplicate, different case
                '   ', // empty
                'mend',
              ]),
            ),
          );
        }),
      );
      final out = await svc.findRhymes(apiKey: 'sk', word: 'spend');
      expect(out, ['bend', 'tend', 'send', 'mend']);
    });

    test('caps the result at the requested max', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody(jsonEncode(['a', 'b', 'c', 'd', 'e'])));
        }),
      );
      final out = await svc.findRhymes(apiKey: 'sk', word: 'x', max: 3);
      expect(out, ['a', 'b', 'c']);
    });

    test('strips ```json fences before parsing', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('```json\n["one", "two"]\n```'));
        }),
      );
      final out = await svc.findRhymes(apiKey: 'sk', word: 'x');
      expect(out, ['one', 'two']);
    });

    test('tolerates surrounding prose', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(_textBody('Sure: ["fly", "sky"]. enjoy!'));
        }),
      );
      final out = await svc.findRhymes(apiKey: 'sk', word: 'try');
      expect(out, ['fly', 'sky']);
    });

    test('rejects an empty word before hitting the network', () async {
      var called = false;
      final svc = AiService(
        client: MockClient((req) async {
          called = true;
          return _ok(_textBody('[]'));
        }),
      );
      await expectLater(
        svc.findRhymes(apiKey: 'sk', word: '   '),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Pick a word'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('throws when the array is empty', () async {
      final svc = AiService(
        client: MockClient((req) async => _ok(_textBody('[]'))),
      );
      await expectLater(
        svc.findRhymes(apiKey: 'sk', word: 'x'),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('did not return any rhymes'),
          ),
        ),
      );
    });

    test('throws when no array is present in the text', () async {
      final svc = AiService(
        client: MockClient(
          (req) async => _ok(_textBody('I cannot help with that.')),
        ),
      );
      await expectLater(
        svc.findRhymes(apiKey: 'sk', word: 'x'),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Could not parse JSON'),
          ),
        ),
      );
    });
  });

  group('suggestNextLine', () {
    test('returns the first non-empty line', () async {
      final svc = AiService(
        client: MockClient((req) async {
          return _ok(
            _textBody('\n\nthe pew won\'t hold you\nthe way you\'re bending\n'),
          );
        }),
      );
      final out = await svc.suggestNextLine(
        apiKey: 'sk',
        lyricBody: 'pray like you mean it',
      );
      expect(out, "the pew won't hold you");
    });

    test('passes section and BPM hints in the user content', () async {
      late http.Request seen;
      final svc = AiService(
        client: MockClient((req) async {
          seen = req;
          return _ok(_textBody('next'));
        }),
      );
      await svc.suggestNextLine(
        apiKey: 'sk',
        lyricBody: 'verse line one',
        section: 'verse',
        bpm: 80,
      );
      final json = jsonDecode(seen.body) as Map<String, dynamic>;
      final content =
          ((json['messages'] as List).first as Map)['content'] as String;
      expect(content, contains('Section: verse'));
      expect(content, contains('BPM: 80'));
    });

    test('omits hints when section/BPM are missing or empty', () async {
      late http.Request seen;
      final svc = AiService(
        client: MockClient((req) async {
          seen = req;
          return _ok(_textBody('next'));
        }),
      );
      await svc.suggestNextLine(
        apiKey: 'sk',
        lyricBody: 'body',
        section: '   ',
        bpm: 0,
      );
      final json = jsonDecode(seen.body) as Map<String, dynamic>;
      final content =
          ((json['messages'] as List).first as Map)['content'] as String;
      expect(content, isNot(contains('Section:')));
      expect(content, isNot(contains('BPM:')));
    });

    test('rejects empty body before hitting the network', () async {
      var called = false;
      final svc = AiService(
        client: MockClient((req) async {
          called = true;
          return _ok(_textBody('x'));
        }),
      );
      await expectLater(
        svc.suggestNextLine(apiKey: 'sk', lyricBody: '   '),
        throwsA(isA<AiException>()),
      );
      expect(called, isFalse);
    });

    test('throws if the response is empty / whitespace only', () async {
      final svc = AiService(
        client: MockClient((req) async => _ok(_textBody('   \n   \n'))),
      );
      await expectLater(
        svc.suggestNextLine(apiKey: 'sk', lyricBody: 'body'),
        throwsA(isA<AiException>()),
      );
    });
  });
}
