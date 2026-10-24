pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// Kashier 0.1.4 uses InAppWebView Android 1.1.3. Its release script
// references the R8 file removed in AGP 9. Keep the package cache immutable
// and apply the upstream ProGuard filename fix to a generated build script.
findProject(":flutter_inappwebview_android")?.let { webView ->
    val original = webView.projectDir.resolve("build.gradle").readText()
    val obsolete = "getDefaultProguardFile('proguard-android.txt')"
    if (original.contains(obsolete)) {
        val manifest = webView.projectDir.parentFile.resolve("pubspec.yaml").readText()
        require(Regex("(?m)^version: 1\\.1\\.3\\s*$").containsMatchIn(manifest)) {
            "Review the InAppWebView Android compatibility patch for this version."
        }
        require(original.split(obsolete).size == 3) {
            "Unexpected InAppWebView ProGuard configuration."
        }
        val patched = rootDir.resolve("../build/android-compat/inappwebview.gradle")
        patched.parentFile.mkdirs()
        val contents = original.replace(
            obsolete, "getDefaultProguardFile('proguard-android-optimize.txt')"
        )
        if (!patched.exists() || patched.readText() != contents) patched.writeText(contents)
        webView.buildFileName = patched.relativeTo(webView.projectDir).path
    }
}
