import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../donnees/api.dart';
import '../donnees/push_navigateur.dart';
import '../donnees/reglages.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/notifications.dart';
import '../metier/plateforme.dart';
import '../metier/rappels.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Les réglages des notifications, depuis Profil.
///
/// Deux familles, rangées là où elles vivent :
///
///  - **les rappels**, programmés par ce téléphone (série, examens, fin de
///    pack) — réglés sur l'appareil, comme eux ;
///  - **ce qui m'arrive**, le push envoyé par le serveur, par catégorie —
///    réglé sur le compte, puisque c'est le serveur qui décide d'envoyer.
///
/// Le centre de notifications, lui, garde tout quoi qu'on coupe ici.
class EcranReglagesNotifications extends ConsumerStatefulWidget {
  const EcranReglagesNotifications({super.key});

  @override
  ConsumerState<EcranReglagesNotifications> createState() => _EtatReglages();
}

class _EtatReglages extends ConsumerState<EcranReglagesNotifications> {
  /// `false` : coupées sur le téléphone. `null` : on ne sait pas (web, test).
  bool? _autorisees;

  /// Le choix en cours d'enregistrement, montré tout de suite.
  PrefsPush? _prefsLocales;

  @override
  void initState() {
    super.initState();
    _lirePermission();
  }

  Future<void> _lirePermission() async {
    final ok = await ref.read(serviceRappelsProvider).autorisees();
    if (mounted) setState(() => _autorisees = ok);
  }

  Future<void> _autoriser() async {
    final ok = await ref.read(servicePushProvider).demanderPermission();
    if (mounted) setState(() => _autorisees = ok);
  }

