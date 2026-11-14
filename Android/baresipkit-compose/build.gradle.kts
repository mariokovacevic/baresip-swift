import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "io.github.mariokovacevic.baresipkit.compose"
    compileSdk = 36

    defaultConfig {
        minSdk = 28
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

val coreProject = project(":baresipkit")

tasks.withType<Test>().configureEach {
    dependsOn(":baresipkit:buildHostJni")
    systemProperty(
        "java.library.path",
        coreProject.layout.buildDirectory
            .dir("host-jni")
            .get()
            .asFile.absolutePath,
    )
    systemProperty("baresipkit.hostCore", System.getProperty("os.name") == "Linux")
}

dependencies {
    api(project(":baresipkit"))
    api(project(":baresipkit-video"))
    api(platform(libs.compose.bom))
    api(libs.compose.runtime)
    api(libs.compose.ui)
    implementation(libs.compose.foundation)
    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
}
