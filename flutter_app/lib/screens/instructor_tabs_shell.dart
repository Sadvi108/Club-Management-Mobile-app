import 'package:flutter/material.dart';
import '../widgets/club_tab_bar.dart';

class InstructorTabsShell extends StatelessWidget {
  final Widget child;
  final String location;
  const InstructorTabsShell(
      {super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : ClubTabBar(location: location, instructor: true),
      );
}
