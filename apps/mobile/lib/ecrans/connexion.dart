import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/champ.dart';
import '../donnees/config.dart';
import '../donnees/supabase.dart';
import '../i18n/fr.dart';
import '../metier/otp.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Écran de connexion.
///
/// **Code par email**, et non lien magique : dans une application, un lien
/// reçu par mail s'ouvre dans le navigateur et la session s'installe là, pas
/// ici. Le code se saisit sur place.
///
/// Sa longueur n'est pas codée en dur : ce projet Supabase en émet huit, un
/// autre en émettrait six. Voir `metier/otp.dart`.
///
/// Toute la machinerie web — `reviz://auth`, l'onglet personnalisé, la route
/// `/auth/rappel` — devient inutile : `supabase_flutter` fait l'échange dans
/// l'application.
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key});

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

enum _Etape { email, code }

class _EcranConnexionState extends State<EcranConnexion> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  _Etape _etape = _Etape.email;
  bool _enCours = false;
  String? _erreur;

  /// Compte à rebours avant de pouvoir redemander un code : Supabase limite
  /// la cadence, mieux vaut le dire que se faire refuser.
  int _attente = 0;
  Timer? _minuteur;

  @override
  void dispose() {
    _minuteur?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _lancerAttente() {
    setState(() => _attente = 60);
    _minuteur?.cancel();
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _attente--);
      if (_attente <= 0) t.cancel();
    });
  }

  bool _emailPlausible(String v) {
    // Volontairement permissif : refuser une adresse valide est plus grave
    // qu'accepter une faute de frappe, que le serveur verra de toute façon.
    final t = v.trim();
    return t.length >= 5 && t.contains('@') && t.contains('.');
  }

  Future<void> _envoyerCode() async {
    final email = _email.text.trim().toLowerCase();
    if (!_emailPlausible(email)) {
      return setState(() => _erreur = Fr.connexion.emailInvalide);
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await supabase.auth.signInWithOtp(email: email, shouldCreateUser: true);
      if (!mounted) return;
      setState(() => _etape = _Etape.code);
      _lancerAttente();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erreur = Fr.connexion.envoiImpossible);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _verifierCode() async {
    final code = chiffresSeulement(_code.text);
    if (!codePlausible(code)) {
      return setState(() => _erreur = Fr.connexion.codeIncomplet);
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await supabase.auth.verifyOTP(
        email: _email.text.trim().toLowerCase(),
        token: code,
        type: OtpType.email,
      );
      // La redirection est faite par le routeur, qui écoute
      // `onAuthStateChange` : cet écran n'a pas à savoir où aller ensuite.
    } on AuthException catch (_) {
      if (!mounted) return;
      setState(() => _erreur = Fr.connexion.codeInvalide);
    } catch (_) {
      if (!mounted) return;
      setState(() => _erreur = Fr.erreurs.inconnue);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.ecran,
                vertical: Espaces.x32,
              ),
              children: [
                Text(
                  _etape == _Etape.email
                      ? Fr.connexion.titre
                      : Fr.connexion.titreCode,
                  style: Typo.headlineXl,
                ),
                const SizedBox(height: Espaces.x8),
                Text(
                  _etape == _Etape.email
                      ? Fr.connexion.sousTitre
                      : Fr.connexion.sousTitreCode(_email.text.trim()),
                  style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x32),

                if (_etape == _Etape.email) ..._etapeEmail() else ..._etapeCode(),

                if (_erreur != null) ...[
                  const SizedBox(height: Espaces.x16),
                  Text(
                    _erreur!,
                    style: Typo.labelSm.copyWith(color: Couleurs.danger),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _etapeEmail() => [
    // Google reste affiché mais inerte sans identifiant client : le masquer
    // ferait croire que l'application ne le propose pas, l'activer donnerait
    // une erreur opaque.
    Bouton(
      libelle: Fr.connexion.avecGoogle,
      icone: Icons.account_circle,
      variante: VarianteBouton.secondaire,
      onTap: Config.googleWebClientId.isEmpty
          ? null
          : () => setState(
              () => _erreur = 'Connexion Google : à brancher (phase 4 bis).',
            ),
    ),
    if (Config.googleWebClientId.isEmpty) ...[
      const SizedBox(height: Espaces.x4),
      Text(
        Fr.connexion.googleIndisponible,
        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
        textAlign: TextAlign.center,
      ),
    ],

    const SizedBox(height: Espaces.x24),
    Row(
      children: [
        const Expanded(child: Divider(color: Couleurs.bordure)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espaces.x12),
          child: Text(
            Fr.connexion.ou,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          ),
        ),
        const Expanded(child: Divider(color: Couleurs.bordure)),
      ],
    ),
    const SizedBox(height: Espaces.x24),

    Champ(
      libelle: Fr.connexion.labelEmail,
      aide: Fr.connexion.aideEmail,
      controleur: _email,
      typeClavier: TextInputType.emailAddress,
      actif: !_enCours,
      onSoumis: (_) => _envoyerCode(),
    ),
    const SizedBox(height: Espaces.x16),
    Bouton(
      libelle: _enCours ? Fr.commun.chargement : Fr.connexion.recevoirCode,
      icone: Icons.mail_outline,
      onTap: _enCours ? null : _envoyerCode,
    ),
  ];

  List<Widget> _etapeCode() => [
    Champ(
      libelle: Fr.connexion.titreCode,
      aide: Fr.connexion.codeAstuce,
      controleur: _code,
      typeClavier: TextInputType.number,
      autoFocus: true,
      maxCaracteres: longueurCodeMax,
      actif: !_enCours,
      onChange: (v) {
        // On ne garde que les chiffres, sans les tronquer à une longueur
        // supposée : ce projet Supabase émet **huit** chiffres, et couper à
        // six ferait refuser un code parfaitement valide. Pas de validation
        // automatique pour la même raison — on ne sait pas quand le code est
        // complet.
        final code = chiffresSeulement(v);
        if (v != code) {
          _code.text = code;
          _code.selection = TextSelection.collapsed(offset: code.length);
        }
      },
      onSoumis: (_) => _verifierCode(),
    ),
    const SizedBox(height: Espaces.x16),
    Bouton(
      libelle: _enCours ? Fr.commun.chargement : Fr.connexion.valider,
      icone: Icons.check,
      onTap: _enCours ? null : _verifierCode,
    ),
    const SizedBox(height: Espaces.x12),
    Carte(
      petite: true,
      enfants: [
        Bouton(
          libelle: _attente > 0
              ? Fr.connexion.renvoyerDans(_attente)
              : Fr.connexion.renvoyer,
          variante: VarianteBouton.secondaire,
          icone: Icons.refresh,
          onTap: _attente > 0 || _enCours ? null : _envoyerCode,
        ),
        TextButton(
          onPressed: _enCours
              ? null
              : () => setState(() {
                  _etape = _Etape.email;
                  _code.clear();
                  _erreur = null;
                }),
          child: Text(
            Fr.connexion.changerEmail,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          ),
        ),
      ],
    ),
    const SizedBox(height: Espaces.x8),
    // Coller depuis le presse-papiers : le geste le plus courant après avoir
    // ouvert le mail.
    TextButton.icon(
      onPressed: _enCours
          ? null
          : () async {
              final donnees = await Clipboard.getData(Clipboard.kTextPlain);
              final code = extraireCode(
                donnees?.text ?? '',
                longueur: longueurCodeMax,
              );
              if (code.isEmpty) return;
              _code.text = code;
              // Collé depuis le mail : la suite de chiffres est complète, on
              // peut valider tout de suite.
              if (codePlausible(code)) _verifierCode();
            },
      icon: const Icon(Icons.content_paste, size: 18),
      label: const Text('Coller le code'),
    ),
  ];
}
