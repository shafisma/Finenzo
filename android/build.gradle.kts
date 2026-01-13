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
    if (project.name == "telephony") {
        val fixNamespace = {
             val android = project.extensions.findByName("android")
             if (android != null) {
                 try {
                     val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                     setNamespace.invoke(android, "com.shounakmulay.telephony")
                 } catch (e: Exception) {
                     project.logger.warn("Failed to set namespace for telephony: ${e.message}")
                 }
             }
        }
        
        if (project.state.executed) {
            fixNamespace()
        } else {
            project.afterEvaluate { fixNamespace() }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
