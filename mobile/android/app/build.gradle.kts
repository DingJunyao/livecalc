import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // KGP 由 Flutter 的 Built-in Kotlin 提供，应用侧不再显式声明。
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// release 签名：读 android/key.properties（已被 .gitignore 排除，不会进仓库）。
// 文件不存在时回退到 debug 签名，保证未配置签名的机器/CI 也能出包（不能上架）。
// 字段见同目录 key.properties.example；storeFile 的相对路径以 mobile/android/ 为基准。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.a4ding.livecalc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        compose = false
    }

    compileOptions {
        // 与 Flutter Built-in Kotlin 的默认 JVM Target（21）保持一致，否则 Java/Kotlin 编译目标不一致
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.a4ding.livecalc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // 未配置 android/key.properties：仍用 debug 签名，`flutter build apk` 可跑，
                // 但产物不能上架、也无法用正式 key 覆盖升级。
                // 用 logger.quiet：flutter 调 Gradle 时带 -q，lifecycle/warn 级别的日志会被吃掉，
                // 只有 ERROR/QUIET 能显示出来，否则这条提醒永远不会被看到。
                logger.quiet(
                    "⚠️  未找到 android/key.properties，release 构建将使用 debug 签名（不可上架）。" +
                        "参考 android/key.properties.example 配置。"
                )
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

// Kotlin 的 jvmTarget 必须与上面 compileOptions 的 21 一致：项目用外部 KGP
// （gradle.properties 里 android.builtInKotlin=false，故 Flutter 不会替你按 Java 兼容级别
// 设置 jvmTarget），KGP 2.4.x 默认取 JDK 工具链版本（Android Studio 的 JBR 是 25），
// 不显式声明会报 "Inconsistent JVM-target compatibility ... (21) and (25)"。
// Flutter 3.50.1 模板里是同样的写法（模板取 JVM_17，本项目 Java 兼容级别为 21）。
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
    }
}

flutter {
    source = "../.."
}
