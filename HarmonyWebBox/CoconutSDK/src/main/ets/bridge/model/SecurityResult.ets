/**
 * Security validation result
 */
export class SecurityResult {
  isValid: boolean = true;
  message: string = '';

  static Valid(): SecurityResult {
    const r = new SecurityResult();
    r.isValid = true;
    r.message = '';
    return r;
  }

  static Invalid(reason: string): SecurityResult {
    const r = new SecurityResult();
    r.isValid = false;
    r.message = reason;
    return r;
  }
}
