allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Add configuration to handle duplicate Play Core classes
    configurations.all {
        resolutionStrategy {
            // Force a specific version to resolve conflicts
            force("com.google.android.play:core:1.10.3")
            // Exclude the conflicting core-common module
            exclude(group = "com.google.android.play", module = "core-common")
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
