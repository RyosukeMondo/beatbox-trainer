package com.ryosukemondo.beatbox_trainer

import android.content.Context
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DiagnosticsLifecycleTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Before
    fun setUp() {
        DiagnosticsLogBuffer.clear()
    }

    @Test
    fun broadcastReceiverRecordsLifecycleOrdering() {
        DiagnosticsReceiver.emit(
            context = context,
            phase = DiagnosticsPhase.JNI_LOAD,
            status = DiagnosticsStatus.SUCCESS,
            detail = "native load complete",
        )

        DiagnosticsReceiver.emit(
            context = context,
            phase = DiagnosticsPhase.JNI_UNLOAD,
            status = DiagnosticsStatus.SUCCESS,
            detail = "engine teardown",
        )

        awaitEntries(2)

        val entries = DiagnosticsLogBuffer.snapshot()
        assertEquals(DiagnosticsPhase.JNI_LOAD, entries[0].phase)
        assertEquals(DiagnosticsPhase.JNI_UNLOAD, entries[1].phase)
        assertTrue(
            "events should be monotonic",
            entries[0].timestampMs <= entries[1].timestampMs,
        )
    }

    @Test
    fun permissionFailureIsFlaggedForTelemetry() {
        DiagnosticsReceiver.logPermissionResult(
            context = context,
            permission = "android.permission.RECORD_AUDIO",
            granted = false,
            requestCode = 77,
        )

        awaitEntries(1)

        val entry = DiagnosticsLogBuffer.snapshot().last()
        assertEquals(DiagnosticsPhase.PERMISSION_RESULT, entry.phase)
        assertEquals(DiagnosticsStatus.FAILURE, entry.status)
        assertEquals("android.permission.RECORD_AUDIO", entry.permission)
        assertFalse(entry.granted!!)
        assertTrue(entry.detail.contains("granted=false"))
    }

    @Test
    fun jniLoadFailuresSurfaceTelemetryWarning() {
        DiagnosticsReceiver.logJniLoad(
            context = context,
            success = false,
            detail = "Shared object missing",
        )

        awaitEntries(1)

        val entry = DiagnosticsLogBuffer.snapshot().last()
        assertEquals(DiagnosticsPhase.JNI_LOAD, entry.phase)
        assertEquals(DiagnosticsStatus.FAILURE, entry.status)
        assertTrue(entry.detail.contains("Shared object missing"))
    }

    private fun awaitEntries(count: Int, timeoutMs: Long = 2_000L) {
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        while (SystemClock.elapsedRealtime() < deadline) {
            if (DiagnosticsLogBuffer.snapshot().size >= count) {
                return
            }
            SystemClock.sleep(25)
        }
        fail("Timed out waiting for $count diagnostics entries")
    }
}
