# DESIGN.md — Système de design Reviz

> **Source de vérité.** Ce fichier est extrait du projet Stitch
> `projects/4246361917454252874` — « Reviz Gamified Design System » (design system
> `assets/38b8635e22484d04bdeb0a6b1c355c59`), le 8 septembre 2026.
>
> Les valeurs ci-dessous sont celles **réellement émises par Stitch** dans le
> `tailwind.config` embarqué de chaque écran généré et dans le markup HTML de ces
> écrans — pas celles recopiées à la main dans `CLAUDE.md`. En cas de conflit,
> ce fichier gagne. Les divergences avec `CLAUDE.md` sont listées au § 10.
>
> Écrans analysés : Tableau de bord, Session QCM, Feedback bonne réponse, Feedback
> mauvaise réponse, Récapitulatif fin de quiz, Ligue & Classement, Boutique des
> packs, Portefeuille & parrainage (8 écrans sur les 34 du projet).

---

## 1. Fondations

| Réglage | Valeur Stitch |
| --- | --- |
| Type d'appareil | `MOBILE` |
| Mode couleur | `LIGHT` (aucune variante sombre générée) |
| Variante de couleur | `FIDELITY` |
| Arrondi global | `ROUND_EIGHT` |
| Police titres / corps / labels | `NUNITO_SANS` → **Nunito Sans** |

### Couleurs sources (seeds) vs couleurs rendues

Stitch part de couleurs « seed » et les fait passer dans son moteur tonal
Material 3. **Les seeds ne sont pas ce qui s'affiche à l'écran.**

| Rôle | Seed fournie à Stitch | Valeur rendue et utilisée |
| --- | --- | --- |
| `customColor` / primaire | `#ffc300` | `primary-container: #ffc300` (inchangée) |
| `overrideSecondaryColor` | `#ff6b2c` | `secondary-container: #fe6a2b` |
| `overrideTertiaryColor` | `#cfe0ff` | `tertiary-container: #bccdeb` |
| `overrideNeutralColor` | `#1a1a1a` | `on-surface: #1c1b1b` |

C'est l'explication de la plupart des écarts du § 10 : les valeurs de `CLAUDE.md`
sont les **entrées**, pas les **sorties**.

---

## 2. Palette complète (telle qu'émise)

### Surfaces et texte

| Token | Hex | Usage observé |
| --- | --- | --- |
| `surface` / `background` | `#fcf9f8` | Fond de toutes les pages, header et nav en `/85`–`/95` + blur |
| `surface-container-lowest` | `#ffffff` | Toutes les cartes, options QCM, feuilles |
| `surface-container-low` | `#f6f3f2` | Encarts secondaires dans une carte |
| `surface-container` | `#f0eded` | Pilules neutres, pistes de barres de progression |
| `surface-container-high` | `#eae7e7` | Pistes de progression segmentées |
| `surface-container-highest` | `#e5e2e1` | Pistes désactivées |
| `surface-dim` | `#dcd9d9` | — |
| `surface-variant` | `#e5e2e1` | — |
| `on-surface` | `#1c1b1b` | Tout le texte principal |
| `on-surface-variant` | `#4f4632` | Texte secondaire, lettres de jours, onglets inactifs (**brun chaud, pas gris**) |
| `outline` | `#81765f` | Icônes de nav inactives |
| `outline-variant` | `#d3c5ab` | Bordures, points « jour à venir », arête tactile neutre |
| `inverse-surface` | `#313030` | Toasts |
| `inverse-on-surface` | `#f3f0ef` | Texte sur toast |
| `surface-tint` | `#785a00` | — |

### Jaune (famille primaire)

