// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library safe_dom.test.utils;

import 'dart:html';
import 'package:safe_dom/validators.dart';
import 'package:unittest/unittest.dart';


/**
 * Validate that two DOM trees are equivalent.
 */
void validate(Node a, Node b, [String path = '']) {
  path = '${path}${a.runtimeType}';
  expect(a.nodeType, b.nodeType, reason: '$path nodeTypes differ');
  expect(a.nodeValue, b.nodeValue, reason: '$path nodeValues differ');
  expect(a.text, b.text, reason: '$path texts differ');
  expect(a.nodes.length, b.nodes.length, reason: '$path nodes.lengths differ');

  if (a is Element) {
    Element bE = b;
    Element aE = a;

    expect(aE.tagName, bE.tagName, reason: '$path tagNames differ');
    expect(aE.attributes.length, bE.attributes.length,
        reason: '$path attributes.lengths differ');
    for (var key in aE.attributes.keys) {
      expect(aE.attributes[key], bE.attributes[key],
          reason: '$path attribute [$key] values differ');
    }
  }
  for (var i = 0; i < a.nodes.length; ++i) {
    validate(a.nodes[i], b.nodes[i], '$path[$i].');
  }
}

/**
 * Combines adjacent text nodes.
 */
void normalizeTextNodes(Node node) {
  var currentText = null;

  for (var i = node.nodes.length - 1; i >= 0; --i) {
    var child = node.nodes[i];
    if (child is Text) {
      if (currentText == null) {
        currentText = child;
      } else {
        currentText.text = child.text + currentText.text;
        child.remove();
      }
    } else {
      currentText = null;
    }
    if (child is Element) {
      normalizeTextNodes(child);
    }
  }
}

/**
 * Validator which accepts everything.
 */
class NullValidator implements NodeValidator {
  bool allowsElement(Element element) => true;
  bool allowsAttribute(Element element, String name, String value) => true;
}

/**
 * Sanitizer which does nothing.
 */
class NullTreeSanitizer implements NodeTreeSanitizer {
  void sanitizeTree(Node node) {}
}
