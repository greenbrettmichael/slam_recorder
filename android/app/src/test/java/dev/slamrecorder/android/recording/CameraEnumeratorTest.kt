package dev.slamrecorder.android.recording

import android.hardware.camera2.CameraCharacteristics
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraEnumeratorTest {
    @Test
    fun `hides logical cameras when physical children exist`() {
        val options = buildCameraOptions(
            listOf(
                CameraInfo(
                    id = "0",
                    facing = CameraCharacteristics.LENS_FACING_BACK,
                    physicalIds = setOf("2", "4"),
                    focalLength = null,
                ),
                CameraInfo("2", CameraCharacteristics.LENS_FACING_BACK, emptySet(), 2.2f),
                CameraInfo("4", CameraCharacteristics.LENS_FACING_BACK, emptySet(), 4.5f),
            ),
        )

        assertFalse(options.any { it.id == "0" })
        assertTrue(options.any { it.id == "2" })
        assertTrue(options.any { it.id == "4" })
    }

    @Test
    fun `deduplicates physical cameras with same facing and focal`() {
        val options = buildCameraOptions(
            listOf(
                CameraInfo("0", CameraCharacteristics.LENS_FACING_BACK, setOf("2", "5"), null),
                CameraInfo("2", CameraCharacteristics.LENS_FACING_BACK, emptySet(), 3.5f),
                CameraInfo("5", CameraCharacteristics.LENS_FACING_BACK, emptySet(), 3.5f),
            ),
        )

        val backCams = options.filter { it.facing == CameraCharacteristics.LENS_FACING_BACK }
        assertEquals(1, backCams.size)
        assertEquals("3.5", String.format("%.1f", backCams.first().focalLength))
    }

    @Test
    fun `labels physical cameras with type hint`() {
        val options = buildCameraOptions(
            listOf(
                CameraInfo("0", CameraCharacteristics.LENS_FACING_BACK, setOf("2"), null),
                CameraInfo("2", CameraCharacteristics.LENS_FACING_BACK, emptySet(), 2.1f),
            ),
        )
        val label = options.first().label

        assertTrue(label.contains("Ultra-wide"))
    }
}