| Token | Hex | Usage observé |
| --- | --- | --- |
| `primary` | `#785a00` | **Couleur de texte / icône**, jamais un fond de CTA |
| `on-primary` | `#ffffff` | — |
| `primary-container` | `#ffc300` | **Le jaune Reviz.** Fond des CTA, remplissage de progression, podium n°1, badge XP, FAB « Réviser », onglet actif |
| `on-primary-container` | `#6d5200` | Texte et icônes sur jaune |
| `primary-fixed` | `#ffdf9a` | Jaune pâle : option QCM sélectionnée, pastilles |
| `primary-fixed-dim` | `#f8be00` | — |
| `on-primary-fixed` | `#251a00` | — |
| `on-primary-fixed-variant` | `#5a4300` | — |
| `inverse-primary` | `#f8be00` | — |

### Orange (famille secondaire)

| Token | Hex | Usage observé |
| --- | --- | --- |
| `secondary` | `#a83900` | Texte d'urgence, chiffres mis en avant |
| `on-secondary` | `#ffffff` | — |
| `secondary-container` | `#fe6a2b` | **L'orange Reviz.** Carte héros compte à rebours, jour de streak actif, badges de rang |
| `on-secondary-container` | `#5b1b00` | — |
| `secondary-fixed` | `#ffdbcf` | Pêche pâle : **bloc du podium n°3**, pilules d'info |
| `secondary-fixed-dim` | `#ffb59a` | — |
| `on-secondary-fixed` | `#380d00` | — |
| `on-secondary-fixed-variant` | `#802900` | Arête tactile sur pêche |

### Bleu (famille tertiaire)

| Token | Hex | Usage observé |
| --- | --- | --- |
| `tertiary` | `#4f5f79` | Pastilles d'index |
| `on-tertiary` | `#ffffff` | — |
| `tertiary-container` | `#bccdeb` | **Le bleu Reviz.** Bloc du podium n°2, anneau d'avatar n°2 |
| `on-tertiary-container` | `#475771` | — |
| `tertiary-fixed` | `#d4e3ff` | Bleu très clair, fonds d'encarts (souvent en `/30`) |
| `tertiary-fixed-dim` | `#b6c7e6` | — |
| `on-tertiary-fixed` | `#0a1c33` | — |
| `on-tertiary-fixed-variant` | `#374760` | — |

### Erreur

| Token | Hex | Usage observé |
| --- | --- | --- |
| `error` | `#ba1a1a` | **Mauvaise réponse** : segment de progression, pastille de correction |
| `on-error` | `#ffffff` | — |
| `error-container` | `#ffdad6` | Encart « ce qu'il fallait répondre » |
| `on-error-container` | `#93000a` | Texte sur cet encart, arête tactile rouge |

> ⚠️ **Il n'y a pas de vert de succès dans le design system, et c'est voulu.**
> Une bonne réponse est célébrée en jaune / orange, une mauvaise en `#ba1a1a`.
> Le `#22C55E` codé en dur dans le script d'un écran (bouton « Valider » qui passe
> au vert, arête `#15803D`) est une scorie : **ne pas le reprendre**.
> Arbitré le 8 septembre 2026 (§ 11) : la palette reste strictement chaude.

### Couleurs hors design system (marques tierces, littérales)

Opérateurs Mobile Money et WhatsApp, codés en dur dans les écrans concernés :
`#FFCC00` (MTN), `#FF7900` (Orange), `#00D2FF` / `#006699` (Moov),
`#25D366` / `#1EBE5B` / `#128C7E` (WhatsApp).

---

## 3. Typographie

Famille unique : **Nunito Sans** (Google Fonts, `ital,opsz,wght@0,6..12,400..900;1,6..12,400..900`).
Icônes : **Material Symbols Outlined**.

| Niveau | Taille | Interlignage | Graisse | Interlettrage |
| --- | --- | --- | --- | --- |
| `display-hero` | 44px | 48px | 800 | −0.02em |
| `display-hero-mobile` | 38px | 42px | 800 | −0.02em |
| `headline-xl` | 28px | 34px | 800 | −0.015em |
| `headline-lg` | 22px | 28px | 800 | −0.01em |
| `headline-md` | 18px | 24px | 800 | — |
| `headline-sm` | 16px | 22px | 700 | — |
| `body-lg` | 16px | 24px | 500 | — |
| `body-md` | 15px | 22px | 500 | — |
| `label-lg` | 16px | 20px | 700 | — |
| `label-md` | 14px | 18px | 700 | — |
| `label-sm` | 13px | 16px | 600 | — |
| `caption` | 11px | 14px | 700 | +0.04em |

