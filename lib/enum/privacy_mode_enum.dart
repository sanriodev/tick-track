import 'package:ticktrack/l10n/l10n.dart';

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

  String label(AppLocalizations l10n) => switch (this) {
        PrivacyMode.private => l10n.privacyPrivate,
        PrivacyMode.protected => l10n.privacyProtected,
        PrivacyMode.public => l10n.privacyPublic,
      };

  String description(AppLocalizations l10n) => switch (this) {
        PrivacyMode.private => l10n.privacyPrivateDescription,
        PrivacyMode.protected => l10n.privacyProtectedDescription,
        PrivacyMode.public => l10n.privacyPublicDescription,
      };
}
