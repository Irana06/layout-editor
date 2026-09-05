import 'package:flutter_test/flutter_test.dart';
import 'package:shiclash/features/calibration/domain/calibration_draft.dart';

void main() {
  test('drag groups changes into one undo, saving establishes a new reset baseline', () {
    final draft = CalibrationDraft({'offset_x': 0.0, 'offset_y': 0.0});
    draft.beginGesture();
    draft.change({'offset_x': 10.0});
    draft.change({'offset_x': 20.0});
    draft.endGesture();
    expect(draft.dirty, true);
    draft.undo();
    expect(draft.values['offset_x'], 0);
    expect(draft.dirty, false);
    draft.redo();
    expect(draft.values['offset_x'], 20);
    draft.saved(draft.values);
    draft.change({'offset_y': -10.0});
    draft.reset();
    expect(draft.values, {'offset_x': 20.0, 'offset_y': 0.0});
    expect(draft.dirty, false);
    draft.dispose();
  });
  test('new change clears redo and null footprint remains distinct from explicit dimensions', () {
    final draft = CalibrationDraft({'grid_width': null});
    draft.change({'grid_width': 3});
    draft.undo();
    expect(draft.values['grid_width'], isNull);
    draft.change({'grid_width': 4});
    expect(draft.canRedo, false);
    draft.dispose();
  });
}
