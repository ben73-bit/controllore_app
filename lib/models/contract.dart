class Contract {
  final String? id;
  final String companyName;
  final String? contractNumber;
  final double hourlyRate;
  final double? totalHoursLimit;
  final double? billedHours;
  final DateTime startDate;
  final DateTime? endDate;

  Contract({
    this.id,
    required this.companyName,
    this.contractNumber,
    required this.hourlyRate,
    this.totalHoursLimit,
    this.billedHours,
    required this.startDate,
    this.endDate,
  });

  /// Restituisce una rappresentazione stringa completa del contratto (es. "Azienda (N. Contratto)" o solo "Azienda").
  String get displayName {
    if (contractNumber != null && contractNumber!.trim().isNotEmpty) {
      return '$companyName (${contractNumber!.trim()})';
    }
    return companyName;
  }

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'] as String?,
      companyName: json['company_name'] ?? json['Company'],
      contractNumber: json['contract_number'] ?? json['ContractNumber'],
      hourlyRate: (json['hourly_rate'] ?? json['HourlyRate'] as num).toDouble(),
      totalHoursLimit: json['total_hours_limit'] != null ? (json['total_hours_limit'] as num).toDouble() : (json['TotalHours'] != null ? (json['TotalHours'] as num).toDouble() : null),
      billedHours: json['billed_hours'] != null ? (json['billed_hours'] as num).toDouble() : (json['BilledHours'] != null ? (json['BilledHours'] as num).toDouble() : null),
      startDate: DateTime.parse(json['start_date'] ?? json['StartDate']),
      endDate: (json['end_date'] ?? json['EndDate']) != null ? DateTime.parse(json['end_date'] ?? json['EndDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'company_name': companyName,
      'contract_number': contractNumber,
      'hourly_rate': hourlyRate,
      'total_hours_limit': totalHoursLimit,
      'billed_hours': billedHours,
      'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
    };
  }
}
