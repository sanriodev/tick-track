import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ticktrack/state/locale_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('locale_store_test');
    Hive.init(tempDir.path);
    await LocaleStore.openBox();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('ohne gespeicherte Wahl entscheidet die Gerätesprache', () {
    final resolved = LocaleStore().resolveStartupLocale();

    expect(['de', 'en'], contains(resolved.languageCode));
  });

  test('eine gespeicherte Sprache gewinnt gegen die Gerätesprache', () async {
    await LocaleStore().save(const Locale('de'));

    expect(LocaleStore().resolveStartupLocale(), const Locale('de'));

    await LocaleStore().save(const Locale('en'));

    expect(LocaleStore().resolveStartupLocale(), const Locale('en'));
  });

  test('eine unbekannte gespeicherte Sprache wird verworfen', () async {
    await Hive.box('settings').put('locale', 'fr');

    expect(['de', 'en'], contains(LocaleStore().resolveStartupLocale().languageCode));
  });

  test('ohne geöffnete Box bleibt der Start möglich', () async {
    await Hive.box('settings').close();

    expect(LocaleStore().resolveStartupLocale().languageCode, isNotEmpty);
  });
}
