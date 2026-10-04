# Reviz sur iPhone

> Arbitrages du 1er octobre 2026 : **App Store** (TestFlight d'abord), compilé
> sur un **Mac de Codemagic** ; **aucun achat dans l'application iOS** ;
> **connexion par e-mail seulement** sur iPhone.

Le code est prêt. Ce qui manque ne s'écrit pas : un compte Apple, une clé
d'API, et un essai sur un vrai iPhone. Aucune build iOS n'a encore tourné —
une application iOS ne se compile que sur un Mac, et ce dépôt est développé
sous Windows. La première build Codemagic est donc aussi la première
vérification de compilation.

## 1. Ce qui diffère d'Android, et pourquoi

| | Android (APK) | iPhone (App Store) | Règle |
|---|---|---|---|
| Achat des packs | Mobile Money dans l'app | **Aucun** : ni prix, ni bouton, ni renvoi vers un achat ailleurs. L'écran devient « Mon accès ». | App Store 3.1.1 : un contenu numérique ne s'y vend que par l'achat intégré d'Apple, qui ne parle pas Mobile Money. |
| Pack Découverte | Oui | Oui (gratuit, il ne s'achète pas) | — |
| Accès payé ailleurs | — | Reconnu à la connexion : il est lié au compte, pas au téléphone. | — |
| Connexion | Google ou e-mail | **E-mail seul** (code à 6 chiffres) | 4.8 : Google obligerait à proposer « Se connecter avec Apple ». |
| Appareils | Téléphones | **iPhone seulement**, iOS 15+, portrait | — |
| Suppression du compte | Dans l'app | Dans l'app | 5.1.1(v), déjà en place. |

Tout passe par deux interrupteurs, dans `apps/mobile/lib/metier/plateforme.dart` :
`achatsDansLApplication` et `connexionGoogleProposee`. Les écrans touchés —
boutique, dépôt, correction, profil, aide, connexion — et leurs tests
(`test/ecrans_test.dart`, groupe « iPhone », qui simule iOS) en dépendent.
**Un nouvel écran qui montre un prix ou mène à `Chemins.boutique` doit les
consulter.**

## 2. Le compte Apple Developer (le propriétaire)

1. <https://developer.apple.com/programs/enroll/> : **99 $ par an**, renouvelé
   automatiquement par Apple. Sans lui, ni TestFlight ni App Store.
2. **Individuel** (ton nom apparaît comme vendeur sur l'App Store) ou
   **Organisation** (le nom de la société, mais il faut un numéro D-U-N-S,
   gratuit, compter une à deux semaines). Pour démarrer vite : individuel.
3. Il faut un identifiant Apple avec la double authentification, donc un
   appareil Apple ou un numéro de téléphone pour recevoir les codes.

## 3. L'application dans App Store Connect

1. *Certificates, Identifiers & Profiles* → *Identifiers* → **+** → App IDs →
   App → Bundle ID explicite **`com.reviz.app`** (le même que l'APK). Aucune
   capacité à cocher : pas de Push, pas de Sign in with Apple.
2. <https://appstoreconnect.apple.com> → *Apps* → **+** → Nouvelle app :
   plateforme iOS, nom **Reviz** (s'il est pris : « Reviz — Révisions »),
   langue principale **Français**, bundle `com.reviz.app`, SKU `reviz-ios`.
3. Noter l'**Apple ID** de l'app (un nombre, dans *Informations sur l'app*) :
   c'est `APP_STORE_APPLE_ID` plus bas.
4. **Clé d'API** : *Utilisateurs et accès* → *Intégrations* → *App Store
   Connect API* → générer une clé, rôle **App Manager**. Télécharger le
   fichier `.p8` — **une seule fois possible** — et noter l'*Issuer ID* et le
   *Key ID*. Ce fichier ne va **jamais** dans le dépôt ni dans une
   conversation : il va directement dans Codemagic.

## 4. Codemagic

1. <https://codemagic.io> → se connecter avec GitHub → ajouter le dépôt
   `Qempm/reviz`. Codemagic lit `codemagic.yaml` à la racine.
2. *Team settings* → *Integrations* → *Developer Portal* → **Connect** :
   nom **`Reviz`** (le nom exact attendu par `codemagic.yaml`), Issuer ID,
   Key ID, fichier `.p8`.
3. *Team settings* → *Code signing identities* :
   - *iOS certificates* → **Generate certificate** (type *Apple
     Distribution*) via l'intégration `Reviz`. Garder la phrase de passe
     proposée dans un gestionnaire de mots de passe.
   - *iOS provisioning profiles* → **Fetch profiles** → le profil *App Store*
     de `com.reviz.app` (Codemagic le crée s'il n'existe pas).
4. *Environment variables* de l'app → groupe **`reviz_ios`**, chaque valeur
   cochée *Secure* :

   | Variable | Valeur |
   |---|---|
   | `SUPABASE_URL` | la même que `NEXT_PUBLIC_SUPABASE_URL` |
   | `SUPABASE_ANON_KEY` | la même que `NEXT_PUBLIC_SUPABASE_ANON_KEY` — **la clé anonyme, jamais celle de service** |
   | `API_BASE` | `https://revizapp.fun` |
   | `APP_STORE_APPLE_ID` | le nombre noté au § 3.3 |
   | `CONTACT_WHATSAPP` | facultatif, comme pour l'APK |

   L'étape « Garde-fou » de `codemagic.yaml` refuse de construire si une
   variable manque ou si la clé Supabase est celle de service.
5. **Start new build** → workflow *Reviz iOS → TestFlight*. Compter 15 à
   25 minutes. Le plan gratuit donne 500 minutes de Mac par mois.

Si la première build échoue, le journal est dans les artefacts
(`xcodebuild_logs`). Les causes probables, dans l'ordre : un greffon qui
exige une version d'iOS plus haute (monter `platform :ios` dans
`apps/mobile/ios/Podfile` **et** `IPHONEOS_DEPLOYMENT_TARGET` dans le projet
Xcode), un profil de signature introuvable (refaire *Fetch profiles*).

## 5. TestFlight, puis l'App Store

1. La build arrive dans App Store Connect → *TestFlight* après 10 à 30 minutes
   de traitement par Apple. Ajouter des **testeurs internes** (jusqu'à 100,
   membres du compte) : ils installent l'app *TestFlight*, puis Reviz.
2. **Essayer sur un vrai iPhone**, au minimum : connexion par code, dépôt
   d'un PDF et d'une photo, une série, une copie à corriger, le rappel du
   soir, la suppression du compte. Vérifier qu'aucun prix n'apparaît nulle
   part.
3. Fiche App Store, à remplir avant de soumettre :
   - catégorie **Éducation**, âge **4+** ;
   - URL de confidentialité : <https://revizapp.fun/confidentialite>
     (relue par le propriétaire avant la soumission) ;
   - URL d'assistance : <https://revizapp.fun> ;
   - captures d'écran **6,9 pouces** (1320 × 2868) — les bancs d'aperçu
     (`flutter test test_apercus --update-goldens`) peuvent les rendre à
     cette taille ;
   - *Confidentialité de l'app* : données collectées et **liées à
     l'utilisateur**, aucune utilisée pour du **suivi** — coordonnées
     (e-mail, nom, téléphone facultatif), contenu utilisateur (photos,
     documents), identifiants (identifiant du compte), historique d'achats
     (packs achetés hors iPhone), usage (progression). Finalité : *Fonctions
     de l'app*.
   - *Chiffrement* : déjà déclaré dans `Info.plist`
     (`ITSAppUsesNonExemptEncryption = false`) — la question ne sera pas
     posée.
4. **Compte de démonstration** : Apple exige de pouvoir se connecter. Voir
   § 6.
5. Soumettre à la main depuis App Store Connect (`codemagic.yaml` ne
   soumet qu'à TestFlight). Premier examen : 1 à 3 jours.

## 6. Points d'attention pour l'examen

- **Connexion de l'examinateur.** La connexion par code envoie un e-mail :
  un examinateur ne peut pas recevoir un code arrivé dans notre boîte. Soit
  il crée son propre compte avec son adresse (l'inscription est ouverte à
  tous, l'écrire dans les *Notes pour l'examen*), soit on prévoit un compte
  d'examen à code fixe côté serveur. **À trancher avant la soumission.**
- **Parrainage.** L'écran Gains parle de commissions en Mobile Money : c'est
  de l'argent versé à l'étudiant, pas un achat, ce qu'Apple tolère. Si un
  examinateur le conteste, masquer l'écran Gains sur iPhone se fait par le
  même interrupteur.
- **Mentions d'achat.** Aucun texte iOS ne doit dire « réactive », « achète »
  ou « passe à un pack plus large » : les variantes `…SansAchat` de
  `lib/i18n/fr.dart` existent pour cela.

## 7. Fichiers

| Fichier | Rôle |
|---|---|
| `codemagic.yaml` | La build iOS, signée, envoyée à TestFlight. |
| `apps/mobile/ios/` | Le projet Xcode : bundle `com.reviz.app`, iOS 15, iPhone seul, portrait. |
| `apps/mobile/ios/Runner/Info.plist` | Textes d'autorisation (appareil photo, photos), chiffrement. |
| `apps/mobile/ios/Runner/AppDelegate.swift` | Les rappels s'affichent aussi app ouverte. |
| `apps/mobile/ios/Podfile` | iOS 15 pour les greffons. |
| `scripts/icones.mjs` | Produit aussi l'icône iOS (1024 px, sans transparence). |
| `apps/mobile/lib/metier/plateforme.dart` | Les deux interrupteurs. |
| `app/confidentialite/page.tsx` | La politique de confidentialité exigée par l'App Store. |
