import 'calendar_event_exception.dart';
import 'calendar_event_platform_interface.dart';

export 'calendar_event_exception.dart';

class CalendarEvent {
  Future<String?> getPlatformVersion() {
    return CalendarEventPlatform.instance.getPlatformVersion();
  }

  /// Requests full calendar access from the user and returns whether it was granted.
  ///
  /// Call this before [addEvent], [updateEvent] or [deleteEvent]. Those methods
  /// do not request access; they throw a [CalendarEventException] with code
  /// `permissionDenied` if access has not been granted.
  ///
  /// Returns `true` when access is granted and `false` when the user denies it.
  static Future<bool> requestPermission() {
    return CalendarEventPlatform.instance.requestPermission();
  }

  /// Adds an event to the device calendar and returns its platform event ID.
  ///
  /// Throws a [CalendarEventException] with code `permissionDenied` if calendar
  /// access has not been granted. Call [requestPermission] first.
  ///
  /// If [endDate] is omitted, the event lasts 1 hour, or 1 day when [allDay]
  /// is `true`.
  ///
  /// Platform support:
  /// * [title], [startDate], [endDate]: Android, iOS.
  /// * [description] (Notes): Android, iOS.
  /// * [location]: Android, iOS.
  /// * [allDay]: Android, iOS.
  /// * [url]: Android, iOS. On Android the URL is appended to the description,
  ///   because the Calendar Provider has no URL field.
  /// * [alert]: Android, iOS. On Android the reminder is stored in whole
  ///   minutes, so seconds are dropped.
  ///
  /// Throws a [CalendarEventException] if the event could not be added.
  static Future<String?> addEvent({
    required String title,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    String? location,
    bool allDay = false,
    String? url,
    Duration? alert,
  }) async {
    final end =
        endDate ??
        (allDay
            ? startDate.add(const Duration(days: 1))
            : startDate.add(const Duration(hours: 1)));

    if (!end.isAfter(startDate)) {
      throw const CalendarEventException(
        CalendarEventErrorCode.invalidArgument,
        'endDate must be after startDate.',
      );
    }

    return CalendarEventPlatform.instance.addEvent(
      title: title,
      startDate: startDate,
      endDate: end,
      description: description,
      location: location,
      allDay: allDay,
      url: url,
      alert: alert,
    );
  }

  /// Updates the event with the given [eventId], as returned by [addEvent].
  ///
  /// Throws a [CalendarEventException] with code `permissionDenied` if calendar
  /// access has not been granted. Call [requestPermission] first.
  ///
  /// Only the parameters you pass are changed. A `null` parameter leaves that
  /// field unchanged. Pass an empty string to clear [description] or [location].
  /// Use [clearAlert] to remove the reminder.
  ///
  /// [startDate] and [endDate] must be passed together.
  ///
  /// On Android, passing [description] or [url] replaces the notes with both
  /// values, so pass both if you want to keep the URL.
  ///
  /// Throws a [CalendarEventException] with code `eventNotFound` if no event
  /// has this ID, or `invalidArgument` if the arguments are inconsistent.
  static Future<void> updateEvent({
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
    if ((startDate == null) != (endDate == null)) {
      throw const CalendarEventException(
        CalendarEventErrorCode.invalidArgument,
        'startDate and endDate must be updated together.',
      );
    }

    if (startDate != null && !endDate!.isAfter(startDate)) {
      throw const CalendarEventException(
        CalendarEventErrorCode.invalidArgument,
        'endDate must be after startDate.',
      );
    }

    if (alert != null && clearAlert) {
      throw const CalendarEventException(
        CalendarEventErrorCode.invalidArgument,
        'alert and clearAlert cannot be used together.',
      );
    }

    return CalendarEventPlatform.instance.updateEvent(
      eventId: eventId,
      title: title,
      startDate: startDate,
      endDate: endDate,
      description: description,
      location: location,
      allDay: allDay,
      url: url,
      alert: alert,
      clearAlert: clearAlert,
    );
  }

  /// Deletes the event with the given [eventId], as returned by [addEvent].
  ///
  /// Throws a [CalendarEventException] with code `permissionDenied` if calendar
  /// access has not been granted. Call [requestPermission] first.
  ///
  /// Throws a [CalendarEventException] with code `eventNotFound` if no event
  /// has this ID.
  static Future<void> deleteEvent({required String eventId}) {
    return CalendarEventPlatform.instance.deleteEvent(eventId: eventId);
  }
}
