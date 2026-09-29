/// Les opérateurs Mobile Money payables **dans l'application**.
///
/// Port de `lib/metier/operateurs.ts` : l'écran doit savoir quoi proposer
/// sans aller-retour, mais c'est le serveur qui décide — il refuse un
/// opérateur absent du pays du numéro.
///
/// Seuls les modes FedaPay « sans redirection » y figurent : la demande part
/// directement sur le téléphone, et l'étudiant la valide avec son code
/// secret, sans jamais quitter Reviz. Wave, Orange et le Burkina Faso ne se
/// paient que sur la page hébergée de FedaPay : ils n'apparaissent pas.
library;

/// Un opérateur, tel que le serveur le nomme, et tel que l'étudiant le lit.
class Operateur {
  const Operateur(this.code, this.libelle);

  final String code;
  final String libelle;

  @override
  bool operator ==(Object other) => other is Operateur && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

const mtn = Operateur('mtn', 'MTN MoMo');
const moov = Operateur('moov', 'Moov Money');
const celtiis = Operateur('celtiis', 'Celtiis Cash');
const togocel = Operateur('togocel', 'Mixx by Yas');
const free = Operateur('free', 'Free Money');

/// Pays par pays, dans l'ordre d'affichage. Même table que le serveur.
const Map<String, List<Operateur>> _parPays = {
  'BJ': [mtn, moov, celtiis],
  'TG': [moov, togocel],
  'CI': [mtn],
  'SN': [free],
};

/// Les opérateurs proposés pour un pays ; vide s'il n'y en a aucun.
List<Operateur> operateursDuPays(String codePays) =>
    _parPays[codePays.toUpperCase()] ?? const [];
