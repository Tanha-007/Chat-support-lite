import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../data/moderation_repository.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import 'inbox_screen.dart';
import 'moderation_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.chat,
    required this.moderation,
    required this.profile,
    required this.onProfileChanged,
    required this.onSignOut,
  });

  final ChatRepository chat;
  final ModerationRepository moderation;
  final Profile profile;
  final ValueChanged<Profile> onProfileChanged;
  final Future<void> Function() onSignOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _badge = 0;

  @override
  Widget build(BuildContext context) {
    final mod = widget.profile.isModerator;

    final pages = <Widget>[
      if (mod)
        ModerationScreen(
          repository: widget.moderation,
          onOpenCount: (n) => setState(() => _badge = n),
        )
      else
        InboxScreen(
          repository: widget.chat,
          profile: widget.profile,
          onUnreadCount: (n) => setState(() => _badge = n),
        ),
      ProfileScreen(
        repository: widget.chat,
        profile: widget.profile,
        onProfileChanged: widget.onProfileChanged,
        onSignOut: widget.onSignOut,
      ),
    ];

    final firstLabel = mod ? 'Moderation' : 'Inbox';
    final firstIcon = mod ? Icons.shield_outlined : Icons.inbox_outlined;
    final firstIconOn = mod ? Icons.shield_rounded : Icons.inbox_rounded;

    Widget badged(IconData icon) => Badge(
      isLabelVisible: _badge > 0,
      backgroundColor: AppColors.signal,
      label: Text(_badge > 99 ? '99+' : '$_badge'),
      child: Icon(icon),
    );

    final body = IndexedStack(index: _index, children: pages);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(right: BorderSide(color: AppColors.line)),
              ),
              child: NavigationRail(
                backgroundColor: AppColors.card,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                indicatorColor: AppColors.sunken,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.signal,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                selectedLabelTextStyle: AppType.body(
                  12,
                  weight: FontWeight.w600,
                ),
                unselectedLabelTextStyle: AppType.body(
                  12,
                  weight: FontWeight.w600,
                  color: AppColors.muted,
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: badged(firstIcon),
                    selectedIcon: badged(firstIconOn),
                    label: Text(firstLabel),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: Text('Profile'),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: badged(firstIcon),
              selectedIcon: badged(firstIconOn),
              label: firstLabel,
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
