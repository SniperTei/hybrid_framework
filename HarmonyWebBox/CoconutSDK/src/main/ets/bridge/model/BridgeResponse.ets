import { ErrorCode } from './ErrorCode';
import { JsonObject } from '../../utils/JsonHelper';

/**
 * Bridge Response Model (Flattened)
 *
 * {
 *   "id": "request-id",
 *   "code": "000000",
 *   "message": "success",
 *   "result": { ... },
 *   "streaming": true   // optional; present = more responses coming, callback kept
 * }
 *
 * For streaming use cases (queue progress, downloads, etc.), native sends
 * multiple responses with the same id. Intermediate responses include
 * `"streaming": true`; the final response omits the field. coconut.js fires
 * the callback for each response but only releases it on the final one.
 */
export class BridgeResponse {
  id: string = '';
  code: string = ErrorCode.SUCCESS;
  message: string = 'success';
  result: string = '{}'; // JSON string
  streaming: boolean | undefined = undefined;

  get isSuccess(): boolean {
    return this.code === ErrorCode.SUCCESS;
  }

  get isError(): boolean {
    return this.code !== ErrorCode.SUCCESS;
  }

  static success(id: string, result: string): BridgeResponse {
    const resp = new BridgeResponse();
    resp.id = id;
    resp.code = ErrorCode.SUCCESS;
    resp.message = 'success';
    resp.result = result;
    return resp;
  }

  /**
   * Streaming response: coconut.js fires the callback but keeps it
   * registered for subsequent responses with the same id (and resets
   * the timeout timer). Send a final non-streaming response (omit
   * `streaming`) to release the callback.
   */
  static streaming(id: string, result: string): BridgeResponse {
    const resp = new BridgeResponse();
    resp.id = id;
    resp.code = ErrorCode.SUCCESS;
    resp.message = 'success';
    resp.result = result;
    resp.streaming = true;
    return resp;
  }

  static error(id: string, code: string, message: string): BridgeResponse {
    const resp = new BridgeResponse();
    resp.id = id;
    resp.code = code;
    resp.message = message;
    resp.result = '{}';
    return resp;
  }

  static parseError(id: string, message: string = 'Parse error'): BridgeResponse {
    return BridgeResponse.error(id, ErrorCode.PARSE_ERROR, message);
  }

  static invalidRequest(id: string, message: string = 'Invalid request'): BridgeResponse {
    return BridgeResponse.error(id, ErrorCode.INVALID_REQUEST, message);
  }

  static methodNotFound(id: string, method: string): BridgeResponse {
    return BridgeResponse.error(id, ErrorCode.METHOD_NOT_FOUND, `Method not found: ${method}`);
  }

  static invalidParams(id: string, message: string = 'Invalid params'): BridgeResponse {
    return BridgeResponse.error(id, ErrorCode.INVALID_PARAMS, message);
  }

  static internalError(id: string, message: string = 'Internal error'): BridgeResponse {
    return BridgeResponse.error(id, ErrorCode.INTERNAL_ERROR, message);
  }

  toJson(): string {
    const builder = new JsonObject();
    builder.put('id', this.id);
    builder.put('code', this.code);
    builder.put('message', this.message);
    builder.putJson('result', this.result);
    // Omit streaming when undefined so one-shot responses don't leak the field
    // (coconut.js keys strictly off streaming === true).
    if (this.streaming === true) {
      builder.putBool('streaming', true);
    }
    return builder.build();
  }
}