Règles observées :

- `display-hero` / `display-hero-mobile` : XP, montants FCFA, chiffres de podium.
- `caption` est le seul niveau porté en majuscules (`uppercase tracking-wider`).
- Les libellés de la barre de navigation sont en `caption` (11px).

---

## 4. Espacement

Échelle nommée émise par Stitch (utilisée via `p-space-16`, `gap-space-12`, …) :

| Token | Valeur | Token | Valeur |
| --- | --- | --- | --- |
| `space-2` | 0.125rem (2px) | `space-20` | 1.25rem (20px) |
| `space-4` | 0.25rem (4px) | `space-24` | 1.5rem (24px) |
| `space-8` | 0.5rem (8px) | `space-32` | 2rem (32px) |
| `space-12` | 0.75rem (12px) | `space-40` | 2.5rem (40px) |
| `space-16` | 1rem (16px) | `space-48` | 3rem (48px) |
| `screen-margin-mobile` | 1rem (16px) | `screen-margin-tablet` | 1.5rem (24px) |

Fréquences réelles (8 écrans) : `space-12` (81), `space-4` (69), `space-8` (65),
`space-16` (31), `space-20` (12). Les gaps dominants sont `gap-space-4`,
`gap-space-8` et `gap-space-12` ; `gap-space-20` sépare les grandes sections.

Gabarit de page : `px-space-16`, `pt-16` (header de 64px), `pb-[96px]` au-dessus
de la barre de navigation (80px + safe area).

---

## 5. Rayons

⚠️ **Deux échelles coexistent dans Stitch.** Celle du front-matter de son
`designMd` n'est **pas** celle qu'il compile. La seconde est la bonne.

Échelle Tailwind réellement émise (le reste retombe sur les défauts Tailwind) :

| Classe | Valeur | Origine |
| --- | --- | --- |
| `rounded` | 0.25rem (4px) | Stitch |
| `rounded-lg` | 0.5rem (8px) | Stitch |
| `rounded-xl` | 0.75rem (12px) | Stitch |
| `rounded-full` | 9999px | Stitch |
| `rounded-sm` | 0.125rem (2px) | défaut Tailwind |
| `rounded-md` | 0.375rem (6px) | défaut Tailwind |
| `rounded-2xl` | 1rem (16px) | défaut Tailwind |
| `rounded-3xl` | 1.5rem (24px) | défaut Tailwind |

Usage réel (8 écrans, 294 occurrences) :
`rounded-full` 189 · `rounded-xl` 49 · `rounded-2xl` 24 · `rounded-lg` 14 ·
`rounded-[20px]` 6 · `rounded-md` 4 · `rounded-[16px]` 4 · `rounded-3xl` 2 ·
`rounded-[24px]` 1 · `rounded-[28px]` 1.

**Le rayon dominant des composants est donc 12px (`rounded-xl`), pas 20px.**
Le 20px n'apparaît que sur quelques grandes cartes, le 24px sur la carte héros,
le 28px sur la feuille modale.

---

## 6. Ombres et effet tactile

### Ombres d'ambiance

| Rôle | Valeur |
| --- | --- |
| Header collé | `0 4px 20px rgba(26,26,26,0.04)` |
| Carte standard | `0 4px 20px rgba(26,26,26,0.06)` |
| Carte moyenne | `0 4px 16px rgba(26,26,26,0.05)` |
| Élément flottant | `0 8px 24px rgba(26,26,26,0.06)` |
| Carte héros orange | `0 8px 24px rgba(254,106,43,0.22)` |
| Halo jaune | `0 8px 24px rgba(255,195,0,0.15)` · `0 2px 6px rgba(255,195,0,0.3)` |
| Barre de navigation | `0 -8px 32px rgba(26,26,26,0.06)` |

