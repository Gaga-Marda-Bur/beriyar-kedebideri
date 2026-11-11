package com.afrigama.beriyarkedebideri

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec

/** No advertising ID, no SharedPreferences, no private key exported to Dart. */
class CommerceVaultChannel(private val context: Context, messenger: BinaryMessenger) {
    private val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private val deviceAlias = "bk-commerce-device-v1"
    private val vaultAlias = "bk-commerce-vault-v1"

    init {
        MethodChannel(messenger, "bk/commerce_v1").setMethodCallHandler { call, result ->
            try {
                if (Build.VERSION.SDK_INT < 23) throw IllegalStateException("Keystore API unavailable")
                when (call.method) {
                    "resetSession" -> {
                        // Cryptographic erasure even if deleting an old ciphertext fails.
                        // This alias encrypts ONLY commerce data, never learning preferences.
                        if (store.containsAlias(vaultAlias)) store.deleteEntry(vaultAlias)
                        context.noBackupFilesDir.listFiles()?.filter {
                            it.name.matches(Regex("bk-commerce-[0-9a-f]{64}(\\.bak|\\.new)?"))
                        }?.forEach { it.delete() }
                        result.success(null)
                    }
                    "clock" -> {
                        val boot = if (Build.VERSION.SDK_INT >= 24) {
                            Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT).toString()
                        } else {
                            File("/proc/sys/kernel/random/boot_id").readText().trim()
                        }
                        if (boot.isBlank()) throw IllegalStateException("Boot identity unavailable")
                        result.success(mapOf("boot" to boot, "elapsed_ms" to SystemClock.elapsedRealtime()))
                    }
                    "publicKey" -> {
                        ensureDeviceKey()
                        result.success(Base64.encodeToString(store.getCertificate(deviceAlias).publicKey.encoded, Base64.NO_WRAP))
                    }
                    "sign" -> {
                        val message = call.argument<String>("message") ?: error("message required")
                        if (message.length > 1024 || !message.startsWith("BK-DEVICE/v1\n")) error("Invalid proof domain")
                        ensureDeviceKey()
                        val signature = Signature.getInstance("SHA256withECDSA")
                        signature.initSign(store.getKey(deviceAlias, null) as java.security.PrivateKey)
                        signature.update(message.toByteArray(Charsets.US_ASCII))
                        result.success(Base64.encodeToString(signature.sign(), Base64.NO_WRAP))
                    }
                    "read", "write", "remove" -> {
                        val scope = call.argument<String>("scope") ?: error("scope required")
                        if (scope.length > 256) error("scope too long")
                        val digest = MessageDigest.getInstance("SHA-256").digest(scope.toByteArray())
                            .joinToString("") { "%02x".format(it) }
                        val file = AtomicFile(File(context.noBackupFilesDir, "bk-commerce-$digest"))
                        when (call.method) {
                            "remove" -> { file.delete(); result.success(null) }
                            "read" -> {
                                if (!file.baseFile.exists()) result.success(null) else {
                                    ensureVaultKey()
                                    val data = file.readFully()
                                    if (data.size !in 28..65536) error("Invalid vault size")
                                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                                    cipher.init(Cipher.DECRYPT_MODE, store.getKey(vaultAlias, null), GCMParameterSpec(128, data.copyOfRange(0,12)))
                                    cipher.updateAAD(scope.toByteArray())
                                    result.success(String(cipher.doFinal(data.copyOfRange(12,data.size)), Charsets.UTF_8))
                                }
                            }
                            else -> {
                                val value = call.argument<String>("value") ?: error("value required")
                                val raw = value.toByteArray(Charsets.UTF_8)
                                if (raw.size > 60000) error("value too long")
                                ensureVaultKey()
                                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                                cipher.init(Cipher.ENCRYPT_MODE, store.getKey(vaultAlias, null))
                                cipher.updateAAD(scope.toByteArray())
                                val encrypted = cipher.iv + cipher.doFinal(raw)
                                val stream = file.startWrite()
                                try {
                                    stream.write(encrypted)
                                    file.finishWrite(stream)
                                } catch (exc: Exception) {
                                    file.failWrite(stream)
                                    throw exc
                                }
                                result.success(null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (exc: Exception) {
                // No key material, account ID, payload or filesystem details in errors.
                result.error("COMMERCE_UNAVAILABLE", "Online validation required", null)
            }
        }
    }

    private fun ensureDeviceKey() {
        if (store.containsAlias(deviceAlias)) return
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore").apply {
            initialize(KeyGenParameterSpec.Builder(deviceAlias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256).build())
            generateKeyPair()
        }
    }

    private fun ensureVaultKey() {
        if (store.containsAlias(vaultAlias)) return
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(vaultAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
            generateKey()
        }
    }
}
