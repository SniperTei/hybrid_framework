package com.sniper.androidwebbox

import com.sniper.coconut.nav.NavConfig
import com.sniper.coconut.web.CoconutWebActivity

/**
 * Template container demo (v3.5.0 container navigation).
 *
 * Registered in assets/coconut_templates.json as "demo" — forward({template:"demo"})
 * resolves this class via reflection and launches it instead of the standard
 * container. Code-level NavConfig default (second tier of the merge chain:
 * CoconutConfig.nav < defaultNavConfig < per-open header).
 *
 * NOTE: every template Activity must be declared in AndroidManifest.xml —
 * reflection resolves the class fine without it, launching crashes.
 */
class DemoTemplateActivity : CoconutWebActivity() {

    override val defaultNavConfig: NavConfig = NavConfig(
        titleMode = NavConfig.TitleMode.FIXED,
        titleText = "模板容器",
        rightButtonText = "模板按钮",
    )
}
