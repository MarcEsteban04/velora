import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/theme/app_colors.dart';
import 'package:velora/core/theme/scene_schedule.dart';

void main() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 9, 29, h, m);

  test('Day from 6 AM, Afternoon from 3 PM, Night from 6 PM', () {
    expect(SceneSchedule.at(at(5, 59)), Scene.night);
    expect(SceneSchedule.at(at(6)), Scene.day);
    expect(SceneSchedule.at(at(14, 59)), Scene.day);
    expect(SceneSchedule.at(at(15)), Scene.afternoon);
    expect(SceneSchedule.at(at(17, 59)), Scene.afternoon);
    expect(SceneSchedule.at(at(18)), Scene.night);
    expect(SceneSchedule.at(at(23, 30)), Scene.night);
    expect(SceneSchedule.at(at(0)), Scene.night);
  });

  test('the next change is the next boundary, overnight included', () {
    expect(SceneSchedule.nextChange(at(3)), at(6));
    expect(SceneSchedule.nextChange(at(6)), at(15));
    expect(SceneSchedule.nextChange(at(16, 20)), at(18));
    expect(SceneSchedule.nextChange(at(21)), DateTime(2026, 9, 30, 6));
  });

  test('labels read as clock times', () {
    expect(SceneSchedule.label(6), '6 AM');
    expect(SceneSchedule.label(15), '3 PM');
    expect(SceneSchedule.label(0), '12 AM');
    expect(SceneSchedule.label(12), '12 PM');
  });
}
