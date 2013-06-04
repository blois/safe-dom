// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library safe_dom.src.node_validation_policy;

import 'dart:html';

import 'html5_validator.dart';
import 'package:safe_dom/validators.dart';

class NodeValidationPolicy implements NodeValidator {

  final List<NodeValidator> _validators = <NodeValidator>[];

  void allowNavigation([UriPolicy uriPolicy]) {
    if (uriPolicy == null) {
      uriPolicy = new UriPolicy();
    }
    add(new SimpleNodeValidator.allowNavigation(uriPolicy));
  }

  void allowImages([UriPolicy uriPolicy]) {
    if (uriPolicy == null) {
      uriPolicy = new UriPolicy();
    }
    add(new SimpleNodeValidator.allowImages(uriPolicy));
  }

  void allowTextElements() {
    add(new SimpleNodeValidator.allowTextElements());
  }

  void allowClassAttributes() {
    add(new SimpleNodeValidator.allowClassAttributes());
  }

  void allowHtml5() {
    add(new Html5NodeValidator());
  }

  void allowCustomElement(String tagName,
      {UriPolicy uriPolicy,
      Iterable<String> attributes,
      Iterable<String> uriAttributes}) {

    var tagNameUpper = tagName.toUpperCase();
    var attrs;
    if (attributes != null) {
      attrs =
          attributes.map((name) => '$tagNameUpper::${name.toLowerCase()}');
    }
    var uriAttrs;
    if (uriAttributes != null) {
      uriAttrs =
          uriAttributes.map((name) => '$tagNameUpper::${name.toLowerCase()}');
    }
    if (uriPolicy == null) {
      uriPolicy = new UriPolicy();
    }

    add(new _CustomElementNodeValidator(
        uriPolicy,
        [tagNameUpper],
        attrs,
        uriAttrs,
        false,
        true));
  }

  void allowTagExtension(String tagName, String baseName,
      {UriPolicy uriPolicy,
      Iterable<String> attributes,
      Iterable<String> uriAttributes}) {

    var baseNameUpper = baseName.toUpperCase();
    var tagNameUpper = tagName.toUpperCase();
    var attrs;
    if (attributes != null) {
      attrs =
          attributes.map((name) => '$baseNameUpper::${name.toLowerCase()}');
    }
    var uriAttrs;
    if (uriAttributes != null) {
      uriAttrs =
          uriAttributes.map((name) => '$baseNameUpper::${name.toLowerCase()}');
    }
    if (uriPolicy == null) {
      uriPolicy = new UriPolicy();
    }

    add(new _CustomElementNodeValidator(
        uriPolicy,
        [tagNameUpper, baseNameUpper],
        attrs,
        uriAttrs,
        true,
        false));
  }

  void allowElement(String tagName, {UriPolicy uriPolicy,
    Iterable<String> attributes,
    Iterable<String> uriAttributes}) {

    allowCustomElement(tagName, uriPolicy: uriPolicy,
        attributes: attributes,
        uriAttributes: uriAttributes);
  }

  void allowTemplating() {}

  void add(NodeValidator validator) {
    _validators.add(validator);
  }

  bool allowsElement(Element element) {
    return _validators.any((v) => v.allowsElement(element));
  }

  bool allowsAttribute(Element element, String attributeName, String value) {
    return _validators.any(
        (v) => v.allowsAttribute(element, attributeName, value));
  }
}

class SimpleNodeValidator implements NodeValidator {
  final Set<String> allowedElements;
  final Set<String> allowedAttributes;
  final Set<String> allowedUriAttributes;
  final UriPolicy uriPolicy;

  factory SimpleNodeValidator.allowNavigation(UriPolicy uriPolicy) {
    return new SimpleNodeValidator(uriPolicy,
      allowedElements: [
        'A',
        'FORM'],
      allowedAttributes: [
        'A::accesskey',
        'A::coords',
        'A::hreflang',
        'A::name',
        'A::shape',
        'A::tabindex',
        'A::target',
        'A::type',
        'FORM::accept',
        'FORM::autocomplete',
        'FORM::enctype',
        'FORM::method',
        'FORM::name',
        'FORM::novalidate',
        'FORM::target',
      ],
      allowedUriAttributes: [
        'A::href',
        'FORM::action',
      ]);
  }

