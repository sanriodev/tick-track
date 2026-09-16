import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/state/connectivity_status.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  @override
  void initState() {
    super.initState();
    ConnectivityStatus().addListener(_onStatusChanged);
  }

  @override
  void dispose() {
    ConnectivityStatus().removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ConnectivityStatus().backendReachable) {
      return widget.child;
    }

    return Column(
      children: [
        _OfflineBar(topInset: MediaQuery.of(context).padding.top),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _OfflineBar extends StatelessWidget {
  final double topInset;

  const _OfflineBar({required this.topInset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: EdgeInsets.only(top: topInset, bottom: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIconsRegular.cloudSlash,
              size: 14,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.offline,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
