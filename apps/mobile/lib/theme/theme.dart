import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'jetons.dart';
import 'typographie.dart';

/// `ThemeData` de Reviz, assemblé depuis les jetons.
final ThemeData themeReviz = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Couleurs.fond,
  fontFamily: familleTexte,
  colorScheme: const ColorScheme.light(
    surface: Couleurs.fond,
    onSurface: Couleurs.encre,
    // Le jaune est `primaryContainer`, pas `primary` : `primary` sert au
    // texte. Confondre les deux donne un CTA brun.
    primary: Couleurs.texteAccent,
    onPrimary: Colors.white,
    primaryContainer: Couleurs.jaune,
    onPrimaryContainer: Couleurs.surJaune,
    secondary: Couleurs.orange,
    onSecondary: Colors.white,
    error: Couleurs.danger,
    onError: Colors.white,
    outline: Couleurs.bordure,
  ),
  textTheme: TextTheme(
    displayLarge: Typo.displayHeros,
    headlineLarge: Typo.headlineXl,
    headlineMedium: Typo.headlineLg,
    headlineSmall: Typo.headlineMd,
    titleMedium: Typo.headlineSm,
    bodyLarge: Typo.bodyLg,
    bodyMedium: Typo.bodyMd,
    labelLarge: Typo.labelLg,
    labelMedium: Typo.labelMd,
    labelSmall: Typo.labelSm,
  ),
  // Les barres d'application se posent sur le fond, sans ombre ni teinte au
  // défilement — Material 3 les assombrit par défaut dès qu'une liste passe
  // dessous, ce qui salit le crème.
  appBarTheme: AppBarTheme(
    backgroundColor: Couleurs.fond,
    foregroundColor: Couleurs.encre,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: Typo.headlineSm.copyWith(fontSize: 19),
  ),
  // Le jaune de marque partout où Material mettrait sa couleur primaire, qui
  // est ici un gris d'encre réservé au texte.
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Couleurs.jaune,
    circularTrackColor: Couleurs.surfaceConteneur,
    linearTrackColor: Couleurs.surfaceConteneur,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: const WidgetStatePropertyAll(Colors.white),
    trackColor: WidgetStateProperty.resolveWith(
      (etats) => etats.contains(WidgetState.selected)
          ? Couleurs.jaune
          : Couleurs.surfaceHaute,
    ),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: Couleurs.encre,
    contentTextStyle: Typo.labelMd.copyWith(color: Colors.white),
    behavior: SnackBarBehavior.floating,
    shape: formeContinue(Rayons.normal),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Couleurs.encre,
    selectionColor: Couleurs.jauneDoux,
    selectionHandleColor: Couleurs.jaune,
  ),
  // Une page qu'on ouvre glisse depuis la droite, et repart vers la droite
  // au retour — le geste d'iOS, sur Android aussi. La transition par défaut
  // d'Android (fondu montant) ne dit pas « je suis descendu d'un niveau » ;
  // le glissement, si, et il se rejoue au doigt depuis le bord de l'écran.
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  ),
  // Pas de mode sombre au MVP : Stitch n'en a pas généré.
  brightness: Brightness.light,
);
