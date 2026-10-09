import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_genarator/defaults.dart';
import 'package:pdf_genarator/models.dart';
import 'package:pdf_genarator/utils.dart';

void main() {
  test('amountInWords uses lakh/crore', () {
    expect(amountInWords(236000), 'Two Lakh Thirty Six Thousand Rupees');
    expect(amountInWords(0), 'Zero Rupees');
    expect(
      amountInWords(12345678.5),
      'One Crore Twenty Three Lakh Forty Five Thousand Six Hundred '
      'Seventy Eight Rupees and Fifty Paise',
    );
  });

  test('formatMoney uses Indian grouping', () {
    expect(formatMoney(236000), '₹ 2,36,000');
    expect(formatMoney(1500.5), '₹ 1,500.5');
    expect(formatQty(5), '5');
  });

  test('quote numbers continue from 0259', () {
    expect(generateQuoteNumber([]), '0259');
    final q = Quotation(
      id: '1',
      quoteNumber: '0300',
      quotationDate: DateTime(2026),
      expiryDate: DateTime(2026),
      customerName: 'A',
      items: defaultItems(),
    );
    expect(generateQuoteNumber([q]), '0301');
  });

  test('round off acts as lump-sum total', () {
    final q = Quotation(
      id: '1',
      quoteNumber: '0259',
      quotationDate: DateTime(2026),
      expiryDate: DateTime(2026),
      customerName: 'A',
      items: defaultItems(),
      roundOff: 236000,
    );
    expect(q.items.length, 18);
    expect(q.totalQuantity, 24);
    expect(q.total, 236000);
  });

  test('project file survives a save/load round trip', () {
    final p = ProjectFile(
      id: 'x',
      projectNumber: '0001',
      createdDate: DateTime(2026, 10, 9),
      customerName: 'LATHEEFKA',
      installationDate: DateTime(2026, 10, 20),
      photos: ['/a.jpg'],
      projectAmount: 236000,
      amountReceived: 100000,
      paymentStatus: 'Partial',
    );
    final back = ProjectFile.fromJson(p.toJson());
    expect(back.installationDate, DateTime(2026, 10, 20));
    expect(back.photos, ['/a.jpg']);
    expect(back.balance, 136000);
    expect(ProjectFile.fromJson({}).inspectionStatus, 'Pending');
  });
}
