import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/screens/home/main_app_screen.dart';
import 'package:flutter/material.dart';

class LanguageToggle extends StatelessWidget {
  final bool compact;

  const LanguageToggle({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCode = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: appLanguages
            .map((language) => _buildSegment(context, language, activeCode))
            .toList(),
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    AppLanguage language,
    String activeCode,
  ) {
    final theme = Theme.of(context);
    final isActive = language.code == activeCode;

    return Semantics(
      button: true,
      selected: isActive,
      label: language.nativeName,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => MainAppScreen.of(context)?.changeLocale(language.locale),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: isActive ? theme.scaffoldBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            compact ? language.code.toUpperCase() : language.nativeName,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? theme.textTheme.bodyMedium?.color
                  : theme.hintColor,
            ),
          ),
        ),
      ),
    );
  }
}
