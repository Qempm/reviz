import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé de signature — lue dans un fichier que le dépôt ignore.
//
// `android/key.properties` porte le chemin du magasin et ses mots de passe.
// Il est couvert par `**/key.properties` à la racine, comme `*.jks` et
// `*.keystore` : une clé de signature engagée est une clé à révoquer, et
// rien ne la couvrait avant. Le gabarit est `key.properties.example`.
val proprietesCle = Properties()
val fichierCle = rootProject.file("key.properties")
if (fichierCle.exists()) {
    fichierCle.inputStream().use { proprietesCle.load(it) }
}

/** Le magasin est-il déclaré **et** présent sur cette machine ? */
val cleDisponible: Boolean = run {
    val chemin = proprietesCle.getProperty("storeFile") ?: return@run false
    rootProject.file(chemin).exists()
}

// Une compilation en release sans clé s'arrête ici, avec la raison.
//
// C'est le point de tout ce bloc. La version précédente écrivait
// `signingConfig = signingConfigs.getByName("debug")` avec un TODO au-dessus :
// `flutter build apk --release` rendait donc un APK signé par la clé de
// débogage — installable, d'apparence normale, et impossible à mettre à jour
// plus tard par un APK correctement signé, puisque Android refuse un
// remplacement de signature. Un échec bruyant vaut mieux qu'un artefact qu'on
// distribue sans savoir ce qu'il vaut.
val demandeUneRelease = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (demandeUneRelease && !cleDisponible) {
    throw GradleException(
        """
        Signature de release absente.

        Crée la clé hors du dépôt, puis android/key.properties sur le modèle
        de android/key.properties.example :

          keytool -genkey -v -keystore <chemin hors dépôt>/reviz.jks \
            -keyalg RSA -keysize 2048 -validity 10000 -alias reviz

        Voir docs/GUIDE-APK-REVIZ.md. Les compilations en debug et en profile
        n'ont pas besoin de cette clé.
        """.trimIndent(),
    )
}

android {
    namespace = "com.reviz.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // `com.reviz.app`, et non l'identifiant que `flutter create` déduit du
        // nom du projet : c'est celui que `public/version.json` pointait vers
        // le Play Store, et celui auquel le client OAuth Android de Google
        // Sign-In sera rattaché.
        //
        // C'était aussi celui de l'ancienne coquille Kotlin, signée d'une
        // autre clé : Android refusera donc de remplacer l'une par l'autre, et
        // la page /app dit de désinstaller d'abord.
        applicationId = "com.reviz.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Depuis `pubspec.yaml`, passé à 2.0.0+2 : l'ancienne coquille était
        // en versionCode 1, et versionCode 1 n'est pas une mise à jour de
        // versionCode 1.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (cleDisponible) {
            create("release") {
                storeFile = rootProject.file(proprietesCle.getProperty("storeFile"))
                storePassword = proprietesCle.getProperty("storePassword")
                keyAlias = proprietesCle.getProperty("keyAlias")
                keyPassword = proprietesCle.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // `cleDisponible` est vrai dès qu'on arrive ici en release : le
            // garde-fou plus haut a déjà arrêté le contraire.
            if (cleDisponible) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
