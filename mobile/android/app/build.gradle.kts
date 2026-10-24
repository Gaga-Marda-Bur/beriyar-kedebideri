import java.util.Base64
import java.net.URI
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// --- A13 : garde-fou release -------------------------------------------------
// Flutter transmet les --dart-define à Gradle via la propriété « dart-defines »
// (entrées Base64 séparées par des virgules). Une release doit cibler une API
// HTTPS publique, avec un environnement explicite, et être signée avec la clé
// existante (key.properties). Aucun fichier de signature n'est créé ni modifié.
fun decodeDartDefines(raw: String?): Map<String, String> {
    if (raw.isNullOrBlank()) return emptyMap()
    return raw.split(",").filter { it.isNotBlank() }.mapNotNull { encoded ->
        val decoded = try {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        } catch (e: IllegalArgumentException) {
            return@mapNotNull null
        }
        val separator = decoded.indexOf('=')
        if (separator <= 0) null else decoded.substring(0, separator) to decoded.substring(separator + 1)
    }.toMap()
}

fun isLocalOrPrivateHost(rawHost: String): Boolean {
    val host = rawHost.lowercase().removePrefix("[").removeSuffix("]").trimEnd('.')
    if (host == "localhost" || host.endsWith(".localhost") || host.endsWith(".local") ||
        host == "0.0.0.0" || host == "::1" || host == "::" || host.contains('%') ||
        host.startsWith("::ffff:") || Regex("^fe[89ab][0-9a-f]:").containsMatchIn(host) ||
        ((host.startsWith("fc") || host.startsWith("fd")) && host.contains(":"))
    ) return true
    if (!host.contains('.') && !host.contains(':')) return true
    if (host.contains(':')) {
        val words = host.split(":").filter { it.isNotEmpty() }
        if (words.isNotEmpty() && words.dropLast(1).all { it.toIntOrNull(16) == 0 } &&
            (words.last().toIntOrNull(16) ?: 2) <= 1) return true
    }
    val parts = host.split(".")
    if (parts.all { it.toIntOrNull() != null } && parts.size != 4) return true
    if (parts.any { it.startsWith("0x") || (it.length > 1 && it.startsWith("0") && it.toIntOrNull() != null) }) return true
    val octets = host.split(".").map { it.toIntOrNull() }
    if (octets.size == 4 && octets.all { it != null && it in 0..255 }) {
        val a = octets[0]!!
        val b = octets[1]!!
        return a == 127 || a == 10 || a == 0 || (a == 169 && b == 254) ||
            (a == 172 && b in 16..31) || (a == 192 && b == 168) || (a == 100 && b in 64..127)
    }
    return false
}

fun releaseConfigurationIssues(defines: Map<String, String>): List<String> {
    val issues = mutableListOf<String>()
    val flavor = defines["API_FLAVOR"]?.trim().orEmpty()
    if (flavor != "production" && flavor != "staging") {
        issues += if (flavor.isEmpty()) {
            "API_FLAVOR absent : ajoutez --dart-define=API_FLAVOR=production (ou staging)."
        } else {
            "API_FLAVOR=\"$flavor\" interdit en release (production ou staging)."
        }
    }
    val customUrl = defines["API_BASE_URL"]?.trim().orEmpty()
    if (customUrl.isNotEmpty()) {
        val uri = try { URI(customUrl) } catch (e: Exception) { null }
        if (uri == null || uri.host.isNullOrBlank()) {
            issues += "API_BASE_URL invalide."
        } else {
            if (uri.scheme != "https") issues += "API_BASE_URL doit utiliser HTTPS."
            if (uri.rawQuery != null || uri.rawFragment != null) issues += "API_BASE_URL ne doit pas contenir de paramètres ou fragments."
            if (!uri.userInfo.isNullOrEmpty()) issues += "API_BASE_URL ne doit pas contenir d'identifiants."
            if (isLocalOrPrivateHost(uri.host)) issues += "API_BASE_URL cible un hôte local ou privé : \"${uri.host}\"."
        }
    }
    return issues
}

// Valeurs calculées à la configuration : les blocs doFirst ne capturent que des chaînes.
val a13ReleaseIssues: List<String> = releaseConfigurationIssues(
    decodeDartDefines(project.findProperty("dart-defines") as String?)
)
val a13SigningIssues: List<String> = buildList {
    if (!keystorePropertiesFile.exists()) {
        add("android/key.properties introuvable : la release doit être signée avec la clé existante.")
    } else {
        for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
            if (keystoreProperties.getProperty(key).isNullOrBlank()) add("key.properties : « $key » manquant.")
        }
        val storePath = keystoreProperties.getProperty("storeFile")
        if (!storePath.isNullOrBlank() && !file(storePath).exists()) {
            add("Keystore introuvable : $storePath (aucune clé de remplacement ne sera générée).")
        }
    }
}
// -----------------------------------------------------------------------------

android {
    namespace = "com.afrigama.beriyarkedebideri"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        applicationId = "com.afrigama.beriyarkedebideri"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists() && listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                    .all { !keystoreProperties.getProperty(it).isNullOrBlank() }) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// A13 : échec immédiat d'une release mal configurée (debug/profile non concernés).
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    val issues = a13ReleaseIssues + a13SigningIssues
    doFirst {
        if (issues.isNotEmpty()) {
            throw GradleException(
                "Build release refusé (A13) :\n - " + issues.joinToString("\n - ") +
                    "\nVoir docs/RELEASE_MOBILE.md."
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
