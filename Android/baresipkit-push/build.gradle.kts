import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinVersion
import org.jetbrains.kotlin.gradle.dsl.abi.ExperimentalAbiValidation

plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "io.github.mariokovacevic.baresipkit.push"
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
    coreLibrariesVersion = "2.1.21"
    explicitApi()
    @OptIn(ExperimentalAbiValidation::class)
    abiValidation()
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
        apiVersion.set(KotlinVersion.KOTLIN_2_1)
        languageVersion.set(KotlinVersion.KOTLIN_2_1)
    }
}

dependencies {
    api(project(":baresipkit"))
    api(project(":baresipkit-telecom"))
    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
}
