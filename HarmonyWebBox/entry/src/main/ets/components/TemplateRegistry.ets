import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';

/**
 * Template registry entry (resources/rawfile/coconut_templates.json).
 * templatePage = router page path on Harmony (e.g. "pages/DemoTemplatePage").
 */
export class TemplateEntry {
  templateName: string = '';
  templatePage: string = '';
}

/**
 * Template registry: logical template name → host custom container page.
 *
 * JSON file shape: `[{"templateName":"demo","templatePage":"pages/DemoTemplatePage"}]`
 *
 * ArkTS has no reflection — validation is SHALLOW by design (container-nav
 * design #17): name non-blank, page path non-empty, no duplicate names.
 * Whether the page actually embeds CoconutWebPage (and is registered in
 * main_pages.json) is a documented host contract; a missing main_pages
 * registration crashes at router.pushUrl time, caught by e2e scenario ⑩.
 *
 * Bad entries throw Error with entry context (fail-fast); the app preload
 * and NavigatorComponent both catch and surface via logs.
 */
export class TemplateRegistry {
  private static cache: Map<string, string> | null = null;
  private static readonly TEMPLATE_FILE: string = 'coconut_templates.json';

  /** Parse the JSON array text into entries (no validation). */
  static parse(jsonText: string): TemplateEntry[] {
    const entries: TemplateEntry[] = [];
    const trimmed = jsonText.trim();
    try {
      JSON.parse(trimmed);
    } catch (e) {
      throw new Error(`coconut_templates.json is not valid JSON: ${e}`);
    }
    const objects = trimmed.match(/\{[^{}]*\}/g);
    if (objects === null) {
      return entries;
    }
    for (const obj of objects) {
      const name = TemplateRegistry.readString(obj, 'templateName');
      const page = TemplateRegistry.readString(obj, 'templatePage');
      if (name !== null || page !== null) {
        const entry = new TemplateEntry();
        entry.templateName = name !== null ? name : '';
        entry.templatePage = page !== null ? page : '';
        entries.push(entry);
      }
    }
    return entries;
  }

  /**
   * Validate entries → name→page map. Throws on blank name, empty page
   * path, or duplicate name (with entry context).
   */
  static validate(entries: TemplateEntry[]): Map<string, string> {
    const map = new Map<string, string>();
    for (const entry of entries) {
      if (entry.templateName.trim().length === 0) {
        throw new Error(`template entry with blank templateName: ${entry.templatePage}`);
      }
      if (entry.templatePage.trim().length === 0) {
        throw new Error(`template '${entry.templateName}': empty templatePage`);
      }
      if (map.has(entry.templateName)) {
        throw new Error(`duplicate templateName: '${entry.templateName}'`);
      }
      map.set(entry.templateName, entry.templatePage);
    }
    return map;
  }

  /**
   * Load + validate from rawfile, cached after first success.
   * Returns an empty map (never throws) — callers decide how to surface.
   */
  static load(context: common.UIAbilityContext | null): Map<string, string> {
    if (TemplateRegistry.cache !== null) {
      return TemplateRegistry.cache as Map<string, string>;
    }
    if (context === null) {
      return new Map<string, string>();
    }
    try {
      const bytes = context.resourceManager.getRawFileContentSync(TemplateRegistry.TEMPLATE_FILE);
      const text = util.TextDecoder.create('utf-8').decodeToString(bytes);
      const map = TemplateRegistry.validate(TemplateRegistry.parse(text));
      TemplateRegistry.cache = map;
      return map;
    } catch (e) {
      console.error(`[TemplateRegistry] load failed: ${e}`);
      return new Map<string, string>();
    }
  }

  /** Drop the cache (tests / template file hot-swap). */
  static resetCache(): void {
    TemplateRegistry.cache = null;
  }

  private static readString(obj: string, key: string): string | null {
    const m = obj.match(new RegExp(`"${key}"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"`));
    if (m === null || m.length < 2) {
      return null;
    }
    return m[1];
  }
}
