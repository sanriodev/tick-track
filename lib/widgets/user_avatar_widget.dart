import 'package:ticktrack/state/avatar_store.dart';
import 'package:flutter/material.dart';

class UserAvatarWidget extends StatefulWidget {
  final int? userId;

  final String? username;

  final double radius;

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
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(
              _initials,
              style: theme.primaryTextTheme.bodySmall?.copyWith(
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
