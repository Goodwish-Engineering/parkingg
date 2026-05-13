import 'package:flutter/material.dart';
import 'package:parking/drawer/add_member.dart';
import 'package:parking/drawer/drawer.dart';
import 'package:parking/drawer/searchvehicle.dart';
import 'package:parking/home/screens/homepage.dart';
import 'package:parking/member/screens/list_member.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int selectedIndex = 0;

  final List<Widget> screens = const [
    Homepage(),
    SearchLostVehicleScreen(),
    RegistrationFlow(),
    ListMember(),
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (selectedIndex != 0) {
          setState(() => selectedIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF668DAF),
        endDrawer: Mydrawer(
          selectedIndex: selectedIndex,
          onSelect: (index) {
            setState(() => selectedIndex = index);
          },
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _AppHeader(
                onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              Expanded(child: screens[selectedIndex]),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  final VoidCallback onMenuTap;

  const _AppHeader({required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: Color(0xFF090044)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset("assets/goodwish.png", height: 40),
          CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: onMenuTap,
            ),
          ),
        ],
      ),
    );
  }
}
