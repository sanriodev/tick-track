import 'dart:convert';

import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/state/avatar_store.dart';
import 'package:ticktrack/state/cache_store.dart';
import 'package:ticktrack/state/connectivity_status.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/note_attachment_store.dart';
import 'package:ticktrack/state/reminder_scheduler.dart';
import 'package:ticktrack/state/reminder_sync.dart';
import 'package:ticktrack/util/localized_exception.dart';
import 'package:blvckleg_dart_core/exception/backend_unavailable.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<T?> navigateToRoute<T>(
  BuildContext context,
  String routeName, {
  Object? extra,
  bool backEnabled = false,
}) async {
  if (!context.mounted) {
    return null;
  }
  if (backEnabled) {
    return context.pushNamed<T>(routeName, extra: extra);
  }
  context.goNamed(routeName, extra: extra);
  return null;
}

Future<void> launchUrlInBrowser(Uri url) async {
  if (!await launchUrl(url)) {
    throw Exception('Could not launch $url');
  }
}

Future<void> deleteBoxAndNavigateToLogin(BuildContext context) async {
  await AuthBackend().clearSession();
  GroupContext().clear();
  AvatarStore().clear();
  NoteAttachmentStore().clear();
  await CacheStore().clear();
  ConnectivityStatus().reset();
  await ReminderScheduler().cancelAll();
  ReminderSync().reset();

  if (context.mounted) {
    navigateToRoute(
      context,
      'login',
    );
  }
}

Future<void> applyRenamedUsername(String username) async {
  final session = AuthBackend().loggedInUser;
  final user = session?.user;
  if (session == null || user == null) {
    return;
  }

  user.username = username;
  await AuthBackend().persistSession(session);
}

Future<void> navigateAfterAuth(BuildContext context) async {
  String target = 'home';
  try {
    await GroupContext().refresh();
    if (!GroupContext().hasGroups) {
      target = 'group-onboarding';
    }
    ReminderSync().sync(force: true);
  } catch (_) {
    await GroupContext().restoreFromCache();
  }
  if (context.mounted) {
    navigateToRoute(context, target);
  }
}

Future<void> showBackendError(
  BuildContext context,
  Object e,
  String fallbackMessage, {
  bool alertWhenOffline = true,
}) async {
  if (e is SessionExpiredException) {
    await _signOutAfterExpiredSession(context);
    return;
  }

  if (_isBackendUnavailable(e)) {
    ConnectivityStatus().reportUnreachable();
    if (alertWhenOffline) {
      _showSnackBar(context, context.l10n.errorOffline(fallbackMessage));
    }
    return;
  }

  _showSnackBar(
    context,
    context.l10n.errorWithDetail(fallbackMessage, _readableError(context, e)),
  );
}

Future<void> _signOutAfterExpiredSession(BuildContext context) async {
  _showSnackBar(context, context.l10n.sessionExpired);
  try {
    await AuthBackend().postLogout();
  } catch (_) {}
  if (context.mounted) {
    await deleteBoxAndNavigateToLogin(context);
  }
}

bool _isBackendUnavailable(Object e) {
  if (e is BackendUnavailableException) {
    return true;
  }
  return e is Response && e.statusCode >= 500;
}

String _readableError(BuildContext context, Object e) {
  if (e is LocalizedException) {
    return e.localizedMessage(context.l10n);
  }
  if (e is! Response) {
    return '$e';
  }
  try {
    final decoded = json.decode(utf8.decode(e.bodyBytes));
    final dynamic raw = (decoded as Map<String, dynamic>?)?['message'];
    if (raw == null) {
      return context.l10n.errorStatusCode(e.statusCode);
    }
    return raw is List ? raw.join(', ') : '$raw';
  } on FormatException {
    return context.l10n.errorStatusCode(e.statusCode);
  }
}

void _showSnackBar(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

IconData privacyIconFor(PrivacyMode? mode) {
  switch (mode) {
    case PrivacyMode.protected:
      return PhosphorIconsRegular.shield;
    case PrivacyMode.public:
      return PhosphorIconsRegular.eye;
    case PrivacyMode.private:
    default:
      return PhosphorIconsRegular.lock;
  }
}
