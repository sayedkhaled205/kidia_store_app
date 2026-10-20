plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val storeAppName = providers.gradleProperty("APP_NAME")
    .orElse("MobiShop Store")
val storeApplicationId = providers.gradleProperty("APPLICATION_ID")
    .orElse("com.mobishop.mobishop_store_app")
val releaseKeyNames = listOf("CM_KEYSTORE_PATH", "CM_KEYSTORE_PASSWORD", "CM_KEY_ALIAS", "CM_KEY_PASSWORD")
val releaseKeyValues = releaseKeyNames.associateWith { System.getenv(it).orEmpty() }
val hasReleaseKey = releaseKeyValues.values.all { it.isNotEmpty() }
val androidBuildMode = System.getenv("MOBISHOP_ANDROID_BUILD_MODE").orEmpty().ifEmpty { "release" }
require(androidBuildMode in setOf("qa", "release")) {
    "Android build mode must be qa or release."
}
require(hasReleaseKey || releaseKeyValues.values.all { it.isEmpty() }) {
    "Android signing configuration is incomplete. Supply all four CM_KEYSTORE variables."
}
require(System.getenv("MOBISHOP_REQUIRE_RELEASE_SIGNING") != "true" || hasReleaseKey) {
    "A release keystore is required for a store submission build."
}
require(androidBuildMode != "qa" || (!hasReleaseKey && System.getenv("MOBISHOP_REQUIRE_RELEASE_SIGNING") != "true")) {
    "An Android test build must not use a release signing identity."
}
// Normal local debug tasks still work. A release task can use Android's debug
// key only when QA was explicitly selected; missing credentials never downgrade.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        require(androidBuildMode == "qa" || hasReleaseKey) {
            "A release keystore is required. Use explicit qa mode only for a test build."
        }
    }
}

android {
    namespace = "com.mobishop.mobishop_store_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        // AGP 9 disables generated resource values by default. The app name
        // below is supplied through resValue, so this feature must stay on.
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = storeApplicationId.get()
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 10 uses Android Keystore ciphers available
        // from Android 6.0 (API 23).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", storeAppName.get())
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("storeRelease") {
                storeFile = file(releaseKeyValues.getValue("CM_KEYSTORE_PATH"))
                storePassword = releaseKeyValues.getValue("CM_KEYSTORE_PASSWORD")
                keyAlias = releaseKeyValues.getValue("CM_KEY_ALIAS")
                keyPassword = releaseKeyValues.getValue("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                androidBuildMode == "qa" -> signingConfigs.getByName("debug")
                hasReleaseKey -> signingConfigs.getByName("storeRelease")
                else -> null
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
