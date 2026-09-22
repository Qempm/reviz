import 'package:flutter/material.dart';
import 'jetons.dart';
import 'typographie.dart';

/// `ThemeData` de Reviz, assemblé depuis les jetons.
final ThemeData themeReviz = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Couleurs.cream,
  fontFamily: 'Nunito Sans',
  colorScheme: const ColorScheme.light(
    surface: Couleurs.cream,
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
  // Pas de mode sombre au MVP : Stitch n'en a pas généré.
  brightness: Brightness.light,
);
