import 'dart:convert';

import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/state/avatar_store.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/note_attachment_store.dart';
import 'package:ticktrack/state/reminder_scheduler.dart';
import 'package:ticktrack/state/reminder_sync.dart';
import 'package:blvckleg_dart_core/exception/session_expired.dart';
import 'package:blvckleg_dart_core/models/auth/login_response_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
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
  final Box<LoginResponse> loginBox = Hive.box<LoginResponse>('auth');

  await loginBox.delete('auth');

  final AuthBackend authBackend = AuthBackend();
  authBackend.loggedInUser = null;
  GroupContext().clear();
  AvatarStore().clear();
  NoteAttachmentStore().clear();
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
  final Box<LoginResponse> loginBox = Hive.box<LoginResponse>('auth');
  await loginBox.put('auth', session);
}

Future<void> navigateAfterAuth(BuildContext context) async {
  String target = 'home';
  try {
    await GroupContext().refresh();
    if (!GroupContext().hasGroups) {
      target = 'group-onboarding';
    }
    ReminderSync().sync(force: true);
  } catch (_) {}
  if (context.mounted) {
    navigateToRoute(context, target);
  }
}

Future<void> showBackendError(
  BuildContext context,
  Object e,
  String fallbackMessage,
) async {
  if (e is SessionExpiredException) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bitte melde dich erneut an.')),
    );
    try {
      await AuthBackend().postLogout();
    } catch (_) {}
    if (context.mounted) {
      await deleteBoxAndNavigateToLogin(context);
    }
    return;
  }

  String message = '$e';
  if (e is Response) {
    final jsonData = json.decode(utf8.decode(e.bodyBytes));
    final dynamic raw = (jsonData as Map<String, dynamic>)['message'];
    message = raw is List ? raw.join(', ') : '${raw ?? e}';
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fallbackMessage: $message')),
    );
  }
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
