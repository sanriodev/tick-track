import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/util/localized_exception.dart';
import 'package:passkeys/types.dart';

class MfaCancelledException implements Exception {
  const MfaCancelledException();
}

enum MfaErrorReason {
  deviceUnsupported,
  domainNotAssociated,
  googleAccountMissing,
  passwordManagerMissing,
  credentialAlreadyRegistered,
  noMatchingPasskey,
  requestTimeout,
  malformedServerRequest;

  String message(AppLocalizations l10n) => switch (this) {
        MfaErrorReason.deviceUnsupported => l10n.mfaErrorDeviceUnsupported,
        MfaErrorReason.domainNotAssociated => l10n.mfaErrorDomainNotAssociated,
        MfaErrorReason.googleAccountMissing =>
          l10n.mfaErrorGoogleAccountMissing,
        MfaErrorReason.passwordManagerMissing =>
          l10n.mfaErrorPasswordManagerMissing,
        MfaErrorReason.credentialAlreadyRegistered =>
          l10n.mfaErrorCredentialAlreadyRegistered,
        MfaErrorReason.noMatchingPasskey => l10n.mfaErrorNoMatchingPasskey,
        MfaErrorReason.requestTimeout => l10n.mfaErrorRequestTimeout,
        MfaErrorReason.malformedServerRequest =>
          l10n.mfaErrorMalformedServerRequest,
      };
}

class MfaUnavailableException implements LocalizedException {
  final MfaErrorReason reason;

  const MfaUnavailableException(this.reason);

  @override
  String localizedMessage(AppLocalizations l10n) => reason.message(l10n);

  @override
  String toString() => 'MfaUnavailableException(${reason.name})';
}

class MfaAuthenticatorException implements LocalizedException {
  final MfaErrorReason reason;

  const MfaAuthenticatorException(this.reason);

  @override
  String localizedMessage(AppLocalizations l10n) => reason.message(l10n);

  @override
  String toString() => 'MfaAuthenticatorException(${reason.name})';
}

Exception translatePasskeyError(Exception error) {
  if (error is PasskeyAuthCancelledException) {
    return const MfaCancelledException();
  }
  if (error is DeviceNotSupportedException ||
      error is PasskeyUnsupportedException) {
    return const MfaUnavailableException(MfaErrorReason.deviceUnsupported);
  }
  if (error is DomainNotAssociatedException) {
    return const MfaUnavailableException(MfaErrorReason.domainNotAssociated);
  }
  if (error is MissingGoogleSignInException ||
      error is SyncAccountNotAvailableException) {
    return const MfaUnavailableException(MfaErrorReason.googleAccountMissing);
  }
  if (error is NoCreateOptionException) {
    return const MfaUnavailableException(
      MfaErrorReason.passwordManagerMissing,
    );
  }
  if (error is ExcludeCredentialsCanNotBeRegisteredException) {
    return const MfaAuthenticatorException(
      MfaErrorReason.credentialAlreadyRegistered,
    );
  }
  if (error is NoCredentialsAvailableException) {
    return const MfaAuthenticatorException(MfaErrorReason.noMatchingPasskey);
  }
  if (error is TimeoutException) {
    return const MfaAuthenticatorException(MfaErrorReason.requestTimeout);
  }
  if (error is MalformedBase64Url) {
    return const MfaAuthenticatorException(
      MfaErrorReason.malformedServerRequest,
    );
  }
  return error;
}
