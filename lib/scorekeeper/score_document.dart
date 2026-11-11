import 'dart:convert';
import 'package:flutter/services.dart';
import 'score_models.dart';

/// Bundle the reviewed website, never load Render in the app. Styles/scripts are
/// inlined so scoring needs no network, cookies, website deployment or file access.
class ScoreDocument {
  static const root = 'lib/assets/scorekeeper/';
  static String scriptJson(Object? data) => jsonEncode(data)
      .replaceAll('<', r'\u003c')
      .replaceAll('>', r'\u003e')
      .replaceAll('&', r'\u0026');
  static Future<String> build(
      {required ScoreKind kind,
      required List<ScorePerson> people,
      required bool teamMode,
      required bool editable,
      Map<String, String> storage = const {}}) async {
    var html = await rootBundle.loadString('$root${kind.asset}');
    // Uno can have more players than the standalone general page's manual picker.
    if (kind == ScoreKind.general) {
      html = html.replaceAll('p.players.slice(0, 8)',
          'p.players.slice(0, window.InzeliConfig.people.length)');
      html = html.replaceAll('clampInt(\$("playerCount").value, 2, 8)',
          'window.InzeliConfig.people.length');
    }
    html = html.replaceAll('content="#f5f4ef"', 'content="#223448"');
    final bootstrap = await rootBundle.loadString('${root}app-bridge.js');
    final ready = await rootBundle.loadString('${root}app-ready.js');
    final links = RegExp(r'<link rel="stylesheet" href="([^"/]+)">');
    for (final match in links.allMatches(html).toList()) {
      final css = await rootBundle.loadString('$root${match[1]}');
      html = html.replaceFirst(match[0]!, '<style>$css</style>');
    }
    final scripts = RegExp(r'<script defer src="([^"/]+)"></script>');
    final sources = <String>[];
    for (final match in scripts.allMatches(html).toList()) {
      sources.add(await rootBundle.loadString('$root${match[1]}'));
      html = html.replaceFirst(match[0]!, '');
    }
    final config = scriptJson({
      'kind': kind.name,
      'people': people.map((p) => p.toJson()).toList(),
      'teamMode': teamMode,
      'editable': editable,
      'storage': storage
    });
    html = html.replaceFirst('</head>',
        '<script>window.InzeliConfig=$config;\n$bootstrap</script>\n</head>');
    final css = await rootBundle.loadString('${root}app-embed.css');
    final theme = await rootBundle.loadString('${root}app-theme.css');
    html = html.replaceFirst(
        '</head>', '<style>$css</style><style>$theme</style></head>');
    // General already has an inline controller at the bottom; other pages use defer files.
    html = html.replaceFirst('</body>',
        '${sources.map((s) => '<script>$s</script>').join('\n')}<script>$ready</script></body>');
    return html;
  }
}
