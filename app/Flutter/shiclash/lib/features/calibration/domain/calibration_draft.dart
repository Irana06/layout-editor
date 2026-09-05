import 'package:flutter/foundation.dart';

/// A gesture is one undo step; saved values remain the reset baseline.
class CalibrationDraft extends ChangeNotifier {
  CalibrationDraft(Map<String, dynamic> values)
    : _saved = Map.of(values),
      _value = Map.of(values);
  Map<String, dynamic> _saved;
  Map<String, dynamic> _value;
  final List<Map<String, dynamic>> _undo = [];
  final List<Map<String, dynamic>> _redo = [];
  Map<String, dynamic>? _gesture;
  Map<String, dynamic> get values => Map.unmodifiable(_value);
  bool get dirty => !mapEquals(_saved, _value);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void beginGesture() => _gesture = Map.of(_value);
  void endGesture() {
    if (_gesture != null && !mapEquals(_gesture, _value)) {
      _undo.add(_gesture!);
      _redo.clear();
    }
    _gesture = null;
    notifyListeners();
  }

  void change(Map<String, dynamic> changes) {
    final next = {..._value, ...changes};
    if (mapEquals(next, _value)) return;
    if (_gesture == null) {
      _undo.add(Map.of(_value));
      if (_undo.length > 100) _undo.removeAt(0);
      _redo.clear();
    }
    _value = next;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_value);
    _value = _undo.removeLast();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_value);
    _value = _redo.removeLast();
    notifyListeners();
  }

  void reset() => change(_saved);
  void saved(Map<String, dynamic> values) {
    _value = Map.of(values);
    _saved = Map.of(values);
    _undo.clear();
    _redo.clear();
    _gesture = null;
    notifyListeners();
  }
}
