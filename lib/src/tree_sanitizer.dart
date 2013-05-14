// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library safe_dom.src.tree_sanitizer;

import 'dart:html';
import 'package:safe_dom/validators.dart';


/**
 * Standard tree sanitizer which validates a node tree against the provided
 * validator and removes any nodes or attributes which are not allowed.
 */
class ValidatingTreeSanitizer implements NodeTreeSanitizer {
  final NodeValidator validator;
  ValidatingTreeSanitizer(this.validator) {}

  void sanitizeTree(Node node) {
    void walk(Node node) {
      sanitizeNode(node);

      var child = node.$dom_lastChild;
      while (child != null) {
        // Child may be removed during the walk.
        var nextChild = child.previousNode;
        walk(child);
        child = nextChild;
      }
    }
    walk(node);
  }

  void sanitizeNode(Node node) {
    switch (node.nodeType) {
      case Node.ELEMENT_NODE:
        Element element = node;
        if (!validator.allowsElement(element.tagName)) {
          element.remove();
        }
        // TODO(blois): Need to be able to get all attributes, irrespective of
        // XMLNS.
        var attrs = element.attributes;
        var keys = attrs.keys.toList();
        for (var i = attrs.length - 1; i >= 0; --i) {
          var name = keys[i];
          if (!validator.allowsAttribute(element.tagName, name, attrs[name])) {
            attrs.remove(name);
          }
        }
        break;
      case Node.COMMENT_NODE:
      case Node.DOCUMENT_FRAGMENT_NODE:
      case Node.TEXT_NODE:
      case Node.CDATA_SECTION_NODE:
        break;
      default:
        node.remove();
    }
  }
}
