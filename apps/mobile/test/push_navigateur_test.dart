import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/donnees/push_navigateur.dart';
import 'package:reviz/ecrans/notifications_reglages.dart';
import 'package:reviz/i18n/fr.dart';

/// Le Web Push de l'app web installée (iPhone sans compte Apple) : ce que dit
/// la carte selon où en est le navigateur.
Future<void> _poser(WidgetTester t, Widget enfant) => t.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: enfant)),
    ),
  ),
);

void main() {
  test('hors du web, pas de Web Push : Firebase s’en charge', () {
    expect(etatPushNavigateur(), EtatPushNavigateur.nonSupporte);
  });

  testWidgets('iPhone dans Safari : installer d’abord, pas de bouton', (
    t,
  ) async {
    await _poser(
      t,
      const CartePushNavigateur(etat: EtatPushNavigateur.aInstaller),
    );
    expect(find.text(Fr.notifications.webInstallerTitre), findsOneWidget);
    expect(find.textContaining('Sur l’écran d’accueil'), findsOneWidget);
    expect(find.text(Fr.notifications.webActiver), findsNothing);
  });

  testWidgets('app installée : un bouton pour activer', (t) async {
    await _poser(
      t,
      const CartePushNavigateur(etat: EtatPushNavigateur.aDemander),
    );
    expect(find.text(Fr.notifications.webActiverTitre), findsOneWidget);
    expect(find.text(Fr.notifications.webActiver), findsOneWidget);
  });

  testWidgets('refusé : le chemin des réglages de l’iPhone', (t) async {
    await _poser(t, const CartePushNavigateur(etat: EtatPushNavigateur.refuse));
    expect(find.textContaining('Réglages de l’iPhone'), findsOneWidget);
    expect(find.text(Fr.notifications.webActiver), findsNothing);
  });

  testWidgets('sur l’accueil, l’invitation s’écarte', (t) async {
    var ecartee = false;
    await _poser(
      t,
      CartePushNavigateur(
        etat: EtatPushNavigateur.aDemander,
        plusTard: () => ecartee = true,
      ),
    );
    await t.tap(find.text(Fr.notifications.webPlusTard));
    expect(ecartee, isTrue);
  });

  testWidgets('tient à 320 px', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await _poser(
      t,
      const CartePushNavigateur(etat: EtatPushNavigateur.aInstaller),
    );
    expect(t.takeException(), isNull);
  });
}
