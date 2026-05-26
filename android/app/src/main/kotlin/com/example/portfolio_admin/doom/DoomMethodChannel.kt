package com.example.portfolio_admin.doom

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter method channel for launching native DOOM.
 */
class DoomMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.example.portfolio_admin/doom"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "launchDoom" -> {
                val gameName = call.argument<String>("game") ?: "DOOM1"
                val game = try {
                    DoomGame.valueOf(gameName)
                } catch (e: IllegalArgumentException) {
                    DoomGame.DOOM1
                }

                DoomActivity.launch(context, game)
                result.success(true)
            }

            "isWadCached" -> {
                val gameName = call.argument<String>("game") ?: "DOOM1"
                val game = try {
                    DoomGame.valueOf(gameName)
                } catch (e: IllegalArgumentException) {
                    DoomGame.DOOM1
                }

                val wadManager = WadDownloadManager(context)
                result.success(wadManager.isWadCached(game))
            }

            "clearWadCache" -> {
                val gameName = call.argument<String>("game")
                val wadManager = WadDownloadManager(context)

                if (gameName != null) {
                    val game = try {
                        DoomGame.valueOf(gameName)
                    } catch (e: IllegalArgumentException) {
                        result.error("INVALID_GAME", "Invalid game name", null)
                        return
                    }
                    wadManager.clearCache(game)
                } else {
                    wadManager.clearAllCache()
                }

                result.success(true)
            }

            "getCacheSize" -> {
                val wadManager = WadDownloadManager(context)
                result.success(wadManager.getCacheSize())
            }

            else -> {
                result.notImplemented()
            }
        }
    }
}
