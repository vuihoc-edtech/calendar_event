/// Error codes that can be returned by the calendar_event plugin.
enum CalendarEventErrorCode {
  /// The user has not granted calendar access.
  permissionDenied,

  /// The device has no calendar that the app can write to.
  noCalendar,

  /// The native calendar API failed to save the event.
  insertFailed,

  /// The arguments passed to the plugin are missing or invalid.
  invalidArgument,

  /// No event exists with the given event ID.
  eventNotFound,

  /// The native calendar API failed to update or delete the event.
  operationFailed,

  /// An error that does not match any of the codes above.
  unknown;

  /// Maps a native error code string to a [CalendarEventErrorCode].
  static CalendarEventErrorCode fromNativeCode(String? code) {
    switch (code) {
      case 'PERMISSION_DENIED':
        return CalendarEventErrorCode.permissionDenied;
      case 'NO_CALENDAR':
        return CalendarEventErrorCode.noCalendar;
      case 'INSERT_FAILED':
        return CalendarEventErrorCode.insertFailed;
      case 'INVALID_ARGUMENT':
        return CalendarEventErrorCode.invalidArgument;
      case 'NOT_FOUND':
        return CalendarEventErrorCode.eventNotFound;
      case 'OPERATION_FAILED':
        return CalendarEventErrorCode.operationFailed;
      default:
        return CalendarEventErrorCode.unknown;
    }
  }
}

/// Exception thrown by the calendar_event plugin when an operation fails.
class CalendarEventException implements Exception {
  const CalendarEventException(this.code, [this.message]);

  /// The category of the error.
  final CalendarEventErrorCode code;

  /// A human-readable description reported by the native platform, if any.
  final String? message;

  @override
  String toString() {
    final detail = message == null ? '' : ': $message';
    return 'CalendarEventException(${code.name})$detail';
  }
}
