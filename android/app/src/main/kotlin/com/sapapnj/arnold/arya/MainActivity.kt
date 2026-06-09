package com.sapapnj.arnold.arya

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val hapticChannel = "sapa_pnj/haptics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hapticChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "impact") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val type = call.argument<String>("type") ?: "medium"
                triggerHaptic(type)
                result.success(null)
            }
    }

    private fun triggerHaptic(type: String) {
        val vibrator = getVibrator() ?: return
        if (!vibrator.hasVibrator()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val effect = when (type) {
                "selection", "light" -> VibrationEffect.EFFECT_TICK
                "heavy" -> VibrationEffect.EFFECT_HEAVY_CLICK
                else -> VibrationEffect.EFFECT_CLICK
            }
            vibrator.vibrate(VibrationEffect.createPredefined(effect))
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val (durationMs, amplitude) = when (type) {
                "selection" -> 8L to 60
                "light" -> 12L to 80
                "heavy" -> 28L to 180
                else -> 18L to 120
            }
            vibrator.vibrate(
                VibrationEffect.createOneShot(durationMs, amplitude)
            )
            return
        }

        @Suppress("DEPRECATION")
        vibrator.vibrate(
            when (type) {
                "selection" -> 8L
                "light" -> 12L
                "heavy" -> 28L
                else -> 18L
            }
        )
    }

    private fun getVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }
}
