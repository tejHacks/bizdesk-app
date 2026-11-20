import 'package:flutter/material.dart';

import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await BizStore.load();
  runApp(StoreScope(store: store, child: const BizDeskApp()));
}

class BizDeskApp extends StatelessWidget {
  const BizDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return MaterialApp(
      title: 'BizDesk',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: store.onboarded ? const Shell() : const OnboardingScreen(),
    );
  }
}
