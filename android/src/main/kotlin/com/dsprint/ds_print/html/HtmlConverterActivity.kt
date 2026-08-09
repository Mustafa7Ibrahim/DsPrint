package com.dsprint.ds_print.html

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ScrollView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.dsprint.ds_print.R
import com.dsprint.ds_print.channel.DsPrintEventSink
import com.dsprint.ds_print.dispatch.HtmlPrintStrategy
import com.dsprint.ds_print.star.StarPrinterGateway

private const val TAG = "HtmlConverterActivity"
private const val CAPTURE_DELAY_MS = 1000L
private const val DISMISS_DELAY_MS = 1000L

/**
 * Renders an HTML payload off-screen in a WebView, screenshots the rendered
 * ScrollView to a Bitmap once layout has settled, prints it via
 * [StarPrinterGateway], and reports the result on [DsPrintEventSink].
 *
 * All per-job state (printer id/type/width) is read once from the launching
 * Intent's extras into local `val`s in [onCreate] and threaded through
 * function parameters — never held on a companion object the way the
 * legacy `HtmlConverterBase64Activity` did (`deviceId`/`printerType`/
 * `widthDotsPaper`/`resultBitmap` were all mutable statics there).
 */
class HtmlConverterActivity : AppCompatActivity() {

    private lateinit var webviewLoaderHtml: WebView
    private lateinit var webScrollView: ScrollView
    private val starPrinterGateway = StarPrinterGateway()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.ds_print_html_converter)

        webviewLoaderHtml = findViewById(R.id.webviewLoaderHtml)
        webScrollView = findViewById(R.id.webScrollView)

        val htmlString = intent.getStringExtra(HtmlPrintStrategy.EXTRA_HTML)
        val printerId = intent.getStringExtra(HtmlPrintStrategy.EXTRA_PRINTER_ID)
        val printerType = intent.getStringExtra(HtmlPrintStrategy.EXTRA_PRINTER_TYPE) ?: "Usb"
        val widthDotsPaper = intent.getIntExtra(HtmlPrintStrategy.EXTRA_WIDTH_DOTS, 500)

        if (htmlString == null || printerId == null) {
            Log.d(TAG, "onCreate() - missing html/printerId extras")
            DsPrintEventSink.success("failed")
            finish()
            return
        }

        setupWebviewWithLoadingHtml(htmlString)
        setupWebviewThenConvertBitmapToBePrinted(printerId, printerType, widthDotsPaper)
    }

    //---------------------------------------------------------------------- webview

    private fun setupWebviewWithLoadingHtml(htmlString: String) {
        webviewLoaderHtml.settings.javaScriptEnabled = true
        webviewLoaderHtml.setBackgroundColor(Color.TRANSPARENT)
        webviewLoaderHtml.loadDataWithBaseURL(null, htmlString, "text/html", "utf-8", null)
    }

    private fun setupWebviewThenConvertBitmapToBePrinted(
        printerId: String,
        printerType: String,
        widthDotsPaper: Int,
    ) {
        webviewLoaderHtml.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                waitBeforeTakingBitmap(printerId, printerType, widthDotsPaper)
            }
        }
    }

    //---------------------------------------------------------------------- convert bitmap

    private fun waitBeforeTakingBitmap(
        printerId: String,
        printerType: String,
        widthDotsPaper: Int,
    ) {
        Handler(Looper.getMainLooper()).postDelayed({
            convertHtmlAfterLoadedToBitmap(printerId, printerType, widthDotsPaper)
        }, CAPTURE_DELAY_MS)
    }

    private fun convertHtmlAfterLoadedToBitmap(
        printerId: String,
        printerType: String,
        widthDotsPaper: Int,
    ) {
        webScrollView.post {
            val width = webScrollView.getChildAt(0).width
            val height = webScrollView.getChildAt(0).height

            if (width > 0 && height > 0) {
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                webScrollView.draw(canvas)

                printStarX(printerId, printerType, widthDotsPaper, bitmap)
            } else {
                Log.d(TAG, "convertHtmlAfterLoadedToBitmap() - width/height is 0")
                DsPrintEventSink.success("failed")
                finish()
            }
        }
    }

    //---------------------------------------------------------------------- print star x

    private fun printStarX(
        printerId: String,
        printerType: String,
        widthDotsPaper: Int,
        bitmap: Bitmap,
    ) {
        starPrinterGateway.printBitmap(
            printerId = printerId,
            context = applicationContext,
            bitmap = bitmap,
            widthDotsPaper = widthDotsPaper,
            printerType = printerType,
        ) { success ->
            dismissAfterWaitSuccess(success)
        }
    }

    private fun dismissAfterWaitSuccess(success: Boolean) {
        Handler(Looper.getMainLooper()).postDelayed({
            finish()
            DsPrintEventSink.success(if (success) "success" else "failed")
        }, DISMISS_DELAY_MS)
    }
}
