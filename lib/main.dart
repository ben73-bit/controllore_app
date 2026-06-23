import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://vwytuyexzbxkrncllyec.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3eXR1eWV4emJ4a3JuY2xseWVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyMjkxMzksImV4cCI6MjA5NzgwNTEzOX0.YweByFnt2Xbh6CDWJ6I87aMQM3719sLxd9Z2TaUfbcg',
  );

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
      home: const DashboardScreen(),
    );
  }
}
