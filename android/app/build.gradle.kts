plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.control_habitos"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Necesario para flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.control_habitos"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Necesario para notificaciones programadas
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            
        }
        
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Necesario para flutter_local_notifications con zonedSchedule
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
