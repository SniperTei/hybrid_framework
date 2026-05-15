/**
 * Component Exception
 */
export class ComponentException extends Error {
  code: string;

  constructor(code: string = '200001', message: string) {
    super(message);
    this.code = code;
    this.name = 'ComponentException';
  }
}

/**
 * Component Not Found Exception
 */
export class ComponentNotFoundException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ComponentNotFoundException';
  }
}

/**
 * Component Not Initialized Exception
 */
export class ComponentNotInitializedException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ComponentNotInitializedException';
  }
}
