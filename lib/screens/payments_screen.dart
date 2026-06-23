import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../services/api.dart';
import '../services/bcpg_service.dart';
import '../services/receipt_pdf.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/app_header.dart';
import '../widgets/list_search.dart';
import 'payment/bcpg_webview_screen.dart';
import 'payment/term_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String selectedMethod = 'card';
  List<dynamic>? _outstanding;
  List<dynamic>? _receipts;
  List<dynamic>? _slips;
  List<dynamic>? _termPayments;
  List<dynamic>? _tranxCharges;
  List<dynamic>? _manualCollection;
  List<dynamic>? _invoiceTypes;
  List<dynamic>? _reimbursement;
  Map<String, dynamic>? _collectionCount;
  List<dynamic>? _collectionCountList;
  bool _showCollectionList = false;
  bool _loading = false;
  String _filter = 'all'; // all | term | charges | manual
  final _receiptSearchCtrl = TextEditingController();
  String _receiptQuery = '';
  String? _receiptCenterFilter;
  String? _receiptMethodFilter;
  dynamic _invoiceTypeFilter;
  final Set<int> _selectedInvoiceIdx = <int>{};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _safeList(Api.outstandingFetch).then((v) => _outstanding = v),
      _safeList(Api.reportsReceipts).then((v) => _receipts = v),
      _safeList(Api.reportsPaymentSlips).then((v) => _slips = v),
      _safeList(Api.outstandingFetchTermPayments).then((v) => _termPayments = v),
      _safeList(Api.outstandingFetchTranxCharges).then((v) => _tranxCharges = v),
      _safeList(Api.outstandingFetchOsManualCollection).then((v) => _manualCollection = v),
      _safeList(Api.listingInvoceTypes).then((v) => _invoiceTypes = v),
      _safeList(Api.reportsReimbursement).then((v) => _reimbursement = v),
      _loadCollectionCount(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCollectionCount() async {
    try {
      final r = await Api.outstandingCollectionCount();
      if (r is Map) {
        _collectionCount = Map<String, dynamic>.from(r);
      } else if (r is num) {
        _collectionCount = {'count': r};
      }
    } catch (e) {
      debugPrint('CollectionCount failed: $e');
    }
  }

  Future<void> _toggleCollectionCountList() async {
    if (!_showCollectionList) {
      try {
        final r = await Api.outstandingCollectionCountList(1);
        _collectionCountList = r is List ? r : (r is Map && r['data'] is List ? r['data'] as List : <dynamic>[]);
      } catch (e) {
        debugPrint('CollectionCountList failed: $e');
      }
    }
    setState(() => _showCollectionList = !_showCollectionList);
  }

  Future<void> _bumpCollection(dynamic typeId) async {
    if (typeId == null) return;
    try {
      await Api.outstandingUpdateCollectionCount(typeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Count incremented')));
      await _loadCollectionCount();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('UpdateCollectionCount failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _viewReceiptPDF(dynamic r) async {
    final m = r is Map ? r : <dynamic, dynamic>{};
    final session = UserSession.instance;
    final receiptNo = (m['receiptNo'] ?? m['id'] ?? '').toString();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Preparing receipt…')));
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
      final group = isReceiptRow
          ? ReceiptPdf.rowsForReceipt(m, pool)
          : <Map>[m];
      final bytes = await ReceiptPdf.build(
        group.isEmpty ? [m] : group,
        clubName: session.clubDisplayName,
      );
      if (!mounted) return;
      if (bytes.isEmpty || !_looksLikePdf(bytes)) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Receipt not available for this payment.')));
        return;
      }
      final fname = 'receipt_${receiptNo.isEmpty ? 'receipt' : receiptNo}.pdf';
      if (kIsWeb) {
        // Web has no file system — sharePdf triggers the browser download.
        await Printing.sharePdf(bytes: bytes, filename: fname);
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
      messenger.showSnackBar(
          SnackBar(content: Text('Receipt failed: $e')));
    }
  }

  /// Derive clubId from the club logo URL (.../Logo//49.png) when authData
  /// doesn't carry it directly.
  int? _clubIdFromPic(UserSession session) {
    final pic = (session.authData?['clubPic'] ?? '').toString();
    final match = RegExp(r'/(\d+)\.png').firstMatch(pic);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  bool _looksLikePdf(List<int> b) =>
      b.length > 4 &&
      b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46; // %PDF

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
          'receiptNo', 'name', 'icNo', 'paymentMethod', 'tcName',
          'centerName', 'description',
        ];
        final hit = keys.any((k) =>
            r[k] != null && r[k].toString().toLowerCase().contains(q));
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
      if (resp is List) return resp;
      if (resp is Map && resp['data'] is List) return resp['data'] as List;
      return null;
    } catch (e) {
      debugPrint('payments load failed: $e');
      return null;
    }
  }

  /// Robust field readers for /Outstanding/Fetch rows — the API uses
  /// varying key names across invoice types, so probe a wide set.
  String _invoiceLabel(Map m, int idx) {
    for (final k in const [
      'invoiceDescription', 'invoiceName', 'description', 'particulars',
      'invoiceTitle', 'item', 'feeType', 'invoiceNo', 'invoiceNumber', 'text'
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
    return [owner, period].where((s) => s.isNotEmpty && s != 'null').join(' · ');
  }

  num _invoiceAmount(Map m) {
    for (final k in const [
      'dueAmount', 'dueAmt', 'amountDue', 'amount', 'outstandingAmount',
      'outstandingAmt', 'balance', 'totalAmount', 'totalDue',
      'invoiceAmount', 'amtDue', 'value'
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

  num _liveOutstandingTotal() {
    final inv = _outstanding;
    if (inv == null) return 0;
    num total = 0;
    for (final i in inv) {
      if (i is Map) total += _invoiceAmount(i);
    }
    return total;
  }

  /// Route the payment by the chosen method:
  ///  • card / FPX-eWallet → online gateway (/Payment/Initiate)
  ///  • bank transfer       → manual record (/Outstanding/PayInvoices)
  Future<void> _confirmPayment(String method) async {
    final invoices = (_outstanding ?? const <dynamic>[])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (invoices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outstanding invoices to pay.')),
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
  Future<void> _recordManualPayment(
      List<Map<String, dynamic>> invoices) async {
    try {
      await Api.outstandingPayInvoices(<String, dynamic>{
        'invoices': invoices,
        'paymentMethod': 'bank-transfer',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Recorded. Transfer to the club account, then upload your slip for verification.')),
      );
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
  Future<void> _onlineUnavailable(
      List<Map<String, dynamic>> invoices) async {
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
          style: TextStyle(
              color: c.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: c.textSecondary)),
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

  /// Initiate an FPX payment through BCPG directly (no webapp middleman).
  ///
  /// Flow:
  ///   1. Pre-flight checks (config + lock + amount).
  ///   2. POST /v1/payments/init via [BcpgService.initiatePayment] →
  ///      get back `uuid` + `paymentUrl`.
  ///   3. Push [BcpgWebViewScreen] which opens `paymentUrl` and watches
  ///      for the merchant returnUrl. On detection it polls
  ///      `getFPXPaymentDetails` to confirm the terminal status.
  ///   4. On `succeeded` → mark invoices paid via the existing
  ///      `/Outstanding/PayInvoices` endpoint (the webapp's manual-paid
  ///      pipeline), refresh the list, release the lock.
  Future<void> _initiateGatewayPayment(
      List<Map<String, dynamic>> invoices) async {
    if (invoices.isEmpty) return;

    // Compile-time BCPG creds missing → tell the user, don't pretend.
    if (!BcpgService.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Online payment not configured (missing BCPG credentials).')));
      _onlineUnavailable(invoices);
      return;
    }

    final session = UserSession.instance;
    // Resolve clubId — authData first, then the logo-URL fallback used
    // for receipts (.../Logo/49.png). Handle int / num / String shapes.
    int coerceInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }
    final clubIdRaw =
        session.authData?['clubId'] ?? session.authData?['clubID'];
    int clubId = coerceInt(clubIdRaw);
    if (clubId == 0) clubId = _clubIdFromPic(session) ?? 0;
    if (clubId == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot determine club id for payment.')));
      return;
    }

    num total = 0;
    final ids = <dynamic>[];
    final invoiceNos = <String>[];
    for (final inv in invoices) {
      ids.add(inv['id'] ?? inv['invoiceId'] ?? inv['invoiceID']);
      total += _invoiceAmount(inv);
      final no = (inv['invoiceNo'] ??
              inv['invoiceNumber'] ??
              inv['invoiceId'] ??
              inv['id'] ??
              '')
          .toString();
      if (no.isNotEmpty) invoiceNos.add(no);
    }
    if (total <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to pay (amount is zero).')));
      return;
    }

    final referenceId = BcpgService.generateReferenceId(clubId);
    final firstNo = invoiceNos.isNotEmpty ? invoiceNos.first : '';
    final description = 'Club Subscription - $firstNo'
        '${invoiceNos.length > 1 ? " (${invoiceNos.join(",")})" : ""}';

    // BCPG requires a reachable returnUrl + callbackUrl. We keep the same
    // webapp URLs the PHP integration uses, so any future server-side
    // callback wiring stays in one place. The WebView only needs the
    // returnUrl to contain the `bcpg_redirect` needle so it can detect
    // the return navigation — we never actually render that page in-app.
    const returnUrl =
        'https://app.maclubsystem.com/transaction/clubsubscriptioninvoice/bcpg_redirect';
    const callbackUrl =
        'https://app.maclubsystem.com/transaction/clubsubscriptioninvoice/bcpg_callback';

    final payload = <String, dynamic>{
      'referenceId': referenceId,
      'amount': total,
      'currency': 'MYR',
      'created': BcpgService.utcIsoNow(),
      'description': description,
      'returnUrl': returnUrl,
      'callbackUrl': callbackUrl,
      'customer': {
        'fullName': session.displayName.isNotEmpty
            ? session.displayName
            : (session.clubDisplayName.isNotEmpty
                ? session.clubDisplayName
                : 'Club Member'),
        'email': session.email.isNotEmpty
            ? session.email
            : 'billing@maclubsystem.com',
        'phone': session.phone,
      },
    };

    if (!mounted) return;
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator()));

    final initResp = await BcpgService.initiatePayment(payload);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss spinner

    if (initResp['error'] == true ||
        initResp['paymentUrl'] == null ||
        (initResp['paymentUrl'] as String).isEmpty) {
      debugPrint('BCPG init failed: $initResp');
      if (!mounted) return;
      final msg = (initResp['message'] ?? 'Payment init failed').toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Pay failed: $msg')));
      _onlineUnavailable(invoices);
      return;
    }

    final paymentUrl = (initResp['paymentUrl']).toString();

    // Open BCPG-hosted FPX flow in an in-app WebView. Pop result is a
    // map: { status, verification, referenceId }.
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => BcpgWebViewScreen(
          paymentUrl: paymentUrl,
          referenceId: referenceId,
          returnUrlNeedle: 'bcpg_redirect',
        ),
      ),
    );

    // Release the 2-minute payment lock regardless of outcome — the
    // attempt is finished.
    UserSession.instance.clearPaymentLock();

    if (!mounted) return;
    final status = (result?['status'] ?? 'unknown').toString();
    if (status == 'succeeded') {
      await _onBcpgSuccess(
        invoices: invoices,
        referenceId: referenceId,
        verification: (result?['verification'] is Map)
            ? Map<String, dynamic>.from(result!['verification'] as Map)
            : <String, dynamic>{},
      );
    } else if (status == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment $status. Please try again.')));
    }
  }

  /// Persist a successful BCPG payment: tell the webapp which invoices
  /// were settled (so its DB updates `ManualInvoice.paidstatus`), then
  /// refresh the live lists.
  Future<void> _onBcpgSuccess({
    required List<Map<String, dynamic>> invoices,
    required String referenceId,
    required Map<String, dynamic> verification,
  }) async {
    final extra = verification['extraDetails'];
    final fpxTxnId = (extra is Map ? extra['fpxTxnId'] : null)?.toString();
    final debitAuthCode =
        (extra is Map ? extra['debitAuthCode'] : null)?.toString();
    final buyerName =
        (extra is Map ? extra['buyerName'] : null)?.toString();
    final uuid = verification['uuid']?.toString();
    final paymentRefNo = 'BCPG:FPX:${fpxTxnId ?? uuid ?? referenceId}';

    try {
      await Api.outstandingPayInvoices(<String, dynamic>{
        'invoices': invoices,
        'paymentMethod': 'BCPG-FPX',
        'referenceId': referenceId,
        'paymentRefNo': paymentRefNo,
        'fpxTxnId': fpxTxnId,
        'debitAuthCode': debitAuthCode,
        'buyerName': buyerName,
      });
    } catch (e) {
      debugPrint('PayInvoices (post-BCPG) failed: $e');
      // Don't block the success UX — payment IS done at BCPG. Surface
      // a warning so the user knows to ping the club if the invoice
      // doesn't flip to Paid.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Payment succeeded but invoice sync failed: $e. Contact club.')));
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment successful · Ref: $paymentRefNo')));
    _selectedInvoiceIdx.clear();
    await _loadAll();
  }

  /// "Paying for" block — names each student + invoice being settled, so
  /// the user always sees whose invoices and what they cover.
  Widget _payingForBlock(AppColors c) {
    final rows = (_outstanding ?? const <dynamic>[])
        .whereType<Map>()
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PAYING FOR',
            style: TextStyle(
                color: c.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        ...rows.take(6).map((m) {
          final label = _invoiceLabel(m, 0);
          final owner = _invoiceOwner(m);
          final amt = _invoiceAmount(m).toStringAsFixed(2);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (owner.isNotEmpty)
                      Text(owner,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('RM $amt',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ]),
          );
        }),
        if (rows.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('+ ${rows.length - 6} more',
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  String _mmss(int total) {
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openPayModal() {
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
    session.startPaymentLock();
    Timer? ticker;
    // Compute live total at open-time so the modal always shows the
    // current outstanding amount, not a stale mock value.
    final liveTotal = _liveOutstandingTotal();
    final modalAmount = liveTotal > 0
        ? liveTotal.toStringAsFixed(2)
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
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 36),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: Text('Complete Payment', style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              ),
              // Countdown chip — the active payment window.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Choose payment method', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Text('RM $modalAmount', style: TextStyle(color: c.primary, fontSize: 32, fontWeight: FontWeight.w800)),
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
                      border: Border.all(color: active ? c.primary : c.border),
                      color: active ? c.surfaceAlt : Colors.transparent,
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: active ? c.primary : c.surfaceAlt, shape: BoxShape.circle),
                        child: Icon(m.icon, size: 18, color: active ? Colors.white : c.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(m.label, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
                      Icon(active ? Icons.radio_button_checked : Icons.radio_button_off, color: active ? c.primary : c.textMuted),
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
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock, color: Colors.white, size: 14),
                  SizedBox(width: 8),
                  Text('Confirm & Pay Securely', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
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
                child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              ),
            ),
          ]),
        );
      }),
    ).whenComplete(() => ticker?.cancel());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final liveTotal = _liveOutstandingTotal();
    final invoices = _outstanding ?? const <dynamic>[];
    final slips = UserSession.instance.scopedRows(_slips);
    final liveAmount = liveTotal > 0
        ? liveTotal.toStringAsFixed(2)
        : (session.dueAmount > 0
            ? session.dueAmount.toStringAsFixed(2)
            : '0.00');
    final liveLabel = invoices.isNotEmpty
        ? '${invoices.length} outstanding invoice(s)'
        : (session.invoiceCount > 0
            ? '${session.invoiceCount} outstanding invoice(s)'
            : 'No outstanding invoices');
    final liveDueDate = session.earliestDueDate.isNotEmpty
        ? session.earliestDueDate
        : '—';
    return Container(
      color: c.background,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: AppHeader(
            title: 'Fees & Payments',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 140),
          sliver: SliverList.list(children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const TermPaymentScreen()),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Term / Advance Payment'),
              ),
            ),
            // Due card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(Radii.xxl),
                boxShadow: Shadows.strong(c),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.error_outline, color: Color(0xFFFFF7ED), size: 18),
                  SizedBox(width: 6),
                  Text('NEXT PAYMENT DUE', style: TextStyle(color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 8),
                Text('RM $liveAmount', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 2),
                Text(liveLabel, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('Due by $liveDueDate', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
                const SizedBox(height: 18),
                InkWell(
                  onTap: _openPayModal,
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Pay Now', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: c.primary, size: 16),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
                  const SizedBox(width: 8),
                  Text('Loading invoices…', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ]),
              ),
            if (invoices.isNotEmpty) _liveInvoicesCard(c, invoices),
            if (invoices.isNotEmpty) const SizedBox(height: 16),
            _collectionCard(c),
            const SizedBox(height: 16),
            if ((_reimbursement ?? const []).isNotEmpty) _reimbursementCard(c, _reimbursement!),
            if ((_reimbursement ?? const []).isNotEmpty) const SizedBox(height: 16),
            if (slips.isNotEmpty) _livePaymentSlipsCard(c, slips),
            if (slips.isNotEmpty) const SizedBox(height: 16),
            const SizedBox(height: 24),
            Text('Payment History', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _filterChips(c),
            const SizedBox(height: 8),
            if ((_invoiceTypes ?? const []).isNotEmpty) _invoiceTypeDropdown(c),
            if (((_receipts ?? const []).length) > 3) ...[
              const SizedBox(height: 8),
              ListSearchBar(
                hint: 'Search receipt no, student, method, center…',
                controller: _receiptSearchCtrl,
                onSearch: (v) => setState(() => _receiptQuery = v),
                resultCount: _filteredReceipts().length,
                totalCount: (_receipts ?? const []).length,
                filters: [
                  if (_uniqStr(_receipts ?? const [], 'tcName').isNotEmpty)
                    ListFilter(
                      label: 'Center',
                      options: _uniqStr(_receipts ?? const [], 'tcName'),
                      selected: _receiptCenterFilter,
                      onSelected: (v) =>
                          setState(() => _receiptCenterFilter = v),
                    ),
                  if (_uniqStr(_receipts ?? const [], 'paymentMethod').isNotEmpty)
                    ListFilter(
                      label: 'Method',
                      options:
                          _uniqStr(_receipts ?? const [], 'paymentMethod'),
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
              if (list.isEmpty) {
                return <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: c.isDark ? Border.all(color: c.border) : null,
                      boxShadow: Shadows.card(c),
                    ),
                    child: Row(children: [
                      Icon(Icons.receipt_long_outlined,
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
                  .take(30)
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
          ]),
        ),
      ]),
    );
  }

  Widget _liveInvoicesCard(AppColors c, List<dynamic> invoices) {
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
            Icon(Icons.cloud_done, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('Outstanding Invoices (${invoices.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 10),
          ...invoices.asMap().entries.take(10).map((e) {
            final idx = e.key;
            final inv = e.value;
            final m = inv is Map ? inv : <dynamic, dynamic>{};
            final label = _invoiceLabel(m, idx);
            final sub = _invoiceSub(m);
            final amount = _invoiceAmount(m).toStringAsFixed(2);
            final selected = _selectedInvoiceIdx.contains(idx);
            return InkWell(
              onTap: () => setState(() {
                if (selected) {
                  _selectedInvoiceIdx.remove(idx);
                } else {
                  _selectedInvoiceIdx.add(idx);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: selected ? c.primary : c.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                        if (sub.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('RM $amount', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.textPrimary)),
                ]),
              ),
            );
          }),
          if (_selectedInvoiceIdx.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                final picks = _selectedInvoiceIdx
                    .map((i) => invoices[i])
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList();
                _initiateGatewayPayment(picks);
              },
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.md)),
                child: Text('Pay Selected (${_selectedInvoiceIdx.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
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
            Icon(Icons.receipt_long, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('Payment Slips (${slips.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...slips.take(5).map((s) {
            final m = s is Map ? s : <dynamic, dynamic>{};
            final label = (m['slipNo'] ?? m['description'] ?? m['text'] ?? 'Slip').toString();
            final amount = (m['amount'] ?? m['value'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary))),
                Text(amount.isEmpty ? '' : 'RM $amount',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
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
    final dateRaw = (m['receiptDate'] ?? m['date'] ?? m['paymentDate'] ?? '').toString();
    final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    final method = (m['paymentMethod'] ?? m['method'] ?? m['paymentMode'] ?? '').toString();
    final amountRaw = m['receiptAmount'] ?? m['amount'] ?? m['value'] ?? 0;
    final amount = amountRaw is num
        ? amountRaw.toStringAsFixed(2)
        : amountRaw.toString();
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
          width: 36, height: 36,
          decoration: BoxDecoration(color: c.isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5), shape: BoxShape.circle),
          child: Icon(Icons.cloud_done, size: 18, color: c.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ),
          ]),
        ),
        Text('RM $amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
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
          hint: Text('All invoice types', style: TextStyle(color: c.textMuted, fontSize: 13)),
          items: <DropdownMenuItem<dynamic>>[
            DropdownMenuItem<dynamic>(value: null, child: Text('All invoice types', style: TextStyle(color: c.textPrimary, fontSize: 13))),
            ...items.map((e) {
              final m = e is Map ? e : <dynamic, dynamic>{};
              final id = m['id'] ?? m['code'] ?? m['value'];
              final name = (m['name'] ?? m['text'] ?? m['title'] ?? e).toString();
              return DropdownMenuItem<dynamic>(value: id, child: Text(name, style: TextStyle(color: c.textPrimary, fontSize: 13)));
            }),
          ],
          onChanged: (v) => setState(() => _invoiceTypeFilter = v),
        ),
      ),
    );
  }

  Widget _collectionCard(AppColors c) {
    final cnt = _collectionCount;
    final count = cnt == null ? '—' : (cnt['count'] ?? cnt['total'] ?? cnt.values.first ?? 0).toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: _toggleCollectionCountList,
          child: Row(children: [
            Icon(Icons.inventory_2, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('Collection Count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
            const Spacer(),
            Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(width: 6),
            Icon(_showCollectionList ? Icons.expand_less : Icons.expand_more, color: c.textMuted),
          ]),
        ),
        if (_showCollectionList) ...[
          const SizedBox(height: 8),
          if (_collectionCountList == null || _collectionCountList!.isEmpty)
            Text('No collection items.', style: TextStyle(fontSize: 12, color: c.textSecondary))
          else
            ..._collectionCountList!.whereType<Map>().take(20).map((m) {
              final id = m['id'] ?? m['typeId'];
              final label = (m['name'] ?? m['text'] ?? m['title'] ?? '?').toString();
              final cnt = (m['count'] ?? m['value'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: c.textPrimary))),
                  if (cnt.isNotEmpty) Text(cnt, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed: () => _bumpCollection(id),
                    icon: Icon(Icons.add_circle, color: c.primary, size: 20),
                    tooltip: '+1',
                  ),
                ]),
              );
            }),
        ],
      ]),
    );
  }

  Widget _reimbursementCard(AppColors c, List<dynamic> items) {
    num total = 0;
    for (final i in items) {
      if (i is Map) {
        final v = i['amount'] ?? i['value'] ?? 0;
        if (v is num) total += v;
        if (v is String) total += num.tryParse(v) ?? 0;
      }
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.savings, size: 16, color: c.primary),
          const SizedBox(width: 6),
          Text('Reimbursements (${items.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          const Spacer(),
          Text('RM ${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary)),
        ]),
      ]),
    );
  }

}
