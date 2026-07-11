allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureProject = {
        val ext = extensions.findByName("android")
        if (ext != null) {
            val baseExt = ext as? com.android.build.gradle.BaseExtension
            baseExt?.compileSdkVersion(36)
        }
    }
    if (state.executed) {
        configureProject()
    } else {
        afterEvaluate {
            configureProject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
