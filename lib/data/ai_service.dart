import 'dart:convert';

import 'package:http/http.dart' as http;

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Token usage reported by the Anthropic Messages API for one call. Cache
/// fields are zero when the response omits them (no prompt caching is in use
/// on any of our calls today; kept in case that changes).
class AiUsage {
  const AiUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.cacheCreationInputTokens = 0,
    this.cacheReadInputTokens = 0,
  });

  final int inputTokens;
  final int outputTokens;
  final int cacheCreationInputTokens;
  final int cacheReadInputTokens;

  /// USD cost using Anthropic Sonnet 4.x list pricing.
  /// input $3/MTok · output $15/MTok · cache write $3.75/MTok · cache read $0.30/MTok.
  double get usdCost =>
      (inputTokens * 3.0 +
          outputTokens * 15.0 +
          cacheCreationInputTokens * 3.75 +
          cacheReadInputTokens * 0.30) /
      1000000.0;

  static AiUsage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final input = raw['input_tokens'];
    final output = raw['output_tokens'];
    if (input is! int || output is! int) return null;
    int asInt(Object? v) => v is int ? v : 0;
    return AiUsage(
      inputTokens: input,
      outputTokens: output,
      cacheCreationInputTokens: asInt(raw['cache_creation_input_tokens']),
      cacheReadInputTokens: asInt(raw['cache_read_input_tokens']),
    );
  }
}

class AiService {
  AiService({http.Client? client, void Function(AiUsage usage)? onUsage})
    : _client = client ?? http.Client(),
      _onUsage = onUsage;

  final http.Client _client;
  final void Function(AiUsage usage)? _onUsage;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _anthropicVersion = '2023-06-01';
  static const _model = 'claude-sonnet-4-6';

