enum PrivacyMode {
  private,
  protected,
  public;

  int toJson() => index;

  static PrivacyMode fromJson(dynamic json) {
    if (json is int && json >= 0 && json < PrivacyMode.values.length) {
      return PrivacyMode.values[json];
    }
    return PrivacyMode.private;
  }

  String get label => switch (this) {
        PrivacyMode.private => 'Privat',
        PrivacyMode.protected => 'Geschützt',
        PrivacyMode.public => 'Öffentlich',
      };

  String get description => switch (this) {
        PrivacyMode.private => 'Nur du kannst sehen und bearbeiten',
        PrivacyMode.protected => 'Alle können sehen, bearbeiten nur du',
        PrivacyMode.public => 'Alle können sehen und bearbeiten',
      };
}
