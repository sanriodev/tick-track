import 'package:ticktrack/state/avatar_store.dart';
import 'package:flutter/material.dart';

/// A user's profile picture, falling back to their initials.
///
/// Reads from the [AvatarStore] cache and asks it to catch up in the
/// background, so a member list costs one request instead of one future per
/// row. Rebuilds itself once the picture arrives.
class UserAvatarWidget extends StatefulWidget {
  /// Null renders the placeholder without asking the backend, for content whose
  /// author no longer exists.
  final int? userId;

  /// Used for the initials and as the screen reader label.
  final String? username;

  final double radius;

  /// Ring around the picture, used to mark the group owner.
  final Color? borderColor;

  const UserAvatarWidget({
    super.key,
    required this.userId,
    this.username,
    this.radius = 20,
    this.borderColor,
  });

  @override
  State<UserAvatarWidget> createState() => _UserAvatarWidgetState();
}

class _UserAvatarWidgetState extends State<UserAvatarWidget> {
  @override
  void initState() {
    super.initState();
    AvatarStore().addListener(_onAvatarsChanged);
    _requestSync();
  }

  @override
  void didUpdateWidget(UserAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _requestSync();
    }
  }

  @override
  void dispose() {
    AvatarStore().removeListener(_onAvatarsChanged);
    super.dispose();
  }

  void _onAvatarsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// The store deduplicates, so a whole list asking at once still results in a
  /// single call.
  void _requestSync() {
    final userId = widget.userId;
    if (userId == null) {
      return;
    }
    AvatarStore().sync([userId]);
  }

  String get _initials {
    final name = widget.username?.trim() ?? '';
    if (name.isEmpty) {
      return '?';
    }
    // by rune, so a name starting with an emoji does not get cut in half
    return String.fromCharCode(name.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = widget.userId;
    final bytes = userId != null ? AvatarStore().bytesFor(userId) : null;
    final diameter = widget.radius * 2;

    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: theme.canvasColor,
      // MemoryImage rather than Image.memory so CircleAvatar clips it
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(
              _initials,
              style: theme.primaryTextTheme.bodySmall?.copyWith(
                // scales along, so one widget works at radius 9 and at 32
                fontSize: widget.radius * 0.8,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );

    return Semantics(
      label: 'Profilbild von ${widget.username ?? 'unbekannt'}',
      excludeSemantics: true,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: widget.borderColor == null
            ? avatar
            : Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.borderColor!, width: 2),
                ),
                padding: const EdgeInsets.all(2),
                child: avatar,
              ),
      ),
    );
  }
}
