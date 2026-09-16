import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/widgets/user_avatar_widget.dart';
import 'package:blvckleg_dart_core/models/user/user_model.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfilePreviewWidget extends StatelessWidget {
  const ProfilePreviewWidget({
    super.key,
    required this.user,
    required this.isLoading,
    required this.onPressed,
  });

  final User? user;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.primaryColor;
    final session = AuthBackend().loggedInUser?.user;
    final username = user?.username ?? session?.username;
    final email = user?.email ?? session?.email;

    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () {
          Haptics.tap();
          onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              UserAvatarWidget(
                userId: user?.id,
                username: username,
                radius: 28,
                borderColor: accent,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.welcomeBackName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      username ?? context.l10n.yourProfile,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email ??
                          (isLoading
                              ? context.l10n.profileLoading
                              : context.l10n.noEmailOnFile),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 18,
                color: theme.primaryIconTheme.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
