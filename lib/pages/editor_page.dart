import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../defaults.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

final _decimalInput = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
final _signedDecimalInput = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9.,\-]'),
);

String _numText(double value) => value == 0 ? '' : formatQty(value);

/// Edits a copy of [quotation]; pops with the saved quotation on save.
class QuotationEditorPage extends StatefulWidget {
  final AppState appState;
  final Quotation quotation;
  final bool isNew;

  const QuotationEditorPage({
    super.key,
    required this.appState,
    required this.quotation,
    required this.isNew,
  });

  @override
  State<QuotationEditorPage> createState() => _QuotationEditorPageState();
}

class _QuotationEditorPageState extends State<QuotationEditorPage> {
  late final Quotation q = widget.quotation.copy();
  final _formKey = GlobalKey<FormState>();
  bool _dirty = false;
  bool _saving = false;

  late final _name = TextEditingController(text: q.customerName);
  late final _phone = TextEditingController(text: q.customerPhone);
  late final _address = TextEditingController(text: q.customerAddress);
  late final _email = TextEditingController(text: q.customerEmail);
  late final _number = TextEditingController(text: q.quoteNumber);
  late final _discount = TextEditingController(text: _numText(q.discount));
  late final _tax = TextEditingController(text: _numText(q.tax));
  late final _additional = TextEditingController(text: _numText(q.additional));
  late final _roundOff = TextEditingController(text: _numText(q.roundOff));
  late final _notes = TextEditingController(text: q.notes);
  late final _terms = TextEditingController(text: q.terms);

  List<TextEditingController> get _all => [
    _name,
    _phone,
    _address,
    _email,
    _number,
    _discount,
    _tax,
    _additional,
    _roundOff,
    _notes,
    _terms,
  ];

