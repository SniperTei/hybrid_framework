/**
 * Bridge Request Model
 *
 * Wire format (v3.1.0+):
 * {
 *   "component":   "storage",   // matches Component.name
 *   "function":    "setItem",   // method on that component
 *   "params":      { ... },
 *   "id":          "request-id",
 *   "bridgeToken": "..."
 * }
 *
 * component / function are separate top-level fields (no joined method).
 */

export class BridgeRequest {
  component: string = '';
  function: string = '';
  params: string = ''; // raw JSON string
  id: string = '';
  bridgeToken: string = '';

  private static readonly NAME_REGEX = /^[a-zA-Z][a-zA-Z0-9_]*$/;

  static isValidName(name: string): boolean {
    return BridgeRequest.NAME_REGEX.test(name);
  }

  /**
   * Joined "component.function" — convenience for logging / metrics /
   * rate-limiting where a single string is still useful as a key.
   */
  get method(): string {
    return `${this.component}.${this.function}`;
  }

  validate(): ValidationResult {
    if (!BridgeRequest.isValidName(this.component)) {
      const r = new ValidationResult();
      r.isValid = false;
      r.message = `Invalid component name: ${this.component}`;
      return r;
    }
    if (!BridgeRequest.isValidName(this.function)) {
      const r = new ValidationResult();
      r.isValid = false;
      r.message = `Invalid function name: ${this.function}`;
      return r;
    }
    if (!this.id || this.id.trim() === '') {
      const r = new ValidationResult();
      r.isValid = false;
      r.message = 'Request ID cannot be blank';
      return r;
    }
    const r = new ValidationResult();
    r.isValid = true;
    r.message = '';
    return r;
  }

  static fromJson(json: string): BridgeRequest {
    const req = new BridgeRequest();

    // Extract component
    const componentPattern = '"component":"';
    const componentStart = json.indexOf(componentPattern);
    if (componentStart !== -1) {
      const valStart = componentStart + componentPattern.length;
      const valEnd = json.indexOf('"', valStart);
      if (valEnd !== -1) {
        req.component = json.substring(valStart, valEnd);
      }
    }

    // Extract function
    const functionPattern = '"function":"';
    const functionStart = json.indexOf(functionPattern);
    if (functionStart !== -1) {
      const valStart = functionStart + functionPattern.length;
      const valEnd = json.indexOf('"', valStart);
      if (valEnd !== -1) {
        req.function = json.substring(valStart, valEnd);
      }
    }

    // Extract params as raw JSON object string
    const paramsPattern = '"params":';
    const paramsIdx = json.indexOf(paramsPattern);
    if (paramsIdx !== -1) {
      const afterColon = paramsIdx + paramsPattern.length;
      // Skip whitespace
      let i = afterColon;
      while (i < json.length && (json[i] === ' ' || json[i] === '\t' || json[i] === '\n' || json[i] === '\r')) {
        i++;
      }
      if (i < json.length && json[i] === '{') {
        // Find matching closing brace
        let depth = 0;
        let start = i;
        while (i < json.length) {
          if (json[i] === '{') {
            depth++;
          } else if (json[i] === '}') {
            depth--;
            if (depth === 0) {
              req.params = json.substring(start, i + 1);
              break;
            }
          }
          i++;
        }
      } else if (i < json.length && json[i] === 'n') {
        // null
        req.params = '';
      }
    }

    // Extract id
    const idPattern = '"id":"';
    const idStart = json.indexOf(idPattern);
    if (idStart !== -1) {
      const valStart = idStart + idPattern.length;
      const valEnd = json.indexOf('"', valStart);
      if (valEnd !== -1) {
        req.id = json.substring(valStart, valEnd);
      }
    }

    // Extract bridgeToken
    const tokenPattern = '"bridgeToken":"';
    const tokenStart = json.indexOf(tokenPattern);
    if (tokenStart !== -1) {
      const valStart = tokenStart + tokenPattern.length;
      const valEnd = json.indexOf('"', valStart);
      if (valEnd !== -1) {
        req.bridgeToken = json.substring(valStart, valEnd);
      }
    }

    return req;
  }
}

export class ValidationResult {
  isValid: boolean = false;
  message: string = '';
}
