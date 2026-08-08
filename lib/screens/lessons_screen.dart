import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/contract.dart';
import '../models/lesson.dart';
import '../services/supabase_service.dart';
import '../utils/ics_parser.dart';
import 'add_lesson_screen.dart';
import 'import_lessons_screen.dart';

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

  // Selezione multipla
  bool _isSelectionMode = false;
  final Set<String> _selectedLessonIds = {};

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
        hours +=
            (int.tryParse(parts[0]) ?? 0) +
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

  // ---- Selezione Multipla & Azioni Batch ----

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedLessonIds.clear();
      }
    });
  }

  void _toggleLessonSelection(String lessonId) {
    setState(() {
      if (_selectedLessonIds.contains(lessonId)) {
        _selectedLessonIds.remove(lessonId);
      } else {
        _selectedLessonIds.add(lessonId);
      }
      if (_selectedLessonIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedLessonIds.length == _lessons.length) {
        _selectedLessonIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedLessonIds.clear();
        _selectedLessonIds.addAll(_lessons.map((l) => l.id));
      }
    });
  }

  Future<void> _assignContractToSelected() async {
    if (_selectedLessonIds.isEmpty || _contracts.isEmpty) return;

    final selectedLessons = _lessons
        .where((l) => _selectedLessonIds.contains(l.id))
        .toList();

    final chosenContract = await showDialog<Contract>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assegna Contratto'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _contracts.length,
            itemBuilder: (ctx, i) {
              final c = _contracts[i];
              return ListTile(
                title: Text(c.displayName),
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );

    if (chosenContract != null) {
      setState(() => _isLoading = true);
      try {
        await _service.assignContractToLessons(
          lessons: selectedLessons,
          contract: chosenContract,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Contratto assegnato a ${selectedLessons.length} lezioni.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() {
          _isSelectionMode = false;
          _selectedLessonIds.clear();
        });
        await _applyFilters();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSelectedLessons() async {
    if (_selectedLessonIds.isEmpty) return;

    final count = _selectedLessonIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Lezioni'),
        content: Text('Eliminare $count lezioni selezionate?'),
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

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.deleteLessonsBatch(_selectedLessonIds.toList());
        setState(() {
          _isSelectionMode = false;
          _selectedLessonIds.clear();
        });
        await _applyFilters();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---- Build UI ----

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: colorScheme.primaryContainer,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              ),
              title: Text('${_selectedLessonIds.length} selezionate'),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedLessonIds.length == _lessons.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  onPressed: _toggleSelectAll,
                  tooltip: 'Seleziona tutte',
                ),
                IconButton(
                  icon: const Icon(Icons.assignment_ind),
                  onPressed: _selectedLessonIds.isNotEmpty
                      ? _assignContractToSelected
                      : null,
                  tooltip: 'Assegna contratto',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedLessonIds.isNotEmpty
                      ? _deleteSelectedLessons
                      : null,
                  tooltip: 'Elimina selezionate',
                ),
              ],
            )
          : AppBar(
              title: const Text('Le Mie Lezioni'),
              actions: [
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
                if (_lessons.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    onPressed: () => setState(() => _isSelectionMode = true),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'import_ics') await _pickAndImportIcs();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'import_ics',
                      child: Row(
                        children: [
                          Icon(Icons.upload_file, size: 20),
                          SizedBox(width: 8),
                          Text('Importa da .ics'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          _buildFilterPanel(colorScheme, textTheme),
          if (!_isLoading) _buildSummaryBar(colorScheme, textTheme, currency),
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
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

  // --- Altri widget di supporto (Pannello filtri, Summary, Empty) ---
  // (Mantengo la logica che hai già scritto ma pulita)

  Widget _buildFilterPanel(ColorScheme colorScheme, TextTheme textTheme) {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth != null &&
        _selectedMonth!.year == now.year &&
        _selectedMonth!.month == now.month;
    final hasActiveFilters =
        _selectedContract != null || _selectedMonth != null;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _selectedContract?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Contratto',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.assignment_outlined, size: 20),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tutti i contratti'),
              ),
              ..._contracts.map(
                (c) =>
                    DropdownMenuItem(value: c.id, child: Text(c.displayName)),
              ),
            ],
            onChanged: (id) {
              setState(
                () => _selectedContract = id == null
                    ? null
                    : _contracts.firstWhere((c) => c.id == id),
              );
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _selectedMonth == null,
                        label: const Text('Tutti i mesi'),
                        onSelected: (_) {
                          setState(() => _selectedMonth = null);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                      if (_selectedMonth != null) ...[
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _prevMonth,
                        ),
                        Text(
                          DateFormat(
                            'MMMM yyyy',
                            'it_IT',
                          ).format(_selectedMonth!),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: isCurrentMonth ? null : _nextMonth,
                        ),
                      ] else
                        ActionChip(
                          label: const Text('Scegli mese corrente'),
                          onPressed: () {
                            setState(
                              () => _selectedMonth = DateTime(
                                now.year,
                                now.month,
                                1,
                              ),
                            );
                            _applyFilters();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              if (hasActiveFilters)
                IconButton(
                  icon: const Icon(Icons.filter_alt_off),
                  color: colorScheme.error,
                  onPressed: () {
                    setState(() {
                      _selectedContract = null;
                      _selectedMonth = null;
                    });
                    _applyFilters();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(
    ColorScheme colorScheme,
    TextTheme textTheme,
    NumberFormat currency,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: colorScheme.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          Text(
            '${_lessons.length} lezioni',
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Text(
            '${_filteredHours.toStringAsFixed(1)} h',
            style: textTheme.labelMedium,
          ),
          const Spacer(),
          Text(
            currency.format(_filteredAmount),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Lesson>> _groupByMonth(List<Lesson> lessons) {
    final map = <String, List<Lesson>>{};
    for (final l in lessons) {
      final key = DateFormat('MMMM yyyy', 'it_IT').format(l.startDateTime);
      map.putIfAbsent(key, () => []).add(l);
    }
    return map;
  }

  Widget _buildGroupedList(
    ColorScheme colorScheme,
    TextTheme textTheme,
    NumberFormat currency,
  ) {
    if (_selectedMonth != null) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _lessons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _dismissibleLesson(
          _lessons[i],
          _buildLessonCard(_lessons[i], colorScheme, textTheme, currency),
        ),
      );
    }

    final grouped = _groupByMonth(_lessons);
    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: keys.length,
      itemBuilder: (_, sectionIndex) {
        final monthKey = keys[sectionIndex];
        final items = grouped[monthKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                monthKey,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...items.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _dismissibleLesson(
                  l,
                  _buildLessonCard(l, colorScheme, textTheme, currency),
                ),
              ),
            ),
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
    final isSelected = _selectedLessonIds.contains(lesson.id);
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final contract = _contracts.firstWhere(
      (c) => c.id == lesson.contractId,
      orElse: () => Contract(
        id: null,
        companyName: '—',
        hourlyRate: 0,
        startDate: DateTime.now(),
      ),
    );

    return InkWell(
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedLessonIds.add(lesson.id);
          });
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleLessonSelection(lesson.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddLessonScreen(lesson: lesson)),
          ).then((updated) {
            if (updated == true) _applyFilters();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (_isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleLessonSelection(lesson.id),
              ),
            Container(
              width: 45,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    lesson.startDateTime.day.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormat(
                      'MMM',
                      'it_IT',
                    ).format(lesson.startDateTime).toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.summary ?? 'Lezione',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                  ),
                  Text(
                    '${timeFormat.format(lesson.startDateTime)} · ${lesson.duration}',
                    style: textTheme.bodySmall,
                  ),
                  if (_selectedContract == null && contract.companyName != '—')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _contractLabel(contract),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (lesson.amount != null)
              Text(
                currency.format(lesson.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Metodi Helper cancellati o ridotti per brevità in questa risposta ---

  Future<void> _deleteLesson(Lesson lesson) async {
    final confirm = await _confirmDeleteLesson(lesson);
    if (confirm == true) {
      await _service.deleteLesson(lesson.id);
      _applyFilters();
    }
  }

  Future<bool?> _confirmDeleteLesson(Lesson lesson) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Lezione'),
        content: Text('Eliminare "${lesson.summary}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Widget _dismissibleLesson(Lesson lesson, Widget child) {
    if (_isSelectionMode) return child;
    return Dismissible(
      key: Key(lesson.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteLesson(lesson),
      onDismissed: (_) => _deleteLesson(lesson),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: child,
    );
  }

  Future<void> _pickAndImportIcs() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      final content = await File(result.files.single.path!).readAsString();
      final parsed = IcsParser.parse(content);
      if (mounted) {
        final imported = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImportLessonsScreen(parsedLessons: parsed),
          ),
        );
        if (imported == true) _loadAll();
      }
    }
  }

  Widget _buildEmpty(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Text('Nessuna lezione trovata.', style: textTheme.bodyLarge),
    );
  }
}
