import 'package:passkeys/types.dart';

class MfaCancelledException implements Exception {
  const MfaCancelledException();
}

class MfaUnavailableException implements Exception {
  final String message;

  const MfaUnavailableException(this.message);

  @override
  String toString() => message;
}

class MfaAuthenticatorException implements Exception {
  final String message;

  const MfaAuthenticatorException(this.message);

  @override
  String toString() => message;
}

Exception translatePasskeyError(Exception error) {
  if (error is PasskeyAuthCancelledException) {
    return const MfaCancelledException();
  }
  if (error is DeviceNotSupportedException ||
      error is PasskeyUnsupportedException) {
    return const MfaUnavailableException(
      'Dieses Gerät unterstützt keine Passkeys.',
    );
  }
  if (error is DomainNotAssociatedException) {
    return const MfaUnavailableException(
      'Diese App ist nicht für Passkeys freigeschaltet. '
      'Bitte wende dich an den Support.',
    );
  }
  if (error is MissingGoogleSignInException ||
      error is SyncAccountNotAvailableException) {
    return const MfaUnavailableException(
      'Für Passkeys braucht Android ein eingerichtetes Google-Konto.',
    );
  }
  if (error is NoCreateOptionException) {
    return const MfaUnavailableException(
      'Auf diesem Gerät ist kein Passwort-Manager für Passkeys eingerichtet.',
    );
  }
  if (error is ExcludeCredentialsCanNotBeRegisteredException) {
    return const MfaAuthenticatorException(
      'Dieses Gerät ist bereits registriert.',
    );
  }
  if (error is NoCredentialsAvailableException) {
    return const MfaAuthenticatorException(
      'Auf diesem Gerät liegt kein passender Passkey. '
      'Nutze ein registriertes Gerät oder einen Wiederherstellungscode.',
    );
  }
  if (error is TimeoutException) {
    return const MfaAuthenticatorException(
      'Die Anfrage ist abgelaufen. Bitte versuche es erneut.',
    );
  }
  if (error is MalformedBase64Url) {
    return const MfaAuthenticatorException(
      'Der Server hat eine unbrauchbare Anfrage geschickt.',
    );
  }
  return error;
}
