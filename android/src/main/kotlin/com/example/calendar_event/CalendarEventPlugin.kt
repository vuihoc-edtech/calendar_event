package com.example.calendar_event

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.TimeZone

/** CalendarEventPlugin */
class CalendarEventPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private companion object {
        const val CALENDAR_PERMISSION_REQUEST_CODE = 21438
        val CALENDAR_PERMISSIONS = arrayOf(
            Manifest.permission.READ_CALENDAR,
            Manifest.permission.WRITE_CALENDAR
        )
    }

    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    // requestPermission calls waiting for the system dialog.
    private val pendingPermissionResults = mutableListOf<Result>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "calendar_event")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "requestPermission" -> requestCalendarPermission(result)
            "addEvent" -> withCalendarPermission(result) { addEvent(call, result) }
            "updateEvent" -> withCalendarPermission(result) { updateEvent(call, result) }
            "deleteEvent" -> withCalendarPermission(result) { deleteEvent(call, result) }
            else -> result.notImplemented()
        }
    }

    /**
     * Runs [action] only when READ_CALENDAR and WRITE_CALENDAR are granted. Otherwise replies with
     * PERMISSION_DENIED. It does not ask the user; requestPermission does that.
     */
    private fun withCalendarPermission(result: Result, action: () -> Unit) {
        val ctx = context
        if (ctx == null) {
            result.error("NO_CONTEXT", "Plugin is not attached to an engine.", null)
            return
        }

        if (!hasCalendarPermissions(ctx)) {
            result.error("PERMISSION_DENIED", "Calendar access is not granted. Call requestPermission first.", null)
            return
        }

        action()
    }

    /**
     * Shows the system dialog for READ_CALENDAR and WRITE_CALENDAR when they are not granted yet,
     * and replies with whether they are granted once the user answers. Replies false immediately
     * when there is no Activity to show the dialog on.
     */
    private fun requestCalendarPermission(result: Result) {
        val ctx = context
        if (ctx == null) {
            result.error("NO_CONTEXT", "Plugin is not attached to an engine.", null)
            return
        }

        if (hasCalendarPermissions(ctx)) {
            result.success(true)
            return
        }

        val act = activity
        if (act == null) {
            result.success(false)
            return
        }

        val isFirstRequest = pendingPermissionResults.isEmpty()
        pendingPermissionResults.add(result)
        if (isFirstRequest) {
            act.requestPermissions(CALENDAR_PERMISSIONS, CALENDAR_PERMISSION_REQUEST_CODE)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != CALENDAR_PERMISSION_REQUEST_CODE) {
            return false
        }

        val pending = pendingPermissionResults.toList()
        pendingPermissionResults.clear()

        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        for (result in pending) {
            result.success(granted)
        }
        return true
    }

    private fun hasCalendarPermissions(ctx: Context): Boolean {
        return CALENDAR_PERMISSIONS.all {
            ctx.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun addEvent(call: MethodCall, result: Result) {
        val title = call.argument<String>("title")
        val startDate = call.argument<Number>("startDate")?.toLong()
        val endDate = call.argument<Number>("endDate")?.toLong()
        val description = call.argument<String>("description")
        val location = call.argument<String>("location")
        val allDay = call.argument<Boolean>("allDay") ?: false
        val url = call.argument<String>("url")
        val alertSeconds = call.argument<Number>("alertSeconds")?.toLong()

        if (title == null || startDate == null || endDate == null) {
            result.error("INVALID_ARGUMENT", "title, startDate and endDate are required.", null)
            return
        }

        val ctx = context
        if (ctx == null) {
            result.error("NO_CONTEXT", "Plugin is not attached to an engine.", null)
            return
        }

        insertWithProvider(
            ctx,
            title,
            startDate,
            endDate,
            description,
            location,
            allDay,
            url,
            alertSeconds,
            result
        )
    }

    /**
     * Saves the event directly with the Calendar Provider. Requires READ_CALENDAR and
     * WRITE_CALENDAR to be granted, and returns the saved event ID.
     *
     * The Calendar Provider has no URL field, so the URL is appended to the description.
     */
    private fun insertWithProvider(
        ctx: Context,
        title: String,
        startDate: Long,
        endDate: Long,
        description: String?,
        location: String?,
        allDay: Boolean,
        url: String?,
        alertSeconds: Long?,
        result: Result
    ) {
        val calendarId = try {
            findWritableCalendarId(ctx)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message, null)
            return
        }
        if (calendarId == null) {
            result.error("NO_CALENDAR", "No writable calendar found on this device.", null)
            return
        }

        val notes = listOfNotNull(description, url).takeIf { it.isNotEmpty() }?.joinToString("\n")

        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, notes)
            put(CalendarContract.Events.EVENT_LOCATION, location)
            put(CalendarContract.Events.DTSTART, startDate)
            put(CalendarContract.Events.DTEND, endDate)
            put(CalendarContract.Events.ALL_DAY, if (allDay) 1 else 0)
            put(CalendarContract.Events.HAS_ALARM, if (alertSeconds != null) 1 else 0)
            put(
                CalendarContract.Events.EVENT_TIMEZONE,
                if (allDay) "UTC" else TimeZone.getDefault().id
            )
        }

        try {
            val uri = ctx.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            if (uri == null) {
                result.error("INSERT_FAILED", "Failed to insert event.", null)
                return
            }

            if (alertSeconds != null) {
                insertReminder(ctx, ContentUris.parseId(uri), alertSeconds)
            }
            result.success(uri.lastPathSegment)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message, null)
        }
    }

    private fun updateEvent(call: MethodCall, result: Result) {
        val eventId = call.argument<String>("eventId")?.toLongOrNull()
        if (eventId == null) {
            result.error("INVALID_ARGUMENT", "eventId is required.", null)
            return
        }

        val ctx = context
        if (ctx == null) {
            result.error("NO_CONTEXT", "Plugin is not attached to an engine.", null)
            return
        }

        val title = call.argument<String>("title")
        val startDate = call.argument<Number>("startDate")?.toLong()
        val endDate = call.argument<Number>("endDate")?.toLong()
        val description = call.argument<String>("description")
        val location = call.argument<String>("location")
        val allDay = call.argument<Boolean>("allDay")
        val url = call.argument<String>("url")
        val alertSeconds = call.argument<Number>("alertSeconds")?.toLong()
        val clearAlert = call.argument<Boolean>("clearAlert") ?: false

        val values = ContentValues().apply {
            if (title != null) put(CalendarContract.Events.TITLE, title)
            if (description != null || url != null) {
                put(CalendarContract.Events.DESCRIPTION, listOfNotNull(description, url).joinToString("\n"))
            }
            if (location != null) put(CalendarContract.Events.EVENT_LOCATION, location)
            if (allDay != null) put(CalendarContract.Events.ALL_DAY, if (allDay) 1 else 0)
            if (startDate != null && endDate != null) {
                put(CalendarContract.Events.DTSTART, startDate)
                put(CalendarContract.Events.DTEND, endDate)
                put(
                    CalendarContract.Events.EVENT_TIMEZONE,
                    if (allDay == true) "UTC" else TimeZone.getDefault().id
                )
            }
            if (alertSeconds != null || clearAlert) {
                put(CalendarContract.Events.HAS_ALARM, if (alertSeconds != null) 1 else 0)
            }
        }

        try {
            val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
            val exists = ctx.contentResolver.query(
                uri,
                arrayOf(CalendarContract.Events._ID),
                null,
                null,
                null
            )?.use { it.moveToFirst() } ?: false
            if (!exists) {
                result.error("NOT_FOUND", "No event found with ID $eventId.", null)
                return
            }

            if (values.size() > 0) {
                ctx.contentResolver.update(uri, values, null, null)
            }

            if (alertSeconds != null || clearAlert) {
                ctx.contentResolver.delete(
                    CalendarContract.Reminders.CONTENT_URI,
                    "${CalendarContract.Reminders.EVENT_ID} = ?",
                    arrayOf(eventId.toString())
                )
                if (alertSeconds != null) {
                    insertReminder(ctx, eventId, alertSeconds)
                }
            }
            result.success(null)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message, null)
        }
    }

    private fun deleteEvent(call: MethodCall, result: Result) {
        val eventId = call.argument<String>("eventId")?.toLongOrNull()
        if (eventId == null) {
            result.error("INVALID_ARGUMENT", "eventId is required.", null)
            return
        }

        val ctx = context
        if (ctx == null) {
            result.error("NO_CONTEXT", "Plugin is not attached to an engine.", null)
            return
        }

        try {
            val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
            val deleted = ctx.contentResolver.delete(uri, null, null)
            if (deleted == 0) {
                result.error("NOT_FOUND", "No event found with ID $eventId.", null)
                return
            }
            result.success(null)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message, null)
        }
    }

    private fun insertReminder(ctx: Context, eventId: Long, alertSeconds: Long) {
        val values = ContentValues().apply {
            put(CalendarContract.Reminders.EVENT_ID, eventId)
            put(CalendarContract.Reminders.MINUTES, (alertSeconds / 60).toInt())
            put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
        }
        ctx.contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, values)
    }

    private fun findWritableCalendarId(ctx: Context): Long? {
        val projection = arrayOf(CalendarContract.Calendars._ID)
        val selection = "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
        val args = arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString())

        ctx.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            args,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getLong(0)
            }
        }
        return null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null

        val pending = pendingPermissionResults.toList()
        pendingPermissionResults.clear()
        for (result in pending) {
            result.success(false)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}
