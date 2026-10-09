import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../glass_nav_bar.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  final AppState appState;
  const SettingsPage({super.key, required this.appState});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late CompanySettings _company = widget.appState.company;

  late final _name = TextEditingController(text: _company.name);
  late final _address = TextEditingController(text: _company.address);
  late final _phone = TextEditingController(text: _company.phone);
  late final _phone2 = TextEditingController(text: _company.phone2);
  late final _email = TextEditingController(text: _company.email);
  late final _gst = TextEditingController(text: _company.gst);
  late final _signatory = TextEditingController(text: _company.signatory);

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _phone,
      _phone2,
      _email,
      _gst,
      _signatory,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _company = CompanySettings(
      name: _name.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      phone2: _phone2.text.trim(),
      email: _email.text.trim(),
      gst: _gst.text.trim(),
      signatory: _signatory.text.trim(),
      signaturePath: widget.appState.company.signaturePath,
    );
    await widget.appState.saveCompany(_company);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Company details saved')));
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: widget.appState.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.length < 2) return;
    await widget.appState.saveUserName(name);
    if (mounted) setState(() {});
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your data stays safe in the cloud. Sign in again to see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await widget.appState.signOut();
  }

  Future<void> _pickSignature() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (picked == null) return;
    await widget.appState.setSignature(picked.path);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final signaturePath = widget.appState.company.signaturePath;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            navBarClearance(context) + 20,
          ),
          children: [
            SectionCard(
              title: 'Account',
              icon: Icons.account_circle_outlined,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Signed in as',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                        InkWell(
                          onTap: _editName,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.appState.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: AppColors.navy,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          widget.appState.user?.email ?? '',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Data syncs with everyone who signs in.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'PDF logo',
              icon: Icons.image_outlined,
              child: Row(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Image.asset('assets/company_logo.png'),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'This logo is printed at the top of every quotation PDF.',
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Company details',
              icon: Icons.business_outlined,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Company name *',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter company name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phone2,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile 2',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _gst,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'GSTIN'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _signatory,
                    decoration: const InputDecoration(
                      labelText: 'Signatory title',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Signature',
              icon: Icons.draw_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 110,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: signaturePath.isEmpty
                        ? const Text(
                            'No signature added',
                            style: TextStyle(color: AppColors.muted),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.file(
                              File(signaturePath),
                              key: ValueKey(signaturePath),
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tip: use a photo of your signature on white paper. It '
                    'appears above "Authorised Signatory" on every PDF.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickSignature,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(signaturePath.isEmpty ? 'Add' : 'Change'),
                        ),
                      ),
                      if (signaturePath.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await widget.appState.removeSignature();
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save company details'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
