// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library safe_dom.validators;

import 'dart:html';
import 'src/tree_sanitizer.dart';
import 'src/caja_validator.dart';


/**
 * Interface used to validate that only accepted elements and attributes are
 * allowed while parsing HTML strings into DOM nodes.
 */
abstract class NodeValidator {

  /**
   * Construct a default NodeValidator which only accepts whitelisted elements
   * and attributes.
   *
   * If a uriPolicy is not specified then the default uriPolicy will be used.
   */
  factory NodeValidator({UriPolicy uriPolicy}) =>
      new CajaValidator(uriPolicy: uriPolicy);

  /**
   * Returns true if the tagName is an accepted type.
   *
   * The tagName parameter will always be in uppercase.
   *
   * Namespaced tags will come through as 'NS:TAGNAME'.
   */
  bool allowsElement(String tagName);

  /**
   * Returns true if the attribute is allowed.
   *
   * The attributeName parameter will always be in lowercase.
   *
   * See [allowsElement] for format of tagName.
   */
  bool allowsAttribute(String tagName, String attributeName, String value);
}

/**
 * Performs sanitization of a node tree after construction to ensure that it
 * does not contain any disallowed elements or attributes.
 *
 * In general custom implementations of this class should not be necessary and
 * all validation customization should be done in custom NodeValidators, but
 * custom implementations of this class can be created to perform more complex
 * tree sanitization.
 */
abstract class NodeTreeSanitizer {

  /**
   * Constructs a default tree sanitizer which will remove all elements and
   * attributes which are not allowed by the provided validator.
   */
  factory NodeTreeSanitizer(NodeValidator validator) =>
      new ValidatingTreeSanitizer(validator);

  /**
   * Called with the root of the tree which is to be sanitized.
   *
   * This method needs to walk the entire tree and either remove elements and
   * attributes which are not recognized as safe or throw an exception which
   * will mark the entire tree as unsafe.
   */
  void sanitizeTree(Node node);
}

/**
 * Defines the policy for what types of uris are allowed for particular
 * attribute values.
 *
 * This can be used to provide custom rules such as allowing all http:// URIs
 * for image attributes but only same-origin URIs for anchor tags.
 */
abstract class UriPolicy {
  /**
   * Constructs the default UriPolicy which is to only allow Uris to the same
   * origin as the application was launched from.
   *
   * This will block all ftp: mailto: URIs. It will also block accessing
   * https://example.com if the app is running from http://example.com.
   */
  factory UriPolicy() => new SameOriginUriPolicy();

  /**
   * Checks if the uri is allowed on the specified attribute.
   *
   * The uri provided may or may not be a relative path.
   *
   * See also [NodeValidator.allowsAttribute] for format of tagName and
   * attributeName.
   */
  bool allowsAttributeUri(String tagName, String attributeName, String uri);
}

/**
 * Allows URIs to the same origin as the current application was loaded from
 * (such as https://example.com:80).
 */
class SameOriginUriPolicy implements UriPolicy {
  final AnchorElement _hiddenAnchor = new AnchorElement();

  bool allowsAttributeUri(String tagName, String attributeName, String uri) {
    _hiddenAnchor.href = uri;
    return _hiddenAnchor.href.startsWith(window.location.origin);
  }
}

/**
 * Allows URIs of the same protocol as the current application was loaded from.
 *
 * If the app was loaded from file:// then all file: URIs will be allowed, but
 * no others.
 */
class SameProtocolUriPolicy implements UriPolicy {
  final AnchorElement _hiddenAnchor = new AnchorElement();

  bool allowsAttributeUri(String tagName, String attributeName, String uri) {
    _hiddenAnchor.href = uri;
    return _hiddenAnchor.href.startsWith(window.location.protocol);
  }
}

/**
 * Allows all URIs utilizing common web protocols.
 *
 * Currently this list is:
 *
 * * http:
 * * https:
 * * mailto:
 * * Current application protocol (file: if launched from file system)
 */
class CommonProtocolUriPolicy implements UriPolicy {
  final AnchorElement _hiddenAnchor = new AnchorElement();

  bool allowsAttributeUri(String tagName, String attributeName, String uri) {
    _hiddenAnchor.href = uri;
    var href = _hiddenAnchor.href;
    return (href.startsWith('http://') ||
          href.startsWith('https://') ||
          href.startsWith('mailto://') ||
          // for file: URIs when executing from local file system.
          href.startsWith(window.location.protocol));
  }
}
