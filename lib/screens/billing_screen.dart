import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lesson.dart';
import '../models/contract.dart';
import '../services/supabase_service.dart';

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

  // Traccia le fatture espanse (per chiave = numero fattura)
  final Set<String> _expandedInvoices = {};

  final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
  final dateFormat = DateFormat('dd/MM/yyyy', 'it_IT');

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
          content: Column(
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
          _buildUnbilledTab(colorScheme, textTheme),
          _buildBilledTab(colorScheme, textTheme),
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

    // Header selezione
    final allSelected = _selected.length == _unbilled.length;

    return Column(
      children: [
        // Barra selezione globale
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: colorScheme.surface,
          child: Row(
            children: [
              Checkbox(
                value: allSelected
                    ? true
                    : _selected.isEmpty
                        ? false
                        : null,
                tristate: true,
                onChanged: (_) {
                  setState(() {
                    if (allSelected) {
                      _selected.clear();
                    } else {
                      _selected.addAll(_unbilled.map((l) => l.id));
                    }
                  });
                },
              ),
              Text(
                allSelected
                    ? 'Deseleziona tutto'
                    : _selected.isEmpty
                        ? 'Seleziona tutto'
                        : '${_selected.length} di ${_unbilled.length} selezionate',
                style: textTheme.bodyMedium,
              ),
              const Spacer(),
              if (_selected.isNotEmpty)
                Text(
                  currency.format(_unbilled
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUnbilled,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: _unbilled.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _buildUnbilledTile(_unbilled[i], colorScheme, textTheme),
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

    // Raggruppa per numero fattura
    final Map<String, List<Lesson>> grouped = {};
    for (final l in _billed) {
      final key = l.invoiceNumber ?? '—';
      grouped.putIfAbsent(key, () => []).add(l);
    }

    return RefreshIndicator(
      onRefresh: _loadBilled,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: grouped.length,
        itemBuilder: (_, i) {
          final invoiceNum = grouped.keys.elementAt(i);
          final lessons = grouped[invoiceNum]!;
          final totalAmount = lessons.fold(0.0, (s, l) => s + (l.amount ?? 0));
          final totalHours = lessons.fold(0.0, (s, l) => s + _lessonHours(l));
          final invoiceDate = lessons.first.invoiceDate;
          final isPaid = lessons.isNotEmpty && lessons.every((l) => l.isPaid == true);
          final isExpanded = _expandedInvoices.contains(invoiceNum);

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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green.withValues(alpha: 0.07)
                      : Colors.amber.withValues(alpha: 0.05),
                ),
                child: Row(
                  children: [
                    // Icona stato
                    Container(
                      width: 40,
                      height: 40,
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
                    const SizedBox(width: 12),

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
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (invoiceDate != null) ...[
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
                                const SizedBox(width: 8),
                              ],
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
                    ),

                    // Importo + badge pagamento
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currency.format(totalAmount),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPaid
                                ? Colors.green.shade700
                                : colorScheme.primary,
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

                    const SizedBox(width: 8),

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
                                        horizontal: 16, vertical: 2),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      lesson.startDateTime.day.toString(),
                                      style: textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  lesson.summary ?? 'Lezione',
                                  style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  contractName(lesson.contractId),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (lesson.amount != null)
                                      Text(
                                        currency.format(lesson.amount),
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: Colors.green.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.undo,
                                          size: 18,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.3)),
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
