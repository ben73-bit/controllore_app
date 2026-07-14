import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contract.dart';
import '../models/lesson.dart';
import '../services/supabase_service.dart';

class AddLessonScreen extends StatefulWidget {
  /// Se [lesson] è fornito, la schermata è in modalità MODIFICA.
  final Lesson? lesson;

  const AddLessonScreen({super.key, this.lesson});

  @override
  State<AddLessonScreen> createState() => _AddLessonScreenState();
}

class _AddLessonScreenState extends State<AddLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Durata in ore e minuti separati per semplicità
  final _hoursController = TextEditingController(text: '1');
  final _minutesController = TextEditingController(text: '0');

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  Contract? _selectedContract;

  bool _isLoadingData = true;
  bool _isSaving = false;
  List<Contract> _contracts = [];
  String? _lastError; // mostrato permanentemente a schermo

  final SupabaseService _supabaseService = SupabaseService();

  bool get _isEditing => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    _loadContracts();

    // Pre-popola i campi in modalità modifica
    if (_isEditing) {
      final l = widget.lesson!;
      _summaryController.text = l.summary ?? '';

      // Parsing della durata (formato HH:MM:SS o HH:MM)
      final parts = l.duration.split(':');
      if (parts.isNotEmpty) {
        _hoursController.text = (int.tryParse(parts[0]) ?? 1).toString();
      }
      if (parts.length > 1) {
        _minutesController.text = (int.tryParse(parts[1]) ?? 0).toString();
      }

      _startDate = l.startDateTime;
      _startTime = TimeOfDay(
        hour: l.startDateTime.hour,
        minute: l.startDateTime.minute,
      );
    }
  }

  Future<void> _loadContracts() async {
    try {
      final contracts = await _supabaseService.getContracts();
      setState(() {
        _contracts = contracts;
        if (_isEditing) {
          // Seleziona il contratto associato alla lezione da modificare
          try {
            _selectedContract = _contracts.firstWhere(
              (c) => c.id == widget.lesson!.contractId,
            );
          } catch (_) {
            if (_contracts.isNotEmpty) {
              _selectedContract = _contracts.first;
            }
          }
        } else {
          if (_contracts.isNotEmpty) {
            _selectedContract = _contracts.first;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _lastError = 'Errore caricamento contratti: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _saveLesson() async {
    FocusScope.of(context).unfocus();
    setState(() => _lastError = null); // Reset errore precedente

    if (!_formKey.currentState!.validate()) return;
    if (_selectedContract == null) {
      setState(() => _lastError = 'Seleziona un contratto.');
      return;
    }

    final h = int.tryParse(_hoursController.text) ?? 0;
    final m = int.tryParse(_minutesController.text) ?? 0;
    if (h == 0 && m == 0) {
      setState(
        () => _lastError = 'Inserisci una durata valida (almeno 1 minuto).',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final finalDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final durationStr =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
      final totalHoursDecimal = h + (m / 60.0);
      final calculatedAmount =
          totalHoursDecimal * _selectedContract!.hourlyRate;

      final lesson = Lesson(
        id: _isEditing
            ? widget.lesson!.id
            : 'LESSON-${DateTime.now().millisecondsSinceEpoch}',
        contractId: _selectedContract!.id!,
        startDateTime: finalDateTime,
        duration: durationStr,
        isConfirmed: _isEditing ? widget.lesson!.isConfirmed : true,
        summary: _summaryController.text.trim(),
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : (_isEditing ? widget.lesson!.description : null),
        amount: calculatedAmount,
        isBilled: _isEditing ? widget.lesson!.isBilled : false,
        invoiceNumber: _isEditing ? widget.lesson!.invoiceNumber : null,
        invoiceDate: _isEditing ? widget.lesson!.invoiceDate : null,
      );

      if (_isEditing) {
        await _supabaseService.updateLesson(lesson);
      } else {
        // Inserimento semplice senza .select().single() per evitare errori di parsing
        await Supabase.instance.client.from('lessons').insert(lesson.toJson());
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _lastError = 'Errore salvataggio:\n${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica Lezione' : 'Nuova Lezione'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _contracts.isEmpty
          ? _buildNoContracts(context)
          : _buildForm(context),
    );
  }

  Widget _buildNoContracts(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Devi creare almeno un contratto prima di inserire lezioni!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Indietro'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner errore permanente a schermo
            if (_lastError != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastError!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            DropdownButtonFormField<Contract>(
              decoration: const InputDecoration(
                labelText: 'Seleziona Contratto',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              initialValue: _selectedContract,
              items: _contracts
                  .map(
                    (c) =>
                        DropdownMenuItem(value: c, child: Text(c.companyName)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedContract = val),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: 'Oggetto (es. Docenza Base)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),

            // Row per la Durata
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hoursController,
                    decoration: const InputDecoration(
                      labelText: 'Ore',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Req' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _minutesController,
                    decoration: const InputDecoration(
                      labelText: 'Minuti',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Req' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_startTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveLesson,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEditing ? 'SALVA MODIFICHE' : 'REGISTRA LEZIONE',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
