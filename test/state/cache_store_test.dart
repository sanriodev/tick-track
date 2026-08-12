import 'dart:io';

import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/state/cache_store.dart';
import 'package:blvckleg_dart_core/adapter/login_auth_adapter.dart';
import 'package:blvckleg_dart_core/models/auth/login_response_model.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Note _note({
  required int id,
  required String title,
  PrivacyMode privacyMode = PrivacyMode.private,
  int? groupId,
  String username = 'tester',
}) {
  return Note(
    id: id,
    title: title,
    content: 'Inhalt von $title',
    privacyMode: privacyMode,
    groupId: groupId,
    user: User(id: 1, username: username),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cache_store_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (call) async => tempDir.path);
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LoginAuthAdapter());
    }
    await Hive.openBox<LoginResponse>('auth');
    await Hive.openBox(CacheStore.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('readList gibt null zurück, solange nichts gespeichert wurde', () {
    final cached = CacheStore().readList(CacheKey.notes(null), Note.fromJson);

    expect(cached, isNull);
  });

  test('writeList und readList überstehen den Roundtrip verlustfrei', () async {
    final notes = [
      _note(id: 1, title: 'Erste', privacyMode: PrivacyMode.public),
      _note(id: 2, title: 'Zweite', groupId: 7),
    ];

    await CacheStore().writeList(CacheKey.notes(null), notes);
    final cached = CacheStore().readList(CacheKey.notes(null), Note.fromJson);

    expect(cached, isNotNull);
    expect(cached!.items.map((note) => note.id), [1, 2]);
    expect(cached.items.first.title, 'Erste');
    expect(cached.items.first.content, 'Inhalt von Erste');
    expect(cached.items.last.groupId, 7);
  });

  test('der PrivacyMode bleibt beim Roundtrip erhalten', () async {
    final notes = [
      _note(id: 1, title: 'Privat'),
      _note(id: 2, title: 'Geschützt', privacyMode: PrivacyMode.protected),
      _note(id: 3, title: 'Öffentlich', privacyMode: PrivacyMode.public),
    ];

    await CacheStore().writeList(CacheKey.notes(null), notes);
    final cached = CacheStore().readList(CacheKey.notes(null), Note.fromJson);

    expect(cached!.items.map((note) => note.privacyMode), [
      PrivacyMode.private,
      PrivacyMode.protected,
      PrivacyMode.public,
    ]);
  });

  test('Gruppen teilen sich keinen Cache-Eintrag', () async {
    await CacheStore()
        .writeList(CacheKey.notes(null), [_note(id: 1, title: 'Privat')]);
    await CacheStore()
        .writeList(CacheKey.notes(4), [_note(id: 2, title: 'Gruppe')]);

    final own = CacheStore().readList(CacheKey.notes(null), Note.fromJson);
    final group = CacheStore().readList(CacheKey.notes(4), Note.fromJson);

    expect(own!.items.single.title, 'Privat');
    expect(group!.items.single.title, 'Gruppe');
  });

  test('writtenAt hält den Zeitpunkt des Schreibens fest', () async {
    final before = DateTime.now().subtract(const Duration(seconds: 1));

    await CacheStore().writeList(CacheKey.notes(null), [
      _note(id: 1, title: 'Erste'),
    ]);
    final cached = CacheStore().readList(CacheKey.notes(null), Note.fromJson);

    expect(cached!.writtenAt.isAfter(before), isTrue);
  });

  test('clear entfernt alle Einträge', () async {
    await CacheStore().writeList(CacheKey.notes(null), [
      _note(id: 1, title: 'Erste'),
    ]);

    await CacheStore().clear();

    expect(CacheStore().readList(CacheKey.notes(null), Note.fromJson), isNull);
  });

  test('writeItem und readItem überstehen den Roundtrip', () async {
    await CacheStore().writeItem(
      CacheKey.note(42),
      _note(id: 42, title: 'Einzeln', privacyMode: PrivacyMode.protected),
    );

    final cached = CacheStore().readItem(CacheKey.note(42), Note.fromJson);

    expect(cached!.item.id, 42);
    expect(cached.item.title, 'Einzeln');
    expect(cached.item.content, 'Inhalt von Einzeln');
    expect(cached.item.privacyMode, PrivacyMode.protected);
  });

  test('readItem trennt Notizen nach ihrer Id', () async {
    await CacheStore().writeItem(CacheKey.note(1), _note(id: 1, title: 'Eins'));
    await CacheStore().writeItem(CacheKey.note(2), _note(id: 2, title: 'Zwei'));

    expect(
      CacheStore().readItem(CacheKey.note(1), Note.fromJson)!.item.title,
      'Eins',
    );
    expect(
      CacheStore().readItem(CacheKey.note(2), Note.fromJson)!.item.title,
      'Zwei',
    );
  });

  test('readItem auf einer gespeicherten Liste liefert null', () async {
    await CacheStore()
        .writeList(CacheKey.notes(null), [_note(id: 1, title: 'Eins')]);

    expect(CacheStore().readItem(CacheKey.notes(null), Note.fromJson), isNull);
  });

  test('beschädigte Einträge liefern null statt zu werfen', () async {
    final box = Hive.box(CacheStore.boxName);
    await box.put('|${CacheKey.notes(null)}', 'kein json');

    expect(CacheStore().readList(CacheKey.notes(null), Note.fromJson), isNull);
  });
}
