// Lecture de la version installée et des seuils publiés.
//
// La règle est dans `lib/metier/version.dart` ; ici, seulement les deux
// entrées/sorties : le paquet installé, et `/version.json`.

library;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../metier/plateforme.dart';
import '../metier/version.dart';
import 'config.dart';

/// Ce qu'on sait de l'état de l'application.
class EtatMiseAJour {
  const EtatMiseAJour({
    required this.exigence,
    required this.locale,
    this.distante,
  });

  final ExigenceVersion exigence;

  /// La version installée, pour l'afficher dans le profil et les journaux.
  final String locale;

  /// `null` quand le fichier n'a pas pu être lu.
  final VersionDistante? distante;

  bool get bloquant =>
      exigence == ExigenceVersion.exigee ||
      exigence == ExigenceVersion.maintenance;
}

class DepotVersion {
  DepotVersion({Dio? dio}) : _dio = dio ?? Dio() {
    // Client à part, et volontairement : `/version.json` est un fichier
    // public, il n'a pas besoin du jeton, et il doit pouvoir se lire **avant**
    // toute connexion — un blocage de version doit s'afficher à quelqu'un qui
    // n'a pas encore de session. Délais courts : ce n'est qu'un contrôle,
    // l'application ne doit pas attendre derrière.
    _dio.options
      ..connectTimeout = const Duration(seconds: 6)
      ..receiveTimeout = const Duration(seconds: 6)
      ..validateStatus = (_) => true;
  }

  final Dio _dio;

  /// L'état de l'application, ou « à jour » quand on n'a rien pu lire.
  ///
  /// **Hors ligne ne bloque pas.** Un étudiant sans réseau doit garder ses
  /// QCM déjà chargés : faire dépendre l'ouverture de l'application d'un
  /// fichier distant reviendrait à la fermer dès que la 3G tombe. Un contrôle
  /// de version qu'on ne peut pas faire est un contrôle qu'on ne fait pas.
  Future<EtatMiseAJour> etat() async {
    final paquet = await _versionInstallee();
    final distante = await _seuils();

    if (distante == null) {
      return EtatMiseAJour(exigence: ExigenceVersion.aJour, locale: paquet);
    }

    final exigence = etatVersion(locale: paquet, distante: distante);
    return EtatMiseAJour(
      // Sur le web, rien à télécharger : la page est toujours la dernière
      // version. Seul un entretien annoncé y vaut encore.
      exigence: versionAInstaller || exigence == ExigenceVersion.maintenance
          ? exigence
          : ExigenceVersion.aJour,
      locale: paquet,
      distante: distante,
    );
  }

  Future<String> _versionInstallee() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      // Sur une plateforme sans greffon — le web de développement, un banc de
      // test — on se déclare à jour plutôt que de bloquer.
      return '0.0.0';
    }
  }

  Future<VersionDistante?> _seuils() async {
    try {
      final reponse = await _dio.get<dynamic>(
        '${Config.apiBase}/version.json',
        // Un fichier statique servi par Vercel se met en cache : on veut
        // l'état du jour, pas celui de la dernière ouverture.
        options: Options(headers: {'cache-control': 'no-cache'}),
      );

      final code = reponse.statusCode ?? 0;
      if (code < 200 || code >= 300) return null;

      final corps = reponse.data;
      if (corps is! Map) return null;

      return VersionDistante.depuis(Map<String, dynamic>.from(corps));
    } catch (_) {
      return null;
    }
  }
}
