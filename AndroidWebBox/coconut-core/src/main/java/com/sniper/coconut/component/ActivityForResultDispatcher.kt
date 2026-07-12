package com.sniper.coconut.component

import android.app.Activity
import android.content.Intent
import com.sniper.coconut.utils.Logger
import java.util.concurrent.atomic.AtomicInteger

/**
 * Activity Result Dispatcher
 *
 * Routes startActivityForResult() results back to Bridge components.
 * Components can launch intents that need a result (camera, picker, etc.)
 * without having to subclass the host Activity.
 *
 * The host Activity (e.g. CoconutWebActivity) must call [dispatch] from
 * its onActivityResult() override.
 */
object ActivityForResultDispatcher {

    private const val TAG = "ActivityResultDispatcher"

    /**
     * Request codes >= this value are owned by this dispatcher.
     * Hosts may use codes below this range for their own purposes.
     */
    private const val BASE_REQUEST_CODE = 50000

    private val nextRequestCode = AtomicInteger(BASE_REQUEST_CODE)
    private val pending = mutableMapOf<Int, (Int, Intent?) -> Unit>()
    private val lock = Any()

    /**
     * Launch an intent expecting a result.
     * Caller is typically suspended in a coroutine waiting on the callback.
     *
     * @return the request code used (for logging/cancellation).
     */
    fun launch(activity: Activity, intent: Intent, callback: (Int, Intent?) -> Unit): Int {
        val code = nextRequestCode.getAndIncrement()
        synchronized(lock) {
            pending[code] = callback
        }
        // Ensure we're on the main thread — startActivityForResult must be called from UI thread
        activity.runOnUiThread {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, code)
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
     * Dispatch an onActivityResult() call.
     * Returns true if the request code was owned by this dispatcher.
     */
    fun dispatch(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val callback = synchronized(lock) { pending.remove(requestCode) } ?: return false
        return try {
            callback(resultCode, data)
            true
        } catch (t: Throwable) {
            Logger.e(TAG, "Error dispatching result for code=$requestCode", t)
            true
        }
    }
}