`shadow-sm` (59 occurrences) et `shadow-md` (19) de Tailwind sont largement
utilisés tels quels.

### Arêtes tactiles (« bouton poussoir »)

Signature visuelle de Reviz : une ombre pleine sans flou sous l'élément, qui se
réduit à l'appui.

| Sur fond | Arête | Occurrences |
| --- | --- | --- |
| `primary-container` `#ffc300` | `#d9a400` | 32 |
| `outline-variant` `#d3c5ab` | `#d3c5ab` | 9 |
| `secondary-container` `#fe6a2b` | `#d94e15` | 2 |
| `secondary-fixed` `#ffdbcf` | `#802900` | 1 |
| `error` `#ba1a1a` | `#93000a` | 1 |

Profondeurs : `0 4px 0` (CTA, FAB, onglet actif), `0 3px 0` (médaillons),
`0 2px 0` (pilules, petits marqueurs), `0 1px 0` (état pressé).

Motif d'interaction canonique :

```
shadow-[0_4px_0_#d9a400] active:translate-y-[2px] active:shadow-[0_2px_0_#d9a400] transition-all
```

---

## 7. Composants (mesures relevées dans le markup)

### Bouton principal (CTA)

Deux variantes coexistaient dans les écrans générés. **La variante A est
canonique** (arbitrage du 8 septembre 2026, § 11) ; la B ne doit plus être reprise.

| Variante | Occurrences | Statut | Markup |
| --- | --- | --- | --- |
| **A** | 10 | ✅ **Canonique** | `w-full h-14 bg-primary-container text-on-primary-container font-headline-md rounded-xl shadow-[0_4px_0_#d9a400] active:translate-y-[2px] active:shadow-[0_2px_0_#d9a400] transition-all` |
| B | 3 | ❌ Abandonnée | `w-full h-[52px] bg-primary-container text-on-primary-container font-label-lg rounded-2xl shadow-[0_4px_0_#d9a400] active:translate-y-[2px]` |

Soit, avec les tokens de `tailwind.config.ts` :
`w-full h-cta bg-reviz-yellow text-reviz-on-yellow text-headline-md rounded-xl shadow-tactile active:translate-y-[2px] active:shadow-tactile-pressed transition-all`

### Carte standard

`bg-surface-container-lowest rounded-[20px] p-space-20 shadow-[0_4px_20px_rgba(26,26,26,0.06)] flex flex-col gap-space-16`

Pas de bordure. Les variantes plus petites utilisent `rounded-xl p-space-12`.

### Carte héros / compte à rebours

`bg-secondary-container text-surface-container-lowest rounded-[24px] p-space-20 shadow-[0_8px_24px_rgba(254,106,43,0.22)]`

Décor : cercles `bg-surface-container-lowest/10` en débord, icône Material à
`text-[64px]` en `/20`. Badge blanc en pilule `text-secondary`, badge secondaire
`bg-black/20`.

### Carte streak (7 jours)

Carte blanche `rounded-[20px] p-space-20`. Médaillon de tête `w-12 h-12
rounded-full bg-primary-container shadow-[0_3px_0_#d9a400]`. Ligne de 7 jours en
`flex justify-between` :

| État | Markup |
| --- | --- |
| Validé | `w-9 h-9 rounded-xl bg-primary-container shadow-[0_2px_0_#d9a400]` + `rotate-3` / `-rotate-3` / `rotate-2` (inclinaison légère et irrégulière) |
| Aujourd'hui | `w-10 h-10 rounded-xl bg-secondary-container shadow-[0_3px_0_#d94e15] scale-105 animate-pulse` + icône flamme |
| À venir | `w-9 h-9 rounded-xl bg-surface-container` + point `w-2 h-2 bg-outline-variant`, conteneur en `opacity-50` |

