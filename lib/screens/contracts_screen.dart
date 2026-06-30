import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contract.dart';
import '../services/supabase_service.dart';
import 'add_contract_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Contract> _contracts = [];

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    setState(() => _isLoading = true);
    try {
      final contracts = await _supabaseService.getContracts();
      setState(() {
        _contracts = contracts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento dei contratti: $e')),
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
      appBar: AppBar(title: const Text('I Miei Contratti')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contracts.isEmpty
          ? _buildEmptyState(textTheme)
          : RefreshIndicator(
              onRefresh: _loadContracts,
              child: ListView.separated(
                padding: const EdgeInsets.all(24.0),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _contracts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildContractCard(
                    _contracts[index],
                    textTheme,
                    colorScheme,
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddContractScreen()),
          ).then((added) {
            if (added == true) {
              _loadContracts();
            }
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text('Nessun contratto trovato.', style: textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildContractCard(
    Contract contract,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final formatDate = DateFormat('dd MMM yyyy', 'it_IT');

    // Calcolo progresso ore
    double progress = 0.0;
    if (contract.totalHoursLimit != null && contract.totalHoursLimit! > 0) {
      final billed = contract.billedHours ?? 0;
      progress = (billed / contract.totalHoursLimit!).clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Azienda e Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  contract.companyName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Attivo', // Potremmo calcolarlo in base a endDate
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (contract.contractNumber != null)
            Text(
              'Rif: ${contract.contractNumber}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),

          // Dettagli Tariffe e Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(
                Icons.payments_outlined,
                'Tariffa',
                '${formatCurrency.format(contract.hourlyRate)}/h',
                textTheme,
                colorScheme,
              ),
              _buildDetailItem(
                Icons.calendar_today_outlined,
                'Inizio',
                formatDate.format(contract.startDate),
                textTheme,
                colorScheme,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress Bar Ore
          if (contract.totalHoursLimit != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ore Fatturate: ${contract.billedHours ?? 0} / ${contract.totalHoursLimit}',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
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
                minHeight: 8,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ] else ...[
            Text(
              'Nessun limite ore impostato.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.secondary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.secondary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
