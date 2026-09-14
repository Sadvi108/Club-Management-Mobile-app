import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/ion.dart';
import 'rn_kit.dart';

/// Port of `frontend/src/ui/reportkit.tsx` (Expo v2.11.1) — the building blocks every
/// instructor report and filter screen shares: a header, a filter card, a list.

typedef RkOption = ({Object id, String text});

/// Plain surface bar with back, left-aligned title and optional subtitle.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const ScreenHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      color: c.background,
      padding: EdgeInsets.fromLTRB(Gaps.lg, MediaQuery.paddingOf(context).top + 8, Gaps.lg, 8),
      child: Row(children: [
        RnCircleButton(icon: Ion.chevronBack, onPress: () => safeBack(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Uppercase tiny field label (`font.tiny` + uppercase).
class RkLabel extends StatelessWidget {
  final String text;
  const RkLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: context.appColors.textSecondary)),
      );
}

/// Pill field shell used by [SelectField] / [DateField].
class _PillField extends StatelessWidget {
  final String text;
  final bool placeholder;
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;
  final bool disabled;
  const _PillField({
    required this.text,
    required this.placeholder,
    required this.icon,
    this.iconSize = 18,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Touchable(
        activeOpacity: 0.7,
        onPress: disabled ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: placeholder ? FontWeight.w500 : FontWeight.w600,
                      color: placeholder ? c.textMuted : c.textPrimary)),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: iconSize, color: c.textMuted),
          ]),
        ),
      ),
    );
  }
}

/// Bottom-sheet shell with the RN handle.
Future<T?> showRkSheet<T>(BuildContext context, WidgetBuilder builder) {
  final c = context.appColors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: c.overlay,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(Gaps.xl, 12, Gaps.xl, 16 + MediaQuery.paddingOf(ctx).bottom),
        decoration: BoxDecoration(
          color: ctx.appColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: ctx.appColors.border, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          builder(ctx),
        ]),
      ),
    ),
  );
}

/// Dropdown that opens a bottom-sheet list (searchable for long lists).
class SelectField extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final Object? value;
  final List<RkOption> options;
  final void Function(Object id, RkOption opt) onChange;
  final bool loading;
  final bool disabled;
  final bool? searchable;

  const SelectField({
    super.key,
    this.label,
    this.placeholder,
    this.value,
    required this.options,
    required this.onChange,
    this.loading = false,
    this.disabled = false,
    this.searchable,
  });

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => '${o.id}' == '$value').firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (label != null) RkLabel(label!),
      _PillField(
        text: loading ? 'Loading…' : (selected?.text ?? placeholder ?? 'Select'),
        placeholder: selected == null,
        icon: Ion.chevronDown,
        disabled: disabled || loading,
        onTap: () => showRkSheet<void>(
          context,
          (ctx) => _SelectSheet(
            title: label ?? placeholder ?? 'Select',
            options: options,
            value: value,
            searchable: searchable ?? options.length > 8,
            onPick: (o) {
              Navigator.pop(ctx);
              onChange(o.id, o);
            },
          ),
        ),
      ),
    ]);
  }
}

