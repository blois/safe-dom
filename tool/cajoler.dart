/**
 * Generates a Dart DOM validator from Caja whitelists.
 *
 * See also:
 *
 * * https://code.google.com/p/google-caja/wiki/CajaWhitelists
 */
library cajoler;

import 'dart:async';
import 'dart:io';
import 'dart:json' as json;
import 'dart:uri';
import 'package:args/args.dart';
import 'package:mustache/mustache.dart' as mustache;

main() {
  final args = new Options().arguments;

  var parser = new ArgParser();
  parser.addOption('elements',
      help: 'URL to the Caja elements whitelist to be generated.',
      defaultsTo: 'htmlall-elements.json');
  parser.addOption('attributes',
      help: 'URL to the Caja attributes whitelist to be generated.',
      defaultsTo: 'htmlall-attributes.json');
  parser.addOption('template',
      help: 'Path to the generated Dart file.',
      defaultsTo: 'validator.mustache');
  parser.addOption('out',
      help: 'Path to the generated Dart file.',
      defaultsTo: 'validator.dart');

  var elementsUri = null;
  var attributesUri = null;
  var templatePath = null;
  var outputPath = null;

  try {
    var results = parser.parse(args);
    elementsUri = toUri(results['elements']);
    attributesUri = toUri(results['attributes']);
    templatePath = results['template'];
    outputPath = results['out'];
  } on FormatException catch (e) {
    print(e);
    showUsage(parser);
    exit(1);
  }

  process(elementsUri, attributesUri, templatePath, outputPath).then((_) {
    exit(0);
  }).catchError((e) {
    print(e);
    exit(1);
  });
}

void showUsage(parser) {
  print('Usage: cajoler [options...]');
  print(parser.getUsage());
}

const doNotEditPrefix =
  '// DO NOT EDIT- this file is generated from running tool/generator.sh.\n\n';

Future process(Uri elementsUri, Uri attributesUri, String templatePath,
    String destination) {

  var elements = new Whitelist(elementsUri);
  var attributes = new Whitelist(attributesUri);

  return Future.forEach([elements, attributes], (whitelist) {
    return whitelist.load();
  }).then((_) {
    return new File(templatePath).readAsString();
  }).then((templateContents) {
    var e = elements.whitelist.toList();
    e.sort();

    var attributeSets = {
      'standardAttributes': [],
      'uriAttributes': [],
    };
    var attrs = attributes.whitelist.toList();
    attrs.sort();
    for (var attr in attrs) {
      var type = attributes.types[attr];
      var attributeSet =
          type != null ? findValidator(type) : 'standardAttributes';

      var parts = attr.split('::');
      attr = '${parts[0]}::${parts[1].toLowerCase()}';

      attributeSets[attributeSet].add(attr);
    }

    var template = mustache.parse(templateContents);
    var generated = template.renderString({
      'elements': e,
      'attributes': attributeSets,
    });
    generated = doNotEditPrefix + generated;
    return new File(destination).writeAsString(generated);
  });
}

String findValidator(String type) {
  if (type == 'URI') {
    return 'uriAttributes';
  }
  return 'standardAttributes';
}

class Whitelist {
  final Uri _uri;
  Set<String> _list = new Set();
  List<String> _allowed = [];
  List<String> _denied = [];
  Map<String, String> _types = {};

  Whitelist([Uri uri]): this._uri = uri {
  }

  Future load() {
    print('Fetching $_uri');

    return readUri(_uri).then((contents) {
      return _process(contents.toString());
    });
  }

  List<String> get allowed => _allowed;
  List<String> get denied => _denied;
  Set<String> get whitelist => _list;
  Map<String, String> get types => _types;

  Future _process(String str) {
    var data = json.parse(str);

    var allowed = data['allowed'];
    if (allowed != null) {
      for (var item in allowed) {
        if (item is Map) {
          var value = item['key'];
          _allowed.add(value);
        } else {
          _allowed.add(item);
        }
      }
    }

    var denied = data['denied'];
    if (denied != null) {
      for (var item in denied) {
        if (item is Map) {
          var value = item['key'];
          _denied.add(value);
        } else {
          _denied.add(item);
        }
      }
    }

    var types = data['types'];
    if (types != null) {
      for (var item in types) {
        var type = item['type'];
        // Block types we don't support validating.
        if (type == 'SCRIPT' || type == 'STYLE') {
          _denied.add(item['key']);
        } else {
          _types[item['key']] = type;
        }
      }
    }
    var dependents = [];
    var inherits = data['inherits'];
    if (inherits != null) {
      for (var inherit in inherits) {
        var uri = _uri.resolve(inherit);
        dependents.add(new Whitelist(uri));
      }
    }
    return Future.forEach(dependents, (dependent) {
      return dependent.load();
    }).then((_) {
      for (var dependent in dependents) {
        _mergeWhitelist(dependent);
      }
      _mergeWhitelist(this);
    });
  }

  _mergeWhitelist(Whitelist list) {
    for (var allowed in list.allowed) {
      if (list != this) {
        _allowed.add(allowed);
      }
      _list.add(allowed);
    }
    for (var denied in list.denied) {
      if (list != this) {
        _denied.add(denied);
      }
      _list.remove(denied);
    }

    list.types.forEach((k, v) {
      _types[k] = v;
    });
  }
}

Uri toUri(String path) {
  var currentUri = new Uri.fromString('file://${Directory.current.path}/');
  return currentUri.resolve(path);
}

Future<String> readUri(Uri uri) {
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    var client = new HttpClient();
    return client.getUrl(uri).then((request) {
      return request.close();
    }).then((response) {
      var contents = new StringBuffer();
      return response.fold(contents, (contents, data) {
        contents.write(new String.fromCharCodes(data));
        return contents;
      });
    });
  } else if (uri.scheme == 'file') {
    return new File(uri.path).readAsString();
  }
  throw new Exception('Unknown scheme: ${uri.scheme}');
}
