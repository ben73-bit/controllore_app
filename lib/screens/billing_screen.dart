import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lesson.dart';
import '../models/contract.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _service = SupabaseService();
  late final TabController _tabController;

  // Tab "Da Fatturare"
  List<Lesson> _unbilled = [];
  List<Contract> _contracts = [];
  final Set<String> _selected = {};
  bool _loadingUnbilled = true;

  // Tab "Fatture"
  List<Lesson> _billed = [];
  bool _loadingBilled = true;

  // Filtri Tab "Da Fatturare"
  Contract? _unbilledSelectedContract;
  DateTime? _unbilledSelectedMonth; // null = tutti i mesi

  // Filtri Tab "Fatture"
  Contract? _billedSelectedContract;
  DateTime? _billedSelectedMonth; // null = tutti i mesi
  String _billedPaymentFilter = 'ALL'; // 'ALL', 'PAID', 'UNPAID'

  // Traccia le fatture espanse (per chiave = numero fattura)
  final Set<String> _expandedInvoices = {};

  final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
  final dateFormat = DateFormat('dd/MM/yyyy', 'it_IT');

  List<Lesson> get _filteredUnbilled {
    return _unbilled.where((l) {
      if (_unbilledSelectedContract != null &&
          l.contractId != _unbilledSelectedContract!.id) {
        return false;
      }
      if (_unbilledSelectedMonth != null) {
        final m = _unbilledSelectedMonth!;
        if (l.startDateTime.year != m.year ||
            l.startDateTime.month != m.month) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Map<String, List<Lesson>> get _filteredGroupedBilled {
    final Map<String, List<Lesson>> grouped = {};
    for (final l in _billed) {
      final key = l.invoiceNumber ?? '—';
      grouped.putIfAbsent(key, () => []).add(l);
    }

    final Map<String, List<Lesson>> result = {};
    for (final entry in grouped.entries) {
      final lessons = entry.value;
      final invoiceDate =
          lessons.first.invoiceDate ?? lessons.first.startDateTime;
      final isPaid =
          lessons.isNotEmpty && lessons.every((l) => l.isPaid == true);

      if (_billedSelectedContract != null) {
        final hasContract =
            lessons.any((l) => l.contractId == _billedSelectedContract!.id);
        if (!hasContract) continue;
      }

      if (_billedSelectedMonth != null) {
        final m = _billedSelectedMonth!;
        if (invoiceDate.year != m.year || invoiceDate.month != m.month) {
          continue;
        }
      }

      if (_billedPaymentFilter == 'PAID' && !isPaid) continue;
      if (_billedPaymentFilter == 'UNPAID' && isPaid) continue;

      result[entry.key] = lessons;
    }
    return result;
  }

  void _prevUnbilledMonth() {
    final m = _unbilledSelectedMonth ?? DateTime.now();
    setState(() => _unbilledSelectedMonth = DateTime(m.year, m.month - 1, 1));
  }

  void _nextUnbilledMonth() {
    if (_unbilledSelectedMonth == null) return;
    final next =
        DateTime(_unbilledSelectedMonth!.year, _unbilledSelectedMonth!.month + 1, 1);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() => _unbilledSelectedMonth = next);
  }

  void _prevBilledMonth() {
    final m = _billedSelectedMonth ?? DateTime.now();
    setState(() => _billedSelectedMonth = DateTime(m.year, m.month - 1, 1));
  }

  void _nextBilledMonth() {
    if (_billedSelectedMonth == null) return;
    final next =
        DateTime(_billedSelectedMonth!.year, _billedSelectedMonth!.month + 1, 1);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() => _billedSelectedMonth = next);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUnbilled(), _loadBilled()]);
  }

  Future<void> _loadUnbilled() async {
    setState(() => _loadingUnbilled = true);
    try {
      final results = await Future.wait([
        _service.getUnbilledLessons(),
        _service.getContracts(),
      ]);
      setState(() {
        _unbilled = results[0] as List<Lesson>;
        _contracts = results[1] as List<Contract>;
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loadingUnbilled = false);
    }
  }

  Future<void> _loadBilled() async {
    setState(() => _loadingBilled = true);
    try {
      _billed = await _service.getBilledLessons();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loadingBilled = false);
    }
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _contractName(String? contractId) {
    if (contractId == null) return '—';
    try {
      final c = _contracts.firstWhere((c) => c.id == contractId);
      return c.contractNumber != null && c.contractNumber!.isNotEmpty
          ? '${c.companyName} · ${c.contractNumber}'
          : c.companyName;
    } catch (_) {
      return '—';
    }
  }

  double _lessonHours(Lesson l) {
    final parts = l.duration.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) + (int.tryParse(parts[1]) ?? 0) / 60.0;
  }

  Future<void> _toggleInvoicePaymentStatus(
      List<Lesson> lessons, bool isCurrentlyPaid) async {
    final lessonIds = lessons.map((l) => l.id).toList();
    final newStatus = !isCurrentlyPaid;

    try {
      await _service.markInvoicePaymentStatus(
        lessonIds: lessonIds,
        isPaid: newStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Fattura segnata come PAGATA!'
                  : 'Fattura ripristinata come DA PAGARE.',
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }
      _loadBilled();
    } catch (e) {
      _showError(e);
    }
  }

  // ------------------------------------------------------------------
  // Creazione fattura
  // ------------------------------------------------------------------

  Future<void> _showCreateInvoiceDialog() async {
    if (_selected.isEmpty) return;

    final invoiceController = TextEditingController();
    DateTime invoiceDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Crea Fattura'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResponsiveLayout.kMaxFormWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_selected.length} lezioni selezionate',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: invoiceController,
                  decoration: const InputDecoration(
                    labelText: 'Numero Fattura *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: invoiceDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) setDialogState(() => invoiceDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('Data fattura: ${DateFormat('dd/MM/yyyy').format(invoiceDate)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (invoiceController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && invoiceController.text.trim().isNotEmpty) {
      try {
        await _service.markLessonsAsBilled(
          lessonIds: _selected.toList(),
          invoiceNumber: invoiceController.text.trim(),
          invoiceDate: invoiceDate,
        );
        setState(() => _selected.clear());
        await _loadAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fattura creata con successo!'),
              backgroundColor: Colors.green,
            ),
          );
          _tabController.animateTo(1); // Passa alla tab "Fatture"
        }
      } catch (e) {
        _showError(e);
      }
    }
  }

  // ------------------------------------------------------------------
  // Annulla fatturazione di una singola lezione
  // ------------------------------------------------------------------

  Future<void> _unmarkLesson(Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annulla Fatturazione'),
        content: Text(
          'Rimuovere la lezione "${lesson.summary ?? 'Lezione'}" dalla fattura ${lesson.invoiceNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _service.unmarkLessonBilling(lesson.id);
        await _loadAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lezione spostata in "Da Fatturare".')),
          );
        }
      } catch (e) {
        _showError(e);
      }
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Totale selezionato
    final selectedLessons = _unbilled.where((l) => _selected.contains(l.id)).toList();
    final selectedHours = selectedLessons.fold(0.0, (s, l) => s + _lessonHours(l));
    final selectedAmount = selectedLessons.fold(0.0, (s, l) => s + (l.amount ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fatturazione'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_empty, size: 18),
                  const SizedBox(width: 6),
                  const Text('Da Fatturare'),
                  if (_unbilled.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_unbilled.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Fatture'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ResponsiveLayout.constrainedWidth(_buildUnbilledTab(colorScheme, textTheme)),
          ResponsiveLayout.constrainedWidth(_buildBilledTab(colorScheme, textTheme)),
        ],
      ),
      // FAB visibile solo nella tab "Da Fatturare" con qualcosa di selezionato
      floatingActionButton: _tabController.index == 0 && _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCreateInvoiceDialog,
              icon: const Icon(Icons.receipt_long),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crea Fattura (${_selected.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${selectedHours.toStringAsFixed(1)}h · ${currency.format(selectedAmount)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            )
          : null,
    );
  }

  // ------------------------------------------------------------------
  // Tab 1: Da Fatturare
  // ------------------------------------------------------------------

  Widget _buildUnbilledFilterBar(ColorScheme colorScheme, TextTheme textTheme) {
    final now = DateTime.now();
    final isCurrentMonth = _unbilledSelectedMonth != null &&
        _unbilledSelectedMonth!.year == now.year &&
        _unbilledSelectedMonth!.month == now.month;
    final hasActiveFilters =
        _unbilledSelectedContract != null || _unbilledSelectedMonth != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: colorScheme.surface,
      child: Column(
        children: [
          DropdownButtonFormField<String?>(
            key: ValueKey(_unbilledSelectedContract?.id),
            initialValue: _unbilledSelectedContract?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Filtra per Contratto',
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
              setState(() {
                _unbilledSelectedContract = id == null
                    ? null
                    : _contracts.firstWhere((c) => c.id == id);
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _unbilledSelectedMonth == null,
                        label: const Text('Tutti i mesi'),
                        onSelected: (_) {
                          setState(() => _unbilledSelectedMonth = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      if (_unbilledSelectedMonth != null) ...[
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _prevUnbilledMonth,
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          DateFormat('MMMM yyyy', 'it_IT')
                              .format(_unbilledSelectedMonth!),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: isCurrentMonth ? null : _nextUnbilledMonth,
                          visualDensity: VisualDensity.compact,
                        ),
                      ] else
                        ActionChip(
                          label: const Text('Scegli mese corrente'),
                          onPressed: () {
                            setState(
                              () => _unbilledSelectedMonth =
                                  DateTime(now.year, now.month, 1),
                            );
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
                  tooltip: 'Resetta filtri',
                  onPressed: () {
                    setState(() {
                      _unbilledSelectedContract = null;
                      _unbilledSelectedMonth = null;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnbilledTab(ColorScheme colorScheme, TextTheme textTheme) {
    if (_loadingUnbilled) return const Center(child: CircularProgressIndicator());
    if (_unbilled.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 64, color: Colors.green.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                'Nessuna lezione da fatturare!\nSei in regola.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredList = _filteredUnbilled;
    final allSelected = filteredList.isNotEmpty &&
        filteredList.every((l) => _selected.contains(l.id));

    return Column(
      children: [
        // Sezione filtri
        _buildUnbilledFilterBar(colorScheme, textTheme),
        const Divider(height: 1),

        // Barra selezione globale per gli elementi filtrati
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: colorScheme.surface,
          child: Row(
            children: [
              Checkbox(
                value: allSelected
                    ? true
                    : filteredList.any((l) => _selected.contains(l.id))
                        ? null
                        : false,
                tristate: true,
                onChanged: filteredList.isEmpty
                    ? null
                    : (_) {
                        setState(() {
                          if (allSelected) {
                            _selected.removeAll(filteredList.map((l) => l.id));
                          } else {
                            _selected.addAll(filteredList.map((l) => l.id));
                          }
                        });
                      },
              ),
              Text(
                allSelected
                    ? 'Deseleziona tutto'
                    : '${_selected.where((id) => filteredList.any((l) => l.id == id)).length} di ${filteredList.length} selezionate',
                style: textTheme.bodyMedium,
              ),
              const Spacer(),
              if (_selected.isNotEmpty)
                Text(
                  currency.format(filteredList
                      .where((l) => _selected.contains(l.id))
                      .fold(0.0, (s, l) => s + (l.amount ?? 0))),
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista lezioni
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off,
                            size: 48,
                            color: colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Nessuna lezione corrisponde ai filtri selezionati.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Mostra tutte'),
                          onPressed: () {
                            setState(() {
                              _unbilledSelectedContract = null;
                              _unbilledSelectedMonth = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUnbilled,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildUnbilledTile(
                        filteredList[i], colorScheme, textTheme),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUnbilledTile(
      Lesson lesson, ColorScheme colorScheme, TextTheme textTheme) {
    final isSelected = _selected.contains(lesson.id);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selected.remove(lesson.id);
          } else {
            _selected.add(lesson.id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.07)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.4)
                : colorScheme.outline.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) {
                setState(() {
                  if (isSelected) {
                    _selected.remove(lesson.id);
                  } else {
                    _selected.add(lesson.id);
                  }
                });
              },
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            // Icona data
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    lesson.startDateTime.day.toString(),
                    style: textTheme.titleSmall?.copyWith(
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
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.summary ?? 'Lezione',
                    style:
                        textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _contractName(lesson.contractId),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (lesson.amount != null)
              Text(
                currency.format(lesson.amount),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Tab 2: Fatture (raggruppate per numero fattura)
  // ------------------------------------------------------------------

  Widget _buildBilledFilterBar(ColorScheme colorScheme, TextTheme textTheme) {
    final now = DateTime.now();
    final isCurrentMonth = _billedSelectedMonth != null &&
        _billedSelectedMonth!.year == now.year &&
        _billedSelectedMonth!.month == now.month;
    final hasActiveFilters = _billedSelectedContract != null ||
        _billedSelectedMonth != null ||
        _billedPaymentFilter != 'ALL';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: colorScheme.surface,
      child: Column(
        children: [
          DropdownButtonFormField<String?>(
            key: ValueKey(_billedSelectedContract?.id),
            initialValue: _billedSelectedContract?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Filtra per Contratto',
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
              setState(() {
                _billedSelectedContract = id == null
                    ? null
                    : _contracts.firstWhere((c) => c.id == id);
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _billedSelectedMonth == null,
                        label: const Text('Tutti i mesi'),
                        onSelected: (_) {
                          setState(() => _billedSelectedMonth = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      if (_billedSelectedMonth != null) ...[
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _prevBilledMonth,
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          DateFormat('MMMM yyyy', 'it_IT')
                              .format(_billedSelectedMonth!),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: isCurrentMonth ? null : _nextBilledMonth,
                          visualDensity: VisualDensity.compact,
                        ),
                      ] else
                        ActionChip(
                          label: const Text('Scegli mese corrente'),
                          onPressed: () {
                            setState(
                              () => _billedSelectedMonth =
                                  DateTime(now.year, now.month, 1),
                            );
                          },
                        ),
                      const SizedBox(width: 12),
                      // Filtro stato pagamento
                      ChoiceChip(
                        label: const Text('Tutte'),
                        selected: _billedPaymentFilter == 'ALL',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _billedPaymentFilter = 'ALL');
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Pagate'),
                        selected: _billedPaymentFilter == 'PAID',
                        selectedColor: Colors.green.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _billedPaymentFilter == 'PAID'
                              ? Colors.green.shade800
                              : null,
                          fontWeight: _billedPaymentFilter == 'PAID'
                              ? FontWeight.bold
                              : null,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _billedPaymentFilter = 'PAID');
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Da Pagare'),
                        selected: _billedPaymentFilter == 'UNPAID',
                        selectedColor: Colors.amber.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _billedPaymentFilter == 'UNPAID'
                              ? Colors.amber.shade900
                              : null,
                          fontWeight: _billedPaymentFilter == 'UNPAID'
                              ? FontWeight.bold
                              : null,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _billedPaymentFilter = 'UNPAID');
                          }
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
                  tooltip: 'Resetta filtri',
                  onPressed: () {
                    setState(() {
                      _billedSelectedContract = null;
                      _billedSelectedMonth = null;
                      _billedPaymentFilter = 'ALL';
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBilledTab(ColorScheme colorScheme, TextTheme textTheme) {
    if (_loadingBilled) return const Center(child: CircularProgressIndicator());
    if (_billed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.15)),
              const SizedBox(height: 16),
              Text(
                'Nessuna fattura ancora emessa.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _filteredGroupedBilled;
    final totalBilledAmount = grouped.values
        .expand((l) => l)
        .fold(0.0, (s, l) => s + (l.amount ?? 0));
    final totalBilledHours = grouped.values
        .expand((l) => l)
        .fold(0.0, (s, l) => s + _lessonHours(l));

    return Column(
      children: [
        // Sezione filtri
        _buildBilledFilterBar(colorScheme, textTheme),
        const Divider(height: 1),

        // Barra riassuntiva fatture filtrate
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: colorScheme.primary.withValues(alpha: 0.05),
          child: Row(
            children: [
              Text(
                '${grouped.length} ${grouped.length == 1 ? "fattura" : "fatture"}',
                style:
                    textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Text(
                '${totalBilledHours.toStringAsFixed(1)} h',
                style: textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                currency.format(totalBilledAmount),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista fatture
        Expanded(
          child: grouped.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48,
                            color: colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Nessuna fattura corrisponde ai filtri selezionati.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Mostra tutte'),
                          onPressed: () {
                            setState(() {
                              _billedSelectedContract = null;
                              _billedSelectedMonth = null;
                              _billedPaymentFilter = 'ALL';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBilled,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    itemCount: grouped.length,
                    itemBuilder: (_, i) {
                      final invoiceNum = grouped.keys.elementAt(i);
                      final lessons = grouped[invoiceNum]!;
                      final totalAmount =
                          lessons.fold(0.0, (s, l) => s + (l.amount ?? 0));
                      final totalHours =
                          lessons.fold(0.0, (s, l) => s + _lessonHours(l));
                      final invoiceDate = lessons.first.invoiceDate;
                      final isPaid = lessons.isNotEmpty &&
                          lessons.every((l) => l.isPaid == true);
                      final isExpanded =
                          _expandedInvoices.contains(invoiceNum);

                      return _InvoiceCard(
                        key: ValueKey(invoiceNum),
                        invoiceNum: invoiceNum,
                        lessons: lessons,
                        totalAmount: totalAmount,
                        totalHours: totalHours,
                        invoiceDate: invoiceDate,
                        isPaid: isPaid,
                        isExpanded: isExpanded,
                        currency: currency,
                        dateFormat: dateFormat,
                        textTheme: textTheme,
                        colorScheme: colorScheme,
                        onToggleExpand: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedInvoices.remove(invoiceNum);
                            } else {
                              _expandedInvoices.add(invoiceNum);
                            }
                          });
                        },
                        onTogglePayment: () =>
                            _toggleInvoicePaymentStatus(lessons, isPaid),
                        onUnmarkLesson: _unmarkLesson,
                        contractName: _contractName,
                        lessonHours: _lessonHours,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widget separato per la card fattura con animazione di espansione
// ---------------------------------------------------------------------------

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    super.key,
    required this.invoiceNum,
    required this.lessons,
    required this.totalAmount,
    required this.totalHours,
    required this.invoiceDate,
    required this.isPaid,
    required this.isExpanded,
    required this.currency,
    required this.dateFormat,
    required this.textTheme,
    required this.colorScheme,
    required this.onToggleExpand,
    required this.onTogglePayment,
    required this.onUnmarkLesson,
    required this.contractName,
    required this.lessonHours,
  });

  final String invoiceNum;
  final List<Lesson> lessons;
  final double totalAmount;
  final double totalHours;
  final DateTime? invoiceDate;
  final bool isPaid;
  final bool isExpanded;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final VoidCallback onToggleExpand;
  final VoidCallback onTogglePayment;
  final void Function(Lesson) onUnmarkLesson;
  final String Function(String?) contractName;
  final double Function(Lesson) lessonHours;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaid
              ? Colors.green.withValues(alpha: 0.35)
              : Colors.amber.withValues(alpha: 0.45),
          width: isPaid ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Riga compatta (sempre visibile) ──────────────────────────
            InkWell(
              onTap: onToggleExpand,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green.withValues(alpha: 0.07)
                      : Colors.amber.withValues(alpha: 0.05),
                ),
                child: Row(
                  children: [
                    // Icona stato
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.withValues(alpha: 0.16)
                            : Colors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPaid ? Icons.check_circle : Icons.receipt_long,
                        color: isPaid
                            ? Colors.green.shade700
                            : Colors.amber.shade800,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Numero e data
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fattura N° $invoiceNum',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (invoiceDate != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 11,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.4)),
                                    const SizedBox(width: 3),
                                    Text(
                                      dateFormat.format(invoiceDate!),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.school_rounded,
                                      size: 11,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.4)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${lessons.length} lez · ${totalHours.toStringAsFixed(1)} h',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Importo + badge pagamento
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            currency.format(totalAmount),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? Colors.green.shade700
                                  : colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green.shade100
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isPaid
                                  ? Colors.green.shade400
                                  : Colors.amber.shade400,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isPaid ? 'PAGATA' : 'DA PAGARE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? Colors.green.shade800
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 6),

                    // Freccia expand/collapse
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 250),
                      turns: isExpanded ? 0.5 : 0.0,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Pannello espanso (dettagli + azioni) ─────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(
                            height: 1,
                            color: colorScheme.outline.withValues(alpha: 0.15)),

                        // Azione pagamento
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: onTogglePayment,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? Colors.grey.withValues(alpha: 0.1)
                                        : Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isPaid
                                          ? Colors.grey.shade400
                                          : Colors.green.shade400,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPaid
                                            ? Icons.undo_rounded
                                            : Icons.task_alt_rounded,
                                        size: 15,
                                        color: isPaid
                                            ? Colors.grey.shade700
                                            : Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isPaid
                                            ? 'Segna da pagare'
                                            : 'Segna come Pagata',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isPaid
                                              ? Colors.grey.shade800
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(
                            height: 1,
                            color: colorScheme.outline.withValues(alpha: 0.12)),

                        // Lista lezioni
                        ...lessons.asMap().entries.map((e) {
                          final lesson = e.value;
                          final isLast = e.key == lessons.length - 1;
                          return Column(
                            children: [
                              ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                isThreeLine: true,
                                leading: Container(
                                  width: 40,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        lesson.startDateTime.day.toString(),
                                        style: textTheme.titleSmall?.copyWith(
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
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                title: Text(
                                  lesson.summary ?? 'Lezione',
                                  style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      contractName(lesson.contractId),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.75),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 12,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${lessonHours(lesson).toStringAsFixed(1)} h (${lesson.duration})',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (lesson.amount != null)
                                      Text(
                                        currency.format(lesson.amount),
                                        style: textTheme.titleSmall?.copyWith(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.undo_rounded,
                                          size: 18,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.35)),
                                      tooltip: 'Rimuovi da fattura',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          onUnmarkLesson(lesson),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Divider(
                                    height: 1,
                                    indent: 68,
                                    color: colorScheme.outline
                                        .withValues(alpha: 0.08)),
                            ],
                          );
                        }),

                        const SizedBox(height: 6),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
