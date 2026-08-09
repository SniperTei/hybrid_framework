import { BaseComponent, ComponentContext, JsonObject } from '@coconut/sdk';

/**
 * Self-test topic emitted by the demo `echo` method.
 */
export const EVENT_TOPIC_TEST_ECHO: string = 'test.echo';

/**
 * Event Component
 *
 * Exposes subscribe/unsubscribe to H5 (delegating to the shared EventEmitter)
 * and a self-test `echo` method that emits a `test.echo` event after 500ms.
 *
 * Lifecycle: subscribes/unsubscribes simply mutate the shared registry;
 * emit fires through the jsExecutor wired by CoconutWebPage.
 */
export class EventComponent extends BaseComponent {
  name: string = 'event';
  version: string = '1.0.0';
  description: string = 'Event subscription component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'subscribe':
        return this.subscribe(paramsJson);
      case 'unsubscribe':
        return this.unsubscribe(paramsJson);
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
   * Register a subscription. Both topic and subscriptionId are H5-supplied
   * (subscriptionId generated client-side to avoid the async-window race).
   */
  private subscribe(paramsJson: string): string {
    const topic = this.getParam(paramsJson, 'topic');
    const subscriptionId = this.getParam(paramsJson, 'subscriptionId');
    if (topic.length === 0 || subscriptionId.length === 0) {
      return this.error('200007', 'topic and subscriptionId are required');
    }
    const ctx = this.getCtx();
    if (ctx === null) {
      return this.error('200008', 'Component not initialized');
    }
    ctx.eventEmitter.subscribe(topic, subscriptionId);

    const builder = new JsonObject();
    builder.put('subscriptionId', subscriptionId);
    builder.put('topic', topic);
    return this.success(builder);
  }

  private unsubscribe(paramsJson: string): string {
    const subscriptionId = this.getParam(paramsJson, 'subscriptionId');
    if (subscriptionId.length === 0) {
      return this.error('200007', 'subscriptionId is required');
    }
    const ctx = this.getCtx();
    if (ctx === null) {
      return this.error('200008', 'Component not initialized');
    }
    ctx.eventEmitter.unsubscribe(subscriptionId);

    const builder = new JsonObject();
    builder.put('subscriptionId', subscriptionId);
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