  /// Controllers also notify on cursor moves; only real text edits count.
  final _lastText = <TextEditingController, String>{};

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      _lastText[c] = c.text;
      c.addListener(() {
        if (_lastText[c] == c.text) return;
        _lastText[c] = c.text;
        _onFieldChanged();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() {
    _pullFields();
    setState(() => _dirty = true);
  }

  void _pullFields() {
    q
      ..customerName = _name.text.trim()
      ..customerPhone = _phone.text.trim()
      ..customerAddress = _address.text.trim()
      ..customerEmail = _email.text.trim()
      ..quoteNumber = _number.text.trim()
      ..discount = parseNumber(_discount.text)
      ..tax = parseNumber(_tax.text)
      ..additional = parseNumber(_additional.text)
      ..roundOff = parseNumber(_roundOff.text)
      ..notes = _notes.text
      ..terms = _terms.text;
  }

  void _changed(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _save() async {
    _pullFields();
    if (!_formKey.currentState!.validate()) {
      _showSnack('Please fill the required fields');
      return;
    }
    if (q.items.isEmpty) {
      _showSnack('Add at least one item');
      return;
    }
    setState(() => _saving = true);
    await widget.appState.saveQuotation(q);
    if (!mounted) return;
    _dirty = false;
    Navigator.pop(context, q);
  }

  void _showSnack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this quotation will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _pickDate({required bool expiry}) async {
    final initial = expiry ? q.expiryDate : q.quotationDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _changed(() {
      if (expiry) {
        q.expiryDate = picked;
      } else {
        final validity = q.expiryDate.difference(q.quotationDate);
        q.quotationDate = picked;
        q.expiryDate = picked.add(validity);
      }
    });
  }

  Future<void> _editItem([int? index]) async {
    final result = await showModalBottomSheet<_ItemResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _ItemSheet(item: index == null ? null : q.items[index]),
    );
    if (result == null) return;
    _changed(() {
      if (result.delete) {
        if (index != null) q.items.removeAt(index);
      } else if (index == null) {
        q.items.add(result.item!);
      } else {
        q.items[index] = result.item!;
      }
    });
  }

  Future<void> _resetItems() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset items?'),
        content: const Text(
          'Replace the current items with the standard item list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) _changed(() => q.items = defaultItems());
  }

  /// Sets Round Off so the total equals the amount entered (lump-sum price).
  Future<void> _setTotal() async {
    final controller = TextEditingController(
      text: q.total == 0 ? '' : formatQty(q.total),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set total amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The difference is added as Round Off, so the PDF total '
              'matches this amount.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalInput],
              decoration: const InputDecoration(
                labelText: 'Total amount',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () =>
                Navigator.pop(context, parseNumber(controller.text)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final roundOff = value - q.totalBeforeRound;
    _roundOff.text = roundOff == 0 ? '' : formatQty(roundOff);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Text(widget.isNew ? 'New Quotation' : 'Edit Quotation'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _customerSection(),
              const SizedBox(height: 14),
              _detailsSection(),
              const SizedBox(height: 14),
              _itemsSection(),
              const SizedBox(height: 14),
              _chargesSection(),
              const SizedBox(height: 14),
              _notesSection(),
            ],
          ),
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  Widget _customerSection() {
    return SectionCard(
      title: 'Customer',
      icon: Icons.person_outline,
      child: Column(
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Customer name *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter customer name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Address (optional)',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              prefixIcon: Icon(Icons.mail_outline, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsSection() {
    Widget dateField(String label, DateTime date, bool expiry) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickDate(expiry: expiry),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(formatDate(date)),
        ),
      ),
    );

    return SectionCard(
      title: 'Quotation details',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quotation No. *',
              prefixText: '# ',
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Enter a quotation number';
              final clash = widget.appState.quotations.any(
                (other) => other.id != q.id && other.quoteNumber == value,
              );
              return clash ? 'This number is already used' : null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              dateField('Quotation date', q.quotationDate, false),
              const SizedBox(width: 12),
              dateField('Expiry date', q.expiryDate, true),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Status',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in quotationStatuses)
                ChoiceChip(
                  label: Text(status),
                  selected: q.status == status,
                  showCheckmark: false,
                  selectedColor: statusColor(status).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: q.status == status
                        ? statusColor(status)
                        : AppColors.text,
                  ),
                  onSelected: (_) => _changed(() => q.status = status),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemsSection() {
    return SectionCard(
      title: 'Items (${q.items.length})',
      icon: Icons.inventory_2_outlined,
      trailing: TextButton.icon(
        onPressed: _resetItems,
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('Reset'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < q.items.length; i++) ...[
            _itemTile(i),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _editItem(),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(int index) {
    final item = q.items[index];
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editItem(index),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    if (item.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${formatQty(item.quantity)} ${item.unit} × '
                          '${formatMoney(item.rate)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatMoney(item.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.muted),
                onSelected: (action) => _changed(() {
                  switch (action) {
                    case 'up':
                      q.items.insert(index - 1, q.items.removeAt(index));
                    case 'down':
                      q.items.insert(index + 1, q.items.removeAt(index));
                    case 'copy':
                      q.items.insert(index + 1, item.copy());
                    case 'delete':
                      q.items.removeAt(index);
                  }
                }),
                itemBuilder: (_) => [
                  if (index > 0)
                    const PopupMenuItem(value: 'up', child: Text('Move up')),
                  if (index < q.items.length - 1)
                    const PopupMenuItem(
                      value: 'down',
                      child: Text('Move down'),
                    ),
                  const PopupMenuItem(value: 'copy', child: Text('Duplicate')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chargesSection() {
    Widget field(
      TextEditingController c,
      String label, {
      String prefix = '₹ ',
      String? suffix,
      bool signed = false,
    }) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(
          decimal: true,
          signed: signed,
        ),
        inputFormatters: [signed ? _signedDecimalInput : _decimalInput],
        decoration: InputDecoration(
          labelText: label,
          hintText: '0',
          prefixText: suffix == null ? prefix : null,
          suffixText: suffix,
        ),
      ),
    );

    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: strong ? AppColors.text : AppColors.muted,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              fontSize: strong ? 16 : 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontSize: strong ? 18 : 14,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );

    return SectionCard(
      title: 'Charges & total',
      icon: Icons.calculate_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              field(_discount, 'Discount'),
              const SizedBox(width: 12),
              field(_tax, 'Tax', suffix: '%'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              field(_additional, 'Additional'),
              const SizedBox(width: 12),
              field(_roundOff, 'Round off', signed: true),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _setTotal,
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text('Set total amount'),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                line('Subtotal', formatMoney(q.subtotal)),
                if (q.discount != 0)
                  line('Discount', '- ${formatMoney(q.discount)}'),
                if (q.tax != 0)
                  line('Tax (${formatQty(q.tax)}%)', formatMoney(q.taxAmount)),
                if (q.additional != 0)
                  line('Additional', formatMoney(q.additional)),
                if (q.roundOff != 0) line('Round off', formatMoney(q.roundOff)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(),
                ),
                line('Total', formatMoney(q.total), strong: true),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    amountInWords(q.total),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesSection() {
    return SectionCard(
      title: 'Notes & terms',
      icon: Icons.notes_outlined,
      child: Column(
        children: [
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _terms,
            minLines: 4,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Terms and conditions',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${q.items.length} items',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formatMoney(q.total),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check, size: 20),
              label: Text(widget.isNew ? 'Save & Preview' : 'Save'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Add / edit item sheet
// ------------------------------------------------------------

class _ItemResult {
  final QuotationItem? item;
  final bool delete;
  const _ItemResult.save(this.item) : delete = false;
  const _ItemResult.delete() : item = null, delete = true;
}

const _units = ['PCS', 'NOS', 'SET', 'MTR', 'KW', 'LOT'];

class _ItemSheet extends StatefulWidget {
  final QuotationItem? item;
  const _ItemSheet({this.item});

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _description = TextEditingController(
    text: widget.item?.description ?? '',
  );
  late final _qty = TextEditingController(
    text: formatQty(widget.item?.quantity ?? 1),
  );
  late final _unit = TextEditingController(text: widget.item?.unit ?? 'PCS');
  late final _rate = TextEditingController(
    text: _numText(widget.item?.rate ?? 0),
  );

  @override
  void initState() {
    super.initState();
    _qty.addListener(_refresh);
    _rate.addListener(_refresh);
    _unit.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _description, _qty, _unit, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ItemResult.save(
        QuotationItem(
          name: _name.text.trim(),
          description: _description.text.trim(),
          quantity: parseNumber(_qty.text),
          unit: _unit.text.trim().toUpperCase(),
          rate: parseNumber(_rate.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseNumber(_qty.text) * parseNumber(_rate.text);
    final isEdit = widget.item != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Edit item' : 'Add item',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: !isEdit,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Item name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter item name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description / brand / specs',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalInput],
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalInput],
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        prefixText: '₹ ',
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (final unit in _units)
                    ChoiceChip(
                      label: Text(unit),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                      selected: _unit.text.trim().toUpperCase() == unit,
                      onSelected: (_) => _unit.text = unit,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const Spacer(),
                    Text(
                      formatMoney(amount),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (isEdit) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, const _ItemResult.delete()),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(isEdit ? 'Update item' : 'Add item'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
