# Coconut Core - ProGuard Rules

# Keep Kotlin serialization
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Keep kotlinx.serialization
-keep class kotlinx.serialization.json.** { *; }
-keep @kotlinx.serialization.Serializable class * { *; }

# Keep component interfaces and implementations
-keep interface com.sniper.coconut.component.** { *; }
-keep class * implements com.sniper.coconut.component.CoconutPlugin { *; }
-keep @com.sniper.coconut.component.ComponentMetadata class * { *; }

# Keep bridge classes
-keep class com.sniper.coconut.bridge.** { *; }

# Keep model classes
-keep class com.sniper.coconut.bridge.model.** { *; }
