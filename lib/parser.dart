// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library safe_dom.parser;

import 'dart:html';
import 'validators.dart';


/**
 * Create a DocumentFragment from the HTML fragment and ensure that it follows
 * the sanitization rules specified by the validator or treeSanitizer.
 *
 * If the default validation behavior is too restrictive then a new
 * NodeValidator should be created, either extending or wrapping a default
 * validator and overriding the validation APIs.
 *
 * The treeSanitizer is used to walk the generated node tree and sanitize it.
 * A custom treeSanitizer can also be provided to perform special validation
 * rules but since the API is more complex to implement this is discouraged.
 *
 * The returned tree is guaranteed to only contain nodes and attributes which
 * are allowed by the provided validator.
 *
 * See also:
 *
 * * [NodeValidator]
 * * [NodeTreeSanitizer]
 */
DocumentFragment createFragment(Element context, String html,
    {NodeValidator validator, NodeTreeSanitizer treeSanitizer}) {

  if (treeSanitizer == null) {
    if (validator == null) {
      validator = new NodeValidator();
    }
    treeSanitizer = new NodeTreeSanitizer(validator);
  }
  return _parseHtml(context, html, treeSanitizer);
}

DocumentFragment _parseHtml(Element context, String html,
  NodeTreeSanitizer treeSanitizer) {

  var doc = document.implementation.createHtmlDocument('');
  var contextElement;
  if (context == null || context is BodyElement) {
    contextElement = doc.body;
  } else {
    contextElement = doc.$dom_createElement(context.tagName);
  }

  // TODO (blois): Fix once integrate w/ Dart build with support for this.
  //if (Range.supportsCreateContextualFragment) {
  try {
    var range = doc.$dom_createRange();
    range.selectNode(contextElement);
    var fragment = range.createContextualFragment(html);

    treeSanitizer.sanitizeTree(fragment);

    return fragment;
  } catch(e) {
    contextElement.innerHtml = html;
    treeSanitizer.sanitizeTree(contextElement);

    var fragment = new DocumentFragment();
    while (contextElement.$dom_firstChild != null) {
      fragment.append(contextElement.$dom_firstChild);
    }
    return fragment;
  }
}
