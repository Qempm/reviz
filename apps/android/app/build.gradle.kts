plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.reviz.app"
    compileSdk {
        version = release(36)
    }

    defaultConfig {
        // Le même identifiant que capacitor.config.json : le jour où la
        // coquille passera à Capacitor, l'APK restera une mise à jour de
        // celui-ci et non une seconde application.
        applicationId = "com.reviz.app"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    // Compose a été retiré : la coquille n'affiche aucune interface native,
    // seulement une WebView. Le garder ajoutait plusieurs mégaoctets à un
    // APK destiné à être partagé par WhatsApp.
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.ktx)
}
