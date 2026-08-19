/**
 * JsonObject - ArkTS-compliant JSON builder
 *
 * Avoids "untyped object literal" errors by building JSON strings
 * through a typed builder pattern.
 */
export class JsonObject {
  private fields: string[] = [];

  put(key: string, value: string): JsonObject {
    this.fields.push(`"${key}":${JSON.stringify(value)}`);
    return this;
  }

  putNumber(key: string, value: number): JsonObject {
    this.fields.push(`"${key}":${value}`);
    return this;
  }

  putBool(key: string, value: boolean): JsonObject {
    this.fields.push(`"${key}":${String(value)}`);
    return this;
  }

  putNull(key: string): JsonObject {
    this.fields.push(`"${key}":null`);
    return this;
  }

  putObject(key: string, obj: JsonObject): JsonObject {
    this.fields.push(`"${key}":${obj.build()}`);
    return this;
  }

  putJson(key: string, jsonStr: string): JsonObject {
    this.fields.push(`"${key}":${jsonStr}`);
    return this;
  }

  putStringArray(key: string, arr: string[]): JsonObject {
    const items: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      items.push(JSON.stringify(arr[i]));
    }
    this.fields.push(`"${key}":[${items.join(',')}]`);
    return this;
  }

  putObjectArray(key: string, arr: JsonObject[]): JsonObject {
    const items: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      items.push(arr[i].build());
    }
    this.fields.push(`"${key}":[${items.join(',')}]`);
    return this;
  }

  build(): string {
    return `{${this.fields.join(',')}}`;
  }
}

/**
 * JsonParser - Extract fields from JSON string
 *
 * Avoids JSON.parse() returning 'any' type.
 */
export class JsonParser {
  static getString(json: string, key: string, defaultValue: string = ''): string {
    const pattern = `"${key}":"`;
    const start = json.indexOf(pattern);
    if (start === -1) {
      return defaultValue;
    }
    const valueStart = start + pattern.length;
    const valueEnd = json.indexOf('"', valueStart);
    return valueEnd === -1 ? defaultValue : json.substring(valueStart, valueEnd);
  }

  static getNumber(json: string, key: string, defaultValue: number = 0): number {
    const pattern = `"${key}":`;
    const start = json.indexOf(pattern);
    if (start === -1) {
      return defaultValue;
    }
    const valueStart = start + pattern.length;
    let valueEnd = valueStart;
    while (valueEnd < json.length && json[valueEnd] !== ',' && json[valueEnd] !== '}') {
      valueEnd++;
    }
    const numStr = json.substring(valueStart, valueEnd).trim();
    if (numStr.length === 0) {
      return defaultValue;
    }
    const result = parseInt(numStr);
    return isNaN(result) ? defaultValue : result;
  }

  static getBool(json: string, key: string, defaultValue: boolean = false): boolean {
    const truePattern = `"${key}":true`;
    const falsePattern = `"${key}":false`;
    if (json.indexOf(truePattern) !== -1) {
      return true;
    }
    if (json.indexOf(falsePattern) !== -1) {
      return false;
    }
    return defaultValue;
  }

  /**
   * Extract a sub-object as raw JSON string
   */
  static getObject(json: string, key: string): string {
    const pattern = `"${key}":{`;
    const start = json.indexOf(pattern);
    if (start === -1) {
      return '{}';
    }
    let depth = 0;
    let i = start + pattern.length - 1;
    while (i < json.length) {
      if (json[i] === '{') {
        depth++;
      } else if (json[i] === '}') {
        depth--;
        if (depth === 0) {
          return json.substring(start + pattern.length - 1, i + 1);
        }
      }
      i++;
    }
    return '{}';
  }

  /**
   * List top-level keys of a JSON object string.
   *
   * Whitespace-tolerant char scan (avoids the compact-only `"key":` pitfall):
   * skips string contents entirely, so braces inside string values
   * (e.g. "url":"http://x/{y}") do not break depth tracking.
   * Only keys at depth 1 (direct children) are returned.
   */
  static getKeys(objJson: string): string[] {
    const keys: string[] = [];
    let depth = 0;
    let i = 0;
    while (i < objJson.length) {
      const ch = objJson[i];
      if (ch === '"' && depth >= 1) {
        // scan the whole string, then decide if it is a key (followed by ':')
        let j = i + 1;
        const startIdx = j;
        while (j < objJson.length && objJson[j] !== '"') {
          if (objJson[j] === '\\') {
            j++; // skip escaped char
          }
          j++;
        }
        let k = j + 1;
        while (k < objJson.length &&
          (objJson[k] === ' ' || objJson[k] === '\n' || objJson[k] === '\t' || objJson[k] === '\r')) {
          k++;
        }
        if (depth === 1 && objJson[k] === ':') {
          keys.push(objJson.substring(startIdx, j));
        }
        i = j + 1;
        continue;
      }
      if (ch === '{') {
        depth++;
      } else if (ch === '}') {
        depth--;
      }
      i++;
    }
    return keys;
  }
}
