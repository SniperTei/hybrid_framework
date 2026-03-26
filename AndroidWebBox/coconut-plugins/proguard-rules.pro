# Coconut Plugins - ProGuard Rules

# Keep all component implementations
-keep class com.sniper.coconut.components.** { *; }
-keep @com.sniper.coconut.component.ComponentMetadata class * { *; }

# Keep component base classes
-keep class * extends com.sniper.coconut.component.BaseComponent { *; }
