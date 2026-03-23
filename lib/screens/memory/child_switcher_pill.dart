import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChildSwitcherPill
//
// A persistent dropdown/toggle pill shown on parent browse screens when
// multiple children are linked.  Hides when there is only one child.
//
// Usage:
//   ChildSwitcherPill(
//     childIds: user.kidUids,
//     childNames: {'uid1': 'Alice', 'uid2': 'Bob'},
//     selectedId: _selectedChildId,
//     onChanged: (id) => setState(() => _selectedChildId = id),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class ChildSwitcherPill extends StatelessWidget {
  final List<String> childIds;
  final Map<String, String> childNames; // uid → display name
  final String selectedId;
  final ValueChanged<String> onChanged;

  const ChildSwitcherPill({
    super.key,
    required this.childIds,
    required this.childNames,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (childIds.length <= 1) return const SizedBox.shrink();

    if (childIds.length == 2) {
      // Toggle-button style for exactly 2 children
      return _TwoPill(
        childIds: childIds,
        childNames: childNames,
        selectedId: selectedId,
        onChanged: onChanged,
      );
    }

    // Dropdown pill for 3+ children
    return _DropdownPill(
      childIds: childIds,
      childNames: childNames,
      selectedId: selectedId,
      onChanged: onChanged,
    );
  }
}

// ─── 2-child toggle ───────────────────────────────────────────────────────────

class _TwoPill extends StatelessWidget {
  final List<String> childIds;
  final Map<String, String> childNames;
  final String selectedId;
  final ValueChanged<String> onChanged;

  const _TwoPill({
    required this.childIds,
    required this.childNames,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: childIds.map((id) {
          final selected = id == selectedId;
          return GestureDetector(
            onTap: () => onChanged(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.navy : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _shortName(childNames[id] ?? id),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.navy,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 3+ child dropdown ────────────────────────────────────────────────────────

class _DropdownPill extends StatelessWidget {
  final List<String> childIds;
  final Map<String, String> childNames;
  final String selectedId;
  final ValueChanged<String> onChanged;

  const _DropdownPill({
    required this.childIds,
    required this.childNames,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.navy,
          ),
          icon: Icon(Icons.expand_more, size: 18, color: AppTheme.navy),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: childIds
              .map((id) => DropdownMenuItem(
                    value: id,
                    child: Text(_shortName(childNames[id] ?? id)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _shortName(String name) {
  final parts = name.trim().split(' ');
  return parts.first;
}

// ─────────────────────────────────────────────────────────────────────────────
// ChildSwitcherMixin
//
// Add to a State class to get child-switching boilerplate:
//   - selectedChildId
//   - childNames map
//   - initChild / persistChild
// ─────────────────────────────────────────────────────────────────────────────

const String _kPrefKey = 'memory_selected_child';

mixin ChildSwitcherMixin<T extends StatefulWidget> on State<T> {
  String _selectedChildId = '';
  Map<String, String> _childNames = {};

  String get selectedChildId => _selectedChildId;
  Map<String, String> get childNames => _childNames;

  /// Call in initState with the parent's kidUids + display names.
  Future<void> initChildSwitcher(
    List<String> kidUids,
    Map<String, String> names,
  ) async {
    _childNames = names;
    if (kidUids.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString(_kPrefKey);
    final valid =
        (persisted != null && kidUids.contains(persisted)) ? persisted : null;

    setState(() {
      _selectedChildId = valid ?? kidUids.first;
    });
  }

  Future<void> selectChild(String uid) async {
    setState(() => _selectedChildId = uid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, uid);
  }
}
