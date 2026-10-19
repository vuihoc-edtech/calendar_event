import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'calendar_event_method_channel.dart';

abstract class CalendarEventPlatform extends PlatformInterface {
  /// Constructs a CalendarEventPlatform.
  CalendarEventPlatform() : super(token: _token);

  static final Object _token = Object();

  static CalendarEventPlatform _instance = MethodChannelCalendarEvent();

  /// The default instance of [CalendarEventPlatform] to use.
  ///
  /// Defaults to [MethodChannelCalendarEvent].
  static CalendarEventPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [CalendarEventPlatform] when
  /// they register themselves.
  static set instance(CalendarEventPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Requests calendar access and resolves to `true` when it is granted.
  ///
  /// Resolves to `false` when the user denies the request.
  Future<bool> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  Future<String?> addEvent({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? location,
    bool allDay = false,
    String? url,
    Duration? alert,
  }) {
    throw UnimplementedError('addEvent() has not been implemented.');
  }

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
  }) {
    throw UnimplementedError('updateEvent() has not been implemented.');
  }

  Future<void> deleteEvent({required String eventId}) {
    throw UnimplementedError('deleteEvent() has not been implemented.');
  }
}
