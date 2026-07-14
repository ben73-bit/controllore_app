import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';
import 'add_lesson_screen.dart';
import 'contracts_screen.dart';
import 'lessons_screen.dart';
import 'billing_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;
  double _totaleOre = 0.0;
  double _totaleCompensi = 0.0;
  List<Lesson> _recentLessons = [];

  // Filtro mese: null = tutto lo storico
  DateTime? _selectedMonth; // es. DateTime(2026, 6, 1)
  bool get _isFiltered => _selectedMonth != null;

  @override
  void initState() {
    super.initState();
    // Di default partiamo con il mese corrente
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> stats;
      if (_isFiltered) {
        stats = await _supabaseService.getDashboardStatsByMonth(
          _selectedMonth!.year,
          _selectedMonth!.month,
        );
      } else {
        stats = await _supabaseService.getDashboardStats();
      }
      final lessons = await _supabaseService.getRecentLessons(limit: 5);

      setState(() {
        _totaleOre = stats['total_hours'];
        _totaleCompensi = stats['total_amount'];
        _recentLessons = lessons;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il caricamento dei dati: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
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

                  // ---- Selettore Mese ----
                  _buildMonthSelector(textTheme, colorScheme),
                  const SizedBox(height: 20),

                  // ---- Cards statistiche ----
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildSummaryCards(textTheme, colorScheme),
                  const SizedBox(height: 32),

                  // ---- Ultime Lezioni ----
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

  Widget _buildHeader(TextTheme textTheme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ciao!',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dashboard',
              style: textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
          ],
        ),
        Row(
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
                padding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(width: 8),
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
                padding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(width: 8),
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
                padding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.person, color: colorScheme.primary, size: 20),
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
