# calendar_event

A new Flutter plugin project.

## Usage

```dart
final eventId = await CalendarEvent.addEvent(
  title: 'Meeting',
  startDate: DateTime(2026, 10, 10, 9),
  endDate: DateTime(2026, 10, 10, 10), // Optional: defaults to 1 hour later (1 day if allDay)
  description: 'Weekly sync',
  location: 'Room 1',
  allDay: false,
);
```

Returns the platform event ID on iOS and Android. `addEvent`, `updateEvent` and
`deleteEvent` request full calendar access natively when it has not been granted yet. If the user denies it, a
`CalendarEventException` with code `permissionDenied` is thrown. Failures throw a `CalendarEventException`:

```dart
try {
  await CalendarEvent.addEvent(/* ... */);
} on CalendarEventException catch (e) {
  switch (e.code) {
    case CalendarEventErrorCode.permissionDenied:
      // Ask the user for calendar permission
    case CalendarEventErrorCode.noCalendar:
      // No writable calendar on this device
    case CalendarEventErrorCode.insertFailed:
      // Saving failed, e.message has details
    case CalendarEventErrorCode.invalidArgument:
      // Check the arguments
    case CalendarEventErrorCode.unknown:
      // Other error
  }
}
```

| Code | Meaning |
|------|---------|
| `permissionDenied` | Calendar access is not granted |
| `noCalendar` | No writable calendar on the device (iOS), or no calendar app (Android) |
| `insertFailed` | The native calendar API failed to save the event |
| `invalidArgument` | Missing or invalid arguments |
| `eventNotFound` | No event exists with the given event ID |
| `operationFailed` | The native calendar API failed to update or delete the event |
| `unknown` | Any other error |

### Updating and deleting events

```dart
await CalendarEvent.updateEvent(
  eventId: eventId, // The ID returned by addEvent
  title: 'Meeting (moved)',
  startDate: DateTime(2026, 10, 11, 9),
  endDate: DateTime(2026, 10, 11, 10), // startDate and endDate must be passed together
  alert: const Duration(minutes: 30), // Or clearAlert: true to remove the reminder
);

await CalendarEvent.deleteEvent(eventId: eventId);
```

Only the parameters you pass are changed. Pass an empty string to clear `description` or `location`.
On Android, passing `description` or `url` replaces the notes with both values, so pass both to keep the URL.

### Permissions

Call `CalendarEvent.requestPermission()` to ask the user for full calendar access. It returns
`true` if access is granted and `false` if the user denies it.

```dart
if (await CalendarEvent.requestPermission()) {
  await CalendarEvent.addEvent(/* ... */);
}
```

`addEvent`, `updateEvent` and `deleteEvent` do not ask for permission. They throw a
`CalendarEventException` with code `permissionDenied` if access has not been granted.

Declare the permissions below so the system dialog can appear.

* **Android**: the plugin does not declare any permission, so add these to your app's `android/app/src/main/AndroidManifest.xml`:

  ```xml
  <uses-permission android:name="android.permission.READ_CALENDAR" />
  <uses-permission android:name="android.permission.WRITE_CALENDAR" />
  ```

* **iOS**: add these keys to your app's `Info.plist`. The plugin requests full calendar access
  on the first call, and the system shows the prompt then.
  * `NSCalendarsFullAccessUsageDescription`: used on iOS 17 and later.
  * `NSCalendarsUsageDescription`: used on iOS 15 and 16.

  On iOS 17 and later, `addEvent` works with write-only access. `updateEvent` and `deleteEvent`
  need full access. If the user has granted only write-only access, the user must allow full
  access in Settings to update or delete events.

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Thêm, sửa và xóa sự kiện trong lịch của bạn.</string>
<key>NSCalendarsUsageDescription</key>
<string>Thêm, sửa và xóa sự kiện trong lịch của bạn.</string>
```

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

