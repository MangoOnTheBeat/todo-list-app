plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "app.lumora.tv"
    compileSdk = 35

    defaultConfig {
        applicationId = "app.lumora.tv"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "2.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Signed with the debug key so the APK installs straight away; use your own key to publish.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

// The interface is the same single-file Lumora web app (lumora-tv/index.html), bundled into the APK.
val copyLumora by tasks.registering(Copy::class) {
    from(rootProject.file("../../index.html"))
    into(layout.projectDirectory.dir("src/main/assets"))
}
tasks.named("preBuild") { dependsOn(copyLumora) }
