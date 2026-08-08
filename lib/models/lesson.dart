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
  final bool isPaid;

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
    this.isPaid = false,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final rawIsPaid = json['is_paid'] ?? json['IsPaid'];
    final rawIsBilled = json['is_billed'] ?? json['IsBilled'];
    final rawIsConfirmed = json['is_confirmed'] ?? json['IsConfirmed'];

    return Lesson(
      id: (json['id'] ?? json['Uid'] ?? '').toString(),
      contractId: json['contract_id'] as String?,
      startDateTime: DateTime.parse(json['start_date_time'] ?? json['StartDateTime']),
      duration: (json['duration'] ?? json['Duration'] ?? '00:00').toString(),
      isConfirmed: rawIsConfirmed == true,
      summary: (json['summary'] ?? json['Summary']) as String?,
      description: (json['description'] ?? json['Description']) as String?,
      location: (json['location'] ?? json['Location']) as String?,
      isBilled: rawIsBilled == true,
      invoiceNumber: (json['invoice_number'] ?? json['InvoiceNumber']) as String?,
      invoiceDate: (json['invoice_date'] ?? json['InvoiceDate']) != null
          ? DateTime.parse((json['invoice_date'] ?? json['InvoiceDate']).toString())
          : null,
      amount: (json['amount'] ?? json['Amount']) != null
          ? ((json['amount'] ?? json['Amount']) as num).toDouble()
          : null,
      isPaid: rawIsPaid == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Includiamo 'id' solo se non è vuoto: se vuoto, il DB genererà
      // automaticamente un UUID tramite DEFAULT gen_random_uuid().
      if (id.isNotEmpty) 'id': id,
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
      if (isPaid) 'is_paid': isPaid,
    };
  }
}
