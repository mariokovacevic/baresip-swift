import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinVersion
import org.jetbrains.kotlin.gradle.dsl.abi.ExperimentalAbiValidation
import java.time.Duration as JavaDuration

plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "io.github.mariokovacevic.baresipkit"
    compileSdk = 36

    ndkVersion = "30.0.16248370"

    defaultConfig {
        minSdk = 28
        consumerProguardFiles("consumer-rules.pro")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    sourceSets {
        getByName("test").kotlin.srcDir("src/sharedTest/kotlin")
        getByName("androidTest").kotlin.srcDir("src/sharedTest/kotlin")
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

val hostJniDir = layout.buildDirectory.dir("host-jni")
val hostCore = rootProject.layout.projectDirectory.file("../Build/out/host/lib/libBaresipKitCore.a")
val isLinuxHost = System.getProperty("os.name") == "Linux"

val buildHostJni by tasks.registering(Exec::class) {
    description = "Builds the JNI bridge against the Linux host core for JVM unit tests."
    onlyIf { isLinuxHost }
    val source = layout.projectDirectory.dir("src/main/cpp")
    inputs.dir(source)
    inputs.file(hostCore)
    outputs.dir(hostJniDir)
    val buildDir = hostJniDir.get().asFile.absolutePath
    commandLine(
        "sh",
        "-c",
        "cmake -S \"$1\" -B \"$2\" -DCMAKE_BUILD_TYPE=Release -DCMAKE_LIBRARY_OUTPUT_DIRECTORY=\"$2\" >/dev/null " +
            "&& cmake --build \"$2\" >/dev/null",
        "sh",
        source.asFile.absolutePath,
        buildDir,
    )
}

tasks.withType<Test>().configureEach {
    dependsOn(buildHostJni)
    timeout.set(JavaDuration.ofMinutes(5))
    testLogging {
        showStandardStreams = System.getenv("BSK_TEST_VERBOSE") != null
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
    systemProperty("java.library.path", hostJniDir.get().asFile.absolutePath)
    systemProperty("baresipkit.hostCore", isLinuxHost)
}

dependencies {
    api(libs.coroutines.core)
    implementation(libs.coroutines.android)
    implementation(libs.lifecycle.process)
    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
    androidTestImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.junit)
}
