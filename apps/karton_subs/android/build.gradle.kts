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

// receive_sharing_intent 1.8.1 nie ustawia targetow JVM: jego Java kompiluje
// na domyslne 1.8, a Kotlin 2.x domyslnie celuje wyzej -> blad "Inconsistent
// JVM Target Compatibility". Sprowadzamy Kotlin TEJ wtyczki do 1.8 (spojnie
// z jej Java); reszty wtyczek nie ruszamy - sa spojne same z siebie.
subprojects {
    if (name == "receive_sharing_intent") {
        plugins.withId("org.jetbrains.kotlin.android") {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
