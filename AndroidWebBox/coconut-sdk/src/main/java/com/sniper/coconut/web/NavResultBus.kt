package com.sniper.coconut.web

/**
 * Single-slot result bus for coconut.navigator.close({result}).
 *
 * The closing container (B) posts its result; the previous container (A)
 * drains it on resume and pushes `nav.result` to its H5. A single slot is
 * provably sufficient: the back stack is LIFO, so at most one closing child
 * hands control back to its immediate predecessor.
 */
object NavResultBus {

    @Volatile
    private var pending: String? = null

    fun post(result: String) {
        pending = result
    }

    fun consume(): String? {
        val value = pending
        pending = null
        return value
    }
}
