class Lesson {
  final String id;
  final String? contractId; // Rende opzionale per l'importazione iniziale prima del link
  final DateTime startDateTime;
  final String duration;
  final bool isConfirmed;
  final String? summary;
  final String? description;
  final String? location;
  final bool isBilled;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final double? amount;

  Lesson({
    required this.id,
    this.contractId,
    required this.startDateTime,
    required this.duration,
    this.isConfirmed = false,
    this.summary,
    this.description,
    this.location,
    this.isBilled = false,
    this.invoiceNumber,
    this.invoiceDate,
    this.amount,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] ?? json['Uid'],
      contractId: json['contract_id'],
      startDateTime: DateTime.parse(json['start_date_time'] ?? json['StartDateTime']),
      duration: json['duration'] ?? json['Duration'],
      isConfirmed: json['is_confirmed'] ?? json['IsConfirmed'] ?? false,
      summary: json['summary'] ?? json['Summary'],
      description: json['description'] ?? json['Description'],
      location: json['location'] ?? json['Location'],
      isBilled: json['is_billed'] ?? json['IsBilled'] ?? false,
      invoiceNumber: json['invoice_number'] ?? json['InvoiceNumber'],
      invoiceDate: (json['invoice_date'] ?? json['InvoiceDate']) != null ? DateTime.parse(json['invoice_date'] ?? json['InvoiceDate']) : null,
      amount: (json['amount'] ?? json['Amount']) != null ? (json['amount'] ?? json['Amount'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (contractId != null) 'contract_id': contractId,
      'start_date_time': startDateTime.toIso8601String(),
      'duration': duration,
      'is_confirmed': isConfirmed,
      'summary': summary,
      'description': description,
      'location': location,
      'is_billed': isBilled,
      'invoice_number': invoiceNumber,
      if (invoiceDate != null) 'invoice_date': invoiceDate!.toIso8601String(),
      if (amount != null) 'amount': amount,
    };
  }
}
