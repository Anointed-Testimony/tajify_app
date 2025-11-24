import com.android.build.gradle.LibraryExtension
import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
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
                defaultConfig {
                    if (minSdkVersion == null || minSdkVersion!!.apiLevel < 23) {
                        minSdk = 23
                    }
                    targetSdk = 34
                }
            }
        }
        if (name.contains("ffmpeg_kit_flutter_min_gpl") && this is com.android.build.gradle.LibraryPlugin) {
            project.extensions.configure(LibraryExtension::class.java) {
                if (namespace.isNullOrBlank()) {
                    namespace = "com.arthenica.ffmpegkit"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
