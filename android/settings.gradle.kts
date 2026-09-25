@Suppress("UNCHECKED_CAST")
fun unsetEnv(key: String) {
    try {
        val env = System.getenv()
        val mapField = env.javaClass.getDeclaredField("m")
        mapField.isAccessible = true
        (mapField.get(env) as MutableMap<String, String>).remove(key)
    } catch (_: Exception) {}
    try {
        val pe = Class.forName("java.lang.ProcessEnvironment")
        val envField = pe.getDeclaredField("theEnvironment")
        envField.isAccessible = true
        (envField.get(null) as MutableMap<String, String>).remove(key)
        val ciEnvField = pe.getDeclaredField("theCaseInsensitiveEnvironment")
        ciEnvField.isAccessible = true
        (ciEnvField.get(null) as MutableMap<String, String>).remove(key)
    } catch (_: Exception) {}
}
unsetEnv("ANDROID_PREFS_ROOT")

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
        maven { url = java.net.URI("https://maven.aliyun.com/repository/google") }
        maven { url = java.net.URI("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