Lettres des jours en `caption` `text-on-surface-variant` au-dessus.

### Podium 2 / 1 / 3

Conteneur `flex items-end justify-center gap-space-8 pt-space-16 pb-space-4`.

| Rang | Avatar | Bloc | Chiffre |
| --- | --- | --- | --- |
| 2 (gauche) | `w-14 h-14 rounded-full p-1 bg-tertiary-container shadow-md` | `w-full h-24 rounded-t-xl bg-tertiary-container pt-space-8 shadow-sm` | `display-hero-mobile font-black opacity-40 text-on-tertiary-container` |
| 1 (centre) | `w-16 h-16 rounded-full p-1 bg-primary-container shadow-lg` | `w-full h-32 rounded-t-xl bg-primary-container pt-space-12 shadow-md` | `display-hero font-black opacity-40 text-on-primary-container` |
| 3 (droite) | `w-14 h-14 rounded-full p-1 bg-secondary-fixed shadow-md` | `w-full h-20 rounded-t-xl bg-secondary-fixed pt-space-8 shadow-sm` | `display-hero-mobile font-black opacity-40 text-on-secondary-fixed` |

Pastille de rang `absolute -bottom-2` sur l'avatar : `w-7 h-7` (n°1) ou `w-6 h-6`,
`rounded-full`, fond = couleur du bloc, `font-headline-sm`.
Couronne : badge `absolute -top-5 rounded-full bg-secondary-container
text-on-secondary font-caption`.

### Barre de progression

`w-full h-2.5 bg-surface-container rounded-full overflow-hidden` (10px), remplie
par `h-full bg-primary-container rounded-full`. **Remplissage plat, pas de
dégradé.**

Variante segmentée : `h-3 bg-surface-container-high p-[2px] flex gap-space-4
shadow-inner`, chaque segment `flex-1 h-2.5 rounded-full` — `bg-primary-container`
réussi, `bg-error shadow-[0_2px_0_#93000a] animate-pulse` raté,
`bg-surface-container` à venir.

### Option QCM

`w-full text-left bg-surface-container-lowest p-space-16 rounded-xl flex items-center justify-between shadow-md active:translate-y-[2px] transition-all`

Sélectionnée : `bg-primary-fixed shadow-[0_4px_0_#d9a400]`.
**Aucune bordure 2px** — la distinction se fait par le fond et l'arête tactile.
Pastille de lettre : `w-8 h-8 rounded-full bg-primary-container
text-on-primary-container font-label-md`.

### Barre de navigation basse

`fixed bottom-0 inset-x-0 z-50 pb-safe bg-surface/90 backdrop-blur-xl
shadow-[0_-8px_32px_rgba(26,26,26,0.06)]`, rangée interne `flex justify-around
items-center h-20 px-space-8` (**80px**). Onglets : Accueil · Réviser · Corriger ·
Gains · Profil, chacun `min-w-[56px]` avec `min-h-[48px]` ou `h-12`, icône
Material `text-[22px]`, libellé `caption`.

Deux variantes coexistaient. **La pilule est canonique** (arbitrage du
8 septembre 2026, § 11) :

- ✅ **Pilule** — les 5 onglets restent égaux, la barre reste plate.
  Onglet actif : `text-on-surface bg-primary-container font-headline-sm
  rounded-full shadow-[0_4px_0_#d9a400]`. Onglet inactif :
  `text-on-surface-variant`.
- ❌ **FAB central** (abandonnée) — « Réviser » sortait de la barre
  (`relative -top-3`) en cercle `w-14 h-14 rounded-full bg-primary-container
  shadow-[0_4px_0_#d9a400] active:translate-y-0.5`.

### Header

`fixed top-0 inset-x-0 z-50 bg-surface/85 backdrop-blur-xl pt-safe
shadow-[0_4px_20px_rgba(26,26,26,0.04)]`, rangée `h-16 px-space-16` (**64px**).
Contient le logo + « Reviz » en `headline-lg`, la pilule de streak et l'avatar
`w-8 h-8 rounded-full p-[2px] bg-primary-container`.

