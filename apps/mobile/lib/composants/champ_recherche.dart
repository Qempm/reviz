import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../donnees/api.dart';
import '../i18n/fr.dart';
import '../metier/referentiel.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Un choix dans une liste qu'on peut chercher — et compléter.
///
/// Remplace les listes déroulantes de l'école, de la filière et de la
/// matière. Avant, un étudiant absent du catalogue ne pouvait ni s'inscrire
/// ni déposer un cours. Ici, il cherche ; s'il ne trouve pas, la dernière
/// ligne propose « Ajouter « ce qu'il a tapé » », et `onAjouter` le crée
/// (ou rend l'existant, s'il était écrit autrement : « F.S.E.G » = « FSEG »).
class ChampRecherche extends StatefulWidget {
  const ChampRecherche({
    super.key,
    required this.libelle,
    required this.marqueur,
    required this.valeur,
    required this.entrees,
    required this.onChoisir,
    this.onAjouter,
    this.actif = true,
  });

  final String libelle;
  final String marqueur;

  /// L'identifiant choisi, ou `null`.
  final String? valeur;

  /// `(identifiant, nom)`.
  final List<(String, String)> entrees;
  final void Function(String id, String nom) onChoisir;

  /// Crée ce qui manque ; rend `(identifiant, nom)`. Absent : pas d'ajout.
  final Future<Reponse<(String, String)>> Function(String saisie)? onAjouter;
  final bool actif;

  @override
  State<ChampRecherche> createState() => _ChampRechercheState();
}

class _ChampRechercheState extends State<ChampRecherche> {
  /// Le dernier choix : un élément tout juste ajouté n'est pas encore dans
  /// `entrees`, qui se recharge — sans cela, le champ réafficherait
  /// l'invite le temps du rechargement.
  (String, String)? _dernier;

  String? get _nomChoisi {
    for (final (id, nom) in widget.entrees) {
      if (id == widget.valeur) return nom;
    }
    final d = _dernier;
    return d != null && d.$1 == widget.valeur ? d.$2 : null;
  }

  Future<void> _ouvrir(BuildContext context) async {
    HapticFeedback.selectionClick();
    final choix = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Couleurs.fond,
      shape: formeContinue(Rayons.feuille),
      builder: (_) => _Feuille(
        titre: widget.libelle,
        entrees: widget.entrees,
        onAjouter: widget.onAjouter,
      ),
    );
    if (choix == null) return;
    setState(() => _dernier = choix);
    widget.onChoisir(choix.$1, choix.$2);
  }

  @override
  Widget build(BuildContext context) {
    final nom = _nomChoisi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.libelle, style: Typo.labelMd),
        const SizedBox(height: Espaces.x8),
        Semantics(
          button: true,
          label: '${widget.libelle} : ${nom ?? widget.marqueur}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.actif ? () => _ouvrir(context) : null,
            child: Container(
              height: Mesures.hauteurCta,
              padding: const EdgeInsets.symmetric(horizontal: Espaces.x16),
              decoration: ShapeDecoration(
                color: Couleurs.carte,
                shape: formeContinue(
                  Rayons.normal,
                  bord: const BorderSide(color: Couleurs.bordure),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      nom ?? widget.marqueur,
                      style: Typo.bodyLg.copyWith(
                        color: nom == null ? Couleurs.attenue : Couleurs.encre,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.search, color: Couleurs.attenue),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Feuille extends StatefulWidget {
  const _Feuille({
    required this.titre,
    required this.entrees,
    required this.onAjouter,
  });

  final String titre;
  final List<(String, String)> entrees;
  final Future<Reponse<(String, String)>> Function(String)? onAjouter;

  @override
  State<_Feuille> createState() => _FeuilleState();
}

class _FeuilleState extends State<_Feuille> {
  final _saisie = TextEditingController();
  bool _ajout = false;
  String? _erreur;

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  Future<void> _ajouter(String texte) async {
    setState(() {
      _ajout = true;
      _erreur = null;
    });
    final reponse = await widget.onAjouter!(texte);
    if (!mounted) return;
    switch (reponse) {
      case ReponseSucces(:final data):
        Navigator.of(context).pop(data);
      case ReponseEchec(:final erreur):
        setState(() {
          _ajout = false;
          _erreur = erreur;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final texte = _saisie.text.trim();
    final trouvees = filtrerParNom(widget.entrees, (e) => e.$2, texte);
    final exacte = trouverParNom(widget.entrees, (e) => e.$2, texte);
    final peutAjouter =
        widget.onAjouter != null && texte.length >= 2 && exacte == null;

    return Padding(
      padding: EdgeInsets.only(
        left: Espaces.ecran,
        right: Espaces.ecran,
        top: Espaces.x16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Espaces.x16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.titre, style: Typo.headlineMd),
            const SizedBox(height: Espaces.x12),
            TextField(
              controller: _saisie,
              autofocus: true,
              enabled: !_ajout,
              textCapitalization: TextCapitalization.sentences,
              style: Typo.bodyLg,
              decoration: InputDecoration(
                hintText: Fr.referentiel.chercher,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Couleurs.carte,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Rayons.normal),
                  borderSide: const BorderSide(color: Couleurs.bordure),
                ),
              ),
              onChanged: (_) => setState(() => _erreur = null),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: Espaces.x8),
              Text(
                _erreur!,
                style: Typo.labelSm.copyWith(color: Couleurs.danger),
              ),
            ],
            const SizedBox(height: Espaces.x8),
            Expanded(
              child: ListView(
                children: [
                  for (final (id, nom) in trouvees)
                    _Ligne(
                      texte: nom,
                      onTap: _ajout
                          ? null
                          : () => Navigator.of(context).pop((id, nom)),
                    ),
                  if (trouvees.isEmpty && !peutAjouter)
                    Padding(
                      padding: const EdgeInsets.all(Espaces.x16),
                      child: Text(
                        Fr.referentiel.aucunResultat,
                        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (peutAjouter)
                    _Ligne(
                      texte: Fr.referentiel.ajouter(texte),
                      detail: Fr.referentiel.ajouterDetail,
                      ajout: true,
                      enCours: _ajout,
                      onTap: _ajout ? null : () => _ajouter(texte),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.texte,
    required this.onTap,
    this.detail,
    this.ajout = false,
    this.enCours = false,
  });

  final String texte;
  final String? detail;
  final VoidCallback? onTap;
  final bool ajout;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaces.x8),
      child: Material(
        color: ajout ? Couleurs.jauneDoux : Couleurs.carte,
        shape: formeContinue(Rayons.normal),
        child: InkWell(
          customBorder: formeContinue(Rayons.normal),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Mesures.zoneTactile),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.x16,
                vertical: Espaces.x12,
              ),
              child: Row(
                children: [
                  if (ajout) ...[
                    enCours
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Couleurs.encre,
                            ),
                          )
                        : const Icon(Icons.add, color: Couleurs.encre),
                    const SizedBox(width: Espaces.x12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(texte, style: Typo.labelLg),
                        if (detail != null)
                          Text(
                            detail!,
                            style: Typo.labelSm.copyWith(
                              color: Couleurs.attenue,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
