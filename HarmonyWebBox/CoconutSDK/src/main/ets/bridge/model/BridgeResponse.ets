import { ErrorCode } from './ErrorCode';
import { JsonObject } from '../../utils/JsonHelper';

/**
 * Bridge Response Model (Flattened)
 *
 * {
 *   "jsonrpc": "2.0",
 *   "id": "request-id",
 *   "code": "000000",
 *   "message": "success",
 *   "result": { ... }
 * }
 */
export class BridgeResponse {
  jsonrpc: string = '2.0';
  id: string = '';
  code: string = ErrorCode.SUCCESS;
  message: string = 'success';
  result: string = '{}'; // JSON string

  static readonly JSONRPC_VERSION = '2.0';

  get isSuccess(): boolean {
    return this.code === ErrorCode.SUCCESS;
  }

  get isError(): boolean {
    return this.code !== ErrorCode.SUCCESS;
  }

  static success(id: string, result: string): BridgeResponse {
    const resp = new BridgeResponse();
    resp.jsonrpc = BridgeResponse.JSONRPC_VERSION;
    resp.id = id;
    resp.code = ErrorCode.SUCCESS;
    resp.message = 'success';
    resp.result = result;
    return resp;
  }

  static error(id: string, code: string, message: string): BridgeResponse {
    const resp = new BridgeResponse();
    resp.jsonrpc = BridgeResponse.JSONRPC_VERSION;
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
    builder.put('jsonrpc', this.jsonrpc);
    builder.put('id', this.id);
    builder.put('code', this.code);
    builder.put('message', this.message);
    builder.putJson('result', this.result);
    return builder.build();
  }
}