### Encart d'erreur / correction

`bg-error-container text-on-error-container rounded-2xl p-space-16 flex items-start gap-space-12 shadow-[0_4px_14px_rgba(186,26,26,0.08)]`,
pastille `w-8 h-8 rounded-full bg-error text-on-error`.

---

## 8. Gabarit et accessibilité

- Largeur des maquettes : **390px** (les exports HTML sont en 780px, soit ×2).
- `body` : `min-height: max(884px, 100dvh)`, `overscroll-behavior: none`,
  `-webkit-tap-highlight-color: transparent`, barres de défilement masquées.
- `viewport-fit=cover` + utilitaires `.pt-safe` / `.pb-safe` (`env(safe-area-inset-*)`).
- Cibles tactiles : `min-h-[48px]` / `h-12` sur toute la navigation et les listes.
- Zone de sécurité basse : `pb-[96px]` sur `main`.

---

## 9. Ce que Stitch n'a pas produit

- **Aucun mode sombre** (`colorMode: LIGHT` seul).
- **Aucun asset local** : tous les avatars, logos et illustrations des écrans sont
  des URL `lh3.googleusercontent.com` générées. Ni `/public/mascotte/*.png`, ni les
  24 avatars de `/public/avatars/` n'existent côté Stitch — il faut les produire.
- **Aucune icône propre** : dépendance à Material Symbols Outlined.
- Les écrans sont générés avec `cdn.tailwindcss.com` ; la configuration des § 2 à 5
  doit être portée telle quelle dans `tailwind.config.ts` pour que le markup Stitch
  copié-collé rende à l'identique.

---

## 10. Écarts avec la section « Design system » de CLAUDE.md

Vérifié par recherche littérale sur les 8 écrans exportés.

| # | `CLAUDE.md` affirme | Réalité Stitch | Gravité |
| --- | --- | --- | --- |
| 1 | Fond crème `#FFF8E7` | `#fcf9f8`. **`#FFF8E7` n'apparaît dans aucun écran.** | ⚖️ **Tranché : Stitch** (§ 11) |
| 2 | Typographie **Nunito** | **Nunito Sans** (famille Google Fonts différente) | 🔴 Identité visuelle |
| 3 | Accent jaune `#FFC300` | Exact — mais c'est `primary-container`. `primary` vaut `#785a00` et sert au **texte** | 🟡 Piège de nommage |
| 4 | Orange `#FF6B2C` | `#fe6a2b` (seed transformée). `#FF6B2C` ne subsiste qu'en littéral dans 2 écrans | 🟡 |
| 5 | Bleu doux `#CFE0FF` | `#bccdeb` (`tertiary-container`). `#d4e3ff` (`tertiary-fixed`) est le plus proche du seed | 🟡 |
| 6 | Encre `#1A1A1A` | `#1c1b1b` | 🟢 |
| 7 | « Pas de gris froid », muted implicite `#6B6B6B` | `#4f4632`, brun chaud. L'esprit est respecté, la valeur non | 🟡 |
| 8 | Vert `#22C55E` / rouge `#EF4444` pour bonne / mauvaise réponse | **Aucun vert dans le design system.** Erreur = `#ba1a1a` / `#ffdad6`. Bonne réponse célébrée en jaune | ⚖️ **Tranché : Stitch** (§ 11) |
| 9 | Célébration en jaune plein `#FFD23F` | **`#FFD23F` absent de tous les écrans** | 🔴 |
| 10 | Cartes rayon 20px | Rayon dominant **12px** (`rounded-xl`, 49×) puis 16px (24×). Le 20px n'apparaît que 6× | 🟡 |
| 11 | Streak « 7 losanges » | 7 **carrés arrondis** `rounded-xl` légèrement inclinés (`rotate-2/3`), pas des losanges à 45° | 🟡 |
| 12 | Podium n°2 en bleu, n°1 jaune | Conforme — mais **n°3 en pêche pâle `#ffdbcf`**, pas en orange. Hauteurs 128/96/80px, avatars 64/56/56px | 🟡 |
| 13 | Barres de progression 10px en pilule | Conforme (`h-2.5`) — piste `#f0eded` et remplissage **plat** (le `designMd` de Stitch promet un dégradé jamais produit) | 🟢 |
| 14 | QCM 4 boutons pleine largeur | Conforme — mais **sans bordure 2px** : carte blanche + `shadow-md`, sélection par fond `#ffdf9a` | 🟡 |
| 15 | Zones tactiles ≥ 48px | Conforme (`min-h-[48px]` / `h-12` partout) | 🟢 |
| 16 | Nav basse à 5 onglets | Conforme (80px de haut) — mais **deux variantes incompatibles** entre écrans : pilule active vs FAB central 56px | ⚖️ **Tranché : pilule** (§ 11) |
| 17 | — | CTA également en **deux variantes** : `h-14` + `rounded-xl` (10×) vs `h-[52px]` + `rounded-2xl` (3×) | ⚖️ **Tranché : `h-14`** (§ 11) |
| 18 | — | Le `designMd` de Stitch décrit une échelle `rounded` (sm .25 / DEFAULT .5 / md .75 / lg 1 / xl 1.5rem) **différente** de celle qu'il compile (§ 5). Suivre la compilée | 🔴 Piège |
| 19 | Mascotte `/public/mascotte/*.png`, 24 avatars | Aucun asset local côté Stitch (§ 9) | 🟡 |
| 20 | Un seul CTA principal par écran, tutoiement, textes courts, mobile 390px | Respectés | 🟢 |

