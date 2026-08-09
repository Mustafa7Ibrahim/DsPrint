package com.dsprint.ds_print.dispatch

import android.content.Context
import android.content.Intent
import com.dsprint.ds_print.html.HtmlConverterActivity

/**
 * Launches [HtmlConverterActivity] to render the HTML payload in a WebView,
 * screenshot it, and print the resulting bitmap. The activity reports its
 * own result via `DsPrintEventSink` once printing finishes.
 */
class HtmlPrintStrategy {

    fun print(context: Context, request: PrintRequest.Html) {
        val intent = Intent(context, HtmlConverterActivity::class.java).apply {
            putExtra(EXTRA_HTML, request.html)
            putExtra(EXTRA_PRINTER_ID, request.printerId)
            putExtra(EXTRA_PRINTER_TYPE, request.printerType)
            putExtra(EXTRA_WIDTH_DOTS, request.widthDots)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    companion object {
        const val EXTRA_HTML = "html_load"
        const val EXTRA_PRINTER_ID = "printer_id"
        const val EXTRA_PRINTER_TYPE = "printerType"
        const val EXTRA_WIDTH_DOTS = "width_dots"
    }
}
