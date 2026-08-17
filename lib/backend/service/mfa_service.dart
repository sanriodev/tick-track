import 'dart:io';

import 'package:blvckleg_dart_core/models/auth/login_response_model.dart';
import 'package:blvckleg_dart_core/models/auth/mfa_challenge_model.dart';
import 'package:blvckleg_dart_core/models/mfa/webauthn_credential_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'package:ticktrack/backend/service/mfa_error_translator.dart';

export 'package:ticktrack/backend/service/mfa_error_translator.dart'
    show
        MfaAuthenticatorException,
        MfaCancelledException,
        MfaUnavailableException;

class MfaService {
  MfaService({PasskeyAuthenticator? authenticator})
      : _authenticator = authenticator ?? PasskeyAuthenticator();

  final PasskeyAuthenticator _authenticator;

  Future<bool> isPasskeySupported() async {
    try {
      if (Platform.isIOS) {
        final availability = await _authenticator.getAvailability().iOS();
        return availability.hasPasskeySupport;
      }
      if (Platform.isAndroid) {
        final availability = await _authenticator.getAvailability().android();
        return availability.hasPasskeySupport;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<WebAuthnCredential> registerCredential({
    String? nickname,
    String? displayName,
  }) async {
    final options = await AuthBackend().mfaRegistrationOptions(
      displayName: displayName,
    );
    final response = await _runRegistration(options);

    return AuthBackend().mfaRegisterCredential(
      response.toJson(),
      nickname: nickname,
    );
  }

  Future<LoginResponse> completeLogin(MfaChallenge challenge) async {
    final options = await AuthBackend().mfaWebAuthnOptions(challenge);
    final response = await _runAuthentication(options);

    return AuthBackend().completeMfaWithWebAuthn(challenge, response.toJson());
  }

  Future<RegisterResponseType> _runRegistration(
    Map<String, dynamic> options,
  ) async {
    try {
      return await _authenticator.register(
        RegisterRequestType.fromJson(options),
      );
    } on Exception catch (error) {
      throw translatePasskeyError(error);
    }
  }

  Future<AuthenticateResponseType> _runAuthentication(
    Map<String, dynamic> options,
  ) async {
    try {
      return await _authenticator.authenticate(
        AuthenticateRequestType.fromJson(
          options,
          preferImmediatelyAvailableCredentials: false,
        ),
      );
    } on Exception catch (error) {
      throw translatePasskeyError(error);
    }
  }
}
