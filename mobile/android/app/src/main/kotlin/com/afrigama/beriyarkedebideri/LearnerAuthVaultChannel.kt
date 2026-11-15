package com.afrigama.beriyarkedebideri

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec

/** Encrypted AndroidKeyStore vault dedicated to learner session secrets (never SharedPreferences). */
class LearnerAuthVaultChannel(private val context: Context, messenger: BinaryMessenger) {
    private val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private val vaultAlias = "bk-learner-auth-vault-v1"

    init {
        MethodChannel(messenger, "bk/learner_auth_v1").setMethodCallHandler { call, result ->
            try {
                if (Build.VERSION.SDK_INT < 23) throw IllegalStateException("Keystore API unavailable")
                when (call.method) {
                    "clear" -> {
                        if (store.containsAlias(vaultAlias)) store.deleteEntry(vaultAlias)
                        context.noBackupFilesDir.listFiles()?.filter {
                            it.name.matches(Regex("bk-learner-auth-[0-9a-f]{64}(\\.bak|\\.new)?"))
                        }?.forEach { it.delete() }
                        result.success(null)
                    }
                    "read", "write", "remove" -> {
                        val scope = call.argument<String>("scope") ?: error("scope required")
                        if (scope.length > 256) error("scope too long")
                        val digest = MessageDigest.getInstance("SHA-256").digest(scope.toByteArray())
                            .joinToString("") { "%02x".format(it) }
                        val file = AtomicFile(File(context.noBackupFilesDir, "bk-learner-auth-$digest"))
                        when (call.method) {
                            "remove" -> {
                                file.delete()
                                result.success(null)
                            }
                            "read" -> {
                                if (!file.baseFile.exists()) {
                                    result.success(null)
                                } else {
                                    ensureVaultKey()
                                    val data = file.readFully()
                                    if (data.size !in 28..65536) error("Invalid vault size")
                                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                                    cipher.init(
                                        Cipher.DECRYPT_MODE,
                                        store.getKey(vaultAlias, null),
                                        GCMParameterSpec(128, data.copyOfRange(0, 12))
                                    )
                                    cipher.updateAAD(scope.toByteArray())
                                    result.success(String(cipher.doFinal(data.copyOfRange(12, data.size)), Charsets.UTF_8))
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
            } catch (_: Exception) {
                result.error("LEARNER_VAULT_ERROR", "Secure storage unavailable", null)
            }
        }
    }

    private fun ensureVaultKey() {
        if (store.containsAlias(vaultAlias)) return
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(
                KeyGenParameterSpec.Builder(vaultAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build()
            )
            generateKey()
        }
    }
}
