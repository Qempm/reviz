// Les lectures gardées sur le téléphone, pour réviser sans réseau.
//
// **La promesse** : tout ce qui a déjà été chargé une fois — cours, chemin,
// QCM, fiches, profil, ligue, corrections — reste lisible sans connexion.
// Seules les actions qui exigent le serveur (déposer un cours, payer, faire
// corriger une copie, retirer) attendent le réseau.
//
// **Le défaut qu'il corrige** : chaque lecture partait sur le réseau sans
// délai, et rien n'était gardé. Hors ligne, une requête Supabase attend le
// renouvellement du jeton de connexion, qui ne vient jamais : l'écran
// chargeait sans fin.
//
// **La règle** : le réseau d'abord, borné par un délai, puis la dernière
// réponse gardée. Sans aucune interface réseau, on sert la copie tout de
// suite. Ce qui est gardé, c'est la réponse brute de PostgREST (du JSON),
// pas les modèles : les fabriques `depuis()` restent le seul chemin, en ligne
// comme hors ligne.
//
// Une copie par compte : deux étudiants qui se prêtent un téléphone ne
// voient pas les cours l'un de l'autre.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reseau.dart';
import 'supabase.dart';

/// Où vivent les copies. Une interface pour que les tests la remplacent.
abstract class StockageLectures {
  Future<String?> lire(String cle);
  Future<void> ecrire(String cle, String valeur);
  Future<void> effacer();
}

/// Sur le téléphone : un fichier par lecture, dans le dossier de
/// l'application. Pas de `SharedPreferences` ici — il se charge en entier au
/// démarrage, et deux cents questions par cours finiraient par peser.
class StockageFichiers implements StockageLectures {
  Directory? _dossier;

  Future<Directory> _ouvrir() async {
    if (_dossier != null) return _dossier!;
    final base = await getApplicationSupportDirectory();
    final dossier = Directory('${base.path}/lectures');
    if (!dossier.existsSync()) dossier.createSync(recursive: true);
    return _dossier = dossier;
  }

  Future<File> _fichier(String cle) async =>
      File('${(await _ouvrir()).path}/${sha1.convert(utf8.encode(cle))}.json');

  @override
  Future<String?> lire(String cle) async {
    final f = await _fichier(cle);
    return f.existsSync() ? f.readAsString() : null;
  }

  @override
  Future<void> ecrire(String cle, String valeur) async {
    final f = await _fichier(cle);
    // Écrire à côté puis renommer : une coupure au milieu ne laisse pas un
    // fichier tronqué, illisible au prochain démarrage hors ligne.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(valeur, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> effacer() async {
    final d = await _ouvrir();
    if (d.existsSync()) d.deleteSync(recursive: true);
    _dossier = null;
  }
}

/// Dans le navigateur : le stockage local de la page.
class StockageNavigateur implements StockageLectures {
  static const _prefixe = 'reviz.lecture.';

  String _cle(String cle) => '$_prefixe${sha1.convert(utf8.encode(cle))}';

  @override
  Future<String?> lire(String cle) async =>
      (await SharedPreferences.getInstance()).getString(_cle(cle));

  @override
  Future<void> ecrire(String cle, String valeur) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _cle(cle),
        valeur,
      );
    } catch (_) {
      // Quota du navigateur atteint : la page marche, sans copie.
    }
  }

  @override
  Future<void> effacer() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith(_prefixe))) {
      await p.remove(k);
    }
  }
}

/// D'où vient ce qu'on vient de lire.
enum Provenance { reseau, copie }

class CacheLectures {
  CacheLectures({
    StockageLectures? stockage,
    Future<bool> Function()? enLigne,
    String Function()? compte,
    this.delaiAvecCopie = const Duration(seconds: 7),
    this.delaiSansCopie = const Duration(seconds: 25),
  }) : _stockage =
           stockage ?? (kIsWeb ? StockageNavigateur() : StockageFichiers()),
       _enLigne = enLigne ?? const DepotReseau().maintenant,
       _compte = compte ?? (() => supabase.auth.currentUser?.id ?? 'anonyme');

