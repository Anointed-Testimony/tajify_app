import com.android.build.gradle.LibraryExtension
import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
}

subprojects {
    plugins.whenPluginAdded {
        if (this is com.android.build.gradle.BasePlugin) {
            project.extensions.configure(BaseExtension::class.java) {
                compileSdkVersion(36)
                if (namespace.isNullOrBlank()) {
                    namespace = "com.tajify." + project.name.replace("-", ".").replace("_", ".")
                }
                defaultConfig {
                    if (minSdkVersion == null || minSdkVersion!!.apiLevel < 23) {
                        minSdk = 23
                    }
                    targetSdk = 35
                }
            }
        }
    }

    val patchManifest = Runnable {
        val manifestFile = project.file("src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            try {
                val contents = manifestFile.readText()
                if (contents.contains("package=")) {
                    val updatedContents = contents.replace(Regex("package=\"[^\"]*\""), "")
                    manifestFile.writeText(updatedContents)
                }
            } catch (e: Exception) {
                println("Failed to patch manifest for ${project.name}: ${e.message}")
            }
        }
    }

    if (project.state.executed) {
        patchManifest.run()
    } else {
        project.afterEvaluate { patchManifest.run() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
