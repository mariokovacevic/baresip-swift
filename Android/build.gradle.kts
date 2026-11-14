import com.android.build.api.dsl.LibraryExtension
import com.vanniktech.maven.publish.MavenPublishBaseExtension

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

val baresipkitVersion: String =
    providers.gradleProperty("VERSION_NAME").orNull
        ?: rootProject.file("../VERSION").readText().trim()

val licenseTexts =
    files(
        rootProject.file("../LICENSE"),
        rootProject.file("../THIRD_PARTY_NOTICES.md"),
        rootProject.file("../LICENSES"),
    )

subprojects {
    apply(plugin = "org.jlleitschuh.gradle.ktlint")
    if (name in libraryModules) {
        apply(plugin = "org.jetbrains.dokka")
        apply(plugin = "com.vanniktech.maven.publish")
        version = baresipkitVersion
        extensions.configure<MavenPublishBaseExtension> {
            coordinates(version = baresipkitVersion)
            if (project.name == "baresipkit") {
                pom {
                    licenses {
                        license {
                            name.set("Apache-2.0")
                            url.set("https://www.apache.org/licenses/LICENSE-2.0")
                            distribution.set("repo")
                            comments.set("OpenSSL, built into libbaresipkit.so")
                        }
                        license {
                            name.set("BSD-2-Clause")
                            url.set("https://opensource.org/license/bsd-2-clause")
                            distribution.set("repo")
                            comments.set("G.722 from sippy/libg722, built into libbaresipkit.so")
                        }
                    }
                }
            }
        }
    }
    if (name == "baresipkit") {
        val licenseDirectory = layout.buildDirectory.dir("generated/licenses")
        val copyLicenses =
            tasks.register<Sync>("copyLicenseTexts") {
                from(licenseTexts) {
                    rename("^LICENSE$", "BaresipKit-LICENSE")
                }
                into(licenseDirectory.map { it.dir("META-INF/baresipkit") })
            }
        plugins.withId("com.android.library") {
            extensions.configure<LibraryExtension> {
                sourceSets.getByName("main").resources.srcDir(licenseDirectory)
            }
            tasks.named("preBuild") { dependsOn(copyLicenses) }
        }
    }
}

dependencies {
    libraryModules.forEach { dokka(project(":$it")) }
}

dokka {
    moduleName.set("BaresipKit for Android")
}
