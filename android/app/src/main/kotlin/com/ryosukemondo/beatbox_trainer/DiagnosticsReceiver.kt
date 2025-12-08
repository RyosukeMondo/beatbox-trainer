package com.ryosukemondo.beatbox_trainer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Broadcast receiver that records diagnostics lifecycle events (JNI load/unload
 * and permission callbacks) into a small ring buffer that instrumentation tests
 * and adb logcat consumers can inspect.
 */
class DiagnosticsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        if (intent.action != ACTION_DIAGNOSTICS_EVENT) {
            Log.w(TAG, "Ignoring intent ${intent.action}")
            return
        }

        val phase = intent.getStringExtra(EXTRA_PHASE)?.let {
            runCatching { DiagnosticsPhase.valueOf(it) }.getOrNull()
        } ?: return
        val status = intent.getStringExtra(EXTRA_STATUS)?.let {
            runCatching { DiagnosticsStatus.valueOf(it) }.getOrNull()
        } ?: DiagnosticsStatus.SUCCESS
        val detail = intent.getStringExtra(EXTRA_DETAIL).orEmpty()
        val timestamp = intent.getLongExtra(EXTRA_TIMESTAMP, System.currentTimeMillis())
        val permission = intent.getStringExtra(EXTRA_PERMISSION)
        val granted = if (intent.hasExtra(EXTRA_GRANTED)) {
            intent.getBooleanExtra(EXTRA_GRANTED, false)
        } else {
            null
        }

        val entry = DiagnosticsLogEntry(
            phase = phase,
            status = status,
            detail = detail,
            timestampMs = timestamp,
            permission = permission,
            granted = granted,
        )

        DiagnosticsLogBuffer.record(entry)
        logEvent(entry)
    }

    private fun logEvent(entry: DiagnosticsLogEntry) {
        val priority = when (entry.status) {
            DiagnosticsStatus.FAILURE -> Log.ERROR
            DiagnosticsStatus.WARNING -> Log.WARN
            DiagnosticsStatus.SUCCESS -> Log.INFO
        }

        val summary = "[${entry.phase}] ${entry.detail.ifEmpty { "(no detail)" }} " +
            "permission=${entry.permission ?: "-"} granted=${entry.granted?.toString() ?: "-"}"
        Log.println(priority, TAG, summary)
    }

    companion object {
        private const val TAG = "DiagnosticsReceiver"

        const val ACTION_DIAGNOSTICS_EVENT =
            "com.ryosukemondo.beatbox_trainer.DIAGNOSTICS_EVENT"
        private const val EXTRA_PHASE = "extra_phase"
        private const val EXTRA_STATUS = "extra_status"
        private const val EXTRA_DETAIL = "extra_detail"
        private const val EXTRA_PERMISSION = "extra_permission"
        private const val EXTRA_GRANTED = "extra_granted"
        private const val EXTRA_TIMESTAMP = "extra_timestamp"

        fun logJniLoad(context: Context, success: Boolean, detail: String) {
            emit(
                context = context,
                phase = DiagnosticsPhase.JNI_LOAD,
                status = if (success) DiagnosticsStatus.SUCCESS else DiagnosticsStatus.FAILURE,
                detail = detail,
            )
        }

        fun logJniUnload(context: Context, detail: String = "Native runtime detached") {
            emit(
                context = context,
                phase = DiagnosticsPhase.JNI_UNLOAD,
                status = DiagnosticsStatus.SUCCESS,
                detail = detail,
            )
        }

        fun logPermissionResult(
            context: Context,
            permission: String,
            granted: Boolean,
            requestCode: Int,
        ) {
            val status = if (granted) DiagnosticsStatus.SUCCESS else DiagnosticsStatus.FAILURE
            val detail = "permission=$permission request=$requestCode granted=$granted"
            emit(
                context = context,
                phase = DiagnosticsPhase.PERMISSION_RESULT,
                status = status,
                detail = detail,
                permission = permission,
                granted = granted,
            )
        }

        fun emit(
            context: Context,
            phase: DiagnosticsPhase,
            status: DiagnosticsStatus,
            detail: String,
            permission: String? = null,
            granted: Boolean? = null,
        ) {
            val diagnosticsIntent = Intent(context, DiagnosticsReceiver::class.java).apply {
                action = ACTION_DIAGNOSTICS_EVENT
                putExtra(EXTRA_PHASE, phase.name)
                putExtra(EXTRA_STATUS, status.name)
                putExtra(EXTRA_DETAIL, detail)
                putExtra(EXTRA_TIMESTAMP, System.currentTimeMillis())
                permission?.let { putExtra(EXTRA_PERMISSION, it) }
                granted?.let { putExtra(EXTRA_GRANTED, it) }
            }
            context.applicationContext.sendBroadcast(diagnosticsIntent)
        }
    }
}

enum class DiagnosticsPhase {
    JNI_LOAD,
    JNI_UNLOAD,
    PERMISSION_RESULT,
}

enum class DiagnosticsStatus {
    SUCCESS,
    WARNING,
    FAILURE,
}

data class DiagnosticsLogEntry(
    val phase: DiagnosticsPhase,
    val status: DiagnosticsStatus,
    val detail: String,
    val timestampMs: Long,
    val permission: String? = null,
    val granted: Boolean? = null,
)

object DiagnosticsLogBuffer {
    private const val MAX_EVENTS = 256
    private val entries = ArrayDeque<DiagnosticsLogEntry>()

    @Synchronized
    fun record(entry: DiagnosticsLogEntry) {
        if (entries.size >= MAX_EVENTS) {
            entries.removeFirst()
        }
        entries.addLast(entry)
    }

    @Synchronized
    fun snapshot(): List<DiagnosticsLogEntry> = entries.toList()

    @Synchronized
    fun clear() {
        entries.clear()
    }
}
