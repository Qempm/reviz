import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/chargement.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/notifications.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Le centre de notifications : tout ce qui est arrivé à l'étudiant.
///
/// Un cours prêt, une copie corrigée, un paiement confirmé, une commission,
/// la ligue de la semaine. Ce qu'un push annonce s'y retrouve — et ce qu'il
/// n'annonce pas (push coupé, web, téléphone sans Firebase) aussi : c'est la
/// trace qui ne dépend de rien.
class EcranNotifications extends ConsumerWidget {
  const EcranNotifications({super.key, this.maintenant});

  /// Pour les tests et les aperçus : l'heure à laquelle « il y a » se calcule.
  final DateTime? maintenant;

  Future<void> _toutLire(WidgetRef ref) async {
    try {
      await ref.read(depotNotificationsProvider).marquerLues();
    } catch (_) {}
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final nonLues = ref.watch(nonLuesProvider);

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.notifications.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.accueil),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
        actions: [
          if (nonLues > 0)
            IconButton(
              onPressed: () => _toutLire(ref),
              icon: const Icon(Icons.done_all_rounded, color: Couleurs.encre),
              tooltip: Fr.notifications.toutLu,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (notifications) {
              AsyncData(:final value) when value.isEmpty => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  mascotte: EtatMascotte.curieux,
                  titre: Fr.notifications.videTitre,
                  description: Fr.notifications.videDetail,
                ),
              ),
              AsyncData(:final value) => RefreshIndicator(
                color: Couleurs.encre,
                onRefresh: () => ref.refresh(notificationsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    Espaces.ecran,
                    Espaces.x8,
                    Espaces.ecran,
                    Espaces.x32,
                  ),
                  itemCount: value.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: Espaces.x8),
                  itemBuilder: (context, i) => _Ligne(
                    notification: value[i],
                    maintenant: maintenant ?? DateTime.now(),
                  ),
                ),
              ),
              AsyncError() => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  mascotte: EtatMascotte.oups,
                  titre: Fr.erreurs.chargementImpossible,
                  description: Fr.erreurs.chargementDetail,
                  action: Bouton(
                    libelle: Fr.commun.reessayer,
                    icone: Icons.refresh,
                    onTap: () => ref.invalidate(notificationsProvider),
                  ),
                ),
              ),
              _ => const Chargement.liste(),
            },
          ),
        ),
      ),
    );
  }
}

class _Ligne extends ConsumerWidget {
  const _Ligne({required this.notification, required this.maintenant});

  final NotificationReviz notification;
  final DateTime maintenant;

  /// L'icône de chaque catégorie, sur sa teinte. Le jaune reste à la
  /// marque : une bonne nouvelle d'argent, une copie corrigée.
  static (IconData, Color, Color) _apparence(String kind) => switch (kind) {
    'cours_pret' => (
      Icons.auto_stories_rounded,
      Couleurs.jauneDoux,
      Couleurs.surJaune,
    ),
    'correction_prete' => (
      Icons.fact_check_rounded,
      Couleurs.jauneDoux,
      Couleurs.surJaune,
    ),
    'paiement_reussi' || 'commission_recue' || 'retrait_paye' => (
      Icons.payments_rounded,
      Couleurs.jauneDoux,
      Couleurs.surJaune,
    ),
    'carte_verifiee' => (
      Icons.verified_rounded,
      Couleurs.bleuDoux,
      Couleurs.encre,
    ),
    'ligue_cloturee' => (
      Icons.emoji_events_rounded,
      Couleurs.bleuDoux,
      Couleurs.encre,
    ),
    _ => (
      Icons.error_outline_rounded,
      Couleurs.dangerDoux,
      Couleurs.surDangerDoux,
    ),
  };

  Future<void> _ouvrir(BuildContext context, WidgetRef ref) async {
    if (!notification.lue) {
      // Sans attendre le serveur : la ligne s'éteint tout de suite, la
      // liste se relira au retour.
      ref
          .read(depotNotificationsProvider)
          .marquerLues([notification.id])
          .then((_) => ref.invalidate(notificationsProvider))
          .catchError((_) {});
    }
    context.descendre(cheminDe(notification.lien));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icone, fond, teinte) = _apparence(notification.kind);
    final texte = notification.texte;
    final lue = notification.lue;

    return Material(
      color: lue ? Couleurs.fond : Couleurs.carte,
      shape: formeContinue(Rayons.carte),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _ouvrir(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(Espaces.x12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: fond,
                  shape: formeContinue(Rayons.normal),
                ),
                child: Icon(icone, color: teinte, size: 24),
              ),
              const SizedBox(width: Espaces.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            texte.titre,
                            style: Typo.labelLg.copyWith(
                              fontWeight: lue
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!lue) ...[
                          const SizedBox(width: Espaces.x8),
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Couleurs.orangeProfond,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: Espaces.x4),
                    Text(
                      texte.corps,
                      style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                    ),
                    const SizedBox(height: Espaces.x4),
                    Text(
                      Fr.notifications.ilYa(
                        maintenant.difference(notification.creeLe),
                      ),
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
