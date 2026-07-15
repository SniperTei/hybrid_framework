import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { ComponentManager } from '@coconut/sdk';
import { ComponentException } from '@coconut/sdk';
import { MockPlugin } from './MockPlugin';

/**
 * Behavior note: sharedContext is left null (ComponentContext needs a real
 * UIAbilityContext), so register() does NOT call plugin.init(). These tests
 * exercise the registry mechanics only — duplicate detection, dependency
 * resolution, unregister / cleanup propagation.
 */
export default function componentManagerTest() {
  describe('ComponentManager', () => {
    const manager: ComponentManager = ComponentManager.getInstance();

    beforeAll(async () => {
      await manager.cleanup();
    });

    afterAll(async () => {
      await manager.cleanup();
    });

    it('register_andLookup_succeeds', 0, async () => {
      const plugin = new MockPlugin('device-a');
      await manager.register(plugin);
      expect(manager.hasComponent('device-a')).assertTrue();
      expect(manager.getComponent('device-a') !== undefined).assertTrue();
      expect(manager.getRegisteredComponents().indexOf('device-a') >= 0).assertTrue();
      await manager.unregister('device-a');
    });

    it('getComponent_unknownReturnsUndefined', 0, () => {
      expect(manager.getComponent('does-not-exist')).assertUndefined();
      expect(manager.hasComponent('nope')).assertFalse();
    });

    it('register_duplicateThrows', 0, async () => {
      const first = new MockPlugin('dup-comp');
      const second = new MockPlugin('dup-comp');
      await manager.register(first);
      let threw = false;
      try {
        await manager.register(second);
      } catch (e) {
        threw = e instanceof ComponentException;
      }
      expect(threw).assertTrue();
      // First instance is still registered.
      expect(manager.hasComponent('dup-comp')).assertTrue();
      await manager.unregister('dup-comp');
    });

    it('register_withMissingDependency_throws', 0, async () => {
      const b = new MockPlugin('dep-b', ['dep-a-missing']);
      let threw = false;
      try {
        await manager.register(b);
      } catch (e) {
        threw = e instanceof ComponentException;
      }
      expect(threw).assertTrue();
      expect(manager.hasComponent('dep-b')).assertFalse();
    });

    it('register_withSatisfiedDependency_succeeds', 0, async () => {
      const a = new MockPlugin('parent-a');
      const b = new MockPlugin('child-b', ['parent-a']);
      await manager.register(a);
      await manager.register(b);
      expect(manager.hasComponent('parent-a')).assertTrue();
      expect(manager.hasComponent('child-b')).assertTrue();
      await manager.unregister('parent-a');
      await manager.unregister('child-b');
    });

    it('unregister_callsCleanupAndRemoves', 0, async () => {
      const plugin = new MockPlugin('removable-comp');
      await manager.register(plugin);
      await manager.unregister('removable-comp');
      expect(manager.hasComponent('removable-comp')).assertFalse();
      expect(plugin.cleanupCallCount).assertEqual(1);
    });

    it('unregister_unknown_isNoop', 0, async () => {
      await manager.unregister('never-existed');
      // No throw, no state change — assert passes if we reach here.
      expect(true).assertTrue();
    });

    it('cleanup_callsCleanupOnAllAndClears', 0, async () => {
      const p1 = new MockPlugin('clean-1');
      const p2 = new MockPlugin('clean-2');
      await manager.register(p1);
      await manager.register(p2);
      await manager.cleanup();
      expect(p1.cleanupCallCount).assertEqual(1);
      expect(p2.cleanupCallCount).assertEqual(1);
      expect(manager.getRegisteredComponents().length).assertEqual(0);
    });

    it('getComponentInfo_returnsJson', 0, async () => {
      const plugin = new MockPlugin('info-target');
      plugin.version = '2.5.0';
      plugin.description = 'desc';
      await manager.register(plugin);
      const info = manager.getComponentInfo('info-target');
      expect(info).assertContain('"name":"info-target"');
      expect(info).assertContain('"version":"2.5.0"');
      expect(info).assertContain('"description":"desc"');
      await manager.unregister('info-target');
    });
  });
}
