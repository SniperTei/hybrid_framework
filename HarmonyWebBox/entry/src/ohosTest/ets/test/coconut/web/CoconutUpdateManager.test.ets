import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium';
import { fileIo } from '@kit.CoreFileKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common } from '@kit.AbilityKit';
import { CoconutUpdateManager, RemoteManifest } from '@coconut/sdk';

/**
 * Hot-update tests: pure helpers (version compare, path guards, decideUpdate,
 * validateManifest, RemoteManifest.parse, md5Hex known vectors) plus sandbox
 * swap / version.json persistence using a temp dir under filesDir. The
 * network paths (checkUpdate/performUpdate over http) are covered by device
 * e2e with scripts/serve-hot-update.sh.
 */
export default function coconutUpdateManagerTest() {
  describe('CoconutUpdateManager', () => {
    let tmpRoot = '';

    const makeTempRoot = (): string => {
      const root = `${tmpRoot}/${Date.now()}-${Math.floor(Math.random() * 100000)}`;
      fileIo.mkdirSync(root, true);
      return root;
    };

    const writeTextFile = (path: string, content: string): void => {
      const parent = path.substring(0, path.lastIndexOf('/'));
      try {
        fileIo.mkdirSync(parent, true);
      } catch (e) {
        // mkdirSync throws "File exists" even with recursive=true (device pitfall)
      }
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, content);
      } finally {
        fileIo.closeSync(file);
      }
    };

    const readTextFile = (path: string): string => {
      const stat = fileIo.statSync(path);
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        const bytes = new Uint8Array(buf);
        let out = '';
        for (let i = 0; i < bytes.length; i++) {
          out += String.fromCharCode(bytes[i]);
        }
        return out;
      } finally {
        fileIo.closeSync(file);
      }
    };

    const fileExists = (path: string): boolean => {
      try {
        fileIo.statSync(path);
        return true;
      } catch (e) {
        return false;
      }
    };

    beforeAll(() => {
      const appContext: common.Context =
        abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      tmpRoot = `${appContext.filesDir}/coconut-update-tests`;
      fileIo.mkdirSync(tmpRoot, true);
    });

    afterEach(() => {
      try {
        fileIo.rmdirSync(tmpRoot);
      } catch (e) {
        // already gone
      }
    });

    // MARK: compareVersions

    it('compare_equalVersions', 0, () => {
      expect(CoconutUpdateManager.compareVersions('1.0.0', '1.0.0')).assertEqual(0);
    });

    it('compare_patchAndMajorOrdering', 0, () => {
      expect(CoconutUpdateManager.compareVersions('1.0.1', '1.0.0') > 0).assertTrue();
      expect(CoconutUpdateManager.compareVersions('0.9.9', '1.0.0') < 0).assertTrue();
      expect(CoconutUpdateManager.compareVersions('2.0.0', '1.99.99') > 0).assertTrue();
    });

    it('compare_missingSegmentsAndGarbage', 0, () => {
      expect(CoconutUpdateManager.compareVersions('1.2', '1.2.0')).assertEqual(0);
      expect(CoconutUpdateManager.compareVersions('x.y.z', '0.0.0')).assertEqual(0);
    });

    // MARK: isSafePackagePath

    it('paths_safePathsAccepted', 0, () => {
      expect(CoconutUpdateManager.isSafePackagePath('index.html')).assertTrue();
      expect(CoconutUpdateManager.isSafePackagePath('js/app.js')).assertTrue();
      expect(CoconutUpdateManager.isSafePackagePath('assets/fonts/v1/font.woff2')).assertTrue();
    });

    it('paths_unsafePathsRejected', 0, () => {
      expect(CoconutUpdateManager.isSafePackagePath('')).assertFalse();
      expect(CoconutUpdateManager.isSafePackagePath('/etc/passwd')).assertFalse();
      expect(CoconutUpdateManager.isSafePackagePath('../escape.js')).assertFalse();
      expect(CoconutUpdateManager.isSafePackagePath('a/../../escape.js')).assertFalse();
      expect(CoconutUpdateManager.isSafePackagePath('a\\b.js')).assertFalse();
      expect(CoconutUpdateManager.isSafePackagePath('a//b.js')).assertFalse();
      expect(CoconutUpdateManager.isSafePackagePath('.')).assertFalse();
    });

    // MARK: md5Hex

    it('md5_knownVectors', 0, () => {
      const hello = CoconutUpdateManager.md5Hex(stringToArrayBuffer('hello'));
      expect(hello).assertEqual('5d41402abc4b2a76b9719d911017c592');
      const empty = CoconutUpdateManager.md5Hex(new ArrayBuffer(0));
      expect(empty).assertEqual('d41d8cd98f00b204e9800998ecf8427e');
      // 'abc' — the RFC 1321 test vector
      const abc = CoconutUpdateManager.md5Hex(stringToArrayBuffer('abc'));
      expect(abc).assertEqual('900150983cd24fb0d6963f7d28e17f72');
    });

    // MARK: decideUpdate

    it('decide_truthTable', 0, () => {
      expect(CoconutUpdateManager.decideUpdate('1.0.0', '1.0.0', '1.0.1')).assertTrue();
      expect(CoconutUpdateManager.decideUpdate(null, '1.0.1', '1.0.1')).assertFalse();
      expect(CoconutUpdateManager.decideUpdate('1.2.0', '1.0.0', '1.1.0')).assertFalse();
      expect(CoconutUpdateManager.decideUpdate(null, null, '0.0.1')).assertTrue();
    });

    // MARK: validateManifest

    it('validate_ok', 0, () => {
      const manifest = new RemoteManifest();
      manifest.moduleId = 'demo';
      manifest.version = '1.0.1';
      manifest.files = ['index.html', 'js/app.js'];
      manifest.fileHashes.set('index.html', 'aa');
      manifest.fileHashes.set('js/app.js', 'bb');
      expect(CoconutUpdateManager.validateManifest(manifest)).assertNull();
    });

    it('validate_noFilesRejected', 0, () => {
      const manifest = new RemoteManifest();
      manifest.moduleId = 'demo';
      manifest.version = '1.0.1';
      expect(CoconutUpdateManager.validateManifest(manifest))
        .assertEqual('manifest has no files');
    });

    it('validate_missingHashFailClosed', 0, () => {
      const manifest = new RemoteManifest();
      manifest.moduleId = 'demo';
      manifest.version = '1.0.1';
      manifest.files = ['index.html'];
      expect(CoconutUpdateManager.validateManifest(manifest))
        .assertEqual('missing fileHashes entry: index.html');
    });

    it('validate_unsafePathRejected', 0, () => {
      const manifest = new RemoteManifest();
      manifest.moduleId = 'demo';
      manifest.version = '1.0.1';
      manifest.files = ['../evil.js'];
      manifest.fileHashes.set('../evil.js', 'aa');
      expect(CoconutUpdateManager.validateManifest(manifest))
        .assertEqual('unsafe package path: ../evil.js');
    });

    // MARK: RemoteManifest.parse

    it('parse_serverJson', 0, () => {
      const json = '{"moduleId":"demo","version":"1.0.1","entry":"index.html",'
        + '"files":["index.html","assets/index.js"],"md5":"pkg",'
        + '"fileHashes":{"index.html":"aa","assets/index.js":"bb"},"extraField":123}';
      const manifest = RemoteManifest.parse(json);
      expect(manifest !== null).assertTrue();
      if (manifest !== null) {
        expect(manifest.moduleId).assertEqual('demo');
        expect(manifest.version).assertEqual('1.0.1');
        expect(manifest.files.length).assertEqual(2);
        expect(manifest.files[1]).assertEqual('assets/index.js');
        expect(manifest.fileHashes.get('assets/index.js')).assertEqual('bb');
      }
    });

    it('parse_emptyOrGarbageReturnsNull', 0, () => {
      expect(RemoteManifest.parse('')).assertNull();
      expect(RemoteManifest.parse('   ')).assertNull();
      expect(RemoteManifest.parse('{"files":["a"]}')).assertNull(); // no moduleId/version
    });

    // MARK: parseStringPairs

    it('parseStringPairs_extractsPairs', 0, () => {
      const pairs = CoconutUpdateManager.parseStringPairs('{"demo":"1.0.1", "other":"2.0.0"}');
      expect(pairs.length).assertEqual(2);
      expect(pairs[0][0]).assertEqual('demo');
      expect(pairs[0][1]).assertEqual('1.0.1');
      expect(pairs[1][0]).assertEqual('other');
    });

    // MARK: swapDir / version.json (temp sandbox under filesDir)

    it('swap_stagingReplacesModuleDir', 0, () => {
      const root = makeTempRoot();
      // old module content
      writeTextFile(`${root}/demo/index.html`, 'OLD');
      // staging with new content incl. nested dir
      writeTextFile(`${root}/.staging_demo/index.html`, 'NEW');
      writeTextFile(`${root}/.staging_demo/js/app.js`, 'console.log(1)');

      CoconutUpdateManager.swapDir(root, 'demo');

      expect(readTextFile(`${root}/demo/index.html`)).assertEqual('NEW');
      expect(readTextFile(`${root}/demo/js/app.js`)).assertEqual('console.log(1)');
      expect(fileExists(`${root}/.staging_demo`)).assertFalse();
    });

    it('swap_worksWhenNoPreviousVersion', 0, () => {
      const root = makeTempRoot();
      writeTextFile(`${root}/.staging_demo/index.html`, 'FIRST');

      CoconutUpdateManager.swapDir(root, 'demo');

      expect(readTextFile(`${root}/demo/index.html`)).assertEqual('FIRST');
    });

    it('versionJson_readRoundTrip', 0, () => {
      const root = makeTempRoot();
      // no version.json yet → empty map
      expect(CoconutUpdateManager.readSandboxVersions(root).size).assertEqual(0);
      writeTextFile(`${root}/version.json`, '{"demo":"1.0.1","other":"2.0.0"}');
      const versions = CoconutUpdateManager.readSandboxVersions(root);
      expect(versions.size).assertEqual(2);
      expect(versions.get('demo')).assertEqual('1.0.1');
      expect(versions.get('other')).assertEqual('2.0.0');
    });

    it('versionJson_missingRootReturnsEmpty', 0, () => {
      const versions = CoconutUpdateManager.readSandboxVersions(`${tmpRoot}/no-such-root`);
      expect(versions.size).assertEqual(0);
    });
  });
}

function stringToArrayBuffer(text: string): ArrayBuffer {
  const buf = new ArrayBuffer(text.length);
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < text.length; i++) {
    bytes[i] = text.charCodeAt(i) & 0xFF;
  }
  return buf;
}
