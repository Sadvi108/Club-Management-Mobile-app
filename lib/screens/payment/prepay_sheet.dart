import 'package:flutter/material.dart';
import '../../config/feature_flags.dart';
import '../../services/prepay_service.dart';
import '../../services/user_session.dart';
import '../../services/api.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet to prepay future monthly fees for the current student.
Future<void> showPrepaySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _PrepaySheet(),
  );
}

class _PrepaySheet extends StatefulWidget {
  const _PrepaySheet();
  @override
  State<_PrepaySheet> createState() => _PrepaySheetState();
}

class _PrepaySheetState extends State<_PrepaySheet> {
  late int _year;
  final Set<int> _selected = <int>{};
  PrepayQuote _quote = const PrepayQuote([]);
  bool _pricing = false;
  bool _paying = false;
  int _repriceSeq = 0;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  Future<void> _reprice() async {
    final sid = UserSession.instance.currentStudentId;
    if (sid == null || _selected.isEmpty) {
      setState(() => _quote = const PrepayQuote([]));
      return;
    }
    final seq = ++_repriceSeq;
    setState(() => _pricing = true);
    final quote = await PrepayService.priceMonths(
      studentId: sid,
      year: _year,
      months: _selected.toList()..sort(),
    );
    // Ignore a stale response when a newer reprice has started.
    if (!mounted || seq != _repriceSeq) return;
    setState(() {
      _quote = quote;
      _pricing = false;
    });
  }

  Future<void> _pay() async {
    final sid = UserSession.instance.currentStudentId;
    if (sid == null || _quote.months.isEmpty) return;
    final months = _quote.months.map((m) => m.month).toList();
    setState(() => _paying = true);
    try {
      await Api.outstandingPayTermPayments(
        studentIds: [sid],
        year: _year,
        months: months,
        paymentMethod: 1, // 1 = the default method enum; wire chooser later
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prepayment submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prepayment failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final now = DateTime.now();
    final name = UserSession.instance.displayName;
    final canPay = kPrepayPayEnabled &&
        _quote.months.isNotEmpty &&
        !_paying;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: c.border, borderRadius: BorderRadius.circular(2)),
        ),
        Text('Prepay Monthly Fees',
            style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        if (name.isNotEmpty)
          Text(name,
              style: TextStyle(color: c.textMuted, fontSize: 12)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final y in [now.year, now.year + 1, now.year + 2])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text('$y'),
                selected: _year == y,
                onSelected: (_) {
                  setState(() {
                    _year = y;
                    _selected.clear();
                    _quote = const PrepayQuote([]);
                  });
                },
              ),
            ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var m = 1; m <= 12; m++)
              FilterChip(
                label: Text(_monthNames[m - 1]),
                selected: _selected.contains(m),
                onSelected: (_year == now.year && m < now.month)
                    ? null
                    : (sel) {
                        setState(() {
                          if (sel) {
                            _selected.add(m);
                          } else {
                            _selected.remove(m);
                          }
                        });
                        _reprice();
                      },
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_pricing)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          )
        else if (_selected.isNotEmpty && _quote.months.isEmpty)
          Text('No prepayable months for this account.',
              style: TextStyle(color: c.textSecondary)),
        for (final m in _quote.months)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Text(m.label,
                    style: TextStyle(color: c.textPrimary, fontSize: 13)),
              ),
              Text('RM ${m.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: c.textPrimary, fontWeight: FontWeight.w700)),
            ]),
          ),
        if (_quote.months.isNotEmpty) ...[
          const Divider(),
          Row(children: [
            Expanded(
              child: Text('Total',
                  style: TextStyle(
                      color: c.textPrimary, fontWeight: FontWeight.w800)),
            ),
            Text('RM ${_quote.total.toStringAsFixed(2)}',
                style: TextStyle(
                    color: c.primary, fontWeight: FontWeight.w900)),
          ]),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canPay ? _pay : null,
            child: Text(kPrepayPayEnabled
                ? (_paying ? 'Submitting…' : 'Pay')
                : 'Pay (coming soon)'),
          ),
        ),
      ]),
    );
  }
}
