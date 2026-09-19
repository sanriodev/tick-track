class LoginName {
  final String value;

  const LoginName._(this.value);

  factory LoginName.of(String input) => LoginName._(input.trim());

  bool get isEmail => value.contains('@');

  String? get email => isEmail ? value : null;

  String? get username => isEmail ? null : value;
}
