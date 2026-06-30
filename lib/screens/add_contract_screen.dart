import 'package:flutter/material.dart';
import '../models/contract.dart';
import '../services/supabase_service.dart';

class AddContractScreen extends StatefulWidget {
  const AddContractScreen({super.key});

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

  final SupabaseService _supabaseService = SupabaseService();

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

  Future<void> _saveContract() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final contract = Contract(
        id: null,
        companyName: _companyController.text,
        contractNumber: _contractNumberController.text.isNotEmpty ? _contractNumberController.text : null,
        hourlyRate: double.parse(_rateController.text),
        totalHoursLimit: _limitController.text.isNotEmpty ? double.parse(_limitController.text) : null,
        billedHours: 0.0,
        startDate: _startDate,
        endDate: _endDate,
      );

      await _supabaseService.insertContract(contract);

      if (mounted) {
        Navigator.pop(context, true); // Ritorna true per segnalare che è stato aggiunto
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo Contratto')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Nome Azienda / Cliente',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Campo obbligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contractNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Numero Contratto / Riferimento (Opzionale)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rateController,
                    decoration: const InputDecoration(
                      labelText: 'Tariffa Oraria (€)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.euro),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Campo obbligatorio';
                      if (double.tryParse(val) == null) return 'Inserire un numero valido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _limitController,
                    decoration: const InputDecoration(
                      labelText: 'Monte Ore Totale (Opzionale)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                        return 'Inserire un numero valido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context, true),
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Inizio: ${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context, false),
                          icon: const Icon(Icons.calendar_month),
                          label: Text(_endDate == null 
                            ? 'Imposta Scadenza' 
                            : 'Fine: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                        ),
                      ),
                      if (_endDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _endDate = null),
                        )
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _saveContract,
                      child: const Text('SALVA CONTRATTO', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
