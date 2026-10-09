import 'package:intl/intl.dart';

import 'models.dart';

final _money = NumberFormat('#,##,##0.##', 'en_IN');

/// Indian grouping, decimals only when needed: 236000 -> "2,36,000".
String formatNumber(double value) => _money.format(value);

String formatMoney(double value, {String symbol = '₹ '}) =>
    '$symbol${formatNumber(value)}';

/// 5.0 -> "5", 2.5 -> "2.5".
String formatQty(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

String formatDateShort(DateTime date) => DateFormat('d MMM yyyy').format(date);

/// Quote numbers continue from 0259 (the last number issued before this app).
String generateQuoteNumber(List<Quotation> quotations) {
  var highest = 258;
  for (final quotation in quotations) {
    final number = int.tryParse(quotation.quoteNumber) ?? 0;
    if (number > highest) highest = number;
  }
  return (highest + 1).toString().padLeft(4, '0');
}

double parseNumber(String text) =>
    double.tryParse(text.replaceAll(',', '').trim()) ?? 0;

// ------------------------------------------------------------
// Amount in words, Indian numbering (lakh / crore)
// ------------------------------------------------------------

const _ones = [
  '',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
];
const _tens = [
  '',
  '',
  'Twenty',
  'Thirty',
  'Forty',
  'Fifty',
  'Sixty',
  'Seventy',
  'Eighty',
  'Ninety',
];

String _belowHundred(int n) {
  if (n < 20) return _ones[n];
  final rest = n % 10;
  return rest == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]} ${_ones[rest]}';
}

String _belowThousand(int n) {
  final hundreds = n ~/ 100;
  final rest = n % 100;
  final parts = <String>[
    if (hundreds > 0) '${_ones[hundreds]} Hundred',
    if (rest > 0) _belowHundred(rest),
  ];
  return parts.join(' ');
}

String _integerToWords(int n) {
  if (n == 0) return 'Zero';
  final parts = <String>[];
  final crore = n ~/ 10000000;
  n %= 10000000;
  final lakh = n ~/ 100000;
  n %= 100000;
  final thousand = n ~/ 1000;
  n %= 1000;
  if (crore > 0) parts.add('${_integerToWords(crore)} Crore');
  if (lakh > 0) parts.add('${_belowHundred(lakh)} Lakh');
  if (thousand > 0) parts.add('${_belowHundred(thousand)} Thousand');
  if (n > 0) parts.add(_belowThousand(n));
  return parts.join(' ');
}

/// 236000 -> "Two Lakh Thirty Six Thousand Rupees".
String amountInWords(double amount) {
  final negative = amount < 0;
  final abs = amount.abs();
  final rupees = abs.floor();
  final paise = ((abs - rupees) * 100).round();
  var words = '${_integerToWords(rupees)} Rupees';
  if (paise > 0) words += ' and ${_belowHundred(paise)} Paise';
  return negative ? 'Minus $words' : words;
}
