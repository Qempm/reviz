import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/mascotte.dart';
import '../donnees/api.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Le suivi d'un paiement, pendant que l'étudiant paie sur la page FedaPay.
///
/// La demande est partie sur le téléphone de l'étudiant (`EcranPayer`) : il
/// la valide avec son code secret, souvent dans une fenêtre du système
/// par-dessus Reviz. L'écran interroge `/api/payments/status` toutes les
/// quatre secondes, et **tout de suite** quand l'application revient au
/// premier plan — c'est le moment où il attend une réponse. Le serveur, lui, relit la transaction
/// chez FedaPay tant qu'elle n'est pas tranchée : le pack s'active même si le
/// webhook s'est perdu.
///
/// Au bout de dix minutes sans issue, l'écran arrête d'interroger et le dit,
/// plutôt que de tourner indéfiniment : un paiement confirmé plus tard
/// active quand même le pack, par le webhook.
class EcranPaiement extends ConsumerStatefulWidget {
  const EcranPaiement({
    super.key,
    required this.paiementId,
    this.intervalle = const Duration(seconds: 4),
    this.patience = const Duration(minutes: 10),
  });

  final String paiementId;

  /// Réglables pour les tests ; les valeurs par défaut sont celles de l'app.
  final Duration intervalle;
  final Duration patience;

  @override
  ConsumerState<EcranPaiement> createState() => _EcranPaiementState();
}

enum _Etape { attente, reussi, echoue, long }

class _EcranPaiementState extends ConsumerState<EcranPaiement>
    with WidgetsBindingObserver {
  _Etape _etape = _Etape.attente;
  Timer? _minuteur;

  /// Le temps d'attente, compté en tours de minuteur et non à l'horloge :
  /// c'est ce qu'on a réellement passé à interroger.
  Duration _attendu = Duration.zero;
  late Duration _limite = widget.patience;
  bool _enVol = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _demarrer();
  }

  void _demarrer() {
    _minuteur?.cancel();
    _minuteur = Timer.periodic(widget.intervalle, (_) {
      _attendu += widget.intervalle;
      _interroger();
    });
    _interroger();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    // Retour de la page FedaPay : c'est maintenant que l'étudiant regarde.
    if (etat == AppLifecycleState.resumed && _etape == _Etape.attente) {
      _interroger();
    }
  }

  Future<void> _interroger() async {
    if (_enVol || _etape == _Etape.reussi || _etape == _Etape.echoue) return;
    _enVol = true;

    final reponse = await ref
        .read(depotBoutiqueProvider)
        .suivrePaiement(ref.read(apiProvider), widget.paiementId);

    _enVol = false;
    if (!mounted) return;

    final statut = switch (reponse) {
      ReponseSucces(:final data) => data,
      // Une coupure réseau n'est pas une issue : on réessaie au tour suivant.
      ReponseEchec() => 'pending',
    };

    if (statut == 'success') {
      _terminer(_Etape.reussi);
      // L'accès a changé : la boutique, l'accueil et le compteur de
      // corrections doivent le relire.
      ref.invalidate(boutiqueProvider);
      ref.invalidate(accueilProvider);
      ref.invalidate(profilProvider);
    } else if (statut == 'failed') {
      _terminer(_Etape.echoue);
    } else if (_attendu >= _limite) {
      _terminer(_Etape.long);
    }
  }

  void _terminer(_Etape etape) {
    _minuteur?.cancel();
    setState(() => _etape = etape);
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (mascotte, titre, detail) = switch (_etape) {
      _Etape.attente => (
        EtatMascotte.reflexion,
        Fr.boutique.attenteTitre,
        Fr.boutique.attenteDetail,
      ),
      _Etape.reussi => (
        EtatMascotte.bravo,
        Fr.boutique.reussiTitre,
        Fr.boutique.reussiDetail,
      ),
      _Etape.echoue => (
        EtatMascotte.courage,
        Fr.boutique.echecTitre,
        Fr.boutique.echecDetail,
      ),
      _Etape.long => (
        EtatMascotte.dodo,
        Fr.boutique.longTitre,
        Fr.boutique.longDetail,
      ),
    };

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.boutique),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: ListView(
              padding: const EdgeInsets.all(Espaces.ecran),
              children: [
                const SizedBox(height: Espaces.x24),
                Center(
                  child: Mascotte(
                    // Une clé par étape : le panthéreau refait son entrée
                    // quand l'issue tombe, au lieu de changer de pose en
                    // silence.
                    key: ValueKey(_etape),
                    etat: mascotte,
                    taille: 160,
                  ),
                ),
                const SizedBox(height: Espaces.x20),
                Text(
                  titre,
                  style: Typo.headlineLg,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Espaces.x8),
                Text(
                  detail,
                  style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Espaces.x32),
                ..._actions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    switch (_etape) {
      // Rien à faire ici : la demande est sur le téléphone de l'étudiant.
      case _Etape.attente:
        return const [];
      case _Etape.reussi:
        return [
          Bouton(
            libelle: Fr.boutique.commencer,
            icone: Icons.bolt,
            // Changer d'onglet, pas empiler : la boutique et ce suivi n'ont
            // plus de raison d'être sous l'accueil.
            onTap: () => context.go(Chemins.accueil),
          ),
        ];
      case _Etape.echoue:
        return [
          // L'écran de paiement est dessous, numéro et opérateur gardés :
          // réessayer, c'est y revenir et appuyer une seconde fois.
          Bouton(
            libelle: Fr.boutique.reessayer,
            icone: Icons.refresh,
            onTap: () => context.remonter(Chemins.boutique),
          ),
        ];
      case _Etape.long:
        return [
          Bouton(
            libelle: Fr.boutique.verifier,
            icone: Icons.refresh,
            onTap: () {
              // Une minute de plus, pas dix : l'étudiant a demandé à voir,
              // pas à attendre de nouveau aussi longtemps.
              _attendu = Duration.zero;
              _limite = const Duration(minutes: 1);
              setState(() => _etape = _Etape.attente);
              _demarrer();
            },
          ),
        ];
    }
  }
}
