import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contract.dart';
import '../models/lesson.dart';
import '../services/supabase_service.dart';
import 'add_lesson_screen.dart';

class LessonsScreen extends StatefulWidget {
  /// Se passato, pre-seleziona questo contratto nel filtro.
  final Contract? initialContract;

  const LessonsScreen({super.key, this.initialContract});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final SupabaseService _service = SupabaseService();

  bool _isLoading = true;
  List<Lesson> _lessons = [];
  List<Contract> _contracts = [];

  // Filtri attivi
  Contract? _selectedContract;
  DateTime? _selectedMonth; // null = tutti i mesi

  // Statistiche calcolate sulle lezioni filtrate
  double _filteredHours = 0;
  double _filteredAmount = 0;

  @override
  void initState() {
    super.initState();
    _selectedContract = widget.initialContract;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      // Carica contratti per il filtro (solo la prima volta)
      if (_contracts.isEmpty) {
        _contracts = await _service.getContracts();
      }
      await _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyFilters() async {
    final from = _selectedMonth != null
        ? DateTime(_selectedMonth!.year, _selectedMonth!.month, 1)
        : null;
    final to = _selectedMonth != null
        ? DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 1)
        : null;

    final lessons = await _service.getLessonsFiltered(
      contractId: _selectedContract?.id,
      from: from,
      to: to,
    );

    double hours = 0;
    double amount = 0;
    for (final l in lessons) {
      final parts = l.duration.split(':');
      if (parts.length >= 2) {
        hours += (int.tryParse(parts[0]) ?? 0) +
            (int.tryParse(parts[1]) ?? 0) / 60.0;
      }
      amount += l.amount ?? 0;
    }

    if (mounted) {
      setState(() {
        _lessons = lessons;
        _filteredHours = hours;
        _filteredAmount = amount;
      });
    }
  }

  void _prevMonth() {
    final m = _selectedMonth ?? DateTime.now();
    setState(() => _selectedMonth = DateTime(m.year, m.month - 1, 1));
    _applyFilters();
  }

