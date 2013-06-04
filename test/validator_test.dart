// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:svg' as svg;
import 'package:safe_dom/parser.dart' as parser;
import 'package:safe_dom/validators.dart';
import 'package:safe_dom/src/node_validation_policy.dart';
import 'package:safe_dom/src/html5_validator.dart';
import 'package:safe_dom/src/svg_node_validator.dart';
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

  bool allowsUri(String uri) {
    calls.add('$uri');
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
    var validator = new Html5NodeValidator();

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
        '');

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
  });

  group('URI sanitization', () {
    var recorder = new RecordingUriValidator();
    var validator = new Html5NodeValidator(uriPolicy: recorder);

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
        ['s']);

    checkUriPolicyCalls('area::href',
        '<area href="s"></area>',
        '<area></area>',
        ['s']);

    checkUriPolicyCalls('blockquote::cite',
        '<blockquote cite="s"></blockquote>',
        '<blockquote></blockquote>',
        ['s']);
    checkUriPolicyCalls('command::icon',
        '<command icon="s"/>',
        '<command/>',
        ['s']);
    checkUriPolicyCalls('img::src',
        '<img src="s"/>',
        '<img/>',
        ['s']);
    checkUriPolicyCalls('input::src',
        '<input src="s"/>',
        '<input/>',
        ['s']);
    checkUriPolicyCalls('ins::cite',
        '<ins cite="s"></ins>',
        '<ins></ins>',
        ['s']);
    checkUriPolicyCalls('q::cite',
        '<q cite="s"></q>',
        '<q></q>',
        ['s']);
    checkUriPolicyCalls('video::poster',
        '<video poster="s"/>',
        '<video/>',
        ['s']);
  });

  group('NodeValidationPolicy', () {

    group('allowNavigation', () {
      var validator = new NodeValidationPolicy()..allowNavigation();

      testHtml('allows anchor tags',
          validator,
          '<a href="#foo">foo</a>');

      testHtml('allows form elements',
          validator,
          '<form method="post" action="/foo"></form>');

      testHtml('disallows script navigation',
          validator,
          '<a href="javascript:foo = 1">foo</a>',
          '<a>foo</a>');

      testHtml('disallows cross-site navigation',
          validator,
          '<a href="http://example.com">example.com</a>',
          '<a>example.com</a>');

      testHtml('blocks other elements',
          validator,
          '<a href="#foo"><b>foo</b></a>',
          '<a href="#foo"></a>');

      testHtml('blocks tag extension',
          validator,
          '<a is="x-foo"></a>',
          '');
    });

    group('allowImages', () {
      var validator = new NodeValidationPolicy()..allowImages();

      testHtml('allows images',
          validator,
          '<img src="/foo.jpg" alt="something" width="100" height="100"/>');

      testHtml('blocks onerror',
          validator,
          '<img src="/foo.jpg" onerror="something"/>',
          '<img src="/foo.jpg"/>');

      testHtml('enforces same-origin',
          validator,
          '<img src="http://example.com/foo.jpg"/>',
          '<img/>');
    });

    group('allowCustomElement', () {
      var validator = new NodeValidationPolicy()
        ..allowCustomElement(
            'x-foo',
            attributes: ['bar'],
            uriAttributes: ['baz'])
        ..allowHtml5();

      testHtml('allows custom elements',
          validator,
          '<x-foo bar="something" baz="/foo.jpg"></x-foo>');


      testHtml('validates custom tag URIs',
          validator,
          '<x-foo baz="http://example.com/foo.jpg"></x-foo>',
          '<x-foo></x-foo>');

      testHtml('blocks type extensions',
          validator,
          '<div is="x-foo"></div>',
          '');

      testHtml('blocks tags on non-matching elements',
          validator,
          '<div bar="foo"></div>',
          '<div></div>');
    });

    group('allowTagExtension', () {
       var validator = new NodeValidationPolicy()
        ..allowTagExtension(
            'x-foo',
            'div',
            attributes: ['bar'],
            uriAttributes: ['baz'])
        ..allowHtml5();

      testHtml('allows tag extensions',
          validator,
          '<div is="x-foo" bar="something" baz="/foo.jpg"></div>');

      testHtml('blocks custom elements',
            validator,
            '<x-foo></x-foo>',
            '');

      testHtml('validates tag extension URIs',
          validator,
          '<div is="x-foo" baz="http://example.com/foo.jpg"></div>',
          '<div is="x-foo"></div>');

      testHtml('blocks tags on non-matching elements',
          validator,
          '<div bar="foo"></div>',
          '<div></div>');

      testHtml('blocks non-matching tags',
          validator,
          '<span is="x-foo">something</span>',
          '');

      validator = new NodeValidationPolicy()
        ..allowTagExtension(
            'x-foo',
            'div',
            attributes: ['bar'],
            uriAttributes: ['baz'])
        ..allowTagExtension(
            'x-else',
            'div');

      testHtml('blocks tags on non-matching custom elements',
          validator,
          '<div bar="foo" is="x-else"></div>',
          '<div is="x-else"></div>');
    });
  });

  group('svg', () {

    test('parsing', () {
      var svgText =
        '<svg xmlns="http://www.w3.org/2000/svg'
            'xmlns:xlink="http://www.w3.org/1999/xlink">'
          '<image xlink:href="foo" data-foo="bar"/>'
        '</svg>';

      var fragment = parser.createFragment(null, svgText, treeSanitizer: nullSanitizer);
      var element = fragment.nodes.first;
      expect(element is svg.SvgSvgElement, isTrue);
      expect(element.children[0] is svg.ImageElement, isTrue);
    });

    group('SvgNodeValidator', () {
      var validator = new SvgNodeValidator();
      testHtml('allows basic SVG',
        validator,
        '<svg xmlns="http://www.w3.org/2000/svg'
            'xmlns:xlink="http://www.w3.org/1999/xlink">'
          '<image xlink:href="foo" data-foo="bar"/>'
        '</svg>');

      testHtml('blocks script elements',
        validator,
        '<svg xmlns="http://www.w3.org/2000/svg>'
          '<script></script>'
        '</svg>',
        '<svg xmlns="http://www.w3.org/2000/svg></svg>');

      testHtml('blocks script handlers',
        validator,
        '<svg xmlns="http://www.w3.org/2000/svg'
            'xmlns:xlink="http://www.w3.org/1999/xlink">'
          '<image xlink:href="foo" onerror="something"/>'
        '</svg>',
        '<svg xmlns="http://www.w3.org/2000/svg'
            'xmlns:xlink="http://www.w3.org/1999/xlink">'
          '<image xlink:href="foo"/>'
        '</svg>');

      testHtml('blocks foreignObject content',
        validator,
        '<svg xmlns="http://www.w3.org/2000/svg>'
          '<foreignobject width="100" height="150">'
            '<body xmlns="http://www.w3.org/1999/xhtml">'
              '<div>Some content</div>'
            '</body>'
          '</foreignobject>'
        '</svg>',
        '<svg xmlns="http://www.w3.org/2000/svg>'
          '<foreignobject width="100" height="150"></foreignobject>'
        '</svg>');
    });
  });
}
