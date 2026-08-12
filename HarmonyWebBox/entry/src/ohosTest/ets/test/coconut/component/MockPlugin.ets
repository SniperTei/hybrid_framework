import { CoconutPlugin } from '@coconut/sdk';

/**
 * In-process CoconutPlugin stub for unit tests. Tracks lifecycle calls and
 * supports configurable handle results / thrown errors.
 *
 * Mirrors iOSWebBox MockPlugin.swift and Android MockPlugin.kt.
 */
export class MockPlugin implements CoconutPlugin {
  name: string;
  version: string = '1.0.0';
  description: string = 'mock';
  methods: string[] = [];
  dependencies: string[] = [];

  private _isInitialized: boolean = false;

  initCallCount: number = 0;
  cleanupCallCount: number = 0;
  lastHandledFunction: string = '';
  lastHandledParams: string = '';
  handleResult: string = '{"ok":true}';

  /** When non-null, init() throws this Error. */
  throwOnInit: Error | null = null;
  /** When non-null, handle() throws this Error. */
  throwOnHandle: Error | null = null;

  constructor(name: string, dependencies: string[] = []) {
    this.name = name;
    this.dependencies = dependencies;
  }

  get isInitialized(): boolean {
    return this._isInitialized;
  }

  async init(context: Object): Promise<void> {
    this.initCallCount++;
    if (this.throwOnInit !== null) {
      throw this.throwOnInit;
    }
    this._isInitialized = true;
  }

  async handle(functionName: string, paramsJson: string): Promise<string> {
    this.lastHandledFunction = functionName;
    this.lastHandledParams = paramsJson;
    if (this.throwOnHandle !== null) {
      throw this.throwOnHandle;
    }
    return this.handleResult;
  }

  async cleanup(): Promise<void> {
    this.cleanupCallCount++;
    this._isInitialized = false;
  }
}
