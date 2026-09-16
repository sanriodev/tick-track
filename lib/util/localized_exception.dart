import 'package:ticktrack/l10n/l10n.dart';

abstract class LocalizedException implements Exception {
  String localizedMessage(AppLocalizations l10n);
}
