import { describe, it, expect } from '@ohos/hypium';
import { CoconutOfflineResources } from '@coconut/sdk';

/**
 * Pure-helper tests for the coconut:// offline package (URL parsing,
 * translation, MIME table). File serving (sandbox/rawfile) needs a
 * real ability context and is covered by device e2e.
 */
export default function coconutOfflineResourcesTest() {
  describe('CoconutOfflineResources', () => {
    // MARK: parseOfflinePath

    it('parse_moduleIdAndPath', 0, () => {
      expect(CoconutOfflineResources.parseOfflinePath('coconut://demo/index.html'))
        .assertEqual('coconut-web/demo/index.html');
    });

    it('parse_nestedAssetPath', 0, () => {
      expect(CoconutOfflineResources.parseOfflinePath('coconut://demo/assets/index.js'))
        .assertEqual('coconut-web/demo/assets/index.js');
    });

    it('parse_emptyPathResolvesToEntry', 0, () => {
      expect(CoconutOfflineResources.parseOfflinePath('coconut://demo'))
        .assertEqual('coconut-web/demo/index.html');
    });

    it('parse_trailingSlashResolvesToEntry', 0, () => {
      expect(CoconutOfflineResources.parseOfflinePath('coconut://demo/'))
        .assertEqual('coconut-web/demo/index.html');
    });

    it('parse_stripsQuery', 0, () => {
      expect(CoconutOfflineResources.parseOfflinePath('coconut://demo/index.html?autorun=1'))
        .assertEqual('coconut-web/demo/index.html');
    });

    it('parse_rawfilePrefixAlsoMapped', 0, () => {
      expect(CoconutOfflineResources.parseOfflinePath('resource://rawfile/coconut-web/demo/coconut.js'))
        .assertEqual('coconut-web/demo/coconut.js');
    });

    it('parse_nonOfflineUrlsReturnNull', 0, () => {
      expect(CoconutOfflineResources.parseOfflinePath('https://demo/index.html')).assertNull();
      expect(CoconutOfflineResources.parseOfflinePath('resource://rawfile/coconut_index.html')).assertNull();
    });

    // MARK: translateUrl

    it('translate_coconutToRawfile', 0, () => {
      expect(CoconutOfflineResources.translateUrl('coconut://demo/index.html'))
        .assertEqual('resource://rawfile/coconut-web/demo/index.html');
    });

    it('translate_preservesQuery', 0, () => {
      expect(CoconutOfflineResources.translateUrl('coconut://demo/index.html?autorun=1'))
        .assertEqual('resource://rawfile/coconut-web/demo/index.html?autorun=1');
    });

    it('translate_nonCoconutPassesThrough', 0, () => {
      expect(CoconutOfflineResources.translateUrl('https://example.com/'))
        .assertEqual('https://example.com/');
    });

    // MARK: mimeType

    it('mimeTable_alignedWithOtherPlatforms', 0, () => {
      expect(CoconutOfflineResources.mimeType('index.html')).assertEqual('text/html');
      expect(CoconutOfflineResources.mimeType('assets/index.css')).assertEqual('text/css');
      expect(CoconutOfflineResources.mimeType('assets/index.js')).assertEqual('application/javascript');
      expect(CoconutOfflineResources.mimeType('manifest.json')).assertEqual('application/json');
      expect(CoconutOfflineResources.mimeType('favicon.svg')).assertEqual('image/svg+xml');
      expect(CoconutOfflineResources.mimeType('font.woff2')).assertEqual('font/woff2');
      expect(CoconutOfflineResources.mimeType('blob.bin')).assertEqual('application/octet-stream');
    });

    it('mime_matchingIsCaseInsensitive', 0, () => {
      expect(CoconutOfflineResources.mimeType('INDEX.HTML')).assertEqual('text/html');
    });
  });
}
