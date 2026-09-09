import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable search + filter chip bar for any list-heavy screen.
///
/// Usage:
///   ListSearchBar(
///     hint: 'Search students by name or IC…',
///     controller: _searchCtrl,
///     onSearch: (txt) => setState(() => _query = txt),
///     filters: [
///       ListFilter(
///         label: 'Center',
///         options: centers,
///         selected: _center,
///         onSelected: (v) => setState(() => _center = v),
///       ),
///       ListFilter.toggle(
///         label: 'Active only',
///         value: _activeOnly,
///         onChanged: (v) => setState(() => _activeOnly = v),
///       ),
///     ],
///     resultCount: visible.length,
///     totalCount: rows.length,
///     onClearAll: () { ... },
///   )
///
/// Layout: search field on top, chip strip below. Chip strip shows
/// "All <label>", or "<label>: <value>" with an X to clear when active.
/// Tapping a non-toggle chip opens a picker bottom-sheet.
class ListSearchBar extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final List<ListFilter> filters;
  final int? resultCount;
  final int? totalCount;
  final VoidCallback? onClearAll;

  const ListSearchBar({
    super.key,
    required this.hint,
    required this.controller,
    required this.onSearch,
    this.filters = const [],
    this.resultCount,
    this.totalCount,
    this.onClearAll,
  });

  bool get _anyActive {
    if (controller.text.trim().isNotEmpty) return true;
    return filters.any((f) => f.isActive);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field row.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Icon(Icons.search, size: 18, color: c.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onSearch,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: hint,
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              InkWell(
                onTap: () {
                  controller.clear();
                  onSearch('');
                },
                child: Icon(Icons.close, size: 18, color: c.textMuted),
              ),
          ]),
        ),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: filters.length + (_anyActive ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                if (i == filters.length) {
                  // Trailing "clear all" chip.
                  return _chip(
                    c,
                    icon: Icons.refresh,
                    label: 'Reset',
                    activeAccent: c.danger,
                    onTap: () {
                      controller.clear();
                      onSearch('');
                      for (final f in filters) {
                        f.clear();
                      }
                      onClearAll?.call();
                    },
                  );
                }
                final f = filters[i];
                return _filterChip(context, c, f);
              },
            ),
          ),
        ],
        if (resultCount != null && totalCount != null) ...[
          const SizedBox(height: 6),
          Text(
            resultCount == totalCount
                ? 'Showing all $totalCount'
                : 'Showing $resultCount of $totalCount',
            style: TextStyle(
                color: c.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _filterChip(BuildContext context, AppColors c, ListFilter f) {
    if (f.isToggle) {
      return _chip(
        c,
        icon: f.value == true ? Icons.check_circle : Icons.radio_button_unchecked,
        label: f.label,
        activeAccent: f.value == true ? c.primary : null,
        onTap: () => f.onChanged?.call(!(f.value == true)),
      );
    }
    final active = f.selected != null && f.selected!.isNotEmpty;
    return _chip(
      c,
      icon: active ? Icons.filter_alt : Icons.filter_alt_outlined,
      label: active ? '${f.label}: ${f.selected}' : f.label,
      activeAccent: active ? c.primary : null,
      trailing: active
          ? InkWell(
              onTap: () => f.onSelected?.call(null),
              child: Icon(Icons.close, size: 14, color: c.surface),
            )
          : null,
      onTap: () => _pickOption(context, c, f),
    );
  }

  Widget _chip(
    AppColors c, {
    required IconData icon,
    required String label,
    Color? activeAccent,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final bg = activeAccent ?? c.surfaceAlt;
    final fg = activeAccent != null ? Colors.white : c.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: activeAccent != null ? activeAccent : c.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ]),
      ),
    );
  }

  Future<void> _pickOption(
      BuildContext context, AppColors c, ListFilter f) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final ctrl = TextEditingController();
        var query = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final filtered = f.options
              .where((o) =>
                  o.toLowerCase().contains(query.trim().toLowerCase()))
              .toList();
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                    child: Text('Filter by ${f.label}',
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (f.selected != null && f.selected!.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 14),
                      label: const Text('Clear'),
                      onPressed: () {
                        f.onSelected?.call(null);
                        Navigator.pop(ctx);
                      },
                    ),
                ]),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: ctrl,
                  onChanged: (v) => setSheet(() => query = v),
                  style: TextStyle(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    prefixIcon:
                        Icon(Icons.search, size: 18, color: c.textMuted),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                      borderSide: BorderSide(color: c.border),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final opt = filtered[i];
                    final isSel = opt == f.selected;
                    return ListTile(
                      dense: true,
                      title: Text(opt,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600)),
                      trailing: isSel
                          ? Icon(Icons.check, color: c.primary, size: 18)
                          : null,
                      onTap: () => Navigator.pop(ctx, opt),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ]),
          );
        });
      },
    );
    if (result != null) {
      f.onSelected?.call(result);
    }
  }
}

/// Describes one filter chip: either a single-value picker (with [options])
/// or a boolean toggle (constructed via [ListFilter.toggle]).
class ListFilter {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?>? onSelected;

  final bool isToggle;
  final bool? value;
  final ValueChanged<bool>? onChanged;

  const ListFilter({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  })  : isToggle = false,
        value = null,
        onChanged = null;

  const ListFilter.toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  })  : isToggle = true,
        options = const [],
        selected = null,
        onSelected = null;

  bool get isActive => isToggle ? (value == true) : (selected != null && selected!.isNotEmpty);

  void clear() {
    if (isToggle) {
      onChanged?.call(false);
    } else {
      onSelected?.call(null);
    }
  }
}
