import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/mock_data.dart';
import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/app_header.dart';
import '../widgets/list_search.dart';
import '../widgets/app_icon_button.dart';

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
    final clubId = session.authData?['clubId'] ?? session.authData?['clubID'] ?? 0;
    final paymentId = m['paymentId'] ?? m['id'] ?? 0;
    final invoiceId = m['invoiceId'] ?? m['invoiceID'] ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Preparing receipt…')));
    try {
      final resp = await Api.utilitiesReceiptAsPDF(
          clubId: clubId, paymentId: paymentId, invoiceId: invoiceId);
      // Endpoint returns a PDF URL — pull it out of whatever shape comes back.
      String url = '';
      if (resp is String) {
        url = resp;
      } else if (resp is Map) {
        url = (resp['data'] ?? resp['url'] ?? resp['pdfUrl'] ?? '')
            .toString();
      }
      url = url.trim();
      if (!mounted) return;
      if (url.isEmpty || !(url.startsWith('http'))) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Receipt not available for this payment.')));
        return;
      }
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not open the receipt.')));
      }
    } catch (e) {
      debugPrint('ReceiptAsPDF failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Receipt failed: $e')));
    }
  }

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
    // Guardian accounts: narrow to the picked child first.
    base = UserSession.instance.filterByActiveStudent(base);
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
      'invoiceName', 'description', 'particulars', 'name', 'invoiceTitle',
      'item', 'feeType', 'invoiceNo', 'invoiceNumber', 'text'
    ]) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty && v != 'null') return v;
    }
    return 'Invoice #${idx + 1}';
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

  Future<void> _initiateGatewayPayment(List<Map<String, dynamic>> invoices) async {
    final session = UserSession.instance;
    final sid = session.authData?['studentId'] ?? session.authData?['id'];
    num total = 0;
    final ids = <dynamic>[];
    for (final inv in invoices) {
      ids.add(inv['id'] ?? inv['invoiceId'] ?? inv['invoiceID']);
      total += _invoiceAmount(inv);
    }
    String? gatewayUrl;
    String? orderId;
    try {
      final resp = await Api.paymentInitiate(<String, dynamic>{
        'invoiceIds': ids,
        'amount': total,
        'studentId': sid,
      });
      if (resp is Map) {
        gatewayUrl = (resp['url'] ?? resp['gatewayUrl'] ?? resp['paymentUrl'] ??
            (resp['data'] is Map ? (resp['data']['url'] ?? resp['data']['paymentUrl']) : null))?.toString();
        orderId = (resp['orderId'] ?? resp['id'] ??
            (resp['data'] is Map ? (resp['data']['orderId'] ?? resp['data']['id']) : null))?.toString();
      }
    } catch (e) {
      debugPrint('paymentInitiate failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Initiate failed: $e')));
      return;
    }
    if (!mounted) return;
    final c = context.appColors;
    if (gatewayUrl == null || gatewayUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Online payment unavailable — server returned no gateway link.')));
      return;
    }
    // Open the real payment gateway in the browser / external app.
    final launched = await launchUrl(Uri.parse(gatewayUrl),
        mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open the payment gateway.')));
      return;
    }
    // After the user returns from the gateway, let them confirm so the
    // app can finalize the order against the server.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete payment'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total: RM ${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
          const SizedBox(height: 8),
          if (orderId != null) Text('Order: $orderId', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 8),
          Text('Finish the payment in the gateway tab, then tap below to confirm.',
              style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4)),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Api.paymentFinalizing(<String, dynamic>{'orderId': orderId});
                await Api.paymentCompleted('success');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment confirmed')));
                _selectedInvoiceIdx.clear();
                await _loadAll();
              } catch (e) {
                debugPrint('finalize failed: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confirm failed: $e')));
              }
            },
            child: const Text("I've completed payment"),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
        ],
      ),
    );
  }

  void _openPayModal() {
    final c = context.appColors;
    // Compute live total at open-time so the modal always shows the
    // current outstanding amount, not a stale mock value.
    final liveTotal = _liveOutstandingTotal();
    final session = UserSession.instance;
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
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 36),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text('Complete Payment', style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text('Choose payment method', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Text('RM $modalAmount', style: TextStyle(color: c.primary, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
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
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final liveTotal = _liveOutstandingTotal();
    final invoices = _outstanding ?? const <dynamic>[];
    final slips = _slips ?? const <dynamic>[];
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
                  Text('Loading live invoices…', style: TextStyle(fontSize: 12, color: c.textSecondary)),
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
            const SizedBox(height: 8),
            Text('Quick Pay', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(children: [
              _pkgCard(c, Icons.calendar_month, c.primary, 'Monthly', 'RM 480'),
              const SizedBox(width: 10),
              _pkgCard(c, Icons.calendar_today, c.primaryDark, 'Quarterly', 'RM 1,300'),
              const SizedBox(width: 10),
              _pkgCard(c, Icons.emoji_events, c.warning, 'Tournament', 'RM 150'),
            ]),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Payment History', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Export', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
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

  Widget _pkgCard(AppColors c, IconData icon, Color tint, String l, String a) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: c.isDark ? Border.all(color: c.border) : null,
            boxShadow: Shadows.card(c),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: tint),
              const SizedBox(height: 10),
              Text(l, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(a, style: TextStyle(fontSize: 15, color: c.textPrimary, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

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
            Text('LIVE · Outstanding Invoices (${invoices.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 10),
          ...invoices.asMap().entries.take(10).map((e) {
            final idx = e.key;
            final inv = e.value;
            final m = inv is Map ? inv : <dynamic, dynamic>{};
            final label = _invoiceLabel(m, idx);
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
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: selected ? c.primary : c.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: c.textPrimary))),
                  Text('RM $amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
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
            Text('LIVE · Payment Slips (${slips.length})',
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
            Text('LIVE · Collection Count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
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
          Text('LIVE · Reimbursements (${items.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          const Spacer(),
          Text('RM ${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary)),
        ]),
      ]),
    );
  }

  Widget _histRow(AppColors c, payment) => Container(
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
            child: Icon(Icons.check, size: 18, color: c.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 2),
                Text('${payment.date} · ${payment.method}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('RM ${payment.amount}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.download, size: 12, color: c.primary),
                const SizedBox(width: 3),
                Text('Receipt', style: TextStyle(color: c.primary, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
        ]),
      );
}