  /// L'instance de l'application.
  static CacheLectures instance = CacheLectures();

  final StockageLectures _stockage;
  final Future<bool> Function() _enLigne;
  final String Function() _compte;

  /// Quand une copie existe, on ne la fait pas attendre longtemps : une 3G
  /// qui traîne ne doit pas cacher des données qu'on a déjà.
  final Duration delaiAvecCopie;

  /// Sans copie, le réseau est la seule source : on lui laisse le temps
  /// d'une 3G lente, mais pas l'éternité.
  final Duration delaiSansCopie;

  final Map<String, Object?> _memoire = {};

  /// Vrai si la dernière lecture servie venait de la copie : l'écran peut le
  /// dire (« données du 3 octobre »), et le bandeau hors ligne le dit déjà.
  Provenance derniere = Provenance.reseau;

  String _complete(String cle) => '${_compte()}/$cle';

  /// La dernière réponse gardée pour `cle`, ou `_Absente` s'il n'y en a pas.
  Future<Object?> _copie(String complete) async {
    if (_memoire.containsKey(complete)) return _memoire[complete];
    try {
      final brut = await _stockage.lire(complete);
      if (brut == null) return const _Absente();
      final enveloppe = jsonDecode(brut);
      if (enveloppe is! Map || !enveloppe.containsKey('v')) {
        return const _Absente();
      }
      _memoire[complete] = enveloppe['v'];
      return enveloppe['v'];
    } catch (_) {
      return const _Absente();
    }
  }

  /// Lit `cle` : le réseau d'abord, la copie s'il fait défaut.
  ///
  /// `requete` rend la réponse brute de PostgREST (listes, objets, nombres,
  /// `null`) : c'est elle qui est gardée. Le résultat est `dynamic` : relue
  /// du disque, une liste de lignes est une `List<dynamic>`, plus une
  /// `List<Map<String, dynamic>>` — les appelants lisent ligne par ligne.
  Future<dynamic> lire(String cle, Future<dynamic> Function() requete) async {
    final complete = _complete(cle);
    final copie = await _copie(complete);
    final aUneCopie = copie is! _Absente;

    // Aucune interface réseau : inutile de faire attendre l'étudiant.
    if (aUneCopie && !await _enLigne()) {
      derniere = Provenance.copie;
      return copie;
    }

    try {
      final valeur = await requete().timeout(
        aUneCopie ? delaiAvecCopie : delaiSansCopie,
      );
      _memoire[complete] = valeur;
      derniere = Provenance.reseau;
      unawaited(_garder(complete, valeur));
      return valeur;
    } catch (e) {
      if (!aUneCopie) rethrow;
      debugPrint('Lecture « $cle » servie depuis la copie : $e');
      derniere = Provenance.copie;
      return copie;
    }
  }

  /// Une copie existe-t-elle, et de quand date-t-elle ?
  Future<DateTime?> datee(String cle) async {
    try {
      final brut = await _stockage.lire(_complete(cle));
      if (brut == null) return null;
      final e = jsonDecode(brut);
      return e is Map ? DateTime.tryParse(e['le'] as String? ?? '') : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _garder(String complete, Object? valeur) async {
    try {
      await _stockage.ecrire(
        complete,
        jsonEncode({'le': DateTime.now().toIso8601String(), 'v': valeur}),
      );
    } catch (e) {
      debugPrint('Copie non gardée : $e');
    }
  }

  /// À la suppression du compte : rien ne doit rester sur le téléphone.
  Future<void> effacer() async {
    _memoire.clear();
    await _stockage.effacer();
  }
}

class _Absente {
  const _Absente();
}

/// Raccourci des dépôts.
Future<dynamic> lu(String cle, Future<dynamic> Function() requete) =>
    CacheLectures.instance.lire(cle, requete);
