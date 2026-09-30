import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ce que lit l'étudiant ne parle jamais la langue des développeurs.
///
/// Demande du propriétaire (30 septembre 2026) : « ne pas mentionner les
/// trucs techniques, l'utilisateur n'en a rien à faire ». On y trouvait
/// « Corrigé par deepseek-… », « FedaPay n'a pas encore confirmé », « nos
/// serveurs », et, sur sept écrans, le texte brut d'une exception.
void main() {
  /// Les mots qu'aucune chaîne affichée ne doit contenir.
  const interdits = [
    'deepseek', 'qwen', 'glm', 'fedapay', 'supabase', 'vercel', 'n8n',
    'api', 'serveur', 'serveurs', 'json', 'token', 'job', 'http', 'https',
    'webhook', 'exception', 'null', 'backend', 'payload', 'uuid', 'ia',
  ];

  /// Les chaînes littérales de `fr.dart`, commentaires exclus.
  List<String> chaines() {
    final lignes = File('lib/i18n/fr.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'));
    final texte = lignes.join('\n');
    return [
      for (final m in RegExp(r"'((?:[^'\\]|\\.)*)'").allMatches(texte))
        m.group(1)!,
    ];
  }

  test('aucune chaîne affichée ne contient de jargon technique', () {
    final toutes = chaines();
    // Un test qui ne lirait rien passerait toujours.
    expect(toutes.length, greaterThan(200));
    final fautes = <String>[];
    for (final c in toutes) {
      // Un lien n'est pas du jargon : l'étudiant le touche, il ne le lit
      // pas. On le retire avant de chercher.
      final sansLien = c.replaceAll(RegExp(r'\S+\.\S+/\S*'), ' ');
      final mots = sansLien.toLowerCase().split(RegExp(r'[^a-zà-ÿ0-9]+'));
      for (final mot in interdits) {
        if (mots.contains(mot)) fautes.add('« $c » contient « $mot »');
      }
    }
    expect(fautes, isEmpty, reason: fautes.join('\n'));
  });

  test('aucun écran n’affiche le texte brut d’une erreur', () {
    for (final f in Directory('lib/ecrans').listSync().whereType<File>()) {
      final s = f.readAsStringSync();
      expect(s.contains("'\$error'"), isFalse, reason: f.path);
      expect(s.contains('{error}'), isFalse, reason: f.path);
    }
  });
}
