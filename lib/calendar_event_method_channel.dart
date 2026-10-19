import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'calendar_event_exception.dart';
import 'calendar_event_platform_interface.dart';

/// An implementation of [CalendarEventPlatform] that uses method channels.
class MethodChannelCalendarEvent extends CalendarEventPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('calendar_event');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final granted = await methodChannel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } on PlatformException catch (e) {
      throw CalendarEventException(
        CalendarEventErrorCode.fromNativeCode(e.code),
        e.message,
      );
    }
  }

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
  }) async {
    try {
      final eventId = await methodChannel.invokeMethod<String>('addEvent', {
        'title': title,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
        'description': description,
        'location': location,
        'allDay': allDay,
        'url': url,
        'alertSeconds': alert?.inSeconds,
      });
      return eventId;
    } on PlatformException catch (e) {
      throw CalendarEventException(
        CalendarEventErrorCode.fromNativeCode(e.code),
        e.message,
      );
    }
  }

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
  }) async {
    try {
      await methodChannel.invokeMethod<void>('updateEvent', {
        'eventId': eventId,
        'title': title,
        'startDate': startDate?.millisecondsSinceEpoch,
        'endDate': endDate?.millisecondsSinceEpoch,
        'description': description,
        'location': location,
        'allDay': allDay,
        'url': url,
        'alertSeconds': alert?.inSeconds,
        'clearAlert': clearAlert,
      });
    } on PlatformException catch (e) {
      throw CalendarEventException(
        CalendarEventErrorCode.fromNativeCode(e.code),
        e.message,
      );
    }
  }

  @override
  Future<void> deleteEvent({required String eventId}) async {
    try {
      await methodChannel.invokeMethod<void>('deleteEvent', {
        'eventId': eventId,
      });
    } on PlatformException catch (e) {
      throw CalendarEventException(
        CalendarEventErrorCode.fromNativeCode(e.code),
        e.message,
      );
    }
  }
}
