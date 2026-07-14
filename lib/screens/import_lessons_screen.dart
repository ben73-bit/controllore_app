import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lesson.dart';
import '../models/contract.dart';
import '../services/supabase_service.dart';

class ImportLessonsScreen extends StatefulWidget {
  final List<Lesson> parsedLessons;

  const ImportLessonsScreen({super.key, required this.parsedLessons});

  @override
  State<ImportLessonsScreen> createState() => _ImportLessonsScreenState();
}

class _ImportLessonsScreenState extends State<ImportLessonsScreen> {
  final SupabaseService _service = SupabaseService();

  List<Contract> _contracts = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Mappa per tenere traccia delle lezioni selezionate (chiave: indice nella lista originaria)
  final Set<int> _selectedIndices = {};

  // Mappa per assegnare i contratti alle singole lezioni (chiave: indice, valore: contractId)
  final Map<int, String?> _assignedContracts = {};

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');

  @override
  void initState() {
    super.initState();
    // Seleziona tutte le lezioni di default
    for (int i = 0; i < widget.parsedLessons.length; i++) {
      _selectedIndices.add(i);
    }
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    try {
      final contracts = await _service.getContracts();
      setState(() {
        _contracts = contracts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento contratti: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importSelected() async {
    // Raccoglie le lezioni selezionate
    final List<Lesson> lessonsToImport = [];

    for (final index in _selectedIndices) {
      final contractId = _assignedContracts[index];

      if (contractId == null || contractId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Assicurati di assegnare un contratto a tutte le lezioni selezionate.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final originalLesson = widget.parsedLessons[index];

      // Calcola l'amount se il contratto ha una tariffa
      double? amount;
      try {
        final c = _contracts.firstWhere((c) => c.id == contractId);
        final parts = originalLesson.duration.split(':');
        if (parts.length >= 2) {
          final hours =
              (int.tryParse(parts[0]) ?? 0) +
              (int.tryParse(parts[1]) ?? 0) / 60.0;
          amount = hours * c.hourlyRate;
        }
      } catch (_) {}

      lessonsToImport.add(
        Lesson(
          id: '', // Sarà ignorato e ricreato dal DB
          contractId: contractId,
          startDateTime: originalLesson.startDateTime,
          duration: originalLesson.duration,
          summary: originalLesson.summary,
          amount: amount,
          isBilled: false,
        ),
      );
    }

    if (lessonsToImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna lezione selezionata.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _service.insertLessons(lessonsToImport);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lessonsToImport.length} lezioni importate con successo!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Torna indietro segnalando successo
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore importazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Permette di assegnare un contratto a tutte le lezioni selezionate
  Future<void> _assignContractToAllSelected() async {
    if (_contracts.isEmpty) return;

    final contract = await showDialog<Contract>(
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
                title: Text(c.companyName),
                subtitle: c.contractNumber != null
                    ? Text(c.contractNumber!)
                    : null,
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

    if (contract != null) {
      setState(() {
        for (final idx in _selectedIndices) {
          _assignedContracts[idx] = contract.id;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Riepilogo Importazione')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: colorScheme.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedIndices.length} di ${widget.parsedLessons.length} selezionate',
                        style: textTheme.titleMedium,
                      ),
                      OutlinedButton.icon(
                        onPressed: _selectedIndices.isEmpty
                            ? null
                            : _assignContractToAllSelected,
                        icon: const Icon(Icons.assignment_ind, size: 18),
                        label: const Text('Assegna a tutte'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: widget.parsedLessons.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lesson = widget.parsedLessons[index];
                      final isSelected = _selectedIndices.contains(index);
                      final contractId = _assignedContracts[index];

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.05)
                              : colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.3)
                                : colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIndices.add(index);
                                  } else {
                                    _selectedIndices.remove(index);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lesson.summary ?? 'Evento senza titolo',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      decoration: isSelected
                                          ? null
                                          : TextDecoration.lineThrough,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_dateFormat.format(lesson.startDateTime)} • ${lesson.duration}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Dropdown Contratto
                                  // ignore: deprecated_member_use
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        contractId, // Usiamo 'value' ignorando il lint oppure initialValue
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      labelText: 'Contratto',
                                      labelStyle: const TextStyle(fontSize: 12),
                                    ),
                                    items: _contracts.map((c) {
                                      return DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          c.companyName,
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: isSelected
                                        ? (val) => setState(
                                            () =>
                                                _assignedContracts[index] = val,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedIndices.isNotEmpty
          ? SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: FloatingActionButton.extended(
                onPressed: _isSaving ? null : _importSelected,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _isSaving
                      ? 'Salvataggio...'
                      : 'Importa ${_selectedIndices.length} Lezioni',
                ),
              ),
            )
          : null,
    );
  }
}
