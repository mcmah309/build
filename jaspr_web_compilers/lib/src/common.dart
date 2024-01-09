// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:scratch_space/scratch_space.dart';

final defaultAnalysisOptionsId =
    AssetId('build_modules', 'lib/src/analysis_options.default.yaml');

final sdkDir = p.dirname(p.dirname(Platform.resolvedExecutable));
final webSdkDir = (() {
  var result = Process.runSync('flutter', ['doctor', '--version', '--machine'],
      stdoutEncoding: utf8);
  if ((result.stderr as String).isNotEmpty) {
    throw UnsupportedError(
        'Calling "flutter doctor" resulted in: "${result.stderr}". '
        'Make sure flutter is installed and setup correctly.');
  }
  var output = jsonDecode(result.stdout as String) as Map;
  var webSdkPath = p.join(
      output['flutterRoot'] as String, 'bin', 'cache', 'flutter_web_sdk');
  if (!Directory(webSdkPath).existsSync()) {
    Process.runSync('flutter', ['precache', '--web']);
  }
  if (!Directory(webSdkPath).existsSync()) {
    throw UnsupportedError('Could not find flutter web sdk in $webSdkPath. '
        'Make sure flutter is installed and setup correctly. '
        'If you think this is a bug, open an issue at https://github.com/schultek/jaspr/issues');
  }
  return webSdkPath;
})();

String defaultAnalysisOptionsArg(ScratchSpace scratchSpace) =>
    '--options=${scratchSpace.fileFor(defaultAnalysisOptionsId).path}';

String get sdkDdcKernelPath =>
    p.url.join('lib', '_internal', 'ddc_outline.dill');

/// Validates that [config] only has the top level keys [supportedOptions].
///
/// Throws an [ArgumentError] if not.
void validateOptions(Map<String, dynamic> config, List<String> supportedOptions,
    String builderKey,
    {List<String> deprecatedOptions = const []}) {
  var unsupported = config.keys.where(
      (o) => !supportedOptions.contains(o) && !deprecatedOptions.contains(o));
  if (unsupported.isNotEmpty) {
    throw ArgumentError.value(unsupported.join(', '), builderKey,
        'only $supportedOptions are supported options, but got');
  }
  var deprecated = config.keys.where(deprecatedOptions.contains);
  if (deprecated.isNotEmpty) {
    log.warning('Found deprecated options ${deprecated.join(', ')}. These no '
        'longer have any effect and should be removed.');
  }
}

/// Fixes up the [uris] from a source map so they make sense in a browser
/// context.
///
/// - Strips the scheme from the uri
/// - Strips the top level directory if its not `packages`
///
/// Copied to `web/stack_trace_mapper.dart`, these need to be kept in sync.
List<String> fixSourceMapSources(List<String> uris) {
  return uris.map((source) {
    var uri = Uri.parse(source);
    // We only want to rewrite multi-root scheme uris.
    if (uri.scheme.isEmpty) return source;
    var newSegments = uri.pathSegments.first == 'packages'
        ? uri.pathSegments
        : uri.pathSegments.skip(1);
    return Uri(path: p.url.joinAll(['/', ...newSegments])).toString();
  }).toList();
}
