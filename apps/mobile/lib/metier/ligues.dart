/// Les ligues de la semaine : la règle de montée et de descente.
///
/// Miroir de `public.cloturer_ligues()` (migration 20260930130000) : l'écran
/// colore les zones sans attendre la clôture, la base reste l'autorité.
library;

/// Six divisions, de 1 (Bronze) à 6 (Diamant).
const divisionMax = 6;

/// Les sept premiers montent.
const placesMontee = 7;

/// Les cinq derniers descendent.
const placesDescente = 5;

enum IssueLigue { monte, reste, descend }

/// Où finirait un rang si la semaine s'arrêtait maintenant.
///
/// Dans un petit groupe, les zones se chevaucheraient : la montée l'emporte,
/// et l'on ne descend que hors des sept premiers. Monter demande d'avoir
/// gagné quelque chose.
IssueLigue issueDuRang({
  required int rang,
  required int membres,
  required int division,
  required int xp,
}) {
  if (division < divisionMax && rang <= placesMontee && xp > 0) {
    return IssueLigue.monte;
  }
  final seuil = membres - placesDescente > placesMontee
      ? membres - placesDescente
      : placesMontee;
  if (division > 1 && rang > seuil) return IssueLigue.descend;
  return IssueLigue.reste;
}

IssueLigue? issueDepuis(String? code) => switch (code) {
  'monte' => IssueLigue.monte,
  'reste' => IssueLigue.reste,
  'descend' => IssueLigue.descend,
  _ => null,
};
