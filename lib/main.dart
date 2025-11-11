import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/providers/current_screen_index_provider.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/providers/tokens_provider.dart';
import 'package:cndlclar/providers/sorting_field_provider.dart';
import 'package:cndlclar/screens/nav_screen.dart';

void main() {
  runApp(const CndlClarApp());
}

class CndlClarApp extends StatelessWidget {
  const CndlClarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => CurrentScreenIndexProvider(),
        ),
        ChangeNotifierProvider(create: (context) => TokensProvider()),
        ChangeNotifierProvider(create: (context) => IntervalProvider()),
        ChangeNotifierProvider(create: (context) => SortingFieldProvider()),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        home: const NavScreen(),
      ),
    );
  }
}
