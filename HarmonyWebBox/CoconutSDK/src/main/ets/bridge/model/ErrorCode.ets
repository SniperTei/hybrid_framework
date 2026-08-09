/**
 * Standard Error Codes (6-digit strings)
 *
 * | Range        | Category     |
 * |--------------|-------------|
 * | 000000       | Success     |
 * | 100001-100005| Standard errors |
 * | 200001-200009| Business errors |
 * | 300001-300004| Security errors |
 */
export class ErrorCode {
  static readonly SUCCESS: string = '000000';

  // Standard errors
  static readonly PARSE_ERROR: string = '100001';
  static readonly INVALID_REQUEST: string = '100002';
  static readonly METHOD_NOT_FOUND: string = '100003';
  static readonly INVALID_PARAMS: string = '100004';
  static readonly INTERNAL_ERROR: string = '100005';

  // Business errors
  static readonly UNKNOWN_COMPONENT: string = '200001';
  static readonly UNKNOWN_FUNCTION: string = '200002';
  static readonly PERMISSION_DENIED: string = '200003';
  static readonly TIMEOUT: string = '200004';
  static readonly CANCELLED: string = '200005';
  static readonly DOMAIN_NOT_ALLOWED: string = '200006';
  static readonly PARAM_VALIDATION_FAILED: string = '200007';
  static readonly COMPONENT_NOT_INITIALIZED: string = '200008';
  static readonly RATE_LIMIT_EXCEEDED: string = '200009';

  // Security errors
  static readonly BRIDGE_TOKEN_INVALID: string = '300004';

  static getDescription(code: string): string {
    if (code === '000000') return 'Success';
    if (code === '100001') return 'Parse error';
    if (code === '100002') return 'Invalid request';
    if (code === '100003') return 'Method not found';
    if (code === '100004') return 'Invalid params';
    if (code === '100005') return 'Internal error';
    if (code === '200001') return 'Unknown component';
    if (code === '200002') return 'Unknown function';
    if (code === '200003') return 'Permission denied';
    if (code === '200004') return 'Request timeout';
    if (code === '200005') return 'Request cancelled';
    if (code === '200006') return 'Domain not allowed';
    if (code === '200007') return 'Parameter validation failed';
    if (code === '200008') return 'Component not initialized';
    if (code === '200009') return 'Rate limit exceeded';
    if (code === '300004') return 'Bridge token invalid';
    return 'Unknown error';
  }
}
