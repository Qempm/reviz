// Les notifications de l'app web installée (Web Push), vues depuis Dart.
//
// Sur iPhone sans compte développeur Apple, Reviz est l'app web installée
// depuis Safari : depuis iOS 16.4, elle reçoit des notifications par le Web
// Push standard. Le travail se fait dans la page (`window.revizPush`,
// `apps/mobile/web/index.html`) et dans le service worker (`sw.js`) ; ce
// fichier n'est que la passerelle, compilée seulement pour le web — l'APK
// reçoit la version vide.

export 'push_navigateur_vide.dart'
    if (dart.library.js_interop) 'push_navigateur_web.dart';

/// Où en est le navigateur.
enum EtatPushNavigateur {
  /// Ni service worker ni Web Push : un vieux navigateur, ou l'APK.
  nonSupporte,

  /// iPhone, dans Safari : il faut d'abord installer l'app sur l'écran
  /// d'accueil — Apple ne donne le push qu'à l'app installée.
  aInstaller,

  /// Possible, pas encore demandé.
  aDemander,
  accorde,

  /// Refusé : seuls les réglages du téléphone peuvent revenir dessus.
  refuse,
}
