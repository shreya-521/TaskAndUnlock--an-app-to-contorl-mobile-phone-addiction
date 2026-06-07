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
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespaceMethod = android.javaClass.getMethod("getNamespace")
                val namespace = getNamespaceMethod.invoke(android)
                if (namespace == null) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    val fallbackNamespace = "com.taskandunlock." + project.name.replace(":", "_").replace("-", "_")
                    setNamespaceMethod.invoke(android, fallbackNamespace)
                    logger.quiet("Dynamically injected namespace for subproject ${project.name} -> $fallbackNamespace")
                }
            } catch (e: Exception) {
                // Ignore if getNamespace/setNamespace does not exist on older AGP versions
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
