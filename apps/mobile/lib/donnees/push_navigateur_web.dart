// Dans le navigateur : appelle `window.revizPush` (apps/mobile/web/index.html).

import 'dart:js_interop';

import 'push_navigateur.dart';

@JS('revizPush.etat')
external JSString _etat();

@JS('revizPush.demander')
external JSPromise<JSString> _demander();

@JS('revizPush.abonner')
external JSPromise<JSString> _abonner(JSString cle);

@JS('revizPush.desabonner')
external JSPromise<JSString> _desabonner();

@JS('revizPush.ecouter')
external void _ecouter(JSFunction rappel);

EtatPushNavigateur etatPushNavigateur() {
  try {
    return switch (_etat().toDart) {
      'a-installer' => EtatPushNavigateur.aInstaller,
      'a-demander' => EtatPushNavigateur.aDemander,
      'accorde' => EtatPushNavigateur.accorde,
      'refuse' => EtatPushNavigateur.refuse,
      _ => EtatPushNavigateur.nonSupporte,
    };
  } catch (_) {
    // `window.revizPush` absent (une page de test) : comme un vieux navigateur.
    return EtatPushNavigateur.nonSupporte;
  }
}

/// À appeler **tout de suite** dans le toucher de l'étudiant, sans rien
/// attendre avant : Safari refuse une demande qui ne suit pas un geste.
Future<String> demanderPushNavigateur() async {
  try {
    return (await _demander().toDart).toDart;
  } catch (_) {
    return 'denied';
  }
}

/// L'abonnement du navigateur, en JSON (`endpoint`, `keys`), ou `null`.
Future<String?> abonnerPushNavigateur(String cle) async {
  try {
    return (await _abonner(cle.toJS).toDart).toDart;
  } catch (_) {
    return null;
  }
}

/// Rend l'adresse de l'abonnement retiré, pour l'oublier côté serveur.
Future<String?> desabonnerPushNavigateur() async {
  try {
    final adresse = (await _desabonner().toDart).toDart;
    return adresse.isEmpty ? null : adresse;
  } catch (_) {
    return null;
  }
}

/// Les messages du service worker : un push reçu, une notification touchée.
void ecouterPushNavigateur(void Function(String json) rappel) {
  try {
    _ecouter(((JSString m) => rappel(m.toDart)).toJS);
  } catch (_) {}
}
