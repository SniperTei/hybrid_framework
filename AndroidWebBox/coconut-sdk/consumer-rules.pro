# Template container subclasses are instantiated via reflection
# (assets/coconut_templates.json → Class.forName). R8 would otherwise strip
# or rename them, breaking forward({template}).
-keep public class * extends com.sniper.coconut.web.CoconutWebActivity
