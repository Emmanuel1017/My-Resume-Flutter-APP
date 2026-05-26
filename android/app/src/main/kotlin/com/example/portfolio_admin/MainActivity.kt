package com.example.portfolio_admin

import android.os.Build
import android.os.Bundle
import com.example.portfolio_admin.doom.DoomMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register DOOM method channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DoomMethodChannel.CHANNEL_NAME
        ).setMethodCallHandler(DoomMethodChannel(this))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Sustained performance mode (API 24+):
        // Caps CPU/GPU to a thermally stable envelope so the device never
        // boosts → throttles → recovers mid-scroll, which is the main source
        // of visible jank on mid-range and low-end devices.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            window.setSustainedPerformanceMode(true)
        }
    }

    override fun onResume() {
        super.onResume()
        requestHighRefreshRate()
    }

    /**
     * Asks the display subsystem to run at the highest available refresh rate
     * (e.g. 120 Hz on capable devices). Flutter's vsync ticker automatically
     * syncs to whatever rate the display surface delivers.
     *
     * API 23 (Android 6): preferredDisplayModeId in LayoutParams
     * API 30 (Android 11): uses the new Display reference via getDisplay()
     */
    private fun requestHighRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display ?: return
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay ?: return
        }

        val modes = display.supportedModes
        if (modes.isEmpty()) return

        val currentMode = display.mode
        val best = modes
            .filter { it.refreshRate >= currentMode.refreshRate }
            .maxWithOrNull(
                compareBy({ it.refreshRate },
                          { it.physicalWidth * it.physicalHeight })
            ) ?: return

        val params = window.attributes
        params.preferredDisplayModeId = best.modeId
        window.attributes = params
    }
}
