# Coconut SDK - ProGuard Rules

# Keep all SDK public APIs
-keep public class com.sniper.coconut.** { public *; }

# Keep CoconutSDK main entry
-keep object com.sniper.coconut.CoconutSDK { *; }

# Keep configuration classes
-keep class com.sniper.coconut.config.** { *; }

# Keep resource manager
-keep class com.sniper.coconut.resource.** { *; }

# Keep WebView helper
-keep class com.sniper.coconut.web.** { *; }
