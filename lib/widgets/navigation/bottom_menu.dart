import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/widgets/navigation/bottom_menu_navigation_item.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BottomMenu extends StatelessWidget {
  const BottomMenu({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context.l10n);
    final int current = _indexOfCurrentRoute(context, pages);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomNavigationBar(
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            enableFeedback: true,
            iconSize: 26,
            elevation: 8,
            useLegacyColorScheme: false,
            selectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedFontSize: 10,
            selectedItemColor: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Theme.of(context).colorScheme.primary,
            unselectedItemColor:
                Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[500]
                    : Theme.of(context).appBarTheme.titleTextStyle!.color,
            currentIndex: current,
            onTap: (int index) {
              navigateToRoute(
                context,
                pages[index].materialRoute,
              );
            },
            items: pages,
          ),
        ],
      ),
    );
  }

  int _indexOfCurrentRoute(
    BuildContext context,
    List<BottomMenuNavigationItem> pages,
  ) {
    final String route = ModalRoute.of(context)!.settings.name!;
    for (int i = 0; i < pages.length; i++) {
      if (pages[i].materialRoute == route) {
        return i;
      }
    }
    return 0;
  }

  List<BottomMenuNavigationItem> _buildPages(AppLocalizations l10n) => [
        BottomMenuNavigationItem(
          icon: const PhosphorIcon(PhosphorIconsRegular.house),
          label: l10n.navHome,
          materialRoute: 'home',
        ),
        BottomMenuNavigationItem(
          icon: const PhosphorIcon(PhosphorIconsRegular.list),
          label: l10n.navLists,
          materialRoute: 'task-lists',
        ),
        BottomMenuNavigationItem(
          icon: const PhosphorIcon(PhosphorIconsRegular.note),
          label: l10n.navNotes,
          materialRoute: 'notes',
        ),
        BottomMenuNavigationItem(
          icon: const PhosphorIcon(PhosphorIconsRegular.calendarBlank),
          label: l10n.navCalendar,
          materialRoute: 'calendar',
        ),
        BottomMenuNavigationItem(
          icon: const PhosphorIcon(PhosphorIconsRegular.pulse),
          label: l10n.navActivity,
          materialRoute: 'activity',
        ),
      ];
}
