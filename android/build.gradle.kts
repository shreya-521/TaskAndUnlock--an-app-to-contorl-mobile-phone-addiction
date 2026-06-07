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
    fun configureAndroidNamespace(proj: Project) {
        val android = proj.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespaceMethod = android.javaClass.getMethod("getNamespace")
                val namespace = getNamespaceMethod.invoke(android)
                if (namespace == null) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    val fallbackNamespace = "com.taskandunlock." + proj.name.replace(":", "_").replace("-", "_")
                    setNamespaceMethod.invoke(android, fallbackNamespace)
                    proj.logger.quiet("Dynamically injected namespace for subproject ${proj.name} -> $fallbackNamespace")
                }
            } catch (e: Exception) {
                // Ignore if getNamespace/setNamespace does not exist
            }
        }
    }

    if (state.executed) {
        configureAndroidNamespace(this)
    } else {
        afterEvaluate {
            configureAndroidNamespace(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
