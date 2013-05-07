// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'package:safe_dom/parser.dart' as parser;
import 'package:safe_dom/validators.dart';
import 'package:safe_dom/src/caja_validator.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';

import 'utils.dart';


var nullSanitizer = new NullTreeSanitizer();
void validateHtml(String html, String reference, NodeValidator validator) {
  var a = parser.createFragment(document.body, html, validator: validator);
  var b = parser.createFragment(document.body, reference, treeSanitizer: nullSanitizer);

  validate(a, b);
}

class RecordingUriValidator implements UriPolicy {
  final List<String> calls = <String>[];

  bool allowsAttributeUri(String tagName, String attributeName, String uri) {
    calls.add('$tagName::$attributeName=[$uri]');
    return false;
  }

  void reset() {
    calls.clear();
  }
}

void testHtml(String name, NodeValidator validator, String html,
  [String reference]) {
  test(name, () {
    if (reference == null) {
      reference = html;
    }

    validateHtml(html, reference, validator);
  });
}

main() {
  useHtmlConfiguration();

  group('DOM sanitization', () {
    var validator = new CajaValidator();

    testHtml('allows simple constructs',
        validator,
        '<div class="baz">something</div>');

    testHtml('blocks unknown attributes',
        validator,
        '<div foo="baz">something</div>',
        '<div>something</div>');

    testHtml('blocks custom element',
        validator,
        '<x-my-element>something</x-my-element>',
        '');

    testHtml('blocks custom is element',
        validator,
        '<div is="x-my-element">something</div>',
        '<div>something</div>');

    testHtml('blocks body elements',
        validator,
        '<body background="s"></body>',
        '');

    testHtml('allows select elements',
        validator,
        '<select>'
          '<option>a</option>'
        '</select>');

    testHtml('blocks sequential script elements',
        validator,
        '<div><script></script><script></script></div>',
        '<div></div>');

    testHtml('blocks namespaced attributes',
        validator,
        '<div ns:foo="foo"></div>',
        '<div></div>');

    testHtml('blocks namespaced common attributes',
        validator,
        '<div ns:class="foo"></div>',
        '<div></div>');

    testHtml('blocks namespaced common elements',
        validator,
        '<ns:div></ns:div>',
        '');

    testHtml('allows CDATA sections',
        validator,
        '<span>![CDATA[ some text ]]></span>');


    group('custom elements', () {
      var customElementValidator = new CajaValidator(allowCustomElements: true);

      testHtml('allows custom is element',
          customElementValidator,
          '<div is="x-my-element">something</div>');

      testHtml('allows custom element',
          customElementValidator,
          '<x-my-element>something</x-my-element>');

      testHtml('allows attributes on custom element',
          customElementValidator,
          '<x-my-element foo="1"></x-my-element>');

      /*
      Currently fails as attributes are evaluated in isolation and the custom
      attribute is removed.
      Should it? Does allowsCustomAttribute need to be added to Validator API?

      testHtml('allows attributes on custom is element',
          customElementValidator,
          '<div is="x-my-element" foo="1"></div>');
      */

      testHtml('disallows script handlers on custom elements',
          customElementValidator,
          '<x-my-element onload="something"></x-my-element>',
          '<x-my-element></x-my-element>');

      testHtml('disallows known bad custom elements',
          customElementValidator,
          '<script is="x-my-element"></script>',
          '');
    });
  });

  group('URI sanitization', () {
    var recorder = new RecordingUriValidator();
    var validator = new CajaValidator(uriPolicy: recorder);

    checkUriPolicyCalls(String name, String html, String reference,
        List<String> expectedCalls) {

      test(name, () {
        recorder.reset();

        validateHtml(html, reference, validator);
        expect(recorder.calls, expectedCalls);
      });
    }

    checkUriPolicyCalls('a::href',
        '<a href="s"></a>',
        '<a></a>',
        ['A::href=[s]']);

    checkUriPolicyCalls('area::href',
        '<area href="s"></area>',
        '<area></area>',
        ['AREA::href=[s]']);

    checkUriPolicyCalls('blockquote::cite',
        '<blockquote cite="s"></blockquote>',
        '<blockquote></blockquote>',
        ['BLOCKQUOTE::cite=[s]']);
    checkUriPolicyCalls('command::icon',
        '<command icon="s"/>',
        '<command/>',
        ['COMMAND::icon=[s]']);
    checkUriPolicyCalls('img::src',
        '<img src="s"/>',
        '<img/>',
        ['IMG::src=[s]']);
    checkUriPolicyCalls('input::src',
        '<input src="s"/>',
        '<input/>',
        ['INPUT::src=[s]']);
    checkUriPolicyCalls('ins::cite',
        '<ins cite="s"></ins>',
        '<ins></ins>',
        ['INS::cite=[s]']);
    checkUriPolicyCalls('q::cite',
        '<q cite="s"></q>',
        '<q></q>',
        ['Q::cite=[s]']);
    checkUriPolicyCalls('video::poster',
        '<video poster="s"/>',
        '<video/>',
        ['VIDEO::poster=[s]']);
  });
}
