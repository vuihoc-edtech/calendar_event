import EventKit
import Flutter
import UIKit

public class CalendarEventPlugin: NSObject, FlutterPlugin {
  private let eventStore = EKEventStore()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "calendar_event", binaryMessenger: registrar.messenger())
    let instance = CalendarEventPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "requestPermission":
      requestPermission(result: result)
    case "addEvent":
      addEvent(call, result: result)
    case "updateEvent":
      updateEvent(call, result: result)
    case "deleteEvent":
      deleteEvent(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func addEvent(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let title = args["title"] as? String,
          let startMillis = args["startDate"] as? NSNumber,
          let endMillis = args["endDate"] as? NSNumber else {
      result(FlutterError(code: "INVALID_ARGUMENT",
                          message: "title, startDate and endDate are required.",
                          details: nil))
      return
    }

    guard hasWriteAccess() else {
      result(permissionDeniedError())
      return
    }

    let description = args["description"] as? String
    let location = args["location"] as? String
    let allDay = args["allDay"] as? Bool ?? false
    let url = args["url"] as? String
    let alertSeconds = args["alertSeconds"] as? NSNumber

    guard let calendar = self.eventStore.defaultCalendarForNewEvents else {
      result(FlutterError(code: "NO_CALENDAR",
                          message: "No default calendar found on this device.",
                          details: nil))
      return
    }

    let event = EKEvent(eventStore: self.eventStore)
    event.calendar = calendar
    event.title = title
    event.notes = description
    event.location = location
    event.isAllDay = allDay
    event.startDate = Date(timeIntervalSince1970: startMillis.doubleValue / 1000)
    event.endDate = Date(timeIntervalSince1970: endMillis.doubleValue / 1000)
    event.url = url.flatMap { URL(string: $0) }
    if let alertSeconds = alertSeconds {
      event.addAlarm(EKAlarm(relativeOffset: -alertSeconds.doubleValue))
    }

    do {
      try self.eventStore.save(event, span: .thisEvent)
      result(event.eventIdentifier)
    } catch {
      result(FlutterError(code: "INSERT_FAILED",
                          message: error.localizedDescription,
                          details: nil))
    }
  }

  private func updateEvent(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let eventId = args["eventId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT",
                          message: "eventId is required.",
                          details: nil))
      return
    }

    guard hasFullCalendarAccess() else {
      result(permissionDeniedError())
      return
    }

    let title = args["title"] as? String
    let startMillis = args["startDate"] as? NSNumber
    let endMillis = args["endDate"] as? NSNumber
    let description = args["description"] as? String
    let location = args["location"] as? String
    let allDay = args["allDay"] as? Bool
    let url = args["url"] as? String
    let alertSeconds = args["alertSeconds"] as? NSNumber
    let clearAlert = args["clearAlert"] as? Bool ?? false

    guard let event = self.eventStore.event(withIdentifier: eventId) else {
      result(FlutterError(code: "NOT_FOUND",
                          message: "No event found with ID \(eventId).",
                          details: nil))
      return
    }

    if let title = title { event.title = title }
    if let description = description { event.notes = description }
    if let location = location { event.location = location }
    if let allDay = allDay { event.isAllDay = allDay }
    if let url = url { event.url = URL(string: url) }
    if let startMillis = startMillis {
      event.startDate = Date(timeIntervalSince1970: startMillis.doubleValue / 1000)
    }
    if let endMillis = endMillis {
      event.endDate = Date(timeIntervalSince1970: endMillis.doubleValue / 1000)
    }
    if alertSeconds != nil || clearAlert {
      event.alarms?.forEach { event.removeAlarm($0) }
      if let alertSeconds = alertSeconds {
        event.addAlarm(EKAlarm(relativeOffset: -alertSeconds.doubleValue))
      }
    }

    do {
      try self.eventStore.save(event, span: .thisEvent)
      result(nil)
    } catch {
      result(FlutterError(code: "OPERATION_FAILED",
                          message: error.localizedDescription,
                          details: nil))
    }
  }

  private func deleteEvent(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let eventId = args["eventId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT",
                          message: "eventId is required.",
                          details: nil))
      return
    }

    guard hasFullCalendarAccess() else {
      result(permissionDeniedError())
      return
    }

    guard let event = self.eventStore.event(withIdentifier: eventId) else {
      result(FlutterError(code: "NOT_FOUND",
                          message: "No event found with ID \(eventId).",
                          details: nil))
      return
    }

    do {
      try self.eventStore.remove(event, span: .thisEvent)
      result(nil)
    } catch {
      result(FlutterError(code: "OPERATION_FAILED",
                          message: error.localizedDescription,
                          details: nil))
    }
  }

  private func permissionDeniedError() -> FlutterError {
    return FlutterError(code: "PERMISSION_DENIED",
                        message: "Calendar access is not granted. Call requestPermission first.",
                        details: nil)
  }

  private func hasFullCalendarAccess() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)

    if #available(iOS 17.0, *) {
      return status == .fullAccess
    }
    return status == .authorized
  }

  private func hasWriteAccess() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)

    if #available(iOS 17.0, *) {
      return status == .fullAccess || status == .writeOnly
    }
    return status == .authorized
  }

  private func requestPermission(result: @escaping FlutterResult) {
    let status = EKEventStore.authorizationStatus(for: .event)

    if #available(iOS 17.0, *) {
      switch status {
      case .fullAccess:
        result(true)
      case .notDetermined:
        eventStore.requestFullAccessToEvents { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      default:
        result(false)
      }
    } else {
      switch status {
      case .authorized:
        result(true)
      case .notDetermined:
        eventStore.requestAccess(to: .event) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      default:
        result(false)
      }
    }
  }
}
