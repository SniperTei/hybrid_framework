/**
 * Container navigation-bar configuration (v3.5.0 container-nav).
 *
 * All fields are nullable override slots: null = inherit from the next level
 * down in the three-tier chain
 *
 *   forward header (per-call) > template default > CoconutConfig.nav (global)
 *
 * merged field-by-field via [merge]. Resolved defaults come from [default]:
 * visible bar, AUTO title (syncs document.title), AUTO close policy
 * (× only when the WebView history is exhausted).
 *
 * JSON override shape (forward header):
 * `{"visible":false, "title":"订单详情"|"auto", "closePolicy":"always"|"auto",
 *   "leftButtonText":"取消", "rightButtonText":"分享"}`
 *
 * ArkTS port of Android coconut-core nav/NavConfig.kt — keep semantics aligned.
 */

export enum NavTitleMode {
  AUTO,
  FIXED
}

export enum NavClosePolicy {
  AUTO,
  ALWAYS
}

export class NavConfig {
  visible: boolean | null = null;
  titleMode: NavTitleMode | null = null;
  titleText: string | null = null;
  closePolicy: NavClosePolicy | null = null;
  leftButtonText: string | null = null;
  rightButtonText: string | null = null;

  /**
   * Whether the close (×) button should show at this history state.
   * ALWAYS shows unconditionally; AUTO (and unresolved null) only at the
   * stack root (canGoBack=false) so the user always has an exit.
   */
  shouldShowClose(canGoBack: boolean): boolean {
    if (this.closePolicy === NavClosePolicy.ALWAYS) {
      return true;
    }
    return !canGoBack;
  }

  copy(): NavConfig {
    const c = new NavConfig();
    c.visible = this.visible;
    c.titleMode = this.titleMode;
    c.titleText = this.titleText;
    c.closePolicy = this.closePolicy;
    c.leftButtonText = this.leftButtonText;
    c.rightButtonText = this.rightButtonText;
    return c;
  }

  /** Full default: visible bar, AUTO title, AUTO close policy. */
  static default(): NavConfig {
    const c = new NavConfig();
    c.visible = true;
    c.titleMode = NavTitleMode.AUTO;
    c.closePolicy = NavClosePolicy.AUTO;
    return c;
  }

  /** Field-by-field merge; null fields in [override] inherit from [base]. */
  static merge(base: NavConfig, override: NavConfig): NavConfig {
    const c = new NavConfig();
    c.visible = override.visible !== null ? override.visible : base.visible;
    c.titleMode = override.titleMode !== null ? override.titleMode : base.titleMode;
    c.titleText = override.titleText !== null ? override.titleText : base.titleText;
    c.closePolicy = override.closePolicy !== null ? override.closePolicy : base.closePolicy;
    c.leftButtonText = override.leftButtonText !== null ? override.leftButtonText : base.leftButtonText;
    c.rightButtonText = override.rightButtonText !== null ? override.rightButtonText : base.rightButtonText;
    return c;
  }

  /**
   * Parse a JSON override object. Returns null on malformed JSON —
   * callers treat that as "no override" rather than crashing the launch.
   * Field extraction is whitespace-tolerant (regex, not JsonParser's
   * compact-only matching).
   */
  static parseOverride(json: string): NavConfig | null {
    const trimmed = json.trim();
    if (trimmed.length === 0) {
      return null;
    }
    // Validity gate: whole-document parse (result unused — extraction below).
    try {
      JSON.parse(trimmed);
    } catch (e) {
      return null;
    }
    const c = new NavConfig();
    c.visible = NavConfig.readBool(trimmed, 'visible');

    const title = NavConfig.readString(trimmed, 'title');
    if (title !== null) {
      if (title.toLowerCase() === 'auto') {
        c.titleMode = NavTitleMode.AUTO;
      } else {
        c.titleMode = NavTitleMode.FIXED;
        c.titleText = title;
      }
    }

    const policy = NavConfig.readString(trimmed, 'closePolicy');
    if (policy !== null && policy.toLowerCase() === 'always') {
      c.closePolicy = NavClosePolicy.ALWAYS;
    }

    c.leftButtonText = NavConfig.readString(trimmed, 'leftButtonText');
    c.rightButtonText = NavConfig.readString(trimmed, 'rightButtonText');
    return c;
  }

  private static readBool(json: string, key: string): boolean | null {
    const m = json.match(new RegExp(`"${key}"\\s*:\\s*(true|false)`));
    if (m === null || m.length < 2) {
      return null;
    }
    return m[1] === 'true';
  }

  private static readString(json: string, key: string): string | null {
    const m = json.match(new RegExp(`"${key}"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"`));
    if (m === null || m.length < 2) {
      return null;
    }
    return m[1];
  }
}
