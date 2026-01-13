
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/import_pdf/share_handler.dart';

void main() {
  runApp(const ProviderScope(child: MisCuentasApp()));
}

class MisCuentasApp extends StatelessWidget {
  const MisCuentasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis Cuentas',
      theme: AppTheme.darkTheme,
      home: const ShareHandler(child: HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
