enum PrivacyMode {
  private,
  protected,
  public;

  // Encode to API (int: 0, 1, 2).
  int toJson() => index;

  // Decode from API (expects int 0, 1, or 2).
  static PrivacyMode fromJson(dynamic json) {
    if (json is int && json >= 0 && json < PrivacyMode.values.length) {
      return PrivacyMode.values[json];
    }
    return PrivacyMode.private; // Default value
  }

  /// Short name for the mode, e.g. as the title of a menu entry.
  String get label => switch (this) {
        PrivacyMode.private => 'Privat',
        PrivacyMode.protected => 'Geschützt',
        PrivacyMode.public => 'Öffentlich',
      };

  /// Spells out what the mode means for other members of the group.
  String get description => switch (this) {
        PrivacyMode.private => 'Nur du kannst sehen und bearbeiten',
        PrivacyMode.protected => 'Alle können sehen, bearbeiten nur du',
        PrivacyMode.public => 'Alle können sehen und bearbeiten',
      };
}
