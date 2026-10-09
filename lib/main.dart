import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'firebase_options.dart';
import 'pages/expenses_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/login_page.dart';
import 'pages/name_page.dart';
import 'pages/projects_page.dart';
import 'pages/quotations_page.dart';
import 'pages/settings_page.dart';
import 'glass_nav_bar.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const QuotationApp());
}

class QuotationApp extends StatefulWidget {
  const QuotationApp({super.key});

  @override
  State<QuotationApp> createState() => _QuotationAppState();
}

class _QuotationAppState extends State<QuotationApp> {
  final AppState appState = AppState();

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prime Volt',
      theme: buildTheme(),
      // Pages listen to appState themselves (ListenableBuilder), so pushed
      // routes refresh too; only the auth/loading switch is handled here.
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (!appState.authReady) return const _Splash();
          if (appState.user == null) return LoginPage(appState: appState);
          if (appState.loading) return const _Splash();
          if (appState.userName.isEmpty) return NamePage(appState: appState);
          return MainNavigation(
            key: ValueKey(appState.user!.uid),
            appState: appState,
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Image.asset('assets/company_logo.png', width: 180)),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final AppState appState;
  const MainNavigation({super.key, required this.appState});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        appState: widget.appState,
        onOpenQuotations: () => setState(() => currentIndex = 1),
      ),
      QuotationsPage(appState: widget.appState),
      ProjectsPage(appState: widget.appState),
      ExpensesPage(appState: widget.appState),
      SettingsPage(appState: widget.appState),
    ];

    // extendBody lets pages scroll under the frosted bar; pages add
    // navBarClearance() to their bottom padding and FAB offsets.
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: GlassNavBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          GlassNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Home'),
          GlassNavItem(
            Icons.receipt_long_outlined,
            Icons.receipt_long,
            'Quotations',
          ),
          GlassNavItem(Icons.folder_outlined, Icons.folder, 'Projects'),
          GlassNavItem(
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet,
            'Expenses',
          ),
          GlassNavItem(
            Icons.account_circle_outlined,
            Icons.account_circle,
            'Profile',
          ),
        ],
      ),
    );
  }
}
