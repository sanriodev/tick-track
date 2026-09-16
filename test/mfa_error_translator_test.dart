import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticktrack/l10n/l10n.dart';
import 'package:passkeys/types.dart';
import 'package:ticktrack/backend/service/mfa_error_translator.dart';

class _UnrelatedException implements Exception {}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('ein Abbruch durch den Nutzer ist kein Fehler', () {
    final translated = translatePasskeyError(PasskeyAuthCancelledException());

    expect(translated, isA<MfaCancelledException>());
  });

  test('nicht unterstützte Geräte melden Unverfügbarkeit', () {
    expect(
      translatePasskeyError(DeviceNotSupportedException()),
      isA<MfaUnavailableException>(),
    );
    expect(
      translatePasskeyError(PasskeyUnsupportedException('nope')),
      isA<MfaUnavailableException>(),
    );
  });

  test('eine fehlende Domain-Freigabe zeigt auf den Support', () {
    final translated =
        translatePasskeyError(DomainNotAssociatedException('nicht verknüpft'));

    expect(translated, isA<MfaUnavailableException>());
    expect(
      (translated as MfaUnavailableException).reason,
      MfaErrorReason.domainNotAssociated,
    );
    expect(translated.localizedMessage(l10n), contains('support'));
  });

  test('Android ohne Google-Konto wird erklärt', () {
    expect(
      translatePasskeyError(MissingGoogleSignInException()),
      isA<MfaUnavailableException>(),
    );
    expect(
      translatePasskeyError(SyncAccountNotAvailableException()),
      isA<MfaUnavailableException>(),
    );
  });

  test('ein bereits registriertes Gerät wird benannt', () {
    final translated = translatePasskeyError(
      ExcludeCredentialsCanNotBeRegisteredException(),
    );

    expect(translated, isA<MfaAuthenticatorException>());
    expect(
      (translated as MfaAuthenticatorException).reason,
      MfaErrorReason.credentialAlreadyRegistered,
    );
    expect(translated.localizedMessage(l10n), contains('already registered'));
  });

  test('ein fehlender Passkey verweist auf den Wiederherstellungscode', () {
    final translated =
        translatePasskeyError(NoCredentialsAvailableException());

    expect(
      (translated as MfaAuthenticatorException).reason,
      MfaErrorReason.noMatchingPasskey,
    );
    expect(translated.localizedMessage(l10n), contains('recovery code'));
  });

  test('ein Timeout lädt zum erneuten Versuch ein', () {
    final translated = translatePasskeyError(TimeoutException('zu spät'));

    expect(translated, isA<MfaAuthenticatorException>());
  });

  test('eine kaputte Server-Anfrage wird als solche gemeldet', () {
    final translated = translatePasskeyError(MalformedBase64UrlChallenge());

    expect(translated, isA<MfaAuthenticatorException>());
  });

  test('unbekannte Fehler bleiben unverändert', () {
    final original = _UnrelatedException();

    expect(translatePasskeyError(original), same(original));
  });
}
