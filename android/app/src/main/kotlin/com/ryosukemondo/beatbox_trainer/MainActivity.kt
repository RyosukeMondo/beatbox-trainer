package com.ryosukemondo.beatbox_trainer

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private var libraryLoaded = false

        init {
            try {
                System.loadLibrary("beatbox_trainer")
                libraryLoaded = true
                Log.i(TAG, "Successfully loaded native library: beatbox_trainer")
            } catch (e: UnsatisfiedLinkError) {
                libraryLoaded = false
                Log.e(TAG, "Failed to load native library: beatbox_trainer", e)
                Log.e(TAG, "Error details: ${e.message}")
                Log.e(TAG, "Possible causes:")
                Log.e(TAG, "  1. Library not found in APK lib/{arch}/ directory")
                Log.e(TAG, "  2. Incompatible architecture (check device ABI)")
                Log.e(TAG, "  3. Missing dependencies or symbol resolution failure")
                Log.e(TAG, "Please verify the APK contains libbeatbox_trainer.so for your device architecture")
            }
        }

        @JvmStatic
        external fun initializeAudioContext(context: android.content.Context)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (libraryLoaded) {
            try {
                initializeAudioContext(applicationContext)
                Log.i(TAG, "Successfully initialized audio context")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize audio context", e)
                Log.e(TAG, "Error details: ${e.message}")
                Log.e(TAG, "Audio engine may not function correctly")
            }
        } else {
            Log.w(TAG, "Skipping audio context initialization - native library not loaded")
        }
    }
}
