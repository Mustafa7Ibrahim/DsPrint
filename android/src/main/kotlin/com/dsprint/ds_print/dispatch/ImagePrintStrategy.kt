package com.dsprint.ds_print.dispatch

import android.content.Context
import com.dsprint.ds_print.channel.DsPrintEventSink
import com.dsprint.ds_print.star.StarPrinterGateway

/**
 * Decodes the assembled base64 slices straight to bitmaps and prints them,
 * without the HTML/WebView round-trip. Reports the real print result to
 * Flutter only after the Star SDK call actually completes (see
 * [StarPrinterGateway]).
 */
class ImagePrintStrategy(
    private val starPrinterGateway: StarPrinterGateway = StarPrinterGateway(),
) {

    fun print(context: Context, request: PrintRequest.Image) {
        starPrinterGateway.printBase64(
            printerId = request.printerId,
            context = context,
            base64Slices = request.slices,
            widthDotsPaper = request.widthDots,
            printerType = request.printerType,
        ) { success ->
            DsPrintEventSink.success(if (success) "success" else "failed")
        }
    }
}
