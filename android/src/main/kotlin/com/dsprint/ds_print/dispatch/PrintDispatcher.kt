package com.dsprint.ds_print.dispatch

import android.content.Context
import com.dsprint.ds_print.channel.DsPrintEventSink
import com.dsprint.ds_print.channel.PrintChannelRequest

/**
 * The parsed, type-safe form of a completed print transfer. Built from the
 * raw `type_data` string so an unrecognised value fails loudly instead of
 * silently falling back to HTML the way the legacy
 * `MainActivity.chooseTypeDataAfterCompleted` did.
 */
sealed class PrintRequest {
    data class Html(
        val html: String,
        val printerId: String,
        val printerType: String,
        val widthDots: Int,
    ) : PrintRequest()

    /**
     * [slices] is the invoice split into vertical bands, top to bottom, each a
     * base64 PNG. Long invoices have to be captured in pieces because a GPU
     * cannot allocate a texture as tall as the whole page; the bands abut
     * exactly, so printing them back to back reproduces the document. A short
     * receipt arrives as a single-element list.
     */
    data class Image(
        val slices: List<String>,
        val printerId: String,
        val printerType: String,
        val widthDots: Int,
    ) : PrintRequest()
}

/**
 * Chooses how to handle a fully-assembled print payload based on its
 * `type_data`. New payload types are added by adding a `PrintRequest`
 * subclass and a strategy; the `when` in [runStrategy] is used as an
 * expression, so the compiler forces every subclass to be handled there.
 */
class PrintDispatcher(
    private val context: Context,
    private val htmlPrintStrategy: HtmlPrintStrategy = HtmlPrintStrategy(),
    private val imagePrintStrategy: ImagePrintStrategy = ImagePrintStrategy(),
) {

    fun dispatch(channelRequest: PrintChannelRequest, assembledPayload: String) {
        val printRequest = toPrintRequest(channelRequest, assembledPayload)
        if (printRequest == null) {
            // Unrecognised type_data: report an explicit failure instead of
            // silently guessing HTML.
            DsPrintEventSink.success("failed")
            return
        }
        runStrategy(printRequest)
    }

    private fun runStrategy(printRequest: PrintRequest): Unit = when (printRequest) {
        is PrintRequest.Html -> htmlPrintStrategy.print(context, printRequest)
        is PrintRequest.Image -> imagePrintStrategy.print(context, printRequest)
    }

    private fun toPrintRequest(
        channelRequest: PrintChannelRequest,
        payload: String,
    ): PrintRequest? = when (channelRequest.typeData) {
        "html" -> PrintRequest.Html(
            html = payload,
            printerId = channelRequest.printerId,
            printerType = channelRequest.printerType,
            widthDots = channelRequest.widthDots,
        )
        // Newline is an unambiguous separator: base64's alphabet is
        // `A-Z a-z 0-9 + / =`, and the Dart side never wraps its output. A
        // payload captured before slicing existed contains no newline, splits
        // to one element, and prints exactly as it always did.
        "base64" -> PrintRequest.Image(
            slices = payload.split('\n').filter { it.isNotBlank() },
            printerId = channelRequest.printerId,
            printerType = channelRequest.printerType,
            widthDots = channelRequest.widthDots,
        )
        else -> null
    }
}
