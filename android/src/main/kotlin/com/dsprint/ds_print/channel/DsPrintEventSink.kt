package com.dsprint.ds_print.channel

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Single owner of the `listenFromNative` [EventChannel.EventSink].
 *
 * Replaces the old `MainActivity.eventSinkBigData` mutable public static
 * that both `MainActivity` and `HtmlConverterBase64Activity` wrote to
 * directly. The sink reference is `@Volatile` so that `setSink`/`clear`
 * (always invoked on the UI thread by the EventChannel machinery) are
 * visible to `success`.
 *
 * [EventChannel.EventSink.success] is documented `@UiThread`-only, but the
 * print result is now reported from the Star SDK's background print
 * coroutine (see `StarPrinterGateway`). Rather than trust every caller to
 * already be on the main thread, `success` always posts through a
 * main-looper `Handler` here.
 */
object DsPrintEventSink {

    @Volatile
    private var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun setSink(eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    fun clear() {
        sink = null
    }

    fun success(value: String) {
        mainHandler.post {
            sink?.success(value)
        }
    }
}
