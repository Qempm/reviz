// Hors du web (l'APK) : pas de Web Push, Firebase s'en charge (push.dart).

import 'push_navigateur.dart';

EtatPushNavigateur etatPushNavigateur() => EtatPushNavigateur.nonSupporte;

Future<String> demanderPushNavigateur() async => 'denied';

Future<String?> abonnerPushNavigateur(String cle) async => null;

Future<String?> desabonnerPushNavigateur() async => null;

void ecouterPushNavigateur(void Function(String json) rappel) {}
