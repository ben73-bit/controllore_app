import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza i dati di localizzazione per le date (it_IT)
  try {
    await initializeDateFormatting('it_IT', null);
  } catch (e) {
    debugPrint('Errore inizializzazione date formatting: $e');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: 'https://vwytuyexzbxkrncllyec.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3eXR1eWV4emJ4a3JuY2xseWVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyMjkxMzksImV4cCI6MjA5NzgwNTEzOX0.YweByFnt2Xbh6CDWJ6I87aMQM3719sLxd9Z2TaUfbcg',
    );
  } catch (e) {
    debugPrint('Errore inizializzazione Supabase: $e');
  }

  runApp(const ControllOreApp());
}

class ControllOreApp extends StatelessWidget {
  const ControllOreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ControllOre',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
