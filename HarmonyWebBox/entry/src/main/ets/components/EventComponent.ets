import { BaseComponent, ComponentContext, JsonObject } from '@coconut/sdk';

/**
 * Self-test topic emitted by the demo `echo` method.
 */
export const EVENT_TOPIC_TEST_ECHO: string = 'test.echo';

/**
 * Event Component
 *
 * Exposes on/off to H5 (delegating to the shared EventEmitter) and a
 * self-test `echo` method that emits a `test.echo` event after 500ms.
 *
 * Lifecycle: on/off simply mutate the shared registry; emit fires through
 * the jsExecutor wired by CoconutWebPage.
 */
export class EventComponent extends BaseComponent {
  name: string = 'event';
  version: string = '1.0.0';
  description: string = 'Event subscription component';
  methods: string[] = ['on', 'off', 'echo'];

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'on':
        return this.onHandler(paramsJson);
      case 'off':
        return this.offHandler(paramsJson);
      case 'echo':
        return this.echo(paramsJson);
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private getCtx(): ComponentContext | null {
    return this.getComponentContext();
  }

  /**
   * Register a handler for `topic`. One handler per topic; second on overwrites.
   */
  private onHandler(paramsJson: string): string {
    const topic = this.getParam(paramsJson, 'topic');
    if (topic.length === 0) {
      return this.error('200007', 'topic is required');
    }
    const ctx = this.getCtx();
    if (ctx === null) {
      return this.error('200008', 'Component not initialized');
    }
    ctx.eventEmitter.on(topic);

    const builder = new JsonObject();
    builder.put('topic', topic);
    return this.success(builder);
  }

  private offHandler(paramsJson: string): string {
    const topic = this.getParam(paramsJson, 'topic');
    if (topic.length === 0) {
      return this.error('200007', 'topic is required');
    }
    const ctx = this.getCtx();
    if (ctx === null) {
      return this.error('200008', 'Component not initialized');
    }
    ctx.eventEmitter.off(topic);

    const builder = new JsonObject();
    builder.put('topic', topic);
    builder.putBool('success', true);
    return this.success(builder);
  }

  /**
   * Demo: emit `test.echo` with the supplied payload after 500ms.
   */
  private echo(paramsJson: string): string {
    const ctx = this.getCtx();
    if (ctx === null) {
      return this.error('200008', 'Component not initialized');
    }
    // Forward the raw paramsJson as the event data payload.
    const payloadJson = paramsJson.length > 0 ? paramsJson : '{}';
    setTimeout(() => {
      ctx.eventEmitter.emit(EVENT_TOPIC_TEST_ECHO, payloadJson);
    }, 500);

    const builder = new JsonObject();
    builder.putBool('scheduled', true);
    builder.put('topic', EVENT_TOPIC_TEST_ECHO);
    return this.success(builder);
  }
}
