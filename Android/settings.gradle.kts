pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "BaresipKit"

include(
    ":baresipkit",
    ":baresipkit-audio",
    ":baresipkit-video",
    ":baresipkit-telecom",
    ":baresipkit-push",
    ":baresipkit-compose",
    ":zvono",
)
