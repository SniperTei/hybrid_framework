package com.sniper.coconut.resource

import android.content.Context

/**
 * Holds the singleton OfflineResourceManager instance
 */
object CoconutResourceHolder {
    @Volatile
    private var instance: OfflineResourceManager? = null

    fun get(context: Context): OfflineResourceManager {
        return instance ?: synchronized(this) {
            instance ?: OfflineResourceManager(context.applicationContext).also {
                it.init()
                instance = it
            }
        }
    }
}
