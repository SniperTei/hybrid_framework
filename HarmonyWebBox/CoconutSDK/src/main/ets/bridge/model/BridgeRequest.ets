/**
 * Bridge Request Model
 *
 * Bridge request with security extensions
 */

export class BridgeRequest {
  method: string = '';
  params: string = ''; // raw JSON string
  id: string = '';
  timestamp: number = 0;
  nonce: string = '';
  sign: string = '';
  bridgeToken: string = '';

  private static readonly METHOD_REGEX = /^[a-zA-Z][a-zA-Z0-9_]*\.[a-zA-Z][a-zA-Z0-9_]*$/;

  static isValidMethod(method: string): boolean {
    return BridgeRequest.METHOD_REGEX.test(method);
  }

  static extractComponent(method: string): string {
    return method.split('.')[0];
  }

  static extractFunction(method: string): string {
    return method.substring(method.indexOf('.') + 1);
  }

  get componentName(): string {
    return BridgeRequest.extractComponent(this.method);
  }

  get functionName(): string {
    return BridgeRequest.extractFunction(this.method);
  }

  validate(): ValidationResult {
    if (!BridgeRequest.isValidMethod(this.method)) {
      const r = new ValidationResult();
      r.isValid = false;
      r.message = `Invalid method format: ${this.method}`;
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

    // Extract method
    const methodPattern = '"method":"';
    const methodStart = json.indexOf(methodPattern);
    if (methodStart !== -1) {
      const valStart = methodStart + methodPattern.length;
      const valEnd = json.indexOf('"', valStart);
      if (valEnd !== -1) {
        req.method = json.substring(valStart, valEnd);
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

    // Extract timestamp
    const tsPattern = '"timestamp":';
    const tsIdx = json.indexOf(tsPattern);
    if (tsIdx !== -1) {
      const valStart = tsIdx + tsPattern.length;
      let valEnd = valStart;
      while (valEnd < json.length && json[valEnd] !== ',' && json[valEnd] !== '}') {
        valEnd++;
      }
      const numStr = json.substring(valStart, valEnd).trim();
      if (numStr.length > 0) {
        const parsed = parseInt(numStr);
        if (!isNaN(parsed)) {
          req.timestamp = parsed;
        }
      }
    }

    // Extract nonce
    const noncePattern = '"nonce":"';
    const nonceStart = json.indexOf(noncePattern);
    if (nonceStart !== -1) {
      const valStart = nonceStart + noncePattern.length;
      const valEnd = json.indexOf('"', valStart);
      if (valEnd !== -1) {
        req.nonce = json.substring(valStart, valEnd);
      }
    }

    // Extract sign
    const signPattern = '"sign":"';
    const signStart = json.indexOf(signPattern);
    if (signStart !== -1) {
      const valStart = signStart + signPattern.length;
      const valEnd = json.indexOf('"', valStart);
      if (valEnd !== -1) {
        req.sign = json.substring(valStart, valEnd);
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
