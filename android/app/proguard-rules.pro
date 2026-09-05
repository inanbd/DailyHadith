# flutter_local_notifications stores scheduled notifications as Gson-serialised
# models so they can be restored after a device restart. R8 would otherwise
# strip the fields it needs, and reminders would quietly stop firing.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn com.dexterous.**
