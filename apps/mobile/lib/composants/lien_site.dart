import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../donnees/config.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Les pages publiques du site que l'application montre sans les recopier.
enum PageSite {
  conditions('/conditions'),
  confidentialite('/confidentialite');

  const PageSite(this.chemin);

  final String chemin;

  /// L'adresse sur le serveur de l'application : la production dans l'APK,
  /// l'origine de la page dans le navigateur (`Config.apiBase`).
  Uri get adresse => Uri.parse('${Config.apiBase}$chemin');
}

/// Une mention qui renvoie à une page du site : « En créant ton compte, tu
/// acceptes les conditions d'utilisation et de vente ».
///
/// Toute la ligne est la zone tactile, haute de 48 px au moins : un lien de
/// trois mots en petit corps serait introuvable sous le pouce. La page
/// s'ouvre dans le navigateur, qui la garde à jour sans nouvelle version de
/// l'application.
class LienSite extends StatelessWidget {
  const LienSite({
    required this.page,
    required this.lien,
    this.avant,
    this.centre = true,
    super.key,
  });

  final PageSite page;

  /// Les mots soulignés.
  final String lien;

  /// Ce qui précède le lien, en gris.
  final String? avant;

  final bool centre;

  Future<void> _ouvrir() async {
    // Pas de navigateur, ou lien refusé : rien à signaler à l'écran.
    try {
      await launchUrl(page.adresse, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final style = Typo.labelSm.copyWith(color: Couleurs.attenue);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: _ouvrir,
        borderRadius: BorderRadius.circular(Rayons.moyen),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Mesures.zoneTactile),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Espaces.x8,
              vertical: Espaces.x8,
            ),
            child: Align(
              alignment: centre ? Alignment.center : Alignment.centerLeft,
              widthFactor: 1,
              child: Text.rich(
                TextSpan(
                  children: [
                    if (avant != null) TextSpan(text: avant),
                    TextSpan(
                      text: lien,
                      style: style.copyWith(
                        color: Couleurs.encre,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
                style: style,
                textAlign: centre ? TextAlign.center : TextAlign.start,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
