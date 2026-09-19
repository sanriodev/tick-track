import 'package:flutter_test/flutter_test.dart';
import 'package:ticktrack/util/login_name.dart';

void main() {
  test('Eine Eingabe mit @ gilt als E-Mail', () {
    final loginName = LoginName.of('user@example.com');

    expect(loginName.isEmail, isTrue);
    expect(loginName.email, 'user@example.com');
    expect(loginName.username, isNull);
  });

  test('Eine Eingabe ohne @ gilt als Benutzername', () {
    final loginName = LoginName.of('testuser');

    expect(loginName.isEmail, isFalse);
    expect(loginName.username, 'testuser');
    expect(loginName.email, isNull);
  });

  test('Leerzeichen werden entfernt', () {
    expect(LoginName.of('  testuser  ').value, 'testuser');
    expect(LoginName.of(' user@example.com ').email, 'user@example.com');
  });
}
