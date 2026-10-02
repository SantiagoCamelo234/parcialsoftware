import 'package:flutter/material.dart';

import 'screens/ingredientes_screen.dart';

void main() => runApp(const EcoEatApp());

class EcoEatApp extends StatelessWidget {
  const EcoEatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoEat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const IngredientesScreen(),
    );
  }
}
