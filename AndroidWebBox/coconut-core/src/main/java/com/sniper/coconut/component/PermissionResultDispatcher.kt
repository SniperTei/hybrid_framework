package com.sniper.coconut.component

import android.app.Activity
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import com.sniper.coconut.utils.Logger
import java.util.concurrent.atomic.AtomicInteger

/**
 * Permission Result Dispatcher
 *
 * Routes onRequestPermissionsResult() callbacks back to Bridge components.
 * Mirrors [ActivityForResultDispatcher]: components request runtime permissions
 * and suspend on a callback instead of having to subclass the host Activity.
 *
 * The host Activity (e.g. CoconutWebActivity) must call [dispatch] from
 * its onRequestPermissionsResult() override.
 *
 * Request codes start at [BASE_REQUEST_CODE] (60_000) to avoid collisions with
 * [ActivityForResultDispatcher] (50_000) and host-specific codes.
 */
object PermissionResultDispatcher {

    private const val TAG = "PermissionResultDispatcher"

    /**
     * Request codes >= this value are owned by this dispatcher.
     * Hosts may use codes below this range for their own purposes.
     */
    private const val BASE_REQUEST_CODE = 60000

    private val nextRequestCode = AtomicInteger(BASE_REQUEST_CODE)
    private val pending = mutableMapOf<Int, (Map<String, Boolean>) -> Unit>()
    private val lock = Any()

    /**
     * Result callback receives a map of permission -> granted.
     * Granted is true iff [PackageManager.PERMISSION_GRANTED].
     */
    fun request(
        activity: Activity,
        permissions: Array<String>,
        callback: (Map<String, Boolean>) -> Unit
    ): Int {
        val code = nextRequestCode.getAndIncrement()
        synchronized(lock) {
            pending[code] = callback
        }
        activity.runOnUiThread {
            ActivityCompat.requestPermissions(activity, permissions, code)
        }
        return code
    }

    /**
     * Cancel a pending request (e.g. when the calling coroutine is cancelled).
     */
    fun cancel(requestCode: Int) {
        synchronized(lock) {
            pending.remove(requestCode)
        }
    }

    /**
     * Dispatch an onRequestPermissionsResult() call.
     * Returns true if the request code was owned by this dispatcher.
     */
    fun dispatch(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        val callback = synchronized(lock) { pending.remove(requestCode) } ?: return false
        return try {
            val result: Map<String, Boolean> = permissions.indices.mapNotNull { i ->
                val perm = permissions.getOrNull(i) ?: return@mapNotNull null
                perm to (grantResults.getOrNull(i) == PackageManager.PERMISSION_GRANTED)
            }.toMap()
            callback(result)
            true
        } catch (t: Throwable) {
            Logger.e(TAG, "Error dispatching permission result for code=$requestCode", t)
            true
        }
    }
}
