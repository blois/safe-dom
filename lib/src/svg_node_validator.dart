// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library safe_dom.src.svg_validator;

import 'dart:html';
import 'dart:svg' as svg;
import 'package:safe_dom/validators.dart';

class SvgNodeValidator implements NodeValidator {
  bool allowsElement(Element element) {
    if (element is svg.ScriptElement) {
      return false;
    }
    if (element is svg.SvgElement) {
      return true;
    }
    return false;
  }

  bool allowsAttribute(Element element, String attributeName, String value) {
    if (attributeName == 'is' || attributeName.startsWith('on')) {
      return false;
    }
    return true;
  }
}
