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
    id("com.android.application") version "9.3.1" apply false
    // android.builtInKotlin=false（沿用 AGP 9 之前的 KGP 路径，见 gradle.properties），
    // 因此必须显式声明 Kotlin Gradle Plugin，否则会拿到 AGP 自带的 Kotlin，
    // 低于 Flutter 的下限而终止构建。
    // 三件套统一取 Flutter 3.50.1 模板版本（Gradle 9.5.0 / AGP 9.3.1 / KGP 2.4.20）；
    // 3.50.1 的硬性下限是 Gradle 9.3.1、AGP 9.1.1、KGP 2.4.10，低于下限会在
    // DependencyVersionChecker 里直接报错（旧值 9.1.0 / 9.0.1 / 2.4.0 全部在下限之下）。
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")
