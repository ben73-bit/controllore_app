import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;

  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = _supabaseService.currentUser;
    final metadata = user?.userMetadata ?? {};

    String firstName = (metadata['first_name'] as String?) ?? '';
    String lastName = (metadata['last_name'] as String?) ?? '';

    // Se non sono presenti first_name e last_name separati, proviamo a estrarli da full_name o name
    if (firstName.isEmpty && lastName.isEmpty) {
      final fullName = (metadata['full_name'] as String?) ?? (metadata['name'] as String?) ?? '';
      if (fullName.isNotEmpty) {
        final parts = fullName.trim().split(' ');
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
    }

    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabaseService.currentUser;
      final newFirstName = _firstNameController.text.trim();
      final newLastName = _lastNameController.text.trim();
      final newEmail = _emailController.text.trim();

      final fullName = '$newFirstName $newLastName'.trim().isNotEmpty
          ? '$newFirstName $newLastName'.trim()
          : (newFirstName.isNotEmpty ? newFirstName : newLastName);

      final userAttributes = UserAttributes(
        email: (newEmail.isNotEmpty && newEmail != user?.email) ? newEmail : null,
        data: {
          'first_name': newFirstName,
          'last_name': newLastName,
          'full_name': fullName.isNotEmpty ? fullName : newEmail,
        },
      );

      final response = await Supabase.instance.client.auth.updateUser(userAttributes);

      if (mounted) {
        String msg = 'Profilo aggiornato con successo!';
        if (newEmail.isNotEmpty && newEmail != user?.email && response.user?.newEmail != null) {
          msg += '\nÈ stata inviata un\'email di conferma al nuovo indirizzo.';
        }

        setState(() {
          _successMessage = msg;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore durante l\'aggiornamento del profilo:\n$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = _supabaseService.currentUser;

    final metadata = user?.userMetadata ?? {};
    final currentFullName = (metadata['full_name'] as String?) ??
        (metadata['name'] as String?) ??
        user?.email ??
        'Utente';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Il Mio Profilo'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Salva',
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: ResponsiveLayout.constrainedWidth(
        SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // Avatar con iniziale
                CircleAvatar(
                  radius: 46,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    currentFullName.isNotEmpty
                        ? currentFullName[0].toUpperCase()
                        : 'U',
                    style: textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  currentFullName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                if (_successMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Sezione Dati Personali
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'INFORMAZIONI PERSONALI',
                    style: textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Inserisci il tuo nome',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci il tuo nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Cognome',
                    hintText: 'Inserisci il tuo cognome (opzionale)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Indirizzo Email',
                    hintText: 'latua@email.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci un indirizzo email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Inserisci un indirizzo email valido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 36),

                // Pulsante Salva
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _saveProfile,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isLoading ? 'SALVATAGGIO IN CORSO...' : 'SALVA MODIFICHE',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        maxWidth: ResponsiveLayout.kMaxFormWidth,
      ),
    );
  }
}
