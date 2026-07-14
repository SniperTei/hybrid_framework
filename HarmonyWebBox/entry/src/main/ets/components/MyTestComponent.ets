import { BaseComponent, JsonObject } from '@coconut/sdk';

/**
 * MyTest Component
 *
 * A minimal scaffold component for development/debugging.
 * Useful for verifying that the Bridge → Component routing works end-to-end,
 * and as a copy-paste starting point when adding a new real component.
 *
 * Functions:
 *   - ping: {} -> { pong: true, timestamp }
 *   - echo: { message } -> { message }
 *   - add:  { a, b } -> { sum }
 */
export class MyTestComponent extends BaseComponent {
  name: string = 'mytest';
  version: string = '1.0.0';
  description: string = 'Test scaffold component for development';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'ping':
        return this.ping();
      case 'echo':
        return this.echo(paramsJson);
      case 'add':
        return this.add(paramsJson);
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private ping(): string {
    const builder = new JsonObject();
    builder.putBool('pong', true);
    builder.putNumber('timestamp', Date.now());
    return this.success(builder);
  }

  private echo(paramsJson: string): string {
    const message = this.getParam(paramsJson, 'message');
    if (!message) {
      return this.error('200007', `Parameter 'message' is required`);
    }
    const builder = new JsonObject();
    builder.put('message', message);
    return this.success(builder);
  }

  private add(paramsJson: string): string {
    const a = this.getIntParam(paramsJson, 'a', 0);
    const b = this.getIntParam(paramsJson, 'b', 0);
    const builder = new JsonObject();
    builder.putNumber('sum', a + b);
    return this.success(builder);
  }
}