  Future<String> generateJournalSynopsis({
    required String apiKey,
    required String entryBody,
  }) async {
    if (entryBody.trim().isEmpty) {
      throw AiException('Write something in the entry first.');
    }
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 400,
      'system':
          'You write tight, candid synopses of personal journal entries. '
          'Capture the core feeling, key events, and any decisions or shifts '
          'in mood. Two to four sentences. Use the writer\'s own voice — first '
          'person — and avoid hedging or therapy-speak. No preamble, no '
          'headings, no quotes — just the synopsis.',
      'messages': [
        {'role': 'user', 'content': 'Journal entry:\n\n$entryBody'},
      ],
    });
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers(apiKey),
      body: body,
    );
    return _extractText(res).trim();
  }

  Future<Map<String, String>> rephraseInStyles({
    required String apiKey,
    required String phrase,
    required List<String> styles,
  }) async {
    if (phrase.trim().isEmpty) {
      throw AiException('Write a phrase first.');
    }
    if (styles.isEmpty) {
      throw AiException('Add at least one style in Settings.');
    }
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 2000,
      'system':
          'You rewrite a phrase in the voice of given personalities or '
          'artists. Stay close to the original meaning but transform tone, '
          'cadence, and word choice to match each personality. Keep each '
          'rewrite to one or two sentences. '
          'Output STRICTLY a single JSON object: keys are the style names '
          'exactly as given, values are the rewritten phrase strings. No '
          'markdown fences, no commentary, no extra keys.',
      'messages': [
        {
          'role': 'user',
          'content':
              'Phrase:\n"$phrase"\n\nStyles:\n${styles.map((s) => '- $s').join('\n')}',
        },
      ],
    });
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers(apiKey),
      body: body,
    );
    final text = _extractText(res).trim();
    final json = _parseJsonObject(text);
    final result = <String, String>{};
    for (final style in styles) {
      final value = json[style];
      if (value is String && value.trim().isNotEmpty) {
        result[style] = value.trim();
      }
    }
    if (result.isEmpty) {
      throw AiException('Model did not return any rephrasings.');
    }
    return result;
  }

  /// Suggest a single short title (1–4 words) for a poem body.
  Future<String> suggestPoemTitle({
    required String apiKey,
    required String poemBody,
  }) async {
    if (poemBody.trim().isEmpty) {
      throw AiException('Write some of the poem first.');
    }
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 60,
      'system':
          'You title poems. Read the poem and propose ONE title — one to four '
          'words, in title case. The title should hint at the poem\'s emotional '
          'center without restating it. Output ONLY the title — no quotes, no '
          'punctuation at the end, no explanation.',
      'messages': [
        {'role': 'user', 'content': 'Poem:\n\n$poemBody'},
      ],
    });
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers(apiKey),
      body: body,
    );
    return _cleanTitle(_extractText(res));
  }

  /// Continue a poem in the writer's existing voice. Returns 2–6 lines.
  Future<String> continuePoem({
    required String apiKey,
    required String poemBody,
    String? title,
  }) async {
    if (poemBody.trim().isEmpty) {
      throw AiException('Write some of the poem first.');
    }
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 400,
      'system':
          'You continue poems. Read the existing poem and write 2–6 more '
          'lines that pick up the meter, voice, and imagery already on the '
          'page. Do not restart, do not summarize, do not add a title. '
          'Output ONLY the new lines — preserve line breaks.',
      'messages': [
        {
          'role': 'user',
          'content': title == null || title.trim().isEmpty
              ? 'Existing poem:\n\n$poemBody'
              : 'Existing poem (title: $title):\n\n$poemBody',
        },
      ],
    });
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers(apiKey),
      body: body,
    );
    return _extractText(res).trim();
  }

  /// Find rhymes for a single word. Returns a deduplicated list of words.
  Future<List<String>> findRhymes({
    required String apiKey,
    required String word,
    int max = 12,
  }) async {
    final w = word.trim();
    if (w.isEmpty) {
      throw AiException('Pick a word to rhyme with.');
    }
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 300,
      'system':
          'You list rhymes for a single word. Mix true rhymes and '
          'near/slant rhymes. Output STRICTLY a single JSON array of '
          'lowercase strings — no markdown fences, no commentary, no extra '
          'keys.',
      'messages': [
        {
          'role': 'user',
          'content': 'Word: $w\nReturn up to $max rhymes as a JSON array.',
        },
      ],
    });
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers(apiKey),
      body: body,
    );
    final text = _extractText(res).trim();
    final list = _parseJsonArray(text);
    final out = <String>[];
    final seen = <String>{};
    for (final v in list) {
      if (v is! String) continue;
      final s = v.trim().toLowerCase();
      if (s.isEmpty) continue;
      if (seen.add(s)) out.add(s);
      if (out.length >= max) break;
    }
    if (out.isEmpty) {
      throw AiException('Model did not return any rhymes.');
    }
    return out;
  }

  /// Suggest the next line of a lyric. Returns one line.
  Future<String> suggestNextLine({
    required String apiKey,
    required String lyricBody,
    String? section,
    int? bpm,
  }) async {
    if (lyricBody.trim().isEmpty) {
      throw AiException('Write some of the lyric first.');
    }
    final hints = <String>[];
    if (section != null && section.trim().isNotEmpty) {
      hints.add('Section: ${section.trim()}');
    }
    if (bpm != null && bpm > 0) {
      hints.add('BPM: $bpm');
    }
    final prelude = hints.isEmpty ? '' : '${hints.join(' · ')}\n\n';
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 120,
      'system':
          'You write the next line of a song lyric. Match the rhyme scheme, '
          'meter, and emotional tone of what came before. Output ONLY the '
          'new line — one line, no quotes, no commentary, no preamble.',
      'messages': [
        {'role': 'user', 'content': '${prelude}Existing lyric:\n\n$lyricBody'},
      ],
    });
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers(apiKey),
      body: body,
    );
    return _firstLine(_extractText(res));
  }

  Map<String, String> _headers(String apiKey) => {
    'content-type': 'application/json',
    'x-api-key': apiKey,
    'anthropic-version': _anthropicVersion,
    'anthropic-dangerous-direct-browser-access': 'true',
  };

  String _extractText(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiException(_friendlyError(res));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final content = body['content'];
    if (content is! List) {
      throw AiException('Unexpected response shape from Anthropic.');
    }
    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text' && block['text'] is String) {
        buffer.write(block['text']);
      }
    }
    final text = buffer.toString();
    if (text.isEmpty) {
      throw AiException('Empty response from Anthropic.');
    }
    final usage = AiUsage.fromJson(body['usage']);
    if (usage != null) _onUsage?.call(usage);
    return text;
  }

  Map<String, dynamic> _parseJsonObject(String text) {
    var s = _stripFences(text);
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw AiException('Could not parse JSON from model response.');
    }
    s = s.substring(start, end + 1);
    final decoded = jsonDecode(s);
    if (decoded is! Map<String, dynamic>) {
      throw AiException('Model did not return a JSON object.');
    }
    return decoded;
  }

  List<dynamic> _parseJsonArray(String text) {
    var s = _stripFences(text);
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start < 0 || end <= start) {
      throw AiException('Could not parse JSON from model response.');
    }
    s = s.substring(start, end + 1);
    final decoded = jsonDecode(s);
    if (decoded is! List) {
      throw AiException('Model did not return a JSON array.');
    }
    return decoded;
  }

  String _stripFences(String text) {
    var s = text.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?'), '').trim();
      if (s.endsWith('```')) {
        s = s.substring(0, s.length - 3).trim();
      }
    }
    return s;
  }

  String _cleanTitle(String text) {
    var s = text.trim();
    // Strip surrounding quotes / trailing punctuation that the model sometimes
    // adds despite the prompt.
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'")) ||
        (s.startsWith('“') && s.endsWith('”'))) {
      s = s.substring(1, s.length - 1).trim();
    }
    while (s.endsWith('.') || s.endsWith('!') || s.endsWith('?')) {
      s = s.substring(0, s.length - 1).trim();
    }
    if (s.isEmpty) {
      throw AiException('Empty title from model.');
    }
    return s;
  }

  String _firstLine(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw AiException('Empty response from Anthropic.');
    }
    return lines.first;
  }

  String _friendlyError(http.Response res) {
    try {
      final json = jsonDecode(res.body);
      if (json is Map &&
          json['error'] is Map &&
          json['error']['message'] is String) {
        final type = json['error']['type'];
        final msg = json['error']['message'];
        if (res.statusCode == 401) {
          return 'Invalid API key. Check it in Settings.';
        }
        if (res.statusCode == 429) {
          return 'Rate limited by Anthropic. Try again in a moment.';
        }
        return '${type ?? 'Error'}: $msg';
      }
    } catch (_) {}
    return 'Anthropic API error (${res.statusCode}).';
  }

  void dispose() {
    _client.close();
  }
}
