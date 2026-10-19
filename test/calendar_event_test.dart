import 'package:flutter_test/flutter_test.dart';
import 'package:calendar_event/calendar_event.dart';
import 'package:calendar_event/calendar_event_platform_interface.dart';
import 'package:calendar_event/calendar_event_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCalendarEventPlatform
    with MockPlatformInterfaceMixin
    implements CalendarEventPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> requestPermission() => Future.value(true);

  @override
  Future<String?> addEvent({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? location,
    bool allDay = false,
    String? url,
    Duration? alert,
  }) => Future.value('event-1');

  @override
  Future<void> updateEvent({
    required String eventId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    String? location,
    bool? allDay,
    String? url,
    Duration? alert,
    bool clearAlert = false,
  }) => Future.value();

  @override
  Future<void> deleteEvent({required String eventId}) => Future.value();
}

void main() {
  final CalendarEventPlatform initialPlatform = CalendarEventPlatform.instance;

  test('$MethodChannelCalendarEvent is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelCalendarEvent>());
  });

  test('getPlatformVersion', () async {
    CalendarEvent calendarEventPlugin = CalendarEvent();
    MockCalendarEventPlatform fakePlatform = MockCalendarEventPlatform();
    CalendarEventPlatform.instance = fakePlatform;

    expect(await calendarEventPlugin.getPlatformVersion(), '42');
  });

  test('addEvent', () async {
    MockCalendarEventPlatform fakePlatform = MockCalendarEventPlatform();
    CalendarEventPlatform.instance = fakePlatform;

    expect(
      await CalendarEvent.addEvent(
        title: 'Meeting',
        startDate: DateTime(2026, 10, 10, 9),
        endDate: DateTime(2026, 10, 10, 10),
      ),
      'event-1',
    );
  });

  test('updateEvent requires startDate and endDate together', () {
    expect(
      CalendarEvent.updateEvent(
        eventId: 'event-1',
        startDate: DateTime(2026, 10, 10, 9),
      ),
      throwsA(
        isA<CalendarEventException>().having(
          (e) => e.code,
          'code',
          CalendarEventErrorCode.invalidArgument,
        ),
      ),
    );
  });

  test('updateEvent rejects alert together with clearAlert', () {
    expect(
      CalendarEvent.updateEvent(
        eventId: 'event-1',
        alert: const Duration(minutes: 5),
        clearAlert: true,
      ),
      throwsA(
        isA<CalendarEventException>().having(
          (e) => e.code,
          'code',
          CalendarEventErrorCode.invalidArgument,
        ),
      ),
    );
  });

  test('addEvent rejects endDate before startDate', () async {
    expect(
      CalendarEvent.addEvent(
        title: 'Meeting',
        startDate: DateTime(2026, 10, 10, 9),
        endDate: DateTime(2026, 10, 10, 8),
      ),
      throwsA(
        isA<CalendarEventException>().having(
          (e) => e.code,
          'code',
          CalendarEventErrorCode.invalidArgument,
        ),
      ),
    );
  });
}
