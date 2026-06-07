package com.taskandunlock.task_and_unlock

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.os.Handler
import android.os.Looper
import android.util.Log

class AppBlockerAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var activePackageName: String? = null
    private var startTime: Long = 0
    private var trackingRunnable: Runnable? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return
            handlePackageChange(packageName)
        }
    }

    private fun handlePackageChange(newPackage: String) {
        // Exclude system UI, launchers, and our own app
        if (newPackage == "com.android.systemui" || 
            newPackage == "com.taskandunlock.task_and_unlock" ||
            newPackage == activePackageName) {
            return
        }

        // Save usage for previous package if it was a tracked app
        saveUsageOfActiveApp()

        activePackageName = newPackage

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isBlocked = prefs.getBoolean("flutter.blocked_package_$newPackage", false)

        if (isBlocked) {
            startTime = System.currentTimeMillis()
            startTracking(newPackage)
        } else {
            stopTracking()
        }
    }

    private fun startTracking(packageName: String) {
        stopTracking()
        trackingRunnable = object : Runnable {
            override fun run() {
                checkAndBlock(packageName)
                handler.postDelayed(this, 10000) // Check limit status every 10 seconds
            }
        }
        handler.post(trackingRunnable!!)
    }

    private fun stopTracking() {
        trackingRunnable?.let { handler.removeCallbacks(it) }
        trackingRunnable = null
    }

    private fun checkAndBlock(packageName: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Calculate current session minutes
        val elapsedMillis = System.currentTimeMillis() - startTime
        val elapsedMinutes = (elapsedMillis / 60000).toInt()
        
        // Get today's usage and limit
        val todayUsage = prefs.getLong("flutter.usage_$packageName", 0L).toInt()
        val totalUsage = todayUsage + elapsedMinutes
        
        val limit = prefs.getLong("flutter.limit_$packageName", 30L).toInt()
        
        // Check if temporarily unlocked
        val unlockUntil = prefs.getLong("flutter.unlock_until_ms_$packageName", 0L)
        val isUnlocked = System.currentTimeMillis() < unlockUntil

        Log.d("AppBlockerService", "$packageName: usage=$totalUsage min, limit=$limit min, unlocked=$isUnlocked")

        if (totalUsage >= limit && !isUnlocked) {
            launchBlockScreen(packageName)
        }
    }

    private fun saveUsageOfActiveApp() {
        val packageName = activePackageName ?: return
        if (startTime == 0L) return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isBlocked = prefs.getBoolean("flutter.blocked_package_$packageName", false)
        if (!isBlocked) return

        val elapsedMillis = System.currentTimeMillis() - startTime
        val elapsedMinutes = (elapsedMillis / 60000).toInt()
        
        if (elapsedMinutes > 0) {
            val todayUsage = prefs.getLong("flutter.usage_$packageName", 0L).toInt()
            prefs.edit().putLong("flutter.usage_$packageName", (todayUsage + elapsedMinutes).toLong()).apply()
            Log.d("AppBlockerService", "Saved $elapsedMinutes min of usage for $packageName")
        }
        startTime = 0L
    }

    private fun launchBlockScreen(packageName: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("blocked_package", packageName)
        }
        startActivity(intent)
    }

    override fun onInterrupt() {
        stopTracking()
    }

    override fun onDestroy() {
        super.onDestroy()
        saveUsageOfActiveApp()
        stopTracking()
    }
}
