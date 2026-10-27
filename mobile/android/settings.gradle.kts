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
    // Flutter 3.47（stable）的 Android 模板：gradle.properties 里
    // android.builtInKotlin=false（沿用 AGP 9 之前的 KGP 路径），因此必须显式声明
    // Kotlin Gradle Plugin，否则 Flutter 会拿到 AGP 自带的 Kotlin 2.2.10，
    // 低于其最低支持版本 2.2.20 而终止构建。
    // 版本对齐 Flutter 3.47.8 模板的 templateKotlinGradlePluginVersion（2.4.0）。
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
