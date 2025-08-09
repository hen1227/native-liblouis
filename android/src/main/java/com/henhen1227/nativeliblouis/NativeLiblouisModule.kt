package com.henhen1227.nativeliblouis

import android.content.Context
import android.util.Log
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.kotlin.Promise
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class NativeLiblouisModule : Module() {
    companion object {
        private const val TAG = "NativeLiblouisModule"
        private var isInitialized = false
        private var tablesPath: String = ""

        init {
            try {
                System.loadLibrary("liblouis-jni")
                Log.i(TAG, "Successfully loaded liblouis-jni library")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load liblouis-jni library", e)
                throw e
            }
        }

        @JvmStatic
        private external fun nativeSetDataPath(path: String): Boolean

        @JvmStatic
        private external fun nativeTranslate(text: String, table: String): String?

        @JvmStatic
        private external fun nativeBackTranslate(dots: String, table: String): String?

        @JvmStatic
        private external fun nativeGetLastError(): String?
    }

    override fun definition() = ModuleDefinition {
        Name("NativeLiblouisModule")

        Constants(
            "status" to "NativeLiblouisModule is loaded ✅"
        )

        Function("lou_translateString") { text: String, table: String ->
            ensureInitialized()

            val sanitizedInput = text.replace("\u2800", " ") // BRAILLE PATTERN BLANK

            if (sanitizedInput.trim().isEmpty() && text.isNotEmpty()) {
                return@Function " ".repeat(text.length)
            }

            val result = nativeTranslate(sanitizedInput, resolveTablePath(table))

            if (result == null) {
                val error = nativeGetLastError() ?: "Unknown error"
                throw Exception("liblouis translation failed: $error (input: '$text', table: '$table')")
            }

            result
        }

        Function("lou_backTranslateString") { dots: String, table: String ->
            ensureInitialized()

            val sanitizedInput = dots.replace("\u2800", " ") // BRAILLE PATTERN BLANK

            if (sanitizedInput.trim().isEmpty() && dots.isNotEmpty()) {
                return@Function " ".repeat(dots.length)
            }

            val result = nativeBackTranslate(sanitizedInput, resolveTablePath(table))

            if (result == null) {
                val error = nativeGetLastError() ?: "Unknown error"
                throw Exception("liblouis back-translation failed: $error (input: '$dots', table: '$table')")
            }

            result
        }

        Function("lou_isInitialized") {
            ensureInitialized()
            isInitialized
        }
    }

    private fun ensureInitialized() {
        if (isInitialized) return

        Log.i(TAG, "Initializing NativeLiblouisModule...")

        val context = appContext.reactContext
          ?: throw IllegalStateException("React context is null")

        val tablesDir = extractBrailleTables(context)

        if (!tablesDir.exists() || !tablesDir.isDirectory) {
            throw Exception("Failed to extract braille tables to ${tablesDir.absolutePath}")
        }

        tablesPath = tablesDir.absolutePath
        val dataPath = tablesDir.parent ?: throw Exception("Invalid tables directory structure")

        Log.i(TAG, "Setting liblouis data path to: $dataPath")
        Log.i(TAG, "Tables directory: $tablesPath")

        if (!nativeSetDataPath(dataPath)) {
            throw Exception("Failed to initialize liblouis with data path: $dataPath")
        }

        isInitialized = true
        Log.i(TAG, "✅ NativeLiblouisModule initialized successfully")
    }

    private fun extractBrailleTables(context: Context): File {
        val appDir = File(context.filesDir, "liblouis")
        val tablesDir = File(appDir, "tables")

        // Check if tables are already extracted
        if (tablesDir.exists() && tablesDir.listFiles()?.isNotEmpty() == true) {
            Log.i(TAG, "Braille tables already extracted to: ${tablesDir.absolutePath}")
            return tablesDir
        }

        Log.i(TAG, "Extracting braille tables...")

        try {
            // Create directories
            appDir.mkdirs()
            tablesDir.mkdirs()

            // Extract tables from assets
            val assetManager = context.assets
            val tableFiles = assetManager.list("tables") ?: emptyArray()

            if (tableFiles.isEmpty()) {
                throw IOException("No braille table files found in assets/tables")
            }

            Log.i(TAG, "Found ${tableFiles.size} table files to extract")

            for (filename in tableFiles) {
                val inputStream = assetManager.open("tables/$filename")
                val outputFile = File(tablesDir, filename)
                val outputStream = FileOutputStream(outputFile)

                inputStream.use { input ->
                    outputStream.use { output ->
                        input.copyTo(output)
                    }
                }

                Log.d(TAG, "Extracted: $filename")
            }

            Log.i(TAG, "✅ Successfully extracted ${tableFiles.size} braille table files")

        } catch (e: IOException) {
            Log.e(TAG, "Failed to extract braille tables", e)
            throw Exception("Failed to extract braille tables: ${e.message}", e)
        }

        return tablesDir
    }

    private fun resolveTablePath(table: String): String {
        return table.split(",")
            .map { it.trim() }
            .map { tableName ->
                if (tableName.startsWith("/")) {
                    tableName // Absolute path
                } else {
                    File(tablesPath, tableName).absolutePath
                }
            }
            .joinToString(",")
    }
}
