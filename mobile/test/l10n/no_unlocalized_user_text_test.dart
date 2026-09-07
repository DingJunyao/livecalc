import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _han = RegExp(r'[\u3400-\u9FFF]');
final _textCall = RegExp(r'\bText(?:\.rich)?\s*\(');
final _snackBarCall = RegExp(r'\bSnackBar\s*\(');
final _uiNamedArgument = RegExp(
  r'\b(?:label|tooltip|hintText|labelText|validator)\s*:',
);

/// Canonical stored nutrient keys used by nutrition editing default rows.
const _canonicalNutrientHan = <String>{
  '能量',
  '蛋白质',
  '脂肪',
  '碳水化合物',
  '膳食纤维',
  '钠',
  '钾',
  '钙',
  '铁',
  '锌',
  '磷',
  '镁',
  '维生素A',
  '维生素B1',
  '维生素B2',
  '维生素B6',
  '维生素B12',
  '维生素C',
  '维生素D',
  '维生素E',
  '维生素K',
  '叶酸',
  '烟酸',
  '胆固醇',
  '饱和脂肪',
};

/// Provider names in map layer fallback data; localized display uses mapLayer*.
const _canonicalProviderHan = <String>{'高德', '腾讯'};

String _stripComments(String source) {
  final buffer = StringBuffer();
  var singleQuoted = false;
  var doubleQuoted = false;
  var escaped = false;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (singleQuoted || doubleQuoted) {
      buffer.write(char);
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (singleQuoted && char == "'") {
        singleQuoted = false;
      } else if (doubleQuoted && char == '"') {
        doubleQuoted = false;
      }
      continue;
    }
    if (char == "'") {
      singleQuoted = true;
      buffer.write(char);
    } else if (char == '"') {
      doubleQuoted = true;
      buffer.write(char);
    } else if (char == '/' && next == '/') {
      final end = source.indexOf('\n', i);
      if (end < 0) break;
      buffer.write('\n');
      i = end;
    } else if (char == '/' && next == '*') {
      final end = source.indexOf('*/', i + 2);
      buffer.write(' ' * (end < 0 ? source.length - i : end - i + 2));
      i = end < 0 ? source.length : end + 1;
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

int _lineAt(String source, int index) {
  var line = 1;
  for (var i = 0; i < index && i < source.length; i++) {
    if (source[i] == '\n') line++;
  }
  return line;
}

int _matchingClose(String source, int open, String openChar, String closeChar) {
  var depth = 0;
  var singleQuoted = false;
  var doubleQuoted = false;
  var escaped = false;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (singleQuoted || doubleQuoted) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (singleQuoted && char == "'") {
        singleQuoted = false;
      } else if (doubleQuoted && char == '"') {
        doubleQuoted = false;
      }
      continue;
    }
    if (char == "'") {
      singleQuoted = true;
    } else if (char == '"') {
      doubleQuoted = true;
    } else if (char == openChar) {
      depth++;
    } else if (char == closeChar) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return source.length;
}

int _namedValueEnd(String source, int start) {
  var depth = 0;
  var singleQuoted = false;
  var doubleQuoted = false;
  var escaped = false;
  for (var i = start; i < source.length; i++) {
    final char = source[i];
    if (singleQuoted || doubleQuoted) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (singleQuoted && char == "'") {
        singleQuoted = false;
      } else if (doubleQuoted && char == '"') {
        doubleQuoted = false;
      }
      continue;
    }
    if (char == "'") {
      singleQuoted = true;
    } else if (char == '"') {
      doubleQuoted = true;
    } else if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      if (depth == 0) return i;
      depth--;
    } else if (char == ',' && depth == 0) {
      return i;
    }
  }
  return source.length;
}

bool _isAllowed(String path, String body) {
  final trimmed = body.trim();
  final allowed = path.endsWith('nutrition_edit_screen.dart')
      ? _canonicalNutrientHan
      : path.endsWith('map_config_provider.dart')
          ? _canonicalProviderHan
          : const <String>{};
  for (final value in allowed) {
    if (trimmed == "'$value'" || trimmed == '"$value"') return true;
  }
  return false;
}

List<String> _findingsIn(String path, String source) {
  final code = _stripComments(source);
  final findings = <String>[];

  void report(int index, String kind) {
    final line = _lineAt(code, index);
    findings.add('$path:$line: Han text inside $kind');
  }

  for (final match in _textCall.allMatches(code)) {
    final open = code.indexOf('(', match.end - 1);
    if (open < 0) continue;
    final close = _matchingClose(code, open, '(', ')');
    final body = code.substring(open + 1, close);
    if (_han.hasMatch(body)) report(match.start, 'Text');
  }

  for (final match in _snackBarCall.allMatches(code)) {
    final open = code.indexOf('(', match.end - 1);
    if (open < 0) continue;
    final close = _matchingClose(code, open, '(', ')');
    if (_han.hasMatch(code.substring(open + 1, close))) {
      report(match.start, 'SnackBar');
    }
  }

  for (final match in _uiNamedArgument.allMatches(code)) {
    final colon = code.indexOf(':', match.start);
    final start = _skipWhitespace(code, colon + 1);
    if (start >= code.length) continue;
    final end = _namedValueEnd(code, start);
    final body = code.substring(start, end);
    if (_han.hasMatch(body) && !_isAllowed(codePath(path), body)) {
      report(match.start, match.group(0)!.trim());
    }
  }

  return findings;
}

int _skipWhitespace(String source, int index) {
  while (index < source.length && source[index].trim().isEmpty) {
    index++;
  }
  return index;
}

String codePath(String path) => path.replaceAll(r'\', '/');

void main() {
  test('user-visible UI APIs contain no hardcoded Han literals', () {
    final root = Directory('lib');
    final findings = <String>[];
    for (final entry in root.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      findings.addAll(_findingsIn(entry.path, entry.readAsStringSync()));
    }
    expect(findings, isEmpty, reason: findings.join('\n'));
  });
}
