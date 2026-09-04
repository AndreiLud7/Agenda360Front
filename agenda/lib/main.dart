import 'package:flutter/material.dart';
// Atualize o nome do arquivo final na importação caso você também tenha renomeado o arquivo físico
import 'package:agenda/view/home_screen.dart';

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Consultas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0D6EFD),
        useMaterial3: true,
      ),
      home: const HomeScreen(),x
    );
  }
}