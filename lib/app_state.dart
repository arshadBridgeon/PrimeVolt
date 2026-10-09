import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'defaults.dart';
import 'models.dart';
import 'utils.dart';

/// Single source of truth, created once in the app root and passed down.
///
/// Data lives in Firestore and is shared by every signed-in user:
///   quotations/{id}, projects/{id}, settings/company
/// Live snapshot listeners keep both phones in sync. Writes are not awaited
/// against the server: Firestore applies them to the local cache at once and
/// syncs when online, so the app also works offline.
///
/// Images are NOT uploaded (Firebase Storage needs a paid plan): project
/// photos and the signature stay on the phone that added them.
class AppState extends ChangeNotifier {
  AppState() {
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  CollectionReference<Map<String, dynamic>> get _quotationsRef =>
      _db.collection('quotations');
  CollectionReference<Map<String, dynamic>> get _projectsRef =>
      _db.collection('projects');
  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      _db.collection('expenses');
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');
  DocumentReference<Map<String, dynamic>> get _categoriesRef =>
      _db.collection('settings').doc('expense_categories');
  DocumentReference<Map<String, dynamic>> get _companyRef =>
      _db.collection('settings').doc('company');

  List<Quotation> quotations = [];
  List<ProjectFile> projects = [];

  /// Newest first.
  List<Expense> expenses = [];

  /// Shared, editable list (settings/expense_categories); defaults until set.
  List<String> expenseCategoryList = [...expenseCategories];
  CompanySettings company = CompanySettings();

  User? user;

  /// uid -> display name for everyone who has set one (users/{uid}).
  Map<String, String> userNames = {};

  /// The signed-in person's name; empty until they enter it.
  String get userName => userNames[user?.uid] ?? '';

  /// Current name of whoever created a record, falling back to the name
  /// stored on the record if that person's profile is unknown.
  String creatorName(String uid, String storedName) =>
      userNames[uid] ?? storedName;

  /// False until Firebase reports whether someone is signed in.
  bool authReady = false;

  /// True while the first snapshots after sign-in are loading.
  bool loading = false;

  StreamSubscription<User?>? _authSub;
  final _dataSubs = <StreamSubscription<dynamic>>[];

  // Keys of the pre-Firebase local storage, uploaded once on first sign-in.
  static const _localQuotationsKey = 'quotations';
  static const _localProjectsKey = 'projects';
  static const _localCompanyKey = 'company_settings';
  static const _migratedKey = 'migrated_to_firestore';

  /// The signature image is per phone, so its path is kept locally.
  static const _signatureKey = 'signature_path';

  // ---------- Auth ----------

  Future<void> _onAuthChanged(User? newUser) async {
    user = newUser;
    authReady = true;
    await _stopListening();
    if (newUser == null) {
      quotations = [];
      projects = [];
      expenses = [];
      expenseCategoryList = [...expenseCategories];
      company = CompanySettings();
      userNames = {};
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    await _migrateLocalData();
    await _startListening();
  }

  /// Returns null on success, or a message to show.
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Wrong email or password.',
        'too-many-requests' => 'Too many attempts. Try again in a while.',
        'network-request-failed' => 'No internet connection.',
        _ => e.message ?? 'Sign in failed (${e.code}).',
      };
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send reset email (${e.code}).';
    }
  }

  Future<void> signOut() => _auth.signOut();

  // ---------- Live sync ----------

  Future<void> _startListening() async {
    final localSignature = await _prefs.getString(_signatureKey) ?? '';
    var pending = {
      'quotations',
      'projects',
      'expenses',
      'categories',
      'company',
      'users',
    };
    void loaded(String part) {
      if (pending.remove(part) && pending.isEmpty) loading = false;
      notifyListeners();
    }

    void onError(Object e) {
      debugPrint('Firestore listen error: $e');
      loading = false;
      notifyListeners();
    }

    _dataSubs.add(
      _usersRef.snapshots().listen((snap) {
        userNames = {
          for (final d in snap.docs)
            if ((d.data()['name'] as String? ?? '').isNotEmpty)
              d.id: d.data()['name'] as String,
        };
        loaded('users');
      }, onError: onError),
    );
    _dataSubs.add(
      _quotationsRef.snapshots().listen((snap) {
        quotations = snap.docs.map((d) => Quotation.fromJson(d.data())).toList()
          ..sort(_byNumberDesc((q) => q.quoteNumber));
        loaded('quotations');
      }, onError: onError),
    );
    _dataSubs.add(
      _projectsRef.snapshots().listen((snap) {
        projects = snap.docs.map((d) => ProjectFile.fromJson(d.data())).toList()
          ..sort(_byNumberDesc((p) => p.projectNumber));
        loaded('projects');
      }, onError: onError),
    );
    _dataSubs.add(
      _expensesRef.snapshots().listen((snap) {
        expenses = snap.docs.map((d) => Expense.fromJson(d.data())).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        loaded('expenses');
      }, onError: onError),
    );
    _dataSubs.add(
      _categoriesRef.snapshots().listen((snap) {
        final list = (snap.data()?['list'] as List<dynamic>?)?.cast<String>();
        expenseCategoryList = (list == null || list.isEmpty)
            ? [...expenseCategories]
            : list;
        loaded('categories');
      }, onError: onError),
    );
    _dataSubs.add(
      _companyRef.snapshots().listen((snap) {
        company = snap.exists
            ? CompanySettings.fromJson(snap.data()!)
            : CompanySettings();
        company.signaturePath = localSignature;
        loaded('company');
      }, onError: onError),
    );
  }

  Future<void> _stopListening() async {
    for (final sub in _dataSubs) {
      await sub.cancel();
    }
    _dataSubs.clear();
  }

  static int Function(T, T) _byNumberDesc<T>(String Function(T) number) =>
      (a, b) {
        final na = int.tryParse(number(a)) ?? 0;
        final nb = int.tryParse(number(b)) ?? 0;
        return nb.compareTo(na);
      };

  /// Uploads data saved on this phone before Firebase was added, once.
  Future<void> _migrateLocalData() async {
    try {
      if (await _prefs.getBool(_migratedKey) ?? false) return;
      final batch = _db.batch();
      var count = 0;

      final q = await _prefs.getString(_localQuotationsKey);
      if (q != null && q.isNotEmpty) {
        for (final e in jsonDecode(q) as List<dynamic>) {
          final quotation = Quotation.fromJson(Map<String, dynamic>.from(e));
          batch.set(_quotationsRef.doc(quotation.id), quotation.toJson());
          count++;
        }
      }
      final p = await _prefs.getString(_localProjectsKey);
      if (p != null && p.isNotEmpty) {
        for (final e in jsonDecode(p) as List<dynamic>) {
          final project = ProjectFile.fromJson(Map<String, dynamic>.from(e));
          batch.set(_projectsRef.doc(project.id), project.toJson());
          count++;
        }
      }
      final c = await _prefs.getString(_localCompanyKey);
      if (c != null && c.isNotEmpty) {
        final local = CompanySettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(c)),
        );
        if (local.signaturePath.isNotEmpty) {
          await _prefs.setString(_signatureKey, local.signaturePath);
        }
        // Only fill the shared company details if nobody has set them yet.
        final remote = await _companyRef.get();
        if (!remote.exists) batch.set(_companyRef, _companyJson(local));
      }

      if (count > 0) debugPrint('Uploading $count local records to Firestore');
      unawaited(
        batch.commit().catchError((Object e) {
          debugPrint('Migration upload failed: $e');
        }),
      );
      await _prefs.setBool(_migratedKey, true);
    } catch (e) {
      debugPrint('Migration skipped: $e');
    }
  }

  /// Fire-and-forget write: the local cache updates immediately and the
  /// snapshot listener refreshes the UI; the server catches up when online.
  void _write(Future<void> write) {
    unawaited(
      write.catchError((Object e) {
        debugPrint('Firestore write failed: $e');
      }),
    );
  }

  // ---------- User profile ----------

  /// Saves the signed-in person's display name to users/{uid}.
  Future<void> saveUserName(String name) async {
    final uid = user?.uid;
    if (uid == null) return;
    userNames = {...userNames, uid: name.trim()};
    notifyListeners();
    _write(
      _usersRef.doc(uid).set({
        'name': name.trim(),
        'email': user?.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  // ---------- Quotations ----------

  /// A fresh, unsaved quotation pre-filled with the standard items.
  Quotation newQuotation({
    String customerName = '',
    String customerPhone = '',
    String customerAddress = '',
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Quotation(
      id: now.microsecondsSinceEpoch.toString(),
      quoteNumber: generateQuoteNumber(quotations),
      quotationDate: today,
      expiryDate: today.add(const Duration(days: defaultValidityDays)),
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      items: defaultItems(),
      notes: defaultNotes,
      terms: defaultTerms,
      createdByUid: user?.uid ?? '',
      createdByName: userName,
    );
  }

  /// Copy of [source] with a new id/number and today's dates, unsaved.
  Quotation duplicate(Quotation source) {
    final fresh = newQuotation();
    return source.copy()
      ..id = fresh.id
      ..quoteNumber = fresh.quoteNumber
      ..quotationDate = fresh.quotationDate
      ..expiryDate = fresh.expiryDate
      ..status = 'Draft'
      ..createdByUid = fresh.createdByUid
      ..createdByName = fresh.createdByName;
  }

  bool isSaved(String id) => quotations.any((q) => q.id == id);

  Future<void> saveQuotation(Quotation quotation) async {
    final index = quotations.indexWhere((e) => e.id == quotation.id);
    if (index == -1) {
      quotations.insert(0, quotation);
    } else {
      quotations[index] = quotation;
    }
    notifyListeners();
    _write(_quotationsRef.doc(quotation.id).set(quotation.toJson()));
  }

  Future<void> setStatus(Quotation quotation, String status) async {
    quotation.status = status;
    await saveQuotation(quotation);
  }

  Future<void> deleteQuotation(String id) async {
    quotations.removeWhere((quotation) => quotation.id == id);
    notifyListeners();
    _write(_quotationsRef.doc(id).delete());
  }

  // ---------- Company ----------

  Map<String, dynamic> _companyJson(CompanySettings c) =>
      c.toJson()..remove('signaturePath');

  Future<void> saveCompany(CompanySettings value) async {
    value.signaturePath = company.signaturePath;
    company = value;
    notifyListeners();
    _write(_companyRef.set(_companyJson(value)));
  }

  /// Copies a picked image into app storage; the path stays on this phone.
  Future<void> setSignature(String pickedPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = pickedPath.contains('.') ? pickedPath.split('.').last : 'png';
    final target =
        '${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(pickedPath).copy(target);
    await _deleteFile(company.signaturePath);
    company.signaturePath = target;
    await _prefs.setString(_signatureKey, target);
    notifyListeners();
  }

  Future<void> removeSignature() async {
    await _deleteFile(company.signaturePath);
    company.signaturePath = '';
    await _prefs.remove(_signatureKey);
    notifyListeners();
  }

  // ---------- Project files ----------

  /// A fresh, unsaved project, optionally filled from a quotation.
  ProjectFile newProject({Quotation? from}) {
    final now = DateTime.now();
    var highest = 0;
    for (final p in projects) {
      final n = int.tryParse(p.projectNumber) ?? 0;
      if (n > highest) highest = n;
    }
    return ProjectFile(
      id: now.microsecondsSinceEpoch.toString(),
      projectNumber: (highest + 1).toString().padLeft(4, '0'),
      createdDate: DateTime(now.year, now.month, now.day),
      customerName: from?.customerName ?? '',
      customerPhone: from?.customerPhone ?? '',
      customerAddress: from?.customerAddress ?? '',
      projectAmount: from?.total ?? 0,
      quotationId: from?.id ?? '',
      createdByUid: user?.uid ?? '',
      createdByName: userName,
    );
  }

  bool isProjectSaved(String id) => projects.any((p) => p.id == id);

  Future<void> saveProject(ProjectFile project) async {
    final index = projects.indexWhere((e) => e.id == project.id);
    if (index == -1) {
      projects.insert(0, project);
    } else {
      // Delete photo files the edit removed (no-op for another phone's paths).
      final kept = project.photos.toSet();
      for (final path in projects[index].photos) {
        if (!kept.contains(path)) await _deleteFile(path);
      }
      projects[index] = project;
    }
    notifyListeners();
    _write(_projectsRef.doc(project.id).set(project.toJson()));
  }

  Future<void> deleteProject(String id) async {
    final index = projects.indexWhere((p) => p.id == id);
    if (index == -1) return;
    for (final path in projects[index].photos) {
      await _deleteFile(path);
    }
    projects.removeAt(index);
    notifyListeners();
    _write(_projectsRef.doc(id).delete());
  }

  /// Copies a picked/captured photo into app storage and returns its path.
  Future<String> storeProjectPhoto(String pickedPath) async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/project_photos',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = pickedPath.contains('.') ? pickedPath.split('.').last : 'jpg';
    final target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await File(pickedPath).copy(target);
    return target;
  }

  /// Removes photos added in an editor session that was then discarded.
  Future<void> discardPhotos(Iterable<String> paths) async {
    for (final path in paths) {
      await _deleteFile(path);
    }
  }

  Future<void> _deleteFile(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Could not delete $path: $e');
    }
  }

  // ---------- Expense categories ----------

  /// Adds a category (case-insensitive duplicates ignored). Returns the
  /// name as stored, so callers can select it.
  String addExpenseCategory(String name) {
    final clean = name.trim();
    final existing = expenseCategoryList.where(
      (c) => c.toLowerCase() == clean.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first;
    _setCategories([...expenseCategoryList, clean]);
    return clean;
  }

  /// Existing expenses keep their category text; it just stops being offered.
  void removeExpenseCategory(String name) =>
      _setCategories(expenseCategoryList.where((c) => c != name).toList());

  void _setCategories(List<String> list) {
    expenseCategoryList = list;
    notifyListeners();
    _write(_categoriesRef.set({'list': list}));
  }

  // ---------- Expenses ----------

  Expense newExpense({String projectId = ''}) {
    final now = DateTime.now();
    return Expense(
      id: now.microsecondsSinceEpoch.toString(),
      date: DateTime(now.year, now.month, now.day),
      projectId: projectId,
      createdByUid: user?.uid ?? '',
      createdByName: userName,
    );
  }

  Future<void> saveExpense(Expense expense) async {
    final index = expenses.indexWhere((e) => e.id == expense.id);
    if (index == -1) {
      expenses.add(expense);
    } else {
      expenses[index] = expense;
    }
    expenses.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    _write(_expensesRef.doc(expense.id).set(expense.toJson()));
  }

  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    _write(_expensesRef.doc(id).delete());
  }

  ProjectFile? projectById(String id) {
    if (id.isEmpty) return null;
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------- Dashboard numbers ----------

  int get totalQuotations => quotations.length;
  int countWithStatus(String status) =>
      quotations.where((e) => e.status == status).length;
  double get totalValue => quotations.fold(0, (acc, q) => acc + q.total);

  double get thisMonthValue {
    final now = DateTime.now();
    return quotations
        .where(
          (q) =>
              q.quotationDate.year == now.year &&
              q.quotationDate.month == now.month,
        )
        .fold(0, (acc, q) => acc + q.total);
  }

  /// Customers derived from saved quotations, keyed by name + phone.
  List<CustomerSummary> get customers {
    final map = <String, CustomerSummary>{};
    for (final q in quotations) {
      if (q.customerName.trim().isEmpty) continue;
      final key =
          '${q.customerName.trim().toLowerCase()}|${q.customerPhone.trim()}';
      final summary = map.putIfAbsent(
        key,
        () => CustomerSummary(
          name: q.customerName.trim(),
          phone: q.customerPhone.trim(),
          address: q.customerAddress.trim(),
        ),
      );
      summary.quotations.add(q);
    }
    final list = map.values.toList()
      ..sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return list;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    for (final sub in _dataSubs) {
      sub.cancel();
    }
    super.dispose();
  }
}

class CustomerSummary {
  final String name;
  final String phone;
  final String address;
  final List<Quotation> quotations = [];

  CustomerSummary({required this.name, this.phone = '', this.address = ''});

  double get totalValue => quotations.fold(0, (acc, q) => acc + q.total);
  DateTime get lastDate => quotations
      .map((q) => q.quotationDate)
      .reduce((a, b) => a.isAfter(b) ? a : b);
}