---

## 11. Arbitrages tranchés (8 septembre 2026)

Quatre conflits entre `CLAUDE.md` et la sortie réelle de Stitch ont été soumis et
tranchés. **Ces décisions priment sur `CLAUDE.md`, qui doit être corrigé en
conséquence.**

| Conflit | Décision | Conséquence |
| --- | --- | --- |
| Écart 1 — fond crème | **Garder `#fcf9f8`** (valeur Stitch) | `reviz.cream` vaut `#fcf9f8`. Le crème `#FFF8E7` de `CLAUDE.md` est abandonné : le markup Stitch se colle sans retouche, mais le fond de l'app est un blanc cassé quasi neutre, pas un crème chaud. |
| Écart 8 — vert / rouge du QCM | **Suivre Stitch** | Aucun token vert n'est créé. Bonne réponse en jaune (`primary-container` / `primary-fixed`), mauvaise réponse en `error` `#ba1a1a`. Palette strictement chaude. À surveiller en test utilisateur : la distinction bon/faux est moins immédiate qu'avec un vert. |
| Écart 16 — barre de navigation | **Onglet actif en pilule jaune** | Les 5 onglets restent égaux, la barre reste plate à 80px. Le FAB central « Réviser » est abandonné. |
| Écart 17 — bouton principal | **`h-14` (56px) + `rounded-xl` (12px)** | Texte en `headline-md`. Exposé sous `h-cta` dans `tailwind.config.ts`. La variante 52px / 16px est abandonnée. |

### Corrections portées dans CLAUDE.md

✅ **Appliquées le 8 septembre 2026.** La section « Design system » de `CLAUDE.md`
a été réécrite pour refléter les valeurs de ce fichier. Points corrigés :
fond `#FFF8E7` → `#fcf9f8` · **Nunito** → **Nunito Sans** · orange `#FF6B2C` →
`#fe6a2b` · bleu `#CFE0FF` → `#bccdeb` · encre `#1A1A1A` → `#1c1b1b` ·
suppression du vert `#22C55E` et du rouge `#EF4444` au profit de `#ba1a1a` ·
suppression du jaune de célébration `#FFD23F` (inexistant) · rayon de carte
20px → 12px dominant · « 7 losanges » → 7 carrés arrondis inclinés.
