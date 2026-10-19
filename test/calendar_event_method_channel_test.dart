import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calendar_event/calendar_event_exception.dart';
import 'package:calendar_event/calendar_event_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelCalendarEvent platform = MethodChannelCalendarEvent();
  const MethodChannel channel = MethodChannel('calendar_event');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('requestPermission returns the native result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'requestPermission');
          return true;
        });

    expect(await platform.requestPermission(), isTrue);
  });

  test('requestPermission returns false when the native result is null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);

    expect(await platform.requestPermission(), isFalse);
  });

  test('addEvent maps native error codes to CalendarEventException', () async {
    final cases = {
      'PERMISSION_DENIED': CalendarEventErrorCode.permissionDenied,
      'NO_CALENDAR': CalendarEventErrorCode.noCalendar,
      'INSERT_FAILED': CalendarEventErrorCode.insertFailed,
      'INVALID_ARGUMENT': CalendarEventErrorCode.invalidArgument,
      'NO_CONTEXT': CalendarEventErrorCode.unknown,
    };

    for (final entry in cases.entries) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            throw PlatformException(code: entry.key, message: 'msg');
          });

      await expectLater(
        platform.addEvent(
          title: 'Meeting',
          startDate: DateTime(2026, 10, 10, 9),
          endDate: DateTime(2026, 10, 10, 10),
        ),
        throwsA(
          isA<CalendarEventException>()
              .having((e) => e.code, 'code', entry.value)
              .having((e) => e.message, 'message', 'msg'),
        ),
      );
    }
  });

  test('addEvent sends arguments to the native side', () async {
    final start = DateTime(2026, 10, 10, 9);
    final end = DateTime(2026, 10, 10, 10);
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          received = methodCall;
          return 'event-1';
        });

    expect(
      await platform.addEvent(
        title: 'Meeting',
        startDate: start,
        endDate: end,
        location: 'Room 1',
      ),
      'event-1',
    );
    expect(received?.method, 'addEvent');
    expect(received?.arguments, {
      'title': 'Meeting',
      'startDate': start.millisecondsSinceEpoch,
      'endDate': end.millisecondsSinceEpoch,
      'description': null,
      'location': 'Room 1',
      'allDay': false,
      'url': null,
      'alertSeconds': null,
    });
  });

  test('addEvent sends url and alert to the native side', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          received = methodCall;
          return 'event-1';
        });

    await platform.addEvent(
      title: 'Meeting',
      startDate: DateTime(2026, 10, 10, 9),
      endDate: DateTime(2026, 10, 10, 10),
      url: 'https://example.com/meeting',
      alert: const Duration(minutes: 15),
    );

    expect(received?.arguments, containsPair('url', 'https://example.com/meeting'));
    expect(received?.arguments, containsPair('alertSeconds', 900));
  });

  test('updateEvent sends only the changed fields to the native side', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          received = methodCall;
          return null;
        });

    await platform.updateEvent(eventId: 'event-1', title: 'Renamed');

    expect(received?.method, 'updateEvent');
    expect(received?.arguments, {
      'eventId': 'event-1',
      'title': 'Renamed',
      'startDate': null,
      'endDate': null,
      'description': null,
      'location': null,
      'allDay': null,
      'url': null,
      'alertSeconds': null,
      'clearAlert': false,
    });
  });

  test('updateEvent maps native error codes to CalendarEventException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(code: 'NOT_FOUND', message: 'msg');
        });

    await expectLater(
      platform.updateEvent(eventId: 'missing', title: 'Renamed'),
      throwsA(
        isA<CalendarEventException>().having(
          (e) => e.code,
          'code',
          CalendarEventErrorCode.eventNotFound,
        ),
      ),
    );
  });

  test('deleteEvent sends the event ID to the native side', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          received = methodCall;
          return null;
        });

    await platform.deleteEvent(eventId: 'event-1');

    expect(received?.method, 'deleteEvent');
    expect(received?.arguments, {'eventId': 'event-1'});
  });
}
