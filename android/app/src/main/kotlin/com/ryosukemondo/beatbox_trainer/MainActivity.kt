package com.ryosukemondo.beatbox_trainer

import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        DiagnosticsReceiver.logJniLoad(
            context = applicationContext,
            success = libraryLoaded,
            detail = nativeLoadDetail,
        )

        if (libraryLoaded) {
            try {
                initializeAudioContext(applicationContext)
                DiagnosticsReceiver.emit(
                    context = applicationContext,
                    phase = DiagnosticsPhase.JNI_LOAD,
                    status = DiagnosticsStatus.SUCCESS,
                    detail = "initializeAudioContext completed",
                )
                Log.i(TAG, "Successfully initialized audio context")
            } catch (e: Exception) {
                DiagnosticsReceiver.emit(
                    context = applicationContext,
                    phase = DiagnosticsPhase.JNI_LOAD,
                    status = DiagnosticsStatus.FAILURE,
                    detail = "initializeAudioContext failed: ${e.message}",
                )
                Log.e(TAG, "Failed to initialize audio context", e)
                Log.e(TAG, "Audio engine may not function correctly")
            }
        } else {
            DiagnosticsReceiver.emit(
                context = applicationContext,
                phase = DiagnosticsPhase.JNI_LOAD,
                status = DiagnosticsStatus.WARNING,
                detail = "Native library not loaded, skipping initializeAudioContext",
            )
            Log.w(TAG, "Skipping audio context initialization - native library not loaded")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        DiagnosticsReceiver.logJniUnload(applicationContext)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        permissions.forEachIndexed { index, permission ->
            val granted = grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
            DiagnosticsReceiver.logPermissionResult(
                context = applicationContext,
                permission = permission,
                granted = granted,
                requestCode = requestCode,
            )
        }
    }

    companion object {
        private const val TAG = "MainActivity"
        private var libraryLoaded = false
        private var nativeLoadDetail: String = "Native library load pending"

        init {
            try {
                System.loadLibrary("beatbox_trainer")
                libraryLoaded = true
                nativeLoadDetail = "Successfully loaded beatbox_trainer JNI library"
                Log.i(TAG, nativeLoadDetail)
            } catch (e: UnsatisfiedLinkError) {
                libraryLoaded = false
                nativeLoadDetail =
                    "Failed to load beatbox_trainer JNI library: ${e.message ?: "unknown error"}"
                Log.e(TAG, nativeLoadDetail, e)
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
}
