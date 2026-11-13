plugins {
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.ktlint) apply false
    id("org.jetbrains.dokka") version "2.2.0"
    id("com.vanniktech.maven.publish") version "0.36.0" apply false
}

val libraryModules =
    listOf(
        "baresipkit",
        "baresipkit-audio",
        "baresipkit-video",
        "baresipkit-telecom",
        "baresipkit-push",
        "baresipkit-compose",
    )

subprojects {
    apply(plugin = "org.jlleitschuh.gradle.ktlint")
    if (name in libraryModules) {
        apply(plugin = "org.jetbrains.dokka")
        apply(plugin = "com.vanniktech.maven.publish")
    }
}

dependencies {
    libraryModules.forEach { dokka(project(":$it")) }
}

dokka {
    moduleName.set("BaresipKit for Android")
}
