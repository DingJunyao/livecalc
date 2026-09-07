import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _arbFiles = <String, String>{
  'zh': 'lib/l10n/app_zh.arb',
  'en': 'lib/l10n/app_en.arb',
  'ar': 'lib/l10n/app_ar.arb',
};

Map<String, dynamic> _loadArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, String> _translatedValues(Map<String, dynamic> arb) {
  final values = <String, String>{};
  for (final entry in arb.entries) {
    if (entry.key.startsWith('@@') || entry.key.startsWith('@')) continue;
    values[entry.key] = entry.value.toString();
  }
  return values;
}

Map<String, Set<String>> _placeholderNames(Map<String, dynamic> arb) {
  final names = <String, Set<String>>{};
  for (final key in _translatedValues(arb).keys) {
    final metadata = arb['@$key'];
    if (metadata is Map) {
      final placeholders = metadata['placeholders'];
      if (placeholders is Map) {
        names[key] = placeholders.keys.map((key) => key.toString()).toSet();
        continue;
      }
    }
    names[key] = const <String>{};
  }
  return names;
}

void main() {
  final catalogs = {
    for (final entry in _arbFiles.entries) entry.key: _loadArb(entry.value),
  };

  test('all three ARB catalogs expose identical keys and non-empty values', () {
    final baseline = _translatedValues(catalogs['zh']!);
    for (final locale in _arbFiles.keys) {
      final values = _translatedValues(catalogs[locale]!);
      expect(
        values.keys.toSet(),
        baseline.keys.toSet(),
        reason: '$locale key set differs from template zh',
      );
      for (final value in values.values) {
        expect(value.trim().isNotEmpty, isTrue,
            reason: '$locale contains an empty translation');
      }
    }
  });

  test('placeholder names match across all three ARB catalogs', () {
    final baseline = _placeholderNames(catalogs['zh']!);
    for (final locale in _arbFiles.keys) {
      final actual = _placeholderNames(catalogs[locale]!);
      for (final key in baseline.keys) {
        expect(
          actual[key],
          baseline[key],
          reason: '$locale placeholder mismatch for $key',
        );
      }
    }
  });
}
