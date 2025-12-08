package au.com.scanandpay.app

import android.app.Application
import android.util.Log
import com.topwise.cloudpos.service.DeviceServiceManager

class ScanPayApplication : Application() {
    companion object {
        private const val TAG = "ScanPayApplication"
    }

    override fun onCreate() {
        super.onCreate()

        // Initialize Topwise Device Service Manager (required for T6 POS hardware access)
        try {
            DeviceServiceManager.getInstance().init(this)
            Log.d(TAG, "DeviceServiceManager initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize DeviceServiceManager: ${e.message}", e)
        }
    }

    override fun onTerminate() {
        super.onTerminate()

        // Clean up Device Service Manager
        try {
            DeviceServiceManager.getInstance().exit(this)
            Log.d(TAG, "DeviceServiceManager cleanup completed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cleanup DeviceServiceManager: ${e.message}", e)
        }
    }
}
