import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../services/supabase_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    return StreamBuilder<AuthState>(
      stream: supabaseService.onAuthStateChange,
      builder: (context, snapshot) {
        // Se stiamo ancora in attesa della prima risposta da Supabase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final session = snapshot.data?.session ?? supabaseService.currentSession;

        if (session != null) {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