  Future<void> _changerPush(PrefsPush avant, PrefsPush apres) async {
    setState(() => _prefsLocales = apres);
    final reponse = await ref
        .read(depotNotificationsProvider)
        .changerPrefs(ref.read(apiProvider), apres);
    if (!mounted) return;
    switch (reponse) {
      case ReponseSucces():
        ref.invalidate(prefsPushProvider);
      case ReponseEchec():
        setState(() => _prefsLocales = avant);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Fr.notifications.enregistrementImpossible)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = Fr.notifications;
    final rappels = ref.watch(reglagesRappelsProvider);
    final pushPossible = ref.watch(pushDisponibleProvider).value ?? false;
    final prefsServeur = ref.watch(prefsPushProvider).value;
    final prefs = _prefsLocales ?? prefsServeur ?? const PrefsPush();

    void changerRappels(OptionsRappels o) =>
        ref.read(reglagesRappelsProvider.notifier).changer(o);

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(f.reglagesTitre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.profil),
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
              padding: const EdgeInsets.fromLTRB(
                Espaces.ecran,
                Espaces.x8,
                Espaces.ecran,
                Espaces.x32,
              ),
              children: [
                // Le web : le Web Push de l'app installée (iPhone sans
                // compte Apple), selon où en est le navigateur.
                if (ref.watch(etatPushNavigateurProvider) case final etat
                    when etat != EtatPushNavigateur.nonSupporte &&
                        etat != EtatPushNavigateur.accorde) ...[
                  CartePushNavigateur(etat: etat),
                  const SizedBox(height: Espaces.x16),
                ],

                if (_autorisees == false) ...[
                  Carte(
                    enfants: [
                      Text(f.bloquees, style: Typo.headlineSm),
                      Text(
                        f.bloqueesDetail,
                        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                      ),
                      Bouton(
                        libelle: f.autoriser,
                        icone: Icons.notifications_active_outlined,
                        onTap: _autoriser,
                      ),
                    ],
                  ),
                  const SizedBox(height: Espaces.x16),
                ],

                if (rappelsDisponibles) ...[
                  Carte(
                    enfants: [
                      Text(f.rappelsTitre, style: Typo.headlineMd),
                      Text(
                        f.rappelsDetail,
                        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                      ),
                      _Interrupteur(
                        titre: f.rappelSerie,
                        aide: f.rappelSerieAide,
                        valeur: rappels.serie,
                        onChanged: (v) =>
                            changerRappels(rappels.copier(serie: v)),
                      ),
                      if (rappels.serie)
                        _ChoixHeure(
                          heure: rappels.heureSerie,
                          onChanged: (h) =>
                              changerRappels(rappels.copier(heureSerie: h)),
                        ),
                      _Interrupteur(
                        titre: f.rappelExamens,
                        aide: f.rappelExamensAide,
                        valeur: rappels.examens,
                        onChanged: (v) =>
                            changerRappels(rappels.copier(examens: v)),
                      ),
                      _Interrupteur(
                        titre: f.rappelFinPack,
                        aide: f.rappelFinPackAide,
                        valeur: rappels.finPack,
                        onChanged: (v) =>
                            changerRappels(rappels.copier(finPack: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Espaces.x16),
                ],

                if (pushPossible)
                  Carte(
                    enfants: [
                      Text(f.pushTitre, style: Typo.headlineMd),
                      Text(
                        f.pushDetail,
                        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                      ),
                      for (final (categorie, titre, aide) in [
                        (
                          CategorieNotification.cours,
                          f.categorieCours,
                          f.categorieCoursAide,
                        ),
                        (
                          CategorieNotification.argent,
                          f.categorieArgent,
                          f.categorieArgentAide,
                        ),
                        (
                          CategorieNotification.compte,
                          f.categorieCompte,
                          f.categorieCompteAide,
                        ),
                        (
                          CategorieNotification.ligue,
                          f.categorieLigue,
                          f.categorieLigueAide,
                        ),
                      ])
                        _Interrupteur(
                          titre: titre,
                          aide: aide,
                          valeur: prefs.pour(categorie),
                          onChanged: (v) =>
                              _changerPush(prefs, prefs.avec(categorie, v)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une ligne et un `Switch`, comme les réglages du profil — et non un
/// `SwitchListTile`, que la carte (un `DecoratedBox`) masquerait.
/// La carte du Web Push : installer l'app d'abord (iPhone dans Safari),
/// activer, ou revenir sur un refus. Aussi posée sur l'accueil.
class CartePushNavigateur extends ConsumerWidget {
  const CartePushNavigateur({required this.etat, this.plusTard, super.key});

  final EtatPushNavigateur etat;

  /// Sur l'accueil seulement : l'invitation peut s'écarter.
  final VoidCallback? plusTard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = Fr.notifications;
    final (titre, detail) = switch (etat) {
      EtatPushNavigateur.aInstaller => (
        f.webInstallerTitre,
        f.webInstallerDetail,
      ),
      EtatPushNavigateur.refuse => (f.webRefuseTitre, f.webRefuseDetail),
      _ => (f.webActiverTitre, f.webActiverDetail),
    };

    Future<void> activer() async {
      // Tout de suite, dans le toucher : Safari refuse sinon.
      final ok = await ref.read(servicePushProvider).demanderPermission();
      ref.invalidate(etatPushNavigateurProvider);
      ref.invalidate(pushDisponibleProvider);
      if (ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.webActivees)));
      }
    }

    return Carte(
      enfants: [
        Text(titre, style: Typo.headlineSm),
        Text(detail, style: Typo.bodyMd.copyWith(color: Couleurs.attenue)),
        if (etat == EtatPushNavigateur.aDemander)
          Bouton(
            libelle: f.webActiver,
            icone: Icons.notifications_active_outlined,
            onTap: activer,
          ),
        if (plusTard != null)
          TextButton(onPressed: plusTard, child: Text(f.webPlusTard)),
      ],
    );
  }
}

class _Interrupteur extends StatelessWidget {
  const _Interrupteur({
    required this.titre,
    required this.aide,
    required this.valeur,
    required this.onChanged,
  });

  final String titre;
  final String aide;
  final bool valeur;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titre, style: Typo.labelLg),
                Text(
                  aide,
                  style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaces.x8),
          Switch(
            value: valeur,
            onChanged: onChanged,
            activeTrackColor: Couleurs.jaune,
            activeThumbColor: Couleurs.carte,
          ),
        ],
      ),
    );
  }
}

/// L'heure du rappel du soir : de 6 h à 23 h, en pas d'une heure.
class _ChoixHeure extends StatelessWidget {
  const _ChoixHeure({required this.heure, required this.onChanged});

  final int heure;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final f = Fr.notifications;
    return Row(
      children: [
        const SizedBox(width: Espaces.x12),
        const Icon(Icons.schedule_rounded, size: 20, color: Couleurs.attenue),
        const SizedBox(width: Espaces.x8),
        Expanded(child: Text(f.heureSerie, style: Typo.labelMd)),
        DropdownButton<int>(
          value: heure.clamp(heureSerieMin, heureSerieMax),
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(Rayons.normal),
          style: Typo.labelLg.copyWith(color: Couleurs.encre),
          items: [
            for (var h = heureSerieMin; h <= heureSerieMax; h++)
              DropdownMenuItem(value: h, child: Text(f.heure(h))),
          ],
          onChanged: (h) {
            if (h != null) onChanged(h);
          },
        ),
      ],
    );
  }
}
