// Data models. Every `fromJson` falls back to a default for missing fields so
// quotations saved by older versions of the app keep loading.

const quotationStatuses = ['Draft', 'Sent', 'Accepted', 'Rejected'];

class CompanySettings {
  String name;
  String address;
  String phone;
  String phone2;
  String email;
  String gst;
  String signatory;

  /// Absolute path of the signature image copied into app storage, or ''.
  String signaturePath;

  CompanySettings({
    this.name = 'PRIME VOLT TECHNOLOGY',
    this.address = 'KONDOTTY, KONDOTTY, Kerala',
    this.phone = '9037954951',
    this.phone2 = '8139090517',
    this.email = '',
    this.gst = '',
    this.signatory = 'Authorised Signatory',
    this.signaturePath = '',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'phone': phone,
    'phone2': phone2,
    'email': email,
    'gst': gst,
    'signatory': signatory,
    'signaturePath': signaturePath,
  };

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    final d = CompanySettings();
    return CompanySettings(
      name: json['name'] ?? d.name,
      address: json['address'] ?? d.address,
      phone: json['phone'] ?? d.phone,
      phone2: json['phone2'] ?? d.phone2,
      email: json['email'] ?? d.email,
      gst: json['gst'] ?? d.gst,
      signatory: json['signatory'] ?? d.signatory,
      signaturePath: json['signaturePath'] ?? d.signaturePath,
    );
  }
}

class QuotationItem {
  String name;
  String description;
  double quantity;
  String unit;
  double rate;

  QuotationItem({
    required this.name,
    this.description = '',
    this.quantity = 1,
    this.unit = 'PCS',
    this.rate = 0,
  });

  double get amount => quantity * rate;

  QuotationItem copy() => QuotationItem.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'rate': rate,
  };

  factory QuotationItem.fromJson(Map<String, dynamic> json) => QuotationItem(
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unit: json['unit'] ?? 'PCS',
    rate: (json['rate'] as num?)?.toDouble() ?? 0,
  );
}

class Quotation {
  String id;
  String quoteNumber;
  DateTime quotationDate;
  DateTime expiryDate;
  String customerName;
  String customerPhone;
  String customerEmail;
  String customerAddress;
  List<QuotationItem> items;

  /// Flat amount.
  double discount;

  /// Percentage of the amount after discount.
  double tax;
  double additional;
  double roundOff;
  String notes;
  String terms;
  String status;

  /// Firebase uid and display name of the person who created it ('' for
  /// records made before sign-in existed).
  String createdByUid;
  String createdByName;

  Quotation({
    required this.id,
    required this.quoteNumber,
    required this.quotationDate,
    required this.expiryDate,
    required this.customerName,
    this.customerPhone = '',
    this.customerEmail = '',
    this.customerAddress = '',
    required this.items,
    this.discount = 0,
    this.tax = 0,
    this.additional = 0,
    this.roundOff = 0,
    this.notes = '',
    this.terms = '',
    this.status = 'Draft',
    this.createdByUid = '',
    this.createdByName = '',
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.amount);
  double get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  double get afterDiscount => subtotal - discount;
  double get taxAmount => afterDiscount * tax / 100;
  double get totalBeforeRound => afterDiscount + taxAmount + additional;
  double get total => totalBeforeRound + roundOff;

  /// Deep copy, so an editor can change it without touching the saved one.
  Quotation copy() => Quotation.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'quoteNumber': quoteNumber,
    'quotationDate': quotationDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerEmail': customerEmail,
    'customerAddress': customerAddress,
    'items': items.map((e) => e.toJson()).toList(),
    'discount': discount,
    'tax': tax,
    'additional': additional,
    'roundOff': roundOff,
    'notes': notes,
    'terms': terms,
    'status': status,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
  };

  factory Quotation.fromJson(Map<String, dynamic> json) => Quotation(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    quoteNumber: json['quoteNumber'] ?? '0000',
    quotationDate:
        DateTime.tryParse(json['quotationDate'] ?? '') ?? DateTime.now(),
    expiryDate:
        DateTime.tryParse(json['expiryDate'] ?? '') ??
        DateTime.now().add(const Duration(days: 15)),
    customerName: json['customerName'] ?? '',
    customerPhone: json['customerPhone'] ?? '',
    customerEmail: json['customerEmail'] ?? '',
    customerAddress: json['customerAddress'] ?? '',
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => QuotationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    discount: (json['discount'] as num?)?.toDouble() ?? 0,
    tax: (json['tax'] as num?)?.toDouble() ?? 0,
    additional: (json['additional'] as num?)?.toDouble() ?? 0,
    roundOff: (json['roundOff'] as num?)?.toDouble() ?? 0,
    notes: json['notes'] ?? '',
    terms: json['terms'] ?? '',
    status: json['status'] ?? 'Draft',
    createdByUid: json['createdByUid'] ?? '',
    createdByName: json['createdByName'] ?? '',
  );
}

// ------------------------------------------------------------
// Project file (one per installed project)
// ------------------------------------------------------------

const inspectionStatuses = ['Pending', 'Scheduled', 'Completed'];
const netMeterStatuses = ['Not Applied', 'Applied', 'Installed'];
const subsidyStatuses = ['Not Applied', 'Applied', 'Approved', 'Received'];
const paymentStatuses = ['Pending', 'Partial', 'Paid'];

class ProjectFile {
  String id;
  String projectNumber;
  DateTime createdDate;
  String customerName;
  String customerPhone;
  String customerAddress;
  String consumerNo;

  /// Free text such as "3 kW".
  String systemCapacity;
  String panelDetails;
  String inverterDetails;

