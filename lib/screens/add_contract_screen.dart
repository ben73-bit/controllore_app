import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contract.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';

class AddContractScreen extends StatefulWidget {
  /// Se [contract] è fornito, la schermata è in modalità MODIFICA.
  /// Se [contract] è null, la schermata è in modalità CREA.
  final Contract? contract;

  const AddContractScreen({super.key, this.contract});

  @override
  State<AddContractScreen> createState() => _AddContractScreenState();
}

class _AddContractScreenState extends State<AddContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _contractNumberController = TextEditingController();
  final _rateController = TextEditingController();
  final _limitController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;

  bool get _isEditing => widget.contract != null;

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    // Pre-popola i campi se siamo in modalità modifica
    if (_isEditing) {
      final c = widget.contract!;
      _companyController.text = c.companyName;
      _contractNumberController.text = c.contractNumber ?? '';
      _rateController.text = c.hourlyRate.toString();
      _limitController.text = c.totalHoursLimit?.toString() ?? '';
      _startDate = c.startDate;
      _endDate = c.endDate;
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contractNumberController.dispose();
    _rateController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final contract = Contract(
        id: _isEditing ? widget.contract!.id : null,
        companyName: _companyController.text.trim(),
        contractNumber: _contractNumberController.text.isNotEmpty
            ? _contractNumberController.text.trim()
            : null,
        hourlyRate: double.parse(_rateController.text.replaceAll(',', '.')),
        totalHoursLimit: _limitController.text.isNotEmpty
            ? double.parse(_limitController.text.replaceAll(',', '.'))
            : null,
        billedHours: _isEditing ? widget.contract!.billedHours : 0.0,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (_isEditing) {
        await _supabaseService.updateContract(contract);
      } else {
        await _supabaseService.insertContract(contract);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica Contratto' : 'Nuovo Contratto'),
        // In modalità modifica mostriamo un'icona di salvataggio anche in alto
        actions: _isEditing
            ? [
                TextButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Salva'),
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayout.constrainedWidth(
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Sezione: Dati Azienda ----
                      _sectionLabel(context, 'Dati Azienda / Cliente'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _companyController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Azienda / Cliente',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Campo obbligatorio' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contractNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Numero / Riferimento Contratto (opzionale)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ---- Sezione: Condizioni Economiche ----
                      _sectionLabel(context, 'Condizioni Economiche e Limiti'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _rateController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Tariffa Oraria (€ / ora) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.euro),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Campo obbligatorio';
                          }
                          final parsed =
                              double.tryParse(val.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) {
                            return 'Inserisci un importo valido (> 0)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _limitController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Monte Ore Totale (opzionale)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timelapse),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty) {
                            final parsed =
                                double.tryParse(val.replaceAll(',', '.'));
                            if (parsed == null || parsed <= 0) {
                              return 'Inserisci un numero di ore valido (> 0)';
                            }
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // ---- Sezione: Validità Temporale ----
                      _sectionLabel(context, 'Validità Temporale'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(context, true),
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                  'Inizio: ${dateFormat.format(_startDate)}'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(context, false),
                              icon: const Icon(Icons.event, size: 18),
                              label: Text(_endDate == null
                                  ? 'Nessuna fine'
                                  : 'Fine: ${dateFormat.format(_endDate!)}'),
                            ),
                          ),
                          if (_endDate != null)
                            IconButton(
                              icon: Icon(Icons.clear,
                                  color: colorScheme.error),
                              tooltip: 'Rimuovi data fine',
                              onPressed: () => setState(() => _endDate = null),
                            ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // ---- Pulsante Salva ----
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _save,
                          icon: Icon(_isEditing ? Icons.save : Icons.add),
                          label: Text(
                            _isEditing ? 'SALVA MODIFICHE' : 'CREA CONTRATTO',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              maxWidth: ResponsiveLayout.kMaxFormWidth,
            ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
