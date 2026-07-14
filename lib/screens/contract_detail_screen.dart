import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contract.dart';
import '../models/lesson.dart';
import '../services/supabase_service.dart';
import 'add_contract_screen.dart';
import 'add_lesson_screen.dart';

class ContractDetailScreen extends StatefulWidget {
  final Contract contract;

  const ContractDetailScreen({super.key, required this.contract});

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Lesson> _lessons = [];

  // Statistiche calcolate in locale
  double _totalHours = 0.0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    try {
      final lessons = await _supabaseService.getLessonsForContract(
        widget.contract.id!,
      );
      double hours = 0;
      double amount = 0;
      for (final l in lessons) {
        final parts = l.duration.split(':');
        if (parts.length >= 2) {
          hours +=
              (int.tryParse(parts[0]) ?? 0) +
              (int.tryParse(parts[1]) ?? 0) / 60.0;
        }
        amount += l.amount ?? 0;
      }
      setState(() {
        _lessons = lessons;
        _totalHours = hours;
        _totalAmount = amount;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento lezioni: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _confirmDeleteLesson(Lesson lesson) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 40,
        ),
        title: const Text('Elimina Lezione'),
        content: Text(
          'Sei sicuro di voler eliminare\n"${lesson.summary ?? 'Lezione'}"?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    try {
      await _supabaseService.deleteLesson(lesson.id);
      if (mounted) {
        setState(() {
          _lessons.removeWhere((l) => l.id == lesson.id);
          // Ricalcola totali
          _totalHours = 0;
          _totalAmount = 0;
          for (final l in _lessons) {
            final parts = l.duration.split(':');
            if (parts.length >= 2) {
              _totalHours +=
                  (int.tryParse(parts[0]) ?? 0) +
                  (int.tryParse(parts[1]) ?? 0) / 60.0;
            }
            _totalAmount += l.amount ?? 0;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lezione eliminata.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
        _loadLessons();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

    final contract = widget.contract;
    final limitHours = contract.totalHoursLimit;
    final progress = (limitHours != null && limitHours > 0)
        ? (_totalHours / limitHours).clamp(0.0, 1.0)
        : null;

    final Color progressColor = progress == null
        ? colorScheme.primary
        : progress > 0.9
        ? Colors.red
        : progress > 0.7
        ? Colors.orange
        : colorScheme.primary;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadLessons,
        child: CustomScrollView(
          slivers: [
            // ---- SliverAppBar con header contratto ----
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modifica contratto',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddContractScreen(contract: contract),
                      ),
                    ).then((updated) {
                      if (updated == true) _loadLessons();
                    });
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colorScheme.primary, colorScheme.secondary],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (contract.contractNumber != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Rif. ${contract.contractNumber}',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          Text(
                            contract.companyName,
                            style: textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dateFormat.format(contract.startDate)}'
                            '${contract.endDate != null ? ' → ${dateFormat.format(contract.endDate!)}' : ' → In corso'}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Tariffa oraria
                          Row(
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${currency.format(contract.hourlyRate)} / ora',
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ---- Corpo con statistiche e lista lezioni ----
            SliverToBoxAdapter(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ---- Card statistiche ----
                          _buildStatsCard(
                            context,
                            colorScheme,
                            textTheme,
                            currency,
                            progress,
                            progressColor,
                            limitHours,
                          ),
                          const SizedBox(height: 28),

                          // ---- Titolo lista lezioni ----
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lezioni (${_lessons.length})',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_lessons.isEmpty)
                            _buildEmptyLessons(colorScheme, textTheme),
                        ],
                      ),
                    ),
            ),

            // ---- Lista lezioni ----
            if (!_isLoading && _lessons.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList.separated(
                  itemCount: _lessons.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    return Dismissible(
                      key: Key(lesson.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDeleteLesson(lesson),
                      onDismissed: (_) => _deleteLesson(lesson),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 26,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Elimina',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: _buildLessonTile(lesson, colorScheme, textTheme),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    NumberFormat currency,
    double? progress,
    Color progressColor,
    double? limitHours,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.schedule,
                  label: 'Ore Svolte',
                  value: '${_totalHours.toStringAsFixed(1)} h',
                  color: colorScheme.primary,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.euro,
                  label: 'Totale Maturato',
                  value: currency.format(_totalAmount),
                  color: Colors.green.shade600,
                ),
              ),
              if (limitHours != null) ...[
                Container(
                  width: 1,
                  height: 48,
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.hourglass_bottom,
                    label: 'Ore Rimanenti',
                    value:
                        '${(limitHours - _totalHours).clamp(0, limitHours).toStringAsFixed(1)} h',
                    color: progressColor,
                  ),
                ),
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_totalHours.toStringAsFixed(1)} / $limitHours ore utilizzate',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: textTheme.bodySmall?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: progressColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildLessonTile(
    Lesson lesson,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');

    // Calcola ore leggibili dalla stringa HH:MM:SS
    final parts = lesson.duration.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final durationLabel = h > 0
        ? (m > 0 ? '${h}h ${m}min' : '${h}h')
        : '${m}min';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddLessonScreen(lesson: lesson),
          ),
        ).then((updated) {
          if (updated == true) {
            _loadLessons();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            // Icona data
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    lesson.startDateTime.day.toString(),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'MMM',
                      'it_IT',
                    ).format(lesson.startDateTime).toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Dettagli
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.summary ?? 'Lezione',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${timeFormat.format(lesson.startDateTime)} · $durationLabel',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Importo
            if (lesson.amount != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(lesson.amount),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                  if (lesson.isBilled)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Fatturata',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ), // chiude Container
    ); // chiude InkWell
  }

  Widget _buildEmptyLessons(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 56,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Nessuna lezione registrata per questo contratto.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
