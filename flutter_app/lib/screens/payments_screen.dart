import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../data/mock_data.dart';
import '../services/api.dart';
import '../services/boost_payment.dart';
import '../services/receipt_pdf.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../services/web_download.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/app_header.dart';
import '../widgets/list_search.dart';
import 'payment/bcpg_webview_screen.dart';
import 'payment/term_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final String initialTab;
  const PaymentsScreen({super.key, this.initialTab = 'pay'});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with LiveRefreshMixin<PaymentsScreen> {
  @override
  bool get canLiveRefresh =>
      !_loading &&
      _selectedInvoiceIdx.isEmpty &&
      !UserSession.instance.paymentLocked &&
      _tab != 'prepay';
  @override
  Future<void> refreshLiveData() => _loadAll();

  late String _tab;
  String selectedMethod = 'card';
  List<dynamic>? _outstanding;
  List<dynamic>? _receipts;
  List<dynamic>? _slips;
  List<dynamic>? _termPayments;
  List<dynamic>? _tranxCharges;
  List<dynamic>? _manualCollection;
  List<dynamic>? _invoiceTypes;
  bool _loading = false;
  int _loadSequence = 0;
  int? _fetchedStudentId;
  String _filter = 'all'; // all | term | charges | manual
  final _receiptSearchCtrl = TextEditingController();
  String _receiptQuery = '';
  String? _receiptCenterFilter;
  String? _receiptMethodFilter;
  dynamic _invoiceTypeFilter;
  final Set<int> _selectedInvoiceIdx = <int>{};

  /// Invoices the open pay sheet will charge — the user's selection, or all
  /// outstanding when paying via "Pay Now". Drives the sheet's detail list,
  /// total, and the actual charge so selection + siblings are honoured.
  List<Map<String, dynamic>> _payTargets = const [];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    UserSession.instance.addListener(_accountChanged);
    _loadAll();
  }

  void _accountChanged() {
    if (mounted && _fetchedStudentId != UserSession.instance.currentStudentId)
      _loadAll();
  }

  Future<void> _loadAll() async {
    final sequence = ++_loadSequence;
    final session = UserSession.instance;
    final studentId = session.currentStudentId;
    final changed = _fetchedStudentId != studentId;
    _fetchedStudentId = studentId;
    setState(() {
      _loading = true;
      _selectedInvoiceIdx.clear();
      if (changed) _outstanding = null;
    });
    final results = await Future.wait([
      _safeList(() => Api.outstandingFetch(
          {if (studentId != null) 'studentId': studentId})),
      _safeList(Api.reportsReceipts),
      _safeList(Api.reportsPaymentSlips),
      _safeList(Api.outstandingFetchTermPayments),
      _safeList(Api.outstandingFetchTranxCharges),
      _safeList(Api.outstandingFetchOsManualCollection),
      _safeList(Api.listingInvoceTypes),
      _safeList(Api.listingMySiblings),
    ]);
    if (!mounted || sequence != _loadSequence) return;
    setState(() {
      _outstanding = results[0];
      _receipts = results[1];
      _slips = results[2];
      _termPayments = results[3];
      _tranxCharges = results[4];
      _manualCollection = results[5];
      _invoiceTypes = results[6];
      session.siblings = results[7] ?? session.siblings;
      _loading = false;
    });
  }

  Widget _accountChips(UserSession session) {
    final self = session.authData ?? const <String, dynamic>{};
    final accounts = <int, String>{};
    final selfId = int.tryParse('${self['id']}');
    if (selfId != null) accounts[selfId] = '${self['name'] ?? 'Me'}';
    for (final row in (session.siblings ?? const []).whereType<Map>()) {
      final id = int.tryParse('${row['id']}');
      final name = '${row['text'] ?? row['name'] ?? row['studentName'] ?? ''}';
      if (id != null && name.isNotEmpty) accounts[id] = name;
    }
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final account in accounts.entries)
            Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                    label: Text(account.value),
                    selected: account.key == session.currentStudentId,
                    onSelected: (_) => session.switchStudent(account.key,
                        studentName: account.value))),
        ]));
  }

  Future<void> _viewReceiptPDF(dynamic r) async {
    final m = r is Map ? r : <dynamic, dynamic>{};
    final session = UserSession.instance;
    final receiptNo = (m['receiptNo'] ?? m['id'] ?? '').toString();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparing receipt…')));
    try {
      // The server's ReceiptAsPDF endpoint returns a blank template for the
      // IDs the app can supply (the receipt row's id/receiptNo don't resolve
      // to a payment), so every download came back empty. The receipt rows
      // already carry every value a receipt needs, so we render it locally —
      // grouping all line items that share this receiptNo into one document.
      // Only group when the tapped row is an actual receipt (in _receipts);
      // term / charge / manual rows render on their own.
      final pool = _receipts ?? const <dynamic>[];
      final isReceiptRow = pool.any((e) => identical(e, r));
      final group =
          isReceiptRow ? ReceiptPdf.rowsForReceipt(m, pool) : <Map>[m];
      final bytes = await ReceiptPdf.build(
        group.isEmpty ? [m] : group,
        clubName: session.clubDisplayName,
        logoUrl: session.clubPic,
      );
      if (!mounted) return;
      if (bytes.isEmpty || !_looksLikePdf(bytes)) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Receipt not available for this payment.')));
        return;
      }
      final fname = 'receipt_${receiptNo.isEmpty ? 'receipt' : receiptNo}.pdf';
      if (kIsWeb) {
        // Web: download via a Blob + anchor. (Printing.sharePdf throws
        // MissingPluginException on web in this build.)
        downloadBytesWeb(bytes, fname, 'application/pdf');
        return;
      }
      // Native: write the bytes to a real file first, then open it in the
      // device's PDF viewer. Sharing bytes directly (Printing.sharePdf)
      // raced with the receiving app and produced 0-byte files.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fname');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final res = await OpenFilex.open(file.path, type: 'application/pdf');
      if (res.type != ResultType.done && mounted) {
        // Fall back to the share sheet if no PDF viewer handled it.
        await Printing.sharePdf(bytes: bytes, filename: fname);
      }
    } catch (e) {
      debugPrint('ReceiptAsPDF failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Receipt failed: $e')));
    }
  }

  /// Derive clubId from the club logo URL (.../Logo//49.png) when authData
  /// doesn't carry it directly.
  bool _looksLikePdf(List<int> b) =>
      b.length > 4 &&
      b[0] == 0x25 &&
      b[1] == 0x50 &&
      b[2] == 0x44 &&
      b[3] == 0x46; // %PDF

  List<dynamic> _filteredReceipts() {
    List<dynamic> base;
    switch (_filter) {
      case 'term':
        base = _termPayments ?? const <dynamic>[];
        break;
      case 'charges':
        base = _tranxCharges ?? const <dynamic>[];
        break;
      case 'manual':
        base = _manualCollection ?? const <dynamic>[];
        break;
      default:
        base = _receipts ?? const <dynamic>[];
    }
    // Scope to the logged-in student (or picked guardian child). Receipt /
    // term / charge / manual report endpoints return the whole branch for a
    // student token, so this prevents showing other students' records.
    base = UserSession.instance.scopedRows(base);
    final q = _receiptQuery.trim().toLowerCase();
    return base.where((r) {
      if (r is! Map) return true;
      if (_invoiceTypeFilter != null) {
        final t = r['invoiceTypeId'] ?? r['typeId'] ?? r['type'];
        if (t != _invoiceTypeFilter) return false;
      }
      if (_receiptCenterFilter != null && _receiptCenterFilter!.isNotEmpty) {
        final c = (r['tcName'] ?? r['centerName'] ?? '').toString();
        if (c != _receiptCenterFilter) return false;
      }
      if (_receiptMethodFilter != null && _receiptMethodFilter!.isNotEmpty) {
        final m = (r['paymentMethod'] ?? '').toString();
        if (m != _receiptMethodFilter) return false;
      }
      if (q.isNotEmpty) {
        const keys = [
          'receiptNo',
          'name',
          'icNo',
          'paymentMethod',
          'tcName',
          'centerName',
          'description',
        ];
        final hit = keys.any(
            (k) => r[k] != null && r[k].toString().toLowerCase().contains(q));
        if (!hit) return false;
      }
      return true;
    }).toList();
  }

  List<String> _uniqStr(List<dynamic> rows, String key) {
    final s = <String>{};
    for (final r in rows) {
      if (r is Map) {
        final v = r[key]?.toString().trim();
        if (v != null && v.isNotEmpty) s.add(v);
      }
    }
    final list = s.toList()..sort();
    return list;
  }

  Future<List<dynamic>?> _safeList(Future<dynamic> Function() fn) async {
    try {
      final resp = await fn();
      return findRecordList(resp);
    } catch (e) {
      debugPrint('payments load failed: $e');
      return null;
    }
  }

  /// Robust field readers for /Outstanding/Fetch rows — the API uses
  /// varying key names across invoice types, so probe a wide set.
  String _invoiceLabel(Map m, int idx) {
    for (final k in const [
      'invoiceDescription',
      'invoiceName',
      'description',
      'particulars',
      'invoiceTitle',
      'item',
      'feeType',
      'invoiceNo',
      'invoiceNumber',
      'text'
    ]) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty && v != 'null') return v;
    }
    return 'Invoice #${idx + 1}';
  }

  /// Owner (student) for an outstanding row — for the "paying for" label.
  String _invoiceOwner(Map m) {
    for (final k in const ['studentName', 'name', 'memberName']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty && v != 'null') return v;
    }
    return '';
  }

  /// "<student> · <period>" sub-line for an invoice row.
  String _invoiceSub(Map m) {
    final owner = _invoiceOwner(m);
    final period = (m['period'] ?? m['invoicePeriod'] ?? '').toString().trim();
    return [owner, period]
        .where((s) => s.isNotEmpty && s != 'null')
        .join(' · ');
  }

  num _invoiceAmount(Map m) {
    for (final k in const [
      'dueAmount',
      'dueAmt',
      'amountDue',
      'amount',
      'outstandingAmount',
      'outstandingAmt',
      'balance',
      'totalAmount',
      'totalDue',
      'invoiceAmount',
      'amtDue',
      'value'
    ]) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final n = num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), ''));
        if (n != null) return n;
      }
    }
    return 0;
  }

  /// Route the payment by the chosen method:
  ///  • card / FPX-eWallet → online gateway (/Payment/Initiate)
  ///  • bank transfer       → manual record (/Outstanding/PayInvoices)
  Future<void> _confirmPayment(String method) async {
    // Pay exactly the invoices the sheet was opened for (selection or all).
    final invoices =
        _payTargets.map((m) => Map<String, dynamic>.from(m)).toList();
    if (invoices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices to pay.')),
      );
      return;
    }
    if (method == 'bank') {
      await _recordManualPayment(invoices);
    } else {
      await _initiateGatewayPayment(invoices);
    }
  }

  /// Manual / bank-transfer payment — records the intent via
  /// /Outstanding/PayInvoices so the club can verify the transfer.
  Future<void> _recordManualPayment(List<Map<String, dynamic>> invoices) async {
    try {
      final slip = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (slip == null) return;
      final ids = invoices
          .map((r) => int.tryParse('${r['invoiceId'] ?? r['id']}'))
          .whereType<int>()
          .where((id) => id > 0)
          .toList();
      if (ids.length != invoices.length)
        throw Exception(
            'One or more invoice IDs are missing. Refresh and try again.');
      final result = await ApiService.postMultipart(
          '/Outstanding/PayInvoices?PayTermPayments=false&PurchaseItems=false',
          {'PaymentMethod': '1'},
          repeatedFields: {'InvoiceIds': ids.map((id) => '$id').toList()},
          uploads: [(name: slip.name, bytes: await slip.readAsBytes())]);
      final error = apiEnvelopeError(result);
      if (error != null) throw Exception(error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Your payment slip has been submitted for verification.')));
      _selectedInvoiceIdx.clear();
      await _loadAll();
    } catch (e) {
      debugPrint('PayInvoices failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not record payment: $e')),
      );
    }
  }

  /// Online gateway couldn't be reached (endpoint down or returned a
  /// non-JSON error page). Offer the bank-transfer fallback instead of
  /// dumping a raw exception on screen.
  Future<void> _onlineUnavailable(List<Map<String, dynamic>> invoices) async {
    final c = context.appColors;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Online payment unavailable',
            style: TextStyle(color: c.textPrimary, fontSize: 16)),
        content: Text(
          'The online payment gateway is not responding right now. '
          'You can record a bank-transfer payment instead — the club '
          'will verify it once you upload your slip.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _recordManualPayment(invoices);
            },
            child: const Text('Pay by bank transfer'),
          ),
        ],
      ),
    );
  }

  /// Start an online payment through the Boost gateway and report what actually happened.
  ///
  /// The app used to sign requests to Boost itself with a merchant secret compiled into the
  /// APK — extractable by anyone who decompiled it. The backend holds that secret now:
  /// `POST /Bcpg/PayInvoices` returns a checkout URL, and after the user comes back the
  /// result is established by verification + reconciliation rather than trusting the
  /// redirect. The invoices are settled server-side by the gateway callback, so this no
  /// longer marks them paid itself.
  Future<void> _initiateGatewayPayment(
      List<Map<String, dynamic>> invoices) async {
    if (invoices.isEmpty) return;

    final session = UserSession.instance;
    final invoiceIds = <int>[];
    num total = 0;
    for (final inv in invoices) {
      final raw = inv['id'] ?? inv['invoiceId'] ?? inv['invoiceID'];
      final id = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (id > 0) invoiceIds.add(id);
      total += _invoiceAmount(inv);
    }
    if (invoiceIds.length != invoices.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not read the selected invoices.')));
      return;
    }
    if (total <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to pay (amount is zero).')));
      return;
    }

    // Every account whose invoices are in this payment — a parent can pay for several
    // children at once, and the outstanding list is scoped to one student at a time.
    final studentIds = <int?>{};
    for (final inv in invoices) {
      final raw = inv['studentId'] ?? inv['studentID'] ?? inv['sourceKeyId'];
      final id = raw is int ? raw : int.tryParse('$raw');
      studentIds.add(id ?? session.currentStudentId);
    }

    if (!mounted) return;
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    PaymentStart start;
    try {
      start = await BoostPayment.start(PaymentIntent(invoiceIds: invoiceIds));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      _onlineUnavailable(invoices);
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    // Open the gateway. The WebView only reports that the browser came back — it does not
    // decide the outcome.
    await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => BcpgWebViewScreen(
          paymentUrl: start.url,
          referenceId: start.referenceId ?? '',
          returnUrlNeedle: 'bcpg_redirect',
        ),
      ),
    );

    if (!mounted) return;

    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    final result = await BoostPayment.confirm(
      referenceId: start.referenceId,
      invoiceIds: invoiceIds,
      studentIds: studentIds.toList(),
      fetchOutstandingIds: _outstandingIdsFor,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.message),
      duration: const Duration(seconds: 6),
    ));
    if (result.outcome == PaymentOutcome.unknown) {
      session.startPaymentLock();
    } else {
      session.clearPaymentLock();
    }
    if (result.outcome == PaymentOutcome.paid) _selectedInvoiceIdx.clear();
    await _loadAll();
  }

  /// Invoice ids still outstanding for one account — the reconciliation signal.
  Future<List<int>> _outstandingIdsFor(int? studentId) async {
    final res = await Api.outstandingFetch(
        studentId == null ? const {} : {'studentId': studentId});
    final ids = <int>[];
    for (final row in findRecordList(res)) {
      if (row is! Map) continue;
      final raw = row['id'] ?? row['invoiceId'] ?? row['invoiceID'];
      final id = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (id > 0) ids.add(id);
    }
    return ids;
  }

  /// "Paying for" block — lists every selected invoice in detail (Inv No,
  /// Inv Type, Period, Name/sibling, Discount, Due Amt), matching the Term
  /// Payment screen, so the user reviews exactly what's being paid (and for
  /// which child) before proceeding.
  Widget _payingForBlock(AppColors c) {
    final rows = _payTargets;
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PAYING FOR (${rows.length})',
          style: TextStyle(
              color: c.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8)),
      const SizedBox(height: 8),
      ...rows.map((m) => _payInvoiceCard(c, m)),
    ]);
  }

  /// A single invoice detail card for the pay sheet.
  Widget _payInvoiceCard(AppColors c, Map<String, dynamic> m) {
    String pick(List<String> keys, [String fallback = '-']) {
      for (final k in keys) {
        final v = (m[k] ?? '').toString().trim();
        if (v.isNotEmpty && v != 'null') return v;
      }
      return fallback;
    }

    final invNo = pick(['invoiceId', 'invoiceNo', 'invoiceNumber'], '0');
    final type = pick(['transactionType', 'invoiceType', 'type'], '-');
    final period = pick(['period', 'invoicePeriod', 'invoiceDescription'], '-');
    final name = pick(['studentName', 'name', 'memberName'], '-');
    final discount = _invoiceAmount2(m, ['discountAmount', 'discount']);
    final due = _invoiceAmount(m);

    Widget kv(String k, String v, {bool strong = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(color: c.textMuted, fontSize: 10.5)),
            Text(v,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: strong ? c.primary : c.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ]),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            kv('Inv No', invNo),
            kv('Period', period),
            kv('Discount', discount.toStringAsFixed(2)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            kv('Inv Type', type),
            kv('Name', name),
            kv('Due Amt', 'RM ${due.toStringAsFixed(2)}', strong: true),
          ]),
        ),
      ]),
    );
  }

  /// Like [_invoiceAmount] but for an explicit key set (e.g. discount).
  num _invoiceAmount2(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final n = num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), ''));
        if (n != null) return n;
      }
    }
    return 0;
  }

  String _mmss(int total) {
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Open the payment sheet for [invoices] — the user's selection, or all
  /// outstanding when null (the "Pay Now" path).
  void _openPayModal([List<dynamic>? invoices]) {
    final c = context.appColors;
    final session = UserSession.instance;
    // 2-minute lock: while a payment window is open, block starting a
    // second one.
    if (session.paymentLocked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'A payment is already in progress. Try again in ${_mmss(session.paymentLockSeconds)}.')));
      return;
    }
    // Resolve which invoices this sheet pays for.
    final source = invoices ?? session.scopedRows(_outstanding);
    _payTargets = source
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (_payTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices to pay.')),
      );
      return;
    }
    session.startPaymentLock();
    Timer? ticker;
    // Total = sum of exactly the invoices being paid (selection-aware).
    final payTotal = _payTargets.fold<num>(0, (s, m) => s + _invoiceAmount(m));
    final modalAmount = payTotal > 0
        ? payTotal.toStringAsFixed(2)
        : (session.dueAmount > 0
            ? session.dueAmount.toStringAsFixed(2)
            : '0.00');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (!session.paymentLocked) {
            ticker?.cancel();
          }
          if (ctx.mounted) setModal(() {});
        });
        final remain = session.paymentLockSeconds;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          // Reserve the gesture-bar + keyboard inset so the Confirm button
          // never collides with the system bar / bottom nav.
          padding: EdgeInsets.fromLTRB(
              22,
              14,
              22,
              24 +
                  MediaQuery.of(ctx).padding.bottom +
                  MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: c.border,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: Text('Complete Payment',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                    ),
                    // Countdown chip — the active payment window.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.timer_outlined, size: 13, color: c.primary),
                        const SizedBox(width: 4),
                        Text(_mmss(remain),
                            style: TextStyle(
                                color: c.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('Choose payment method',
                      style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  Text('RM $modalAmount',
                      style: TextStyle(
                          color: c.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _payingForBlock(c),
                  const SizedBox(height: 12),
                  ...kPayMethods.map((m) {
                    final active = selectedMethod == m.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => setModal(() => selectedMethod = m.id),
                        borderRadius: BorderRadius.circular(Radii.md),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Radii.md),
                            border: Border.all(
                                color: active ? c.primary : c.border),
                            color: active ? c.surfaceAlt : Colors.transparent,
                          ),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: active ? c.primary : c.surfaceAlt,
                                  shape: BoxShape.circle),
                              child: Icon(m.icon,
                                  size: 18,
                                  color: active ? Colors.white : c.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(m.label,
                                    style: TextStyle(
                                        color: c.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600))),
                            Icon(
                                active
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: active ? c.primary : c.textMuted),
                          ]),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _confirmPayment(selectedMethod);
                    },
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: c.gradient),
                        borderRadius: BorderRadius.circular(Radii.md),
                        boxShadow: Shadows.strong(c),
                      ),
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, color: Colors.white, size: 14),
                            SizedBox(width: 8),
                            Text('Confirm & Pay Securely',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // Explicit abort — release the lock so they can retry.
                        UserSession.instance.clearPaymentLock();
                        Navigator.pop(ctx);
                      },
                      child: Text('Cancel',
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 13)),
                    ),
                  ),
                ]),
          ),
        );
      }),
    ).whenComplete(() => ticker?.cancel());
  }

  @override
  void didUpdateWidget(covariant PaymentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  @override
  void dispose() {
    UserSession.instance.removeListener(_accountChanged);
    _receiptSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final invoices = session.scopedRows(_outstanding);
    final slips = session.scopedRows(_slips);
    return Column(children: [
      AppHeader(
          title: 'Fees & Payments',
          trailing: IconButton(
              onPressed: (_loading && !liveRefreshing) ? null : _loadAll,
              icon: Icon(AppIcons.refresh, color: c.primary))),
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            for (final segment in const [
              ('pay', 'Pay'),
              ('prepay', 'Advance Payment'),
              ('history', 'History')
            ])
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                          onTap: () => setState(() {
                                _tab = segment.$1;
                                _selectedInvoiceIdx.clear();
                              }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                                color: _tab == segment.$1
                                    ? c.primary
                                    : c.surfaceAlt,
                                borderRadius: BorderRadius.circular(14)),
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(segment.$2,
                                    style: TextStyle(
                                        color: _tab == segment.$1
                                            ? Colors.white
                                            : c.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700))),
                          )))),
          ])),
      Expanded(
          child: _tab == 'prepay'
              ? const TermPaymentScreen(embedded: true)
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        20, 8, 20, 120 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      if ((_loading && !liveRefreshing))
                        const LinearProgressIndicator(),
                      if (_tab == 'pay') ...[
                        _accountChips(session),
                        const SizedBox(height: 12),
                        Card(
                            child: ListTile(
                                leading:
                                    Icon(AppIcons.autorenew, color: c.primary),
                                title: const Text('Auto Pay'),
                                subtitle:
                                    const Text('Monthly payment reminders'),
                                trailing: const Icon(AppIcons.chevron_right),
                                onTap: () => context.push('/autopay'))),
                        const SizedBox(height: 14),
                        if (!(_loading && !liveRefreshing) &&
                            _outstanding == null)
                          Column(children: [
                            const Text('Could not load invoices.'),
                            TextButton(
                                onPressed: _loadAll,
                                child: const Text('Retry')),
                          ])
                        else if (!(_loading && !liveRefreshing) &&
                            invoices.isEmpty)
                          Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(children: [
                                Icon(AppIcons.check_circle_outline,
                                    color: c.success, size: 44),
                                const SizedBox(height: 12),
                                const Text("You're all paid up",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700)),
                                const Text('No outstanding invoices.'),
                              ]))
                        else if (invoices.isNotEmpty)
                          _liveInvoicesCard(c, invoices),
                        if (slips.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _livePaymentSlipsCard(c, slips)
                        ],
                      ] else ...[
                        Text('Payment History',
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        _filterChips(c),
                        const SizedBox(height: 8),
                        if ((_invoiceTypes ?? const []).isNotEmpty)
                          _invoiceTypeDropdown(c),
                        if (((_receipts ?? const []).length) > 3) ...[
                          const SizedBox(height: 8),
                          ListSearchBar(
                            hint: 'Search receipt no, student, method, center…',
                            controller: _receiptSearchCtrl,
                            onSearch: (v) => setState(() => _receiptQuery = v),
                            resultCount: _filteredReceipts().length,
                            totalCount: (_receipts ?? const []).length,
                            filters: [
                              if (_uniqStr(_receipts ?? const [], 'tcName')
                                  .isNotEmpty)
                                ListFilter(
                                  label: 'Center',
                                  options:
                                      _uniqStr(_receipts ?? const [], 'tcName'),
                                  selected: _receiptCenterFilter,
                                  onSelected: (v) =>
                                      setState(() => _receiptCenterFilter = v),
                                ),
                              if (_uniqStr(
                                      _receipts ?? const [], 'paymentMethod')
                                  .isNotEmpty)
                                ListFilter(
                                  label: 'Method',
                                  options: _uniqStr(
                                      _receipts ?? const [], 'paymentMethod'),
                                  selected: _receiptMethodFilter,
                                  onSelected: (v) =>
                                      setState(() => _receiptMethodFilter = v),
                                ),
                            ],
                            onClearAll: () => setState(() {
                              _receiptQuery = '';
                              _receiptCenterFilter = null;
                              _receiptMethodFilter = null;
                            }),
                          ),
                        ],
                        const SizedBox(height: 8),
                        ...() {
                          final list = _filteredReceipts();
                          final sourceUnavailable = switch (_filter) {
                            'term' => _termPayments == null,
                            'charges' => _tranxCharges == null,
                            'manual' => _manualCollection == null,
                            _ => _receipts == null,
                          };
                          if (sourceUnavailable) {
                            return <Widget>[
                              const Text(
                                  'The club server could not load this payment history.'),
                              TextButton(
                                  onPressed: _loadAll,
                                  child: const Text('Retry')),
                            ];
                          }
                          if (list.isEmpty) {
                            return <Widget>[
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(Radii.md),
                                  border: c.isDark
                                      ? Border.all(color: c.border)
                                      : null,
                                  boxShadow: Shadows.card(c),
                                ),
                                child: Row(children: [
                                  Icon(AppIcons.receipt_long_outlined,
                                      color: c.textMuted, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'No receipts yet — paid invoices will appear here.',
                                      style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ]),
                              ),
                            ];
                          }
                          return list
                              .toList()
                              .asMap()
                              .entries
                              .map<Widget>((e) => FadeSlideIn.at(
                                    e.key.clamp(0, 8),
                                    offsetY: 14,
                                    child: _liveReceiptRow(c, e.value),
                                  ))
                              .toList();
                        }(),
                      ],
                    ],
                  ))),
    ]);
  }

  Widget _liveInvoicesCard(AppColors c, List<dynamic> invoices) {
    final selectedRows = _selectedInvoiceIdx
        .where((i) => i < invoices.length)
        .map((i) => invoices[i])
        .whereType<Map>()
        .toList();
    final total =
        selectedRows.fold<num>(0, (sum, row) => sum + _invoiceAmount(row));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text('Outstanding Invoices (${invoices.length})',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary))),
        TextButton(
            onPressed: () => setState(() {
                  if (_selectedInvoiceIdx.length == invoices.length) {
                    _selectedInvoiceIdx.clear();
                  } else {
                    _selectedInvoiceIdx
                        .addAll(List.generate(invoices.length, (i) => i));
                  }
                }),
            child: Text(_selectedInvoiceIdx.length == invoices.length
                ? 'Clear'
                : 'Select all')),
      ]),
      for (final entry in invoices.asMap().entries) ...[
        Builder(builder: (context) {
          final row =
              entry.value is Map ? entry.value as Map : <dynamic, dynamic>{};
          final selected = _selectedInvoiceIdx.contains(entry.key);
          final number = (row['invoiceNo'] ??
                  row['invoiceNumber'] ??
                  row['invoiceId'] ??
                  row['id'] ??
                  entry.key + 1)
              .toString();
          final type = (row['invoiceType'] ?? row['type'] ?? '').toString();
          final rawDate = (row['invoiceDate'] ?? row['date'] ?? '').toString();
          final date = DateTime.tryParse(rawDate);
          final metadata = [
            _invoiceSub(row),
            if (date != null) DateFormat('dd MMM yyyy').format(date)
          ].where((s) => s.isNotEmpty).join(' · ');
          return Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() {
                      if (selected) {
                        _selectedInvoiceIdx.remove(entry.key);
                      } else {
                        _selectedInvoiceIdx.add(entry.key);
                      }
                    }),
                child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected ? c.primary : c.border,
                            width: selected ? 1.5 : 1)),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                  selected
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: selected ? c.primary : c.textMuted,
                                  size: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    [number, type]
                                        .where((s) => s.isNotEmpty)
                                        .join(' · '),
                                    style: TextStyle(
                                        color: c.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                Text(_invoiceLabel(row, entry.key),
                                    style: TextStyle(
                                        color: c.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                if (metadata.isNotEmpty)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 7),
                                      child: Text(metadata,
                                          style: TextStyle(
                                              color: c.textMuted,
                                              fontSize: 11))),
                                const SizedBox(height: 8),
                                Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: c.primary
                                                  .withValues(alpha: .12),
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Text('Unpaid',
                                              style: TextStyle(
                                                  color: c.primary,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      Text(
                                          'RM ${_invoiceAmount(row).toStringAsFixed(2)}',
                                          style: TextStyle(
                                              color: c.textPrimary,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800)),
                                    ]),
                              ])),
                        ]))),
          );
        }),
        const SizedBox(height: 12),
      ],
      if (selectedRows.isNotEmpty)
        FilledButton(
            onPressed: () => _openPayModal(selectedRows),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'Pay Selected (${selectedRows.length}) · RM ${total.toStringAsFixed(2)}'))),
    ]);
  }

  Widget _livePaymentSlipsCard(AppColors c, List<dynamic> slips) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(AppIcons.receipt_long, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('Payment Slips (${slips.length})',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.primary,
                    letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...slips.take(5).map((s) {
            final m = s is Map ? s : <dynamic, dynamic>{};
            final label =
                (m['slipNo'] ?? m['description'] ?? m['text'] ?? 'Slip')
                    .toString();
            final amount = (m['amount'] ?? m['value'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                    child: Text(label,
                        style:
                            TextStyle(fontSize: 12, color: c.textSecondary))),
                Text(amount.isEmpty ? '' : 'RM $amount',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _liveReceiptRow(AppColors c, dynamic r) {
    final m = r is Map ? r : <dynamic, dynamic>{};
    // API row shape: {id, tcName, receiptNo, receiptDate, receiptAmount,
    // paymentMethod, icNo, name}.
    final receiptNo = (m['receiptNo'] ?? m['receiptNumber'] ?? '').toString();
    final tcName = (m['tcName'] ?? m['centerName'] ?? '').toString();
    final label = receiptNo.isNotEmpty
        ? 'Receipt #$receiptNo'
        : (m['description'] ?? m['text'] ?? 'Receipt').toString();
    final dateRaw =
        (m['receiptDate'] ?? m['date'] ?? m['paymentDate'] ?? '').toString();
    final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    final method = (m['paymentMethod'] ?? m['method'] ?? m['paymentMode'] ?? '')
        .toString();
    final amountRaw = m['receiptAmount'] ?? m['amount'] ?? m['value'] ?? 0;
    final amount =
        amountRaw is num ? amountRaw.toStringAsFixed(2) : amountRaw.toString();
    final studentName = (m['name'] ?? '').toString();
    final subtitle = [
      if (date.isNotEmpty) date,
      if (studentName.isNotEmpty) studentName,
      if (method.isNotEmpty) method,
      if (tcName.isNotEmpty) tcName,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color:
                  c.isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
              shape: BoxShape.circle),
          child: Icon(Icons.cloud_done, size: 18, color: c.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ),
          ]),
        ),
        Text('RM $amount',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: c.textPrimary)),
        IconButton(
          onPressed: () => _viewReceiptPDF(r),
          icon: Icon(Icons.picture_as_pdf, color: c.danger, size: 18),
          tooltip: 'PDF',
        ),
      ]),
    );
  }

  Widget _filterChips(AppColors c) {
    Widget chip(String key, String label) {
      final active = _filter == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => setState(() => _filter = key),
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? c.primary : c.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: active ? c.primary : c.border),
            ),
            child: Text(label,
                style: TextStyle(
                    color: active ? Colors.white : c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('all', 'All'),
        chip('term', 'Term'),
        chip('charges', 'Charges'),
        chip('manual', 'Manual'),
      ]),
    );
  }

  Widget _invoiceTypeDropdown(AppColors c) {
    final items = _invoiceTypes ?? const <dynamic>[];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          isExpanded: true,
          value: _invoiceTypeFilter,
          hint: Text('All invoice types',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
          items: <DropdownMenuItem<dynamic>>[
            DropdownMenuItem<dynamic>(
                value: null,
                child: Text('All invoice types',
                    style: TextStyle(color: c.textPrimary, fontSize: 13))),
            ...items.map((e) {
              final m = e is Map ? e : <dynamic, dynamic>{};
              final id = m['id'] ?? m['code'] ?? m['value'];
              final name =
                  (m['name'] ?? m['text'] ?? m['title'] ?? e).toString();
              return DropdownMenuItem<dynamic>(
                  value: id,
                  child: Text(name,
                      style: TextStyle(color: c.textPrimary, fontSize: 13)));
            }),
          ],
          onChanged: (v) => setState(() => _invoiceTypeFilter = v),
        ),
      ),
    );
  }
}
