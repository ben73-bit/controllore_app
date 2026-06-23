import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _supabaseService.getDashboardStats();
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
      setState(() => _isLoading = false);
    }
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
                  const SizedBox(height: 32),
                  _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _buildSummaryCards(textTheme, colorScheme),
                  const SizedBox(height: 32),
                  Text(
                    'Ultime Lezioni',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _recentLessons.isEmpty 
                          ? const Text('Nessuna lezione trovata.')
                          : _buildRecentLessonsList(textTheme, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implementare aggiunta lezione
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
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dashboard',
              style: textTheme.displayLarge?.copyWith(fontSize: 32),
            ),
          ],
        ),
        CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          child: Icon(Icons.person, color: colorScheme.primary),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(TextTheme textTheme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Ore Totali',
            value: _totaleOre.toStringAsFixed(1),
            icon: Icons.timer,
            color: colorScheme.primary,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Compensi',
            value: '€${_totaleCompensi.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: AppTheme.accentColor,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),
      ],
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
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
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
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  lesson.isBilled ? Icons.check_circle : Icons.class_, 
                  color: lesson.isBilled ? Colors.green : colorScheme.primary
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.summary ?? 'Lezione', style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      '${lesson.duration} • ${lesson.startDateTime.day}/${lesson.startDateTime.month}/${lesson.startDateTime.year}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
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
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _SummaryCard({
    required this.title,
    required this.value,
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.displayMedium?.copyWith(
              fontSize: 28,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
