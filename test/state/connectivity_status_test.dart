import 'package:ticktrack/state/connectivity_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityStatus().reset());

  test('startet erreichbar', () {
    expect(ConnectivityStatus().backendReachable, isTrue);
    expect(ConnectivityStatus().unreachableSince, isNull);
  });

  test('meldet den Wechsel auf nicht erreichbar genau einmal', () {
    var notifications = 0;
    void listener() => notifications++;
    ConnectivityStatus().addListener(listener);

    ConnectivityStatus().reportUnreachable();
    ConnectivityStatus().reportUnreachable();
    ConnectivityStatus().reportUnreachable();

    expect(ConnectivityStatus().backendReachable, isFalse);
    expect(notifications, 1);
    ConnectivityStatus().removeListener(listener);
  });

  test('meldet die Rückkehr genau einmal', () {
    ConnectivityStatus().reportUnreachable();

    var notifications = 0;
    void listener() => notifications++;
    ConnectivityStatus().addListener(listener);

    ConnectivityStatus().reportReachable();
    ConnectivityStatus().reportReachable();

    expect(ConnectivityStatus().backendReachable, isTrue);
    expect(notifications, 1);
    ConnectivityStatus().removeListener(listener);
  });

  test('merkt sich, seit wann das Backend weg ist', () {
    final before = DateTime.now().subtract(const Duration(seconds: 1));

    ConnectivityStatus().reportUnreachable();

    expect(ConnectivityStatus().unreachableSince, isNotNull);
    expect(ConnectivityStatus().unreachableSince!.isAfter(before), isTrue);
  });

  test('die Rückkehr löscht den Offline-Zeitpunkt', () {
    ConnectivityStatus().reportUnreachable();

    ConnectivityStatus().reportReachable();

    expect(ConnectivityStatus().unreachableSince, isNull);
  });

  test('reset setzt den Status ohne Benachrichtigung zurück', () {
    ConnectivityStatus().reportUnreachable();

    var notifications = 0;
    void listener() => notifications++;
    ConnectivityStatus().addListener(listener);

    ConnectivityStatus().reset();

    expect(ConnectivityStatus().backendReachable, isTrue);
    expect(notifications, 0);
    ConnectivityStatus().removeListener(listener);
  });
}