  /// One serial number per line (panels, inverter, meter...).
  String serialNumbers;
  DateTime? installationDate;

  /// Absolute paths of photos copied into app storage.
  List<String> photos;
  String ksebApplicationNo;
  String inspectionStatus;
  String netMeterStatus;
  String subsidyStatus;
  String paymentStatus;
  double projectAmount;
  double amountReceived;
  String notes;

  /// Quotation this project was created from, or ''.
  String quotationId;

  /// Firebase uid and display name of the person who created it ('' for
  /// records made before sign-in existed).
  String createdByUid;
  String createdByName;

  ProjectFile({
    required this.id,
    required this.projectNumber,
    required this.createdDate,
    this.customerName = '',
    this.customerPhone = '',
    this.customerAddress = '',
    this.consumerNo = '',
    this.systemCapacity = '',
    this.panelDetails = '',
    this.inverterDetails = '',
    this.serialNumbers = '',
    this.installationDate,
    List<String>? photos,
    this.ksebApplicationNo = '',
    this.inspectionStatus = 'Pending',
    this.netMeterStatus = 'Not Applied',
    this.subsidyStatus = 'Not Applied',
    this.paymentStatus = 'Pending',
    this.projectAmount = 0,
    this.amountReceived = 0,
    this.notes = '',
    this.quotationId = '',
    this.createdByUid = '',
    this.createdByName = '',
  }) : photos = photos ?? [];

  double get balance => projectAmount - amountReceived;

  /// Rough progress for list badges: how many of the 4 stages are done.
  int get stagesDone => [
    inspectionStatus == 'Completed',
    netMeterStatus == 'Installed',
    subsidyStatus == 'Received',
    paymentStatus == 'Paid',
  ].where((done) => done).length;

  ProjectFile copy() => ProjectFile.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectNumber': projectNumber,
    'createdDate': createdDate.toIso8601String(),
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerAddress': customerAddress,
    'consumerNo': consumerNo,
    'systemCapacity': systemCapacity,
    'panelDetails': panelDetails,
    'inverterDetails': inverterDetails,
    'serialNumbers': serialNumbers,
    'installationDate': installationDate?.toIso8601String(),
    'photos': photos,
    'ksebApplicationNo': ksebApplicationNo,
    'inspectionStatus': inspectionStatus,
    'netMeterStatus': netMeterStatus,
    'subsidyStatus': subsidyStatus,
    'paymentStatus': paymentStatus,
    'projectAmount': projectAmount,
    'amountReceived': amountReceived,
    'notes': notes,
    'quotationId': quotationId,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
  };

  factory ProjectFile.fromJson(Map<String, dynamic> json) => ProjectFile(
    id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
    projectNumber: json['projectNumber'] ?? '0000',
    createdDate: DateTime.tryParse(json['createdDate'] ?? '') ?? DateTime.now(),
    customerName: json['customerName'] ?? '',
    customerPhone: json['customerPhone'] ?? '',
    customerAddress: json['customerAddress'] ?? '',
    consumerNo: json['consumerNo'] ?? '',
    systemCapacity: json['systemCapacity'] ?? '',
    panelDetails: json['panelDetails'] ?? '',
    inverterDetails: json['inverterDetails'] ?? '',
    serialNumbers: json['serialNumbers'] ?? '',
    installationDate: DateTime.tryParse(json['installationDate'] ?? ''),
    photos: (json['photos'] as List<dynamic>? ?? []).cast<String>().toList(),
    ksebApplicationNo: json['ksebApplicationNo'] ?? '',
    inspectionStatus: json['inspectionStatus'] ?? 'Pending',
    netMeterStatus: json['netMeterStatus'] ?? 'Not Applied',
    subsidyStatus: json['subsidyStatus'] ?? 'Not Applied',
    paymentStatus: json['paymentStatus'] ?? 'Pending',
    projectAmount: (json['projectAmount'] as num?)?.toDouble() ?? 0,
    amountReceived: (json['amountReceived'] as num?)?.toDouble() ?? 0,
    notes: json['notes'] ?? '',
    quotationId: json['quotationId'] ?? '',
    createdByUid: json['createdByUid'] ?? '',
    createdByName: json['createdByName'] ?? '',
  );
}

// ------------------------------------------------------------
// Expense
// ------------------------------------------------------------

const expenseCategories = [
  'Materials',
  'Labour',
  'Transport',
  'Fuel',
  'Food',
  'Salary',
  'Office',
  'Other',
];
const paymentModes = ['Cash', 'UPI', 'Bank', 'Cheque'];

class Expense {
  String id;
  DateTime date;
  String category;
  String description;
  double amount;
  String paymentMode;
  String paidTo;

  /// Linked project file id, or ''.
  String projectId;
  String notes;
  String createdByUid;
  String createdByName;

  Expense({
    required this.id,
    required this.date,
    this.category = 'Materials',
    this.description = '',
    this.amount = 0,
    this.paymentMode = 'Cash',
    this.paidTo = '',
    this.projectId = '',
    this.notes = '',
    this.createdByUid = '',
    this.createdByName = '',
  });

  Expense copy() => Expense.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'category': category,
    'description': description,
    'amount': amount,
    'paymentMode': paymentMode,
    'paidTo': paidTo,
    'projectId': projectId,
    'notes': notes,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    category: json['category'] ?? 'Other',
    description: json['description'] ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    paymentMode: json['paymentMode'] ?? 'Cash',
    paidTo: json['paidTo'] ?? '',
    projectId: json['projectId'] ?? '',
    notes: json['notes'] ?? '',
    createdByUid: json['createdByUid'] ?? '',
    createdByName: json['createdByName'] ?? '',
  );
}
