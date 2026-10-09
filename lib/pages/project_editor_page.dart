import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

String _numText(double value) => value == 0 ? '' : formatQty(value);

/// Edits a copy of [project]; pops with the saved project on save.
class ProjectEditorPage extends StatefulWidget {
  final AppState appState;
  final ProjectFile project;
  final bool isNew;

  const ProjectEditorPage({
    super.key,
    required this.appState,
    required this.project,
    required this.isNew,
  });

  @override
  State<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends State<ProjectEditorPage> {
  late final ProjectFile p = widget.project.copy();
  final _formKey = GlobalKey<FormState>();
  bool _dirty = false;
  bool _saving = false;

  /// Photos copied in during this session; deleted again if discarded.
  final _sessionPhotos = <String>{};

  late final _name = TextEditingController(text: p.customerName);
  late final _phone = TextEditingController(text: p.customerPhone);
  late final _address = TextEditingController(text: p.customerAddress);
  late final _consumerNo = TextEditingController(text: p.consumerNo);
  late final _kseb = TextEditingController(text: p.ksebApplicationNo);
  late final _number = TextEditingController(text: p.projectNumber);
  late final _capacity = TextEditingController(text: p.systemCapacity);
  late final _panel = TextEditingController(text: p.panelDetails);
  late final _inverter = TextEditingController(text: p.inverterDetails);
  late final _serials = TextEditingController(text: p.serialNumbers);
  late final _amount = TextEditingController(text: _numText(p.projectAmount));
  late final _received = TextEditingController(
    text: _numText(p.amountReceived),
  );
  late final _notes = TextEditingController(text: p.notes);

  List<TextEditingController> get _all => [
    _name,
    _phone,
    _address,
    _consumerNo,
    _kseb,
    _number,
    _capacity,
    _panel,
    _inverter,
    _serials,
    _amount,
    _received,
    _notes,
  ];

  final _lastText = <TextEditingController, String>{};

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      _lastText[c] = c.text;
      c.addListener(() {
        if (_lastText[c] == c.text) return;
        _lastText[c] = c.text;
        _pullFields();
        setState(() => _dirty = true);
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

  void _pullFields() {
    p
      ..customerName = _name.text.trim()
      ..customerPhone = _phone.text.trim()
      ..customerAddress = _address.text.trim()
      ..consumerNo = _consumerNo.text.trim()
      ..ksebApplicationNo = _kseb.text.trim()
      ..projectNumber = _number.text.trim()
      ..systemCapacity = _capacity.text.trim()
      ..panelDetails = _panel.text.trim()
      ..inverterDetails = _inverter.text.trim()
      ..serialNumbers = _serials.text.trim()
      ..projectAmount = parseNumber(_amount.text)
      ..amountReceived = parseNumber(_received.text)
      ..notes = _notes.text;
  }

  void _changed(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Future<void> _save() async {
    _pullFields();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill the required fields')),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.appState.saveProject(p);
    if (!mounted) return;
    _dirty = false;
    Navigator.pop(context, p);
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picked = source == ImageSource.camera
        ? [
            await ImagePicker().pickImage(
              source: source,
              maxWidth: 1600,
              imageQuality: 80,
            ),
          ].whereType<XFile>().toList()
        : await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 80);
    if (picked.isEmpty) return;
    final stored = <String>[];
    for (final file in picked) {
      stored.add(await widget.appState.storeProjectPhoto(file.path));
    }
    _sessionPhotos.addAll(stored);
    _changed(() => p.photos.addAll(stored));
  }

  void _removePhoto(String path) {
    _changed(() => p.photos.remove(path));
    // Photos from this session were never saved, so delete them right away;
    // previously saved ones are deleted when the project is saved.
    if (_sessionPhotos.remove(path)) widget.appState.discardPhotos([path]);
  }

  Future<void> _pickInstallationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: p.installationDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) _changed(() => p.installationDate = picked);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this project will be lost.'),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          await widget.appState.discardPhotos(_sessionPhotos);
          _dirty = false;
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Text(widget.isNew ? 'New Project File' : 'Edit Project File'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _customerSection(),
              const SizedBox(height: 14),
              _systemSection(),
              const SizedBox(height: 14),
              _statusSection(),
              const SizedBox(height: 14),
              _paymentSection(),
              const SizedBox(height: 14),
              _photosSection(),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Notes',
                icon: Icons.notes_outlined,
                child: TextField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Anything else about this project',
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check, size: 20),
              label: Text(widget.isNew ? 'Save & Preview' : 'Save'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 12);

  Widget _customerSection() {
    return SectionCard(
      title: 'Customer & KSEB',
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
          _gap(),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
          ),
          _gap(),
          TextFormField(
            controller: _address,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            ),
          ),
          _gap(),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _consumerNo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Consumer No.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Project No. *',
                    prefixText: '# ',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Required';
                    final clash = widget.appState.projects.any(
                      (o) => o.id != p.id && o.projectNumber == value,
                    );
                    return clash ? 'Already used' : null;
                  },
                ),
              ),
            ],
          ),
          _gap(),
          TextFormField(
            controller: _kseb,
            decoration: const InputDecoration(
              labelText: 'KSEB application number',
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemSection() {
    return SectionCard(
      title: 'System details',
      icon: Icons.solar_power_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _capacity,
            decoration: const InputDecoration(
              labelText: 'System capacity',
              hintText: 'e.g. 3 kW',
            ),
          ),
          _gap(),
          TextFormField(
            controller: _panel,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Panel details',
              hintText: 'e.g. WAAREE TOPCON Bifacial 610 W × 5',
            ),
          ),
          _gap(),
          TextFormField(
            controller: _inverter,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Inverter details',
              hintText: 'e.g. DEYE 3 kW micro inverter',
            ),
          ),
          _gap(),
          TextFormField(
            controller: _serials,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Serial numbers (one per line)',
              alignLabelWithHint: true,
            ),
          ),
          _gap(),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickInstallationDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Installation date',
                suffixIcon: p.installationDate == null
                    ? const Icon(Icons.calendar_today_outlined, size: 18)
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            _changed(() => p.installationDate = null),
                      ),
              ),
              child: Text(
                p.installationDate == null
                    ? 'Not installed yet'
                    : formatDate(p.installationDate!),
                style: TextStyle(
                  color: p.installationDate == null
                      ? AppColors.muted
                      : AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSection() {
    return SectionCard(
      title: 'Status',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusPicker(
            label: 'Inspection',
            options: inspectionStatuses,
            value: p.inspectionStatus,
            onChanged: (v) => _changed(() => p.inspectionStatus = v),
          ),
          _StatusPicker(
            label: 'Net meter',
            options: netMeterStatuses,
            value: p.netMeterStatus,
            onChanged: (v) => _changed(() => p.netMeterStatus = v),
          ),
          _StatusPicker(
            label: 'Subsidy',
            options: subsidyStatuses,
            value: p.subsidyStatus,
            onChanged: (v) => _changed(() => p.subsidyStatus = v),
          ),
        ],
      ),
    );
  }

  Widget _paymentSection() {
    final decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
    return SectionCard(
      title: 'Payment',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusPicker(
            label: 'Payment status',
            options: paymentStatuses,
            value: p.paymentStatus,
            onChanged: (v) => _changed(() => p.paymentStatus = v),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimal],
                  decoration: const InputDecoration(
                    labelText: 'Project amount',
                    prefixText: '₹ ',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _received,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimal],
                  decoration: const InputDecoration(
                    labelText: 'Received',
                    prefixText: '₹ ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('Balance', style: TextStyle(color: AppColors.muted)),
                const Spacer(),
                Text(
                  formatMoney(p.balance),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.balance > 0 ? AppColors.red : AppColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photosSection() {
    return SectionCard(
      title: 'Photos (${p.photos.length})',
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.photos.isNotEmpty) ...[
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final path in p.photos)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.background,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(path),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _StatusPicker({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option),
                  selected: value == option,
                  showCheckmark: false,
                  selectedColor: projectStatusColor(
                    option,
                  ).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value == option
                        ? projectStatusColor(option)
                        : AppColors.text,
                  ),
                  onSelected: (_) => onChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
