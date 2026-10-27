import 'package:after_work/models/record.dart';
import 'package:test/test.dart';

void main() {
  group('Record photo_paths JSON serialization', () {
    final base = Record(
      activityId: 1,
      recordDate: '2026-10-19',
      actualMinutes: 30,
      createdAt: DateTime.parse('2026-10-19T10:00:00Z'),
      updatedAt: DateTime.parse('2026-10-19T10:00:00Z'),
    );

    test('empty photoPaths serializes to JSON array string', () {
      final map = base.toMap();
      expect(map['photo_paths'], '[]');
    });

    test('multiple photoPaths serializes to JSON array string', () {
      final record = base.copyWith(
        photoPaths: ['photo1.jpg', 'photo2.jpg'],
      );
      final map = record.toMap();
      expect(map['photo_paths'], '["photo1.jpg","photo2.jpg"]');
    });

    test('empty photoPaths deserializes to empty list', () {
      final record = Record.fromMap({
        'id': 1,
        'plan_id': null,
        'activity_id': 1,
        'record_date': '2026-10-19',
        'actual_minutes': 30,
        'note': null,
        'photo_paths': '[]',
        'created_at': '2026-10-19T10:00:00Z',
        'updated_at': '2026-10-19T10:00:00Z',
      });
      expect(record.photoPaths, isEmpty);
    });

    test('multiple photoPaths deserializes to list', () {
      final record = Record.fromMap({
        'id': 1,
        'plan_id': null,
        'activity_id': 1,
        'record_date': '2026-10-19',
        'actual_minutes': 30,
        'note': null,
        'photo_paths': '["a.jpg","b.jpg"]',
        'created_at': '2026-10-19T10:00:00Z',
        'updated_at': '2026-10-19T10:00:00Z',
      });
      expect(record.photoPaths, ['a.jpg', 'b.jpg']);
    });

    test('null photo_paths deserializes to empty list for backward compat', () {
      final record = Record.fromMap({
        'id': 1,
        'plan_id': null,
        'activity_id': 1,
        'record_date': '2026-10-19',
        'actual_minutes': 30,
        'note': null,
        'photo_paths': null,
        'created_at': '2026-10-19T10:00:00Z',
        'updated_at': '2026-10-19T10:00:00Z',
      });
      expect(record.photoPaths, isEmpty);
    });
  });
}