class _SelectSheet extends StatefulWidget {
  final String title;
  final List<RkOption> options;
  final Object? value;
  final bool searchable;
  final ValueChanged<RkOption> onPick;
  const _SelectSheet({
    required this.title,
    required this.options,
    required this.value,
    required this.searchable,
    required this.onPick,
  });

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final filtered = _q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.text.toLowerCase().contains(_q.toLowerCase())).toList();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(widget.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary)),
      ),
      if (widget.searchable)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
          child: Row(children: [
            Icon(Ion.search, size: 16, color: c.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                autocorrect: false,
                onChanged: (v) => setState(() => _q = v),
                cursorColor: c.primary,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  hintText: 'Search',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                ),
              ),
            ),
          ]),
        ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: filtered.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No options', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final o = filtered[i];
                  final on = '${o.id}' == '${widget.value}';
                  return Touchable(
                    onPress: () => widget.onPick(o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
                      child: Row(children: [
                        Expanded(
                          child: Text(o.text.isEmpty ? '—' : o.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: on ? c.primary : c.textPrimary,
                                  fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
                        ),
                        if (on) Icon(Ion.checkmark, size: 18, color: c.primary),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

String _pad2(int n) => n < 10 ? '0$n' : '$n';

/// RN `toISODate`: `YYYY-MM-DDT00:00:00` (no zone).
String toISODate(DateTime d) => '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}T00:00:00';

/// Date pill that opens a month calendar sheet.
class DateField extends StatelessWidget {
  final String? label;
  final DateTime value;
  final ValueChanged<DateTime> onChange;
  const DateField({super.key, this.label, required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return _PillField(
      text: '${label != null ? '$label ' : ''}${_pad2(value.day)}.${_pad2(value.month)}.${value.year}',
      placeholder: false,
      icon: Ion.calendarOutline,
      iconSize: 16,
      onTap: () async {
        final picked = await showRkSheet<DateTime>(context, (ctx) => _CalendarSheet(value: value));
        if (picked != null) onChange(picked);
      },
    );
  }
}

class _CalendarSheet extends StatefulWidget {
  final DateTime value;
  const _CalendarSheet({required this.value});
  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late DateTime _view = DateTime(widget.value.year, widget.value.month, 1);
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final daysInMonth = DateTime(_view.year, _view.month + 1, 0).day;
    final lead = _view.weekday % 7; // Sunday-first
    final cells = [...List<int?>.filled(lead, null), for (var d = 1; d <= daysInMonth; d++) d];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6).copyWith(bottom: 12),
        child: Row(children: [
          Touchable(
            onPress: () => setState(() => _view = DateTime(_view.year, _view.month - 1, 1)),
            child: Icon(Ion.chevronBack, size: 22, color: c.primary),
          ),
          Expanded(
            child: Text('${_months[_view.month - 1]} ${_view.year}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
          ),
          Touchable(
            onPress: () => setState(() => _view = DateTime(_view.year, _view.month + 1, 1)),
            child: Icon(Ion.chevronForward, size: 22, color: c.primary),
          ),
        ]),
      ),
      Row(children: [
        for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(d,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textMuted)),
            ),
          ),
      ]),
      LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / 7;
        return Wrap(children: [
          for (final day in cells)
            SizedBox(
              width: w,
              child: day == null
                  ? const SizedBox(height: 44)
                  : Builder(builder: (context) {
                      final on = widget.value.year == _view.year &&
                          widget.value.month == _view.month &&
                          widget.value.day == day;
                      return Touchable(
                        onPress: () => Navigator.pop(context, DateTime(_view.year, _view.month, day)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Center(
                            child: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c.primary : null),
                              child: Text('$day',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: on ? Colors.white : c.textPrimary,
                                      fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
                            ),
                          ),
                        ),
                      );
                    }),
            ),
        ]);
      }),
    ]);
  }
}

/// Report scaffold: header + filter card (+ optional Search) + list / skeleton / empty / error.
class ReportScaffold<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? filters;
  final VoidCallback? onSearch;
  final bool loading;
  final String? error;
  final List<T>? data;
  final Widget Function(T item, int index) renderItem;
  final String? emptyText;
  final Future<void> Function()? onRefresh;
  final Widget? footer;

  const ReportScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.filters,
    this.onSearch,
    this.loading = false,
    this.error,
    required this.data,
    required this.renderItem,
    this.emptyText,
    this.onRefresh,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final rows = data ?? const [];

    Widget centered(Widget child) => LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(child: Padding(padding: const EdgeInsets.all(40), child: child)),
            ),
          ),
        );

    Widget body;
    if (error != null) {
      body = centered(Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Ion.alertCircleOutline, size: 40, color: c.danger),
        const SizedBox(height: 10),
        Text(error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger, fontSize: 14)),
      ]));
    } else if (loading && onSearch == null) {
      body = const SingleChildScrollView(child: SkeletonList(rows: 7));
    } else if (rows.isEmpty) {
      body = centered(Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Ion.fileTrayOutline, size: 44, color: c.textMuted),
        const SizedBox(height: 10),
        Text(emptyText ?? 'No data available',
            textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 14)),
      ]));
    } else {
      body = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 140),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => renderItem(rows[i], i),
      );
    }
    if (onRefresh != null) body = RefreshIndicator(color: c.primary, onRefresh: onRefresh!, child: body);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ScreenHeader(title: title, subtitle: subtitle),
        if (filters != null || onSearch != null)
          Container(
            margin: const EdgeInsets.fromLTRB(Gaps.xl, 4, Gaps.xl, 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.xl)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < (filters ?? const []).length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                filters![i],
              ],
              if (onSearch != null) ...[
                if ((filters ?? const []).isNotEmpty) const SizedBox(height: 10),
                Touchable(
                  activeOpacity: 0.9,
                  onPress: loading ? null : onSearch,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(999)),
                    child: loading
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Search',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ]),
          ),
        Expanded(child: body),
        if (footer != null) footer!,
      ]),
    );
  }
}

/// Labelled key/value row used inside report cards.
class KV extends StatelessWidget {
  final String label;
  final Object? value;
  final bool strong;
  const KV(this.label, this.value, {super.key, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final v = value == null || '$value'.isEmpty ? '—' : '$value';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(v,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  color: strong ? c.primary : c.textPrimary,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// The standard report card (`card` style repeated across the r-* screens).
class RkCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const RkCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: rnCard(c),
      child: child,
    );
    return onTap == null ? card : Touchable(activeOpacity: 0.85, onPress: onTap, child: card);
  }
}
