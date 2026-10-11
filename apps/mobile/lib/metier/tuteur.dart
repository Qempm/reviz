/// Le tuteur de maîtrise : les règles affichées par l'écran.
///
/// Port de `lib/metier/tuteur.ts`. Le serveur reste l'autorité — il refuse
/// un second essai ou la 21e session du jour même si l'écran l'a laissée
/// partir ; ici, on sait seulement quoi dire avant d'appeler.
library;

import 'acces.dart';

/// Questions par session.
const int questionsParSession = 3;

/// Sessions par jour, même avec un pack.
const int tuteurParJour = 20;

/// Longueur maximale d'une réponse tapée.
const int reponseMax = 1500;

/// Le jugement d'une réponse. Juste se fête en jaune, partiel en orange,
/// faux en rouge : jamais de vert.
enum NiveauReponse {
  juste,
  partiel,
  faux;

  static NiveauReponse depuis(String valeur) => switch (valeur) {
    'juste' => NiveauReponse.juste,
    'partiel' => NiveauReponse.partiel,
    _ => NiveauReponse.faux,
  };
}

/// Ce qui ouvre le tuteur : un pack actif, ou l'essai gratuit pas encore pris.
enum DroitTuteur { pack, essai, essaiUtilise }

DroitTuteur droitTuteur({
  required EtatAcces acces,
  required bool essaiUtilise,
}) {
  if (acces is AccesActif) return DroitTuteur.pack;
  return essaiUtilise ? DroitTuteur.essaiUtilise : DroitTuteur.essai;
}

/// Points d'une session : 1 pour juste, 0,5 pour partiel. Deux sur trois,
/// c'est maîtrisé — le même seuil que le serveur.
double pointsTuteur(List<NiveauReponse> niveaux) => niveaux.fold(
  0,
  (s, n) =>
      s +
      switch (n) {
        NiveauReponse.juste => 1,
        NiveauReponse.partiel => 0.5,
        NiveauReponse.faux => 0,
      },
);

bool estMaitrise(List<NiveauReponse> niveaux) => pointsTuteur(niveaux) >= 2;

/// Le chapitre d'une série qui n'en nomme pas : celui qui a le plus de
/// questions, le premier rencontré en cas d'égalité. C'est lui que le tuteur
/// propose de vérifier en fin de série — sans lui, les séries lancées par
/// « Réviser » ou « Continuer » ne menaient jamais au tuteur.
String? chapitreDominant(Iterable<String?> chapitres) {
  // Une table insérée dans l'ordre de première apparition : à égalité, le
  // premier rencontré l'emporte.
  final compte = <String, int>{};
  for (final c in chapitres) {
    if (c != null) compte[c] = (compte[c] ?? 0) + 1;
  }
  String? meilleur;
  for (final MapEntry(:key, :value) in compte.entries) {
    if (meilleur == null || value > compte[meilleur]!) meilleur = key;
  }
  return meilleur;
}