  void _nextMonth() {
    if (_selectedMonth == null) return;
    final next = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 1);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() => _selectedMonth = next);
    _applyFilters();
  }

  String _contractLabel(Contract c) {
    if (c.contractNumber != null && c.contractNumber!.isNotEmpty) {
      return '${c.companyName} · ${c.contractNumber}';
    }
    return c.companyName;
  }

  Future<bool?> _confirmDeleteLesson(Lesson lesson) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
        title: const Text('Elimina Lezione'),
        content: Text(
          'Sei sicuro di voler eliminare la lezione\n"${lesson.summary ?? 'Lezione'}"?\n\nL\'operazione è irreversibile.',
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
      await _service.deleteLesson(lesson.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lezione "${lesson.summary ?? 'Lezione'}" eliminata.'),
            backgroundColor: Colors.green,
          ),
        );
        // Aggiorna la lista locale senza ricaricare tutto
        setState(() {
          _lessons.removeWhere((l) => l.id == lesson.id);
          // Ricalcola statistiche
          _filteredHours = 0;
          _filteredAmount = 0;
          for (final l in _lessons) {
            final parts = l.duration.split(':');
            if (parts.length >= 2) {
              _filteredHours += (int.tryParse(parts[0]) ?? 0) +
                  (int.tryParse(parts[1]) ?? 0) / 60.0;
            }
            _filteredAmount += l.amount ?? 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore eliminazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _applyFilters(); // Ripristina la lista
      }
    }
  }

  Widget _dismissibleLesson(Lesson lesson, Widget child) {
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text('Elimina', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      child: child,
    );
  }

  // Raggruppa le lezioni per mese (es. "Giugno 2026")
  Map<String, List<Lesson>> _groupByMonth(List<Lesson> lessons) {
    final map = <String, List<Lesson>>{};
    for (final l in lessons) {
      final key = DateFormat('MMMM yyyy', 'it_IT').format(l.startDateTime);
      map.putIfAbsent(key, () => []).add(l);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Le Mie Lezioni'),
        actions: [
          // Reset filtri
          if (_selectedContract != null || _selectedMonth != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedContract = null;
                  _selectedMonth = null;
                });
                _applyFilters();
              },
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Reset'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ---- Pannello Filtri ----
          _buildFilterPanel(colorScheme, textTheme),

          // ---- Barra riassunto ----
          if (!_isLoading)
            _buildSummaryBar(colorScheme, textTheme, currency),

          // ---- Lista ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _lessons.isEmpty
                    ? _buildEmpty(colorScheme, textTheme)
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        child: _buildGroupedList(colorScheme, textTheme, currency),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddLessonScreen()),
          ).then((added) {
            if (added == true) _loadAll();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuova Lezione'),
      ),
    );
  }

  Widget _buildFilterPanel(ColorScheme colorScheme, TextTheme textTheme) {
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth != null &&
        _selectedMonth!.year == now.year &&
        _selectedMonth!.month == now.month;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Filtro Contratto ----
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Chip "Tutti"
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Tutti i contratti'),
                    selected: _selectedContract == null,
                    onSelected: (_) {
                      setState(() => _selectedContract = null);
                      _applyFilters();
                    },
                    showCheckmark: false,
                    selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _selectedContract == null
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: _selectedContract == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                // Chip per ogni contratto
                ..._contracts.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          c.contractNumber != null && c.contractNumber!.isNotEmpty
                              ? '${c.companyName} · ${c.contractNumber}'
                              : c.companyName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: _selectedContract?.id == c.id,
                        onSelected: (_) {
                          setState(() => _selectedContract =
                              _selectedContract?.id == c.id ? null : c);
                          _applyFilters();
                        },
                        showCheckmark: false,
                        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _selectedContract?.id == c.id
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight: _selectedContract?.id == c.id
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ---- Filtro Mese ----
          Row(
            children: [
              // Toggle "Tutti i mesi"
              GestureDetector(
                onTap: () {
                  setState(() => _selectedMonth =
                      _selectedMonth == null ? DateTime(now.year, now.month, 1) : null);
                  _applyFilters();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _selectedMonth == null
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tutti i mesi',
                    style: textTheme.labelMedium?.copyWith(
                      color: _selectedMonth == null
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Navigazione mese
              if (_selectedMonth != null) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevMonth,
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                ),
                GestureDetector(
                  onTap: !isCurrentMonth ? () {
                    setState(() => _selectedMonth = DateTime(now.year, now.month, 1));
                    _applyFilters();
                  } : null,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      DateFormat('MMMM yyyy', 'it_IT').format(_selectedMonth!),
                      key: ValueKey(_selectedMonth.toString()),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrentMonth ? null : _nextMonth,
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  color: isCurrentMonth
                      ? colorScheme.onSurface.withValues(alpha: 0.2)
                      : colorScheme.onSurface,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(
    ColorScheme colorScheme, TextTheme textTheme, NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '${_lessons.length} lezioni',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.schedule, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 6),
          Text(
            '${_filteredHours.toStringAsFixed(1)} h',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.secondary,
            ),
          ),
          const Spacer(),
          Text(
            currency.format(_filteredAmount),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(
    ColorScheme colorScheme, TextTheme textTheme, NumberFormat currency) {
    // Se il filtro mese è attivo, non raggruppa
    if (_selectedMonth != null) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: _lessons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _dismissibleLesson(
          _lessons[i],
          _buildLessonCard(_lessons[i], colorScheme, textTheme, currency),
        ),
      );
    }

    // Raggruppa per mese
    final grouped = _groupByMonth(_lessons);
    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: keys.length,
      itemBuilder: (_, sectionIndex) {
        final monthKey = keys[sectionIndex];
        final items = grouped[monthKey]!;
        // Totali per sezione
        double secHours = 0;
        double secAmount = 0;
        for (final l in items) {
          final parts = l.duration.split(':');
          if (parts.length >= 2) {
            secHours += (int.tryParse(parts[0]) ?? 0) +
                (int.tryParse(parts[1]) ?? 0) / 60.0;
          }
          secAmount += l.amount ?? 0;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header sezione mese
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    monthKey,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    '${secHours.toStringAsFixed(1)}h · ${currency.format(secAmount)}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...items.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(
                      bottom: e.key < items.length - 1 ? 10 : 20),
                  child: _dismissibleLesson(
                    e.value,
                    _buildLessonCard(e.value, colorScheme, textTheme, currency),
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildLessonCard(
    Lesson lesson,
    ColorScheme colorScheme,
    TextTheme textTheme,
    NumberFormat currency,
  ) {
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final parts = lesson.duration.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final durationLabel =
        h > 0 ? (m > 0 ? '${h}h ${m}min' : '${h}h') : '${m}min';

    // Nome contratto (cerca nella lista locale)
    final contract = _contracts.firstWhere(
      (c) => c.id == lesson.contractId,
      orElse: () => Contract(
          id: null,
          companyName: '—',
          hourlyRate: 0,
          startDate: DateTime.now()),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
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
          // Calendario miniatura
          Container(
            width: 46,
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
                  DateFormat('MMM', 'it_IT')
                      .format(lesson.startDateTime)
                      .toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
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
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 3),
                    Text(
                      '${timeFormat.format(lesson.startDateTime)} · $durationLabel',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                // Nome contratto (mostrato se non c'è filtro contratto)
                if (_selectedContract == null && contract.companyName != '—')
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        Icon(Icons.business,
                            size: 11,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.35)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _contractLabel(contract),
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Importo e stato fatturazione
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lesson.amount != null)
                Text(
                  currency.format(lesson.amount),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              if (lesson.isBilled)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Fatturata',
                    style: textTheme.labelSmall
                        ?.copyWith(color: Colors.green.shade700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64,
                color: colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              'Nessuna lezione trovata\ncon i filtri selezionati.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedContract = null;
                  _selectedMonth = null;
                });
                _applyFilters();
              },
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Rimuovi filtri'),
            ),
          ],
        ),
      ),
    );
  }
}
