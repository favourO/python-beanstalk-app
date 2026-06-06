import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _locations = ['/today', '/cycle', '/log', '/bloom', '/you'];

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellBackground = isDark ? colors.bg : const Color(0xFFFFFBF7);
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _locations.indexWhere(location.startsWith);

    return Scaffold(
      backgroundColor: shellBackground,
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: shellBackground,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: isDark ? colors.bgSurface : const Color(0xFFFFEEE8),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? colors.textPrimary : colors.textTertiary,
              );
            }),
          ),
          child: NavigationBar(
            backgroundColor: shellBackground,
            surfaceTintColor: Colors.transparent,
            height: dims.scaleHeight(76),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) => context.go(_locations[index]),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: l10n.appShellHomeLabel,
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: l10n.appShellCalendarLabel,
              ),
              NavigationDestination(
                icon: Icon(Icons.edit_note_outlined),
                selectedIcon: Icon(Icons.edit_note),
                label: l10n.appShellLogLabel,
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: l10n.appShellBloomLabel,
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: l10n.appShellProfileLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
