plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Rust target mappings for Android architectures
val rustTargets = mapOf(
    "arm64-v8a" to "aarch64-linux-android",
    "armeabi-v7a" to "armv7-linux-androideabi",
    "x86_64" to "x86_64-linux-android"
)
val diagnosticsPackage = "com.ryosukemondo.beatbox_trainer"

android {
    namespace = "com.ryosukemondo.beatbox_trainer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ryosukemondo.beatbox_trainer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Configure native library architectures for APK packaging
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    buildTypes {
        release {
            // Enable code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true

            // ProGuard rules for Flutter and Rust FFI
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Configure jniLibs source directory for native library packaging
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
        animationsDisabled = true
    }
}

flutter {
    source = "../.."
}

// Custom Gradle task to build Rust library for Android using cargo-ndk
tasks.register("buildRustAndroid") {
    description = "Builds Rust library for Android using cargo-ndk"
    group = "build"

    doFirst {
        // Check if cargo-ndk is installed
        val cargoNdkCheck = ProcessBuilder("cargo", "ndk", "--version")
            .redirectErrorStream(true)
            .start()

        val exitCode = cargoNdkCheck.waitFor()
        if (exitCode != 0) {
            throw GradleException(
                "cargo-ndk not found. Install with: cargo install cargo-ndk\n" +
                "Also ensure Rust Android targets are installed:\n" +
                "  rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android"
            )
        }

        println("✓ cargo-ndk found")
    }

    doLast {
        val projectRoot = project.rootDir.parentFile
        val rustDir = File(projectRoot, "rust")
        val jniLibsDir = File(projectDir, "src/main/jniLibs")

        // Ensure jniLibs directory exists
        jniLibsDir.mkdirs()

        // Build for each Android architecture
        rustTargets.forEach { (abi, target) ->
            println("Building Rust library for $abi ($target)...")

            val buildProcess = ProcessBuilder(
                "cargo", "ndk",
                "-t", target,
                "--", "build", "--release"
            )
                .directory(rustDir)
                .redirectErrorStream(true)
                .start()

            // Stream output to console
            buildProcess.inputStream.bufferedReader().forEachLine { line ->
                println("  $line")
            }

            val buildExitCode = buildProcess.waitFor()
            if (buildExitCode != 0) {
                throw GradleException("Failed to build Rust library for $abi (exit code: $buildExitCode)")
            }

            // Copy the .so file to jniLibs/{abi}/
            val soFileName = "libbeatbox_trainer.so"
            val sourceFile = File(rustDir, "target/$target/release/$soFileName")
            val destDir = File(jniLibsDir, abi)
            destDir.mkdirs()
            val destFile = File(destDir, soFileName)

            if (!sourceFile.exists()) {
                throw GradleException("Expected .so file not found: ${sourceFile.absolutePath}")
            }

            sourceFile.copyTo(destFile, overwrite = true)
            println("✓ Copied $soFileName to jniLibs/$abi/")
        }

        println("✓ All Rust libraries built successfully")
    }
}

// Hook buildRustAndroid into the build process before preBuild
tasks.whenTaskAdded {
    if (name == "preBuild") {
        dependsOn("buildRustAndroid")
    }
}

tasks.register("diagnosticsAndroidTestArtifacts") {
    group = "verification"
    description =
        "Runs diagnostics instrumentation tests and captures adb repro/log artifacts."
    val logsDir = File(rootProject.projectDir, "logs/diagnostics/android")
    outputs.dir(logsDir)
    dependsOn("connectedDebugAndroidTest")
    doLast {
        logsDir.mkdirs()
        val reproFile = File(logsDir, "REPRO_COMMAND.txt")
        reproFile.writeText(
            """
            To rerun diagnostics instrumentation tests manually:
              adb shell am instrument -w ${diagnosticsPackage}.test/androidx.test.runner.AndroidJUnitRunner

            Latest Gradle results stored in: ${project.buildDir}/outputs/androidTest-results/connected
            """.trimIndent()
        )

        val sourceDir = File(project.buildDir, "outputs/androidTest-results/connected")
        if (sourceDir.exists()) {
            val targetDir = File(logsDir, "connected")
            if (targetDir.exists()) {
                targetDir.deleteRecursively()
            }
            sourceDir.copyRecursively(targetDir, overwrite = true)
        }
    }
}

dependencies {
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation("androidx.test:core-ktx:1.5.0")
    androidTestImplementation("androidx.test:rules:1.5.0")
    androidTestImplementation("androidx.test:runner:1.5.2")
    androidTestUtil("androidx.test:orchestrator:1.4.2")
}
