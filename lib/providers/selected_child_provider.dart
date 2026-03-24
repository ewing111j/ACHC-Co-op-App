// lib/providers/selected_child_provider.dart
// Persists the currently-selected child UID across Memory Work navigation.
// Used by ChildSwitcherPill, ByUnitScreen, BySubjectScreen, ParentReferenceCard,
// and ParentDashboardScreen.

import 'package:flutter/foundation.dart';

class SelectedChildProvider extends ChangeNotifier {
  String? _selectedChildUid;

  String? get selectedChildUid => _selectedChildUid;

  /// Initialize with the first child UID from the parent's kidUids list.
  void initWithKids(List<String> kidUids) {
    if (_selectedChildUid != null) return; // already initialized
    if (kidUids.isNotEmpty) {
      _selectedChildUid = kidUids.first;
      notifyListeners();
    }
  }

  /// Select a specific child.
  void selectChild(String uid) {
    if (_selectedChildUid == uid) return;
    _selectedChildUid = uid;
    notifyListeners();
  }

  /// Reset when user logs out.
  void reset() {
    _selectedChildUid = null;
    notifyListeners();
  }
}
