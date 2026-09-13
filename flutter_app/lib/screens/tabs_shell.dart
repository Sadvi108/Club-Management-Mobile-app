import 'package:flutter/material.dart';
import '../widgets/club_tab_bar.dart';

class TabsShell extends StatelessWidget {
  final Widget child;
  final String location;
  const TabsShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : ClubTabBar(location: location),
      );
}
