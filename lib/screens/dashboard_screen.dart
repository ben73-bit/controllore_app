import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/migration_service.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
import 'add_lesson_screen.dart';
import 'contracts_screen.dart';
import 'lessons_screen.dart';
import 'billing_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final MigrationService _migrationService = MigrationService();

  // Indice per la navigazione desktop (NavigationRail + IndexedStack)
  int _selectedIndex = 0;

  bool _isLoading = true;
  double _totaleOre = 0.0;
  double _totaleCompensi = 0.0;
  List<Lesson> _recentLessons = [];

  // Filtro mese: null = tutto lo storico
  DateTime? _selectedMonth; // es. DateTime(2026, 6, 1)
  bool get _isFiltered => _selectedMonth != null;

  /// Recupera il nome dell'utente dai metadata o ricorre all'email
  String get _userName {
    final user = _supabaseService.currentUser;
    final metadata = user?.userMetadata;
    final fullName = metadata?['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    final name = metadata?['name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    final firstName = metadata?['first_name'] as String?;
    if (firstName != null && firstName.trim().isNotEmpty) {
      final lastName = metadata?['last_name'] as String? ?? '';
      return '$firstName $lastName'.trim();
    }
    return user?.email ?? 'Utente';
  }

  /// Restituisce il saluto personalizzato 'Ciao [Nome]!'
  String get _greeting => 'Ciao $_userName!';

  @override
  void initState() {
    super.initState();
    // Di default partiamo con il mese corrente
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final statsFuture = _isFiltered
          ? _supabaseService.getDashboardStatsByMonth(
              _selectedMonth!.year,
              _selectedMonth!.month,
            )
          : _supabaseService.getDashboardStats();

      final lessonsFuture = _supabaseService.getRecentLessons(limit: 5);

      final results = await Future.wait([statsFuture, lessonsFuture]);
      final stats = results[0] as Map<String, dynamic>;
      final lessons = results[1] as List<Lesson>;

      if (mounted) {
        setState(() {
          _totaleOre = (stats['total_hours'] as num?)?.toDouble() ?? 0.0;
          _totaleCompensi = (stats['total_amount'] as num?)?.toDouble() ?? 0.0;
          _recentLessons = lessons;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile caricare i dati: $e'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Riprova',
              onPressed: _loadData,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _prevMonth() {
    setState(() {
      final m = _selectedMonth ?? DateTime.now();
      _selectedMonth = DateTime(m.year, m.month - 1, 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(
      (_selectedMonth ?? now).year,
      (_selectedMonth ?? now).month + 1,
      1,
    );
    // Non permettiamo di andare nel futuro
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() => _selectedMonth = next);
    _loadData();
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month, 1));
    _loadData();
  }

  void _toggleAllTime() {
    setState(
      () => _selectedMonth = _isFiltered
          ? null
          : DateTime(DateTime.now().year, DateTime.now().month, 1),
    );
    _loadData();
  }

  Future<void> _importDesktopData() async {
    try {
      // 1. Selezione del file tramite FilePicker
      final platformFile = await _migrationService.pickJsonFile();

      if (platformFile == null) {
        // Selezione annullata dall'utente
        return;
      }

      if (!mounted) return;

      // 2. Mostra dialog di caricamento con indicatore di progresso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Importazione in corso...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Caricamento dati su Supabase',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      String jsonString;
      if (platformFile.bytes != null) {
        jsonString = utf8.decode(platformFile.bytes!);
      } else if (platformFile.path != null) {
        final f = File(platformFile.path!);
        jsonString = await f.readAsString();
      } else {
        throw Exception('Impossibile leggere il file selezionato.');
      }

      final result = await _migrationService.importFromJsonString(
        jsonString: jsonString,
        fileName: platformFile.name,
      );

      // Chiudi il dialog di caricamento
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Importazione completata!\n${result.contractsCount} contratti e ${result.lessonsCount} lezioni caricati da "${result.fileName}".',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      }
    } catch (e) {
      // Chiudi il dialog di caricamento se ancora visibile
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante l\'importazione: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma Logout'),
        content: const Text('Vuoi veramente uscire dall\'applicazione?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Esci', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabaseService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= ResponsiveLayout.kDesktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(textTheme, colorScheme);
        } else {
          return _buildMobileLayout(textTheme, colorScheme);
        }
      },
    );
  }

  // ──────────────────────────────────────────────────
  // Layout MOBILE (< 900px, Drawer a comparsa)
  // ──────────────────────────────────────────────────
  Widget _buildMobileLayout(TextTheme textTheme, ColorScheme colorScheme) {
    return Scaffold(
      drawer: _buildDrawer(textTheme, colorScheme),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(textTheme, colorScheme),
                  const SizedBox(height: 24),
                  _buildMonthSelector(textTheme, colorScheme),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildSummaryCards(textTheme, colorScheme),
                  const SizedBox(height: 32),
                  Text('Ultime Lezioni', style: textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _recentLessons.isEmpty
                      ? _buildEmptyLessons(textTheme, colorScheme)
                      : _buildRecentLessonsList(textTheme, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddLessonScreen()),
          ).then((added) {
            if (added == true) _loadData();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuova Lezione'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  // ──────────────────────────────────────────────────
  // Layout DESKTOP (≥ 900px, NavigationRail permanente)
  // ──────────────────────────────────────────────────
  Widget _buildDesktopLayout(TextTheme textTheme, ColorScheme colorScheme) {
    final userEmail = _supabaseService.currentUser?.email ?? 'Utente';

    // Le 4 sezioni principali: mantengono il proprio stato tramite IndexedStack
    final sections = [
      _buildDashboardContent(textTheme, colorScheme),
      const LessonsScreen(),
      const ContractsScreen(),
      const BillingScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // ── NavigationRail fisso a sinistra ────────────────────
          NavigationRail(
            extended: true,
            minExtendedWidth: 220,
            backgroundColor: colorScheme.surface,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) {
              setState(() => _selectedIndex = i);
              if (i == 0) _loadData();
            },
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) => setState(() {}));
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                        child:
                            Icon(Icons.person, color: colorScheme.primary, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _userName,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        userEmail,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(indent: 16, endIndent: 16),
                  // Importa dati Desktop
                  InkWell(
                    onTap: _importDesktopData,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_upload_outlined,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Importa JSON',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Logout
                  InkWell(
                    onTap: _confirmLogout,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.logout, color: Colors.red, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Esci',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt_rounded),
                label: Text('Le Mie Lezioni'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: Text('I Miei Contratti'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Fatturazione'),
              ),
            ],
          ),

          // Separatore verticale
          const VerticalDivider(width: 1, thickness: 1),

          // ── Contenuto principale ─────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: sections,
            ),
          ),
        ],
      ),
      // FAB visibile su Desktop solo quando siamo nella tab Dashboard
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddLessonScreen()),
                ).then((added) {
                  if (added == true) _loadData();
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Nuova Lezione'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            )
          : null,
    );
  }

  // ──────────────────────────────────────────────────
  // Contenuto Dashboard (usato nel tab 0 su desktop)
  // ──────────────────────────────────────────────────
  Widget _buildDashboardContent(TextTheme textTheme, ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ResponsiveLayout.constrainedWidth(
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header desktop: titolo + menu account
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _greeting,
                              style: textTheme.bodyLarge?.copyWith(
                                color:
                                    colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Dashboard',
                            style:
                                textTheme.displayLarge?.copyWith(fontSize: 30),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.person,
                            color: colorScheme.primary, size: 18),
                      ),
                      tooltip: 'Account',
                      onSelected: (value) async {
                        if (value == 'profile') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()),
                          ).then((_) => setState(() {}));
                        } else if (value == 'import') {
                          _importDesktopData();
                        } else if (value == 'logout') {
                          _confirmLogout();
                        }
                      },
                      itemBuilder: (ctx) {
                        final userEmail =
                            _supabaseService.currentUser?.email ?? 'Utente';
                        return [
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Connesso come:',
                                    style: textTheme.bodySmall),
                                Text(_userName,
                                    style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold)),
                                Text(userEmail,
                                    style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.6))),
                                const Divider(),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'profile',
                            child: Row(children: [
                              Icon(Icons.account_circle_outlined,
                                  color: Colors.indigo, size: 20),
                              SizedBox(width: 8),
                              Text('Il Mio Profilo'),
                            ]),
                          ),
                          const PopupMenuItem<String>(
                            value: 'import',
                            child: Row(children: [
                              Icon(Icons.file_upload_outlined,
                                  color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text('Importa dati Desktop'),
                            ]),
                          ),
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(children: [
                              Icon(Icons.logout, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Esci',
                                  style: TextStyle(color: Colors.red)),
                            ]),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildMonthSelector(textTheme, colorScheme),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildSummaryCards(textTheme, colorScheme),
                const SizedBox(height: 40),
                Text('Ultime Lezioni', style: textTheme.titleLarge),
                const SizedBox(height: 16),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _recentLessons.isEmpty
                    ? _buildEmptyLessons(textTheme, colorScheme)
                    : _buildRecentLessonsList(textTheme, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(TextTheme textTheme, ColorScheme colorScheme) {
    final userEmail = _supabaseService.currentUser?.email ?? 'Utente';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header con info utente
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              ),
              currentAccountPicture: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) => setState(() {}));
                },
                child: CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  child: Icon(Icons.person, color: colorScheme.onPrimary, size: 36),
                ),
              ),
              accountName: Text(
                _userName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              accountEmail: Text(
                userEmail,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Navigazione sezioni
            ListTile(
              leading: Icon(Icons.account_circle_outlined, color: colorScheme.primary),
              title: const Text('Il Mio Profilo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: Icon(Icons.dashboard_outlined, color: colorScheme.primary),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.list_alt_rounded, color: colorScheme.primary),
              title: const Text('Le Mie Lezioni'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LessonsScreen()),
                ).then((_) => _loadData());
              },
            ),
            ListTile(
              leading: Icon(Icons.assignment_outlined, color: colorScheme.primary),
              title: const Text('I Miei Contratti'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContractsScreen(),
                  ),
                ).then((_) => _loadData());
              },
            ),
            ListTile(
              leading: Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
              title: const Text('Fatturazione'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillingScreen()),
                ).then((_) => _loadData());
              },
            ),

            const Divider(),

            // Voce Importa dati Desktop
            ListTile(
              leading: Icon(Icons.file_upload_outlined, color: Colors.blue.shade700),
              title: Text(
                'Importa dati Desktop',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
              subtitle: const Text('Importa file JSON da versione desktop'),
              onTap: () {
                Navigator.pop(context);
                _importDesktopData();
              },
            ),

            const Spacer(),
            const Divider(),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Esci', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(TextTheme textTheme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Hamburger Menu per aprire il Drawer
        Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: colorScheme.primary, size: 24),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Menu',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _greeting,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dashboard',
                  style: textTheme.displayLarge?.copyWith(fontSize: 26),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.receipt_long, color: colorScheme.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillingScreen()),
                ).then((_) => _loadData());
              },
              tooltip: 'Fatturazione',
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.list_alt, color: colorScheme.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LessonsScreen()),
                ).then((_) => _loadData());
              },
              tooltip: 'Lista Lezioni',
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.assignment, color: colorScheme.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContractsScreen(),
                  ),
                ).then((_) => _loadData());
              },
              tooltip: 'Lista Contratti',
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: colorScheme.primary, size: 18),
              ),
              tooltip: 'Account',
              onSelected: (value) async {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) => setState(() {}));
                } else if (value == 'import') {
                  _importDesktopData();
                } else if (value == 'logout') {
                  _confirmLogout();
                }
              },
              itemBuilder: (ctx) {
                final userEmail = _supabaseService.currentUser?.email ?? 'Utente';
                return [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connesso come:',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _userName,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userEmail,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.account_circle_outlined, color: Colors.indigo, size: 20),
                        SizedBox(width: 8),
                        Text('Il Mio Profilo'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.file_upload_outlined, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Importa dati Desktop'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Esci', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthSelector(TextTheme textTheme, ColorScheme colorScheme) {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth != null &&
        _selectedMonth!.year == now.year &&
        _selectedMonth!.month == now.month;
    final isNextDisabled = isCurrentMonth || !_isFiltered;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Toggle "Tutto lo storico"
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: _toggleAllTime,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: !_isFiltered
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Tutto',
                  style: textTheme.labelMedium?.copyWith(
                    color: !_isFiltered
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Navigazione mese
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _isFiltered ? _prevMonth : null,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  color: _isFiltered
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                GestureDetector(
                  onTap: !isCurrentMonth && _isFiltered
                      ? _goToCurrentMonth
                      : null,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isFiltered
                          ? DateFormat(
                              'MMMM yyyy',
                              'it_IT',
                            ).format(_selectedMonth!)
                          : 'Storico completo',
                      key: ValueKey(
                        _isFiltered ? _selectedMonth.toString() : 'all',
                      ),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isFiltered
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isNextDisabled ? null : _nextMonth,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  color: isNextDisabled
                      ? colorScheme.onSurface.withValues(alpha: 0.2)
                      : colorScheme.onSurface,
                ),
              ],
            ),
          ),

          // Badge "Oggi" per tornare al mese corrente
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: _isFiltered && !isCurrentMonth ? _goToCurrentMonth : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isCurrentMonth && _isFiltered
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Oggi',
                  style: textTheme.labelMedium?.copyWith(
                    color: isCurrentMonth && _isFiltered
                        ? colorScheme.onPrimary
                        : _isFiltered && !isCurrentMonth
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(TextTheme textTheme, ColorScheme colorScheme) {
    final label = _isFiltered
        ? DateFormat('MMMM', 'it_IT').format(_selectedMonth!)
        : 'Totale';

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Ore • $label',
            value: _totaleOre.toStringAsFixed(1),
            unit: 'h',
            icon: Icons.timer,
            color: colorScheme.primary,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Compenso • $label',
            value: '€ ${_totaleCompensi.toStringAsFixed(2)}',
            unit: '',
            icon: Icons.account_balance_wallet,
            color: AppTheme.accentColor,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLessons(TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 40,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Nessuna lezione trovata.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLessonsList(TextTheme textTheme, ColorScheme colorScheme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentLessons.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lesson = _recentLessons[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddLessonScreen(lesson: lesson),
              ),
            ).then((updated) {
              if (updated == true) _loadData();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    lesson.isBilled ? Icons.check_circle : Icons.class_,
                    color: lesson.isBilled ? Colors.green : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.summary ?? 'Lezione',
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lesson.duration} • ${lesson.startDateTime.day}/${lesson.startDateTime.month}/${lesson.startDateTime.year}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (lesson.amount != null)
                  Text(
                    '€ ${lesson.amount!.toStringAsFixed(2)}',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ), // chiude Container
        ); // chiude InkWell
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.textTheme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.displayMedium?.copyWith(
              fontSize: 26,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
