// Type declarations for test-setup.js — MockEventSource used in SSE tests.

export declare class MockEventSource extends EventTarget {
  static instances: MockEventSource[];
  static CONNECTING: 0;
  static OPEN: 1;
  static CLOSED: 2;
  static reset(): void;

  url: string;
  readyState: 0 | 1 | 2;
  listeners: Record<string, EventListener[]>;

  constructor(url: string);
  emit(type: string, data: unknown, lastEventId?: string): void;
  close(): void;
}
