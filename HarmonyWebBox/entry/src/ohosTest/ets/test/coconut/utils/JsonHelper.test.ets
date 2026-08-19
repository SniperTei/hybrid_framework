import { describe, it, expect } from '@ohos/hypium';
import { JsonObject, JsonParser } from '@coconut/sdk';

export default function jsonHelperTest() {
  describe('JsonHelper', () => {
    describe('JsonObject', () => {
      it('put_string_serializesAsString', 0, () => {
        const json = new JsonObject().put('name', 'foo').build();
        expect(json).assertEqual('{"name":"foo"}');
      });

      it('putNumber_serializesAsBareNumber', 0, () => {
        const json = new JsonObject().putNumber('count', 42).build();
        expect(json).assertEqual('{"count":42}');
      });

      it('putBool_serializesLowercase', 0, () => {
        expect(new JsonObject().putBool('a', true).build()).assertEqual('{"a":true}');
        expect(new JsonObject().putBool('b', false).build()).assertEqual('{"b":false}');
      });

      it('putNull_serializesNull', 0, () => {
        expect(new JsonObject().putNull('x').build()).assertEqual('{"x":null}');
      });

      it('putObject_nestsSubObject', 0, () => {
        const inner = new JsonObject().put('k', 'v');
        const json = new JsonObject().putObject('inner', inner).build();
        expect(json).assertEqual('{"inner":{"k":"v"}}');
      });

      it('putJson_embedsRawJsonString', 0, () => {
        const json = new JsonObject().putJson('result', '{"a":1}').build();
        expect(json).assertEqual('{"result":{"a":1}}');
      });

      it('putStringArray_serializesQuotedItems', 0, () => {
        const json = new JsonObject().putStringArray('list', ['a', 'b']).build();
        expect(json).assertEqual('{"list":["a","b"]}');
      });

      it('putObjectArray_serializesObjects', 0, () => {
        const a = new JsonObject().put('k', 'a');
        const b = new JsonObject().put('k', 'b');
        const json = new JsonObject().putObjectArray('items', [a, b]).build();
        expect(json).assertEqual('{"items":[{"k":"a"},{"k":"b"}]}');
      });

      it('multiplePuts_joinWithCommas', 0, () => {
        const json = new JsonObject()
          .put('a', '1')
          .putNumber('b', 2)
          .putBool('c', true)
          .build();
        expect(json).assertEqual('{"a":"1","b":2,"c":true}');
      });
    });

    describe('JsonParser', () => {
      it('getString_returnsValue', 0, () => {
        const json = '{"name":"alice"}';
        expect(JsonParser.getString(json, 'name')).assertEqual('alice');
      });

      it('getString_missingKey_returnsDefault', 0, () => {
        expect(JsonParser.getString('{"a":"b"}', 'missing', 'fallback')).assertEqual('fallback');
      });

      it('getNumber_returnsValue', 0, () => {
        expect(JsonParser.getNumber('{"n":123}', 'n')).assertEqual(123);
      });

      it('getNumber_missingKey_returnsDefault', 0, () => {
        expect(JsonParser.getNumber('{"a":1}', 'n', 9)).assertEqual(9);
      });

      it('getBool_returnsTrueFalse', 0, () => {
        expect(JsonParser.getBool('{"a":true}', 'a')).assertTrue();
        expect(JsonParser.getBool('{"a":false}', 'a')).assertFalse();
      });

      it('getBool_missingKey_returnsDefault', 0, () => {
        expect(JsonParser.getBool('{"a":1}', 'b', true)).assertTrue();
      });

      it('getObject_returnsSubObjectJson', 0, () => {
        const json = '{"outer":{"inner":1}}';
        expect(JsonParser.getObject(json, 'outer')).assertEqual('{"inner":1}');
      });

      it('getObject_missingKey_returnsEmptyBraces', 0, () => {
        expect(JsonParser.getObject('{"a":1}', 'b')).assertEqual('{}');
      });

      it('getKeys_compactJson', 0, () => {
        const keys = JsonParser.getKeys('{"url":"http://x","method":"GET","timeoutMs":500}');
        expect(keys.join(',')).assertEqual('url,method,timeoutMs');
      });

      it('getKeys_prettyPrintedJson_isWhitespaceTolerant', 0, () => {
        const pretty = '{\n  "a": "1",\n  "b": {\n    "c": "2"\n  }\n}';
        expect(JsonParser.getKeys(pretty).join(',')).assertEqual('a,b');
      });

      it('getKeys_onlyTopLevel_nestedKeysExcluded', 0, () => {
        const keys = JsonParser.getKeys('{"outer":{"inner1":1,"inner2":2},"top":3}');
        expect(keys.join(',')).assertEqual('outer,top');
      });

      it('getKeys_bracesInsideStringValues_doNotBreakDepth', 0, () => {
        const keys = JsonParser.getKeys('{"url":"http://x/{y}/z","ok":true}');
        expect(keys.join(',')).assertEqual('url,ok');
      });

      it('getKeys_colonInsideStringValue_isNotAKey', 0, () => {
        const keys = JsonParser.getKeys('{"note":"a: b","real":"c"}');
        expect(keys.join(',')).assertEqual('note,real');
      });

      it('getKeys_emptyObject_returnsEmpty', 0, () => {
        expect(JsonParser.getKeys('{}').length).assertEqual(0);
      });
    });
  });
}