  factory SimpleNodeValidator.allowImages(UriPolicy uriPolicy) {
    return new SimpleNodeValidator(uriPolicy,
      allowedElements: [
        'IMG'
      ],
      allowedAttributes: [
        'IMG::align',
        'IMG::alt',
        'IMG::border',
        'IMG::height',
        'IMG::hspace',
        'IMG::ismap',
        'IMG::name',
        'IMG::usemap',
        'IMG::vspace',
        'IMG::width',
      ],
      allowedUriAttributes: [
        'IMG::src',
      ]);
  }

  factory SimpleNodeValidator.allowTextElements() {
    return new SimpleNodeValidator(null,
      allowedElements: [
        'B',
        'BLOCKQUOTE',
        'BR',
        'EM',
        'H1',
        'H2',
        'H3',
        'H4',
        'H5',
        'H6',
        'HR',
        'I',
        'LI',
        'OL',
        'P',
        'SPAN',
        'UL',
      ]);
  }

  factory SimpleNodeValidator.allowClassAttributes() {
    return new SimpleNodeValidator(null,
      allowedAttributes: [
        '*::class',
      ]);
  }

  /**
   * Elements must be uppercased tag names. For example `'IMG'`.
   * Attributes must be uppercased tag name followed by :: followed by
   * lowercase attribute name. For example `'IMG:src'`.
   */
  SimpleNodeValidator(this.uriPolicy,
      {Iterable<String> allowedElements, Iterable<String> allowedAttributes,
      Iterable<String> allowedUriAttributes}):
      this.allowedElements = allowedElements != null ?
          new Set.from(allowedElements) : new Set(),
      this.allowedAttributes = allowedAttributes != null ?
          new Set.from(allowedAttributes) : new Set(),
      this.allowedUriAttributes = allowedUriAttributes != null ?
          new Set.from(allowedUriAttributes) : new Set();

  bool allowsElement(Element element) {
    return allowedElements.contains(element.tagName);
  }

  bool allowsAttribute(Element element, String attributeName, String value) {
    var tagName = element.tagName;
    if (allowedUriAttributes.contains('$tagName::$attributeName')) {
      return uriPolicy.allowsUri(value);
    } else if (allowedUriAttributes.contains('*::$attributeName')) {
      return uriPolicy.allowsUri(value);
    } else if (allowedAttributes.contains('$tagName::$attributeName')) {
      return true;
    } else if (allowedAttributes.contains('*::$attributeName')) {
      return true;
    } else if (allowedAttributes.contains('$tagName::*')) {
      return true;
    } else if (allowedAttributes.contains('*::*')) {
      return true;
    }
    return false;
  }
}

class _CustomElementNodeValidator extends SimpleNodeValidator {
  final bool allowTypeExtension;
  final bool allowCustomTag;

  _CustomElementNodeValidator(UriPolicy uriPolicy,
      Iterable<String> allowedElements,
      Iterable<String> allowedAttributes,
      Iterable<String> allowedUriAttributes,
      bool allowTypeExtension,
      bool allowCustomTag):

      super(uriPolicy,
          allowedElements: allowedElements,
          allowedAttributes: allowedAttributes,
          allowedUriAttributes: allowedUriAttributes),
      this.allowTypeExtension = allowTypeExtension == true,
      this.allowCustomTag = allowCustomTag == true;

  bool allowsElement(Element element) {
    if (allowTypeExtension) {
      var isAttr = element.attributes['is'];
      if (isAttr != null) {
        return allowedElements.contains(isAttr.toUpperCase()) &&
          allowedElements.contains(element.tagName);
      }
    }
    return allowCustomTag && allowedElements.contains(element.tagName);
  }

  bool allowsAttribute(Element element, String attributeName, String value) {
    if (allowsElement(element)) {
      if (allowTypeExtension && allowedElements.contains(value.toUpperCase())) {
        return true;
      }
      return super.allowsAttribute(element, attributeName, value);
    }
    return false;
  }
}
