package com.dsprint.ds_print.star

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import com.starmicronics.stario10.InterfaceType
import com.starmicronics.stario10.StarConnectionSettings
import com.starmicronics.stario10.StarDeviceDiscoveryManager
import com.starmicronics.stario10.StarDeviceDiscoveryManagerFactory
import com.starmicronics.stario10.StarPrinter
import com.starmicronics.stario10.starxpandcommand.DocumentBuilder
import com.starmicronics.stario10.starxpandcommand.PrinterBuilder
import com.starmicronics.stario10.starxpandcommand.StarXpandCommandBuilder
import com.starmicronics.stario10.starxpandcommand.printer.Alignment
import com.starmicronics.stario10.starxpandcommand.printer.CutType
import com.starmicronics.stario10.starxpandcommand.printer.ImageParameter
import com.starmicronics.stario10.starxpandcommand.printer.InternationalCharacterType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

private const val TAG = "StarPrinterGateway"

/** A discovered Star printer, translated out of the SDK's own type. */
data class DiscoveredPrinter(
    val name: String?,
    val id: String,
    val interfaceType: String,
)

/**
 * The only file in ds_print that imports `com.starmicronics.*`.
 *
 * Every print entry point reports its result only after the underlying
 * `printer.printAsync(...).await()` call actually returns — success is
 * never reported "fire and forget" the way the legacy
 * `MainActivity.loadBase64ToPrinter` used to (it reported "success"
 * synchronously right after launching the print coroutine, before the
 * printer had done anything). `closeAsync()` always still runs in a
 * `finally`, exactly as before.
 */
class StarPrinterGateway {

    private var discoveryManager: StarDeviceDiscoveryManager? = null

    fun discover(
        context: Context,
        onPrinterFound: (DiscoveredPrinter) -> Unit,
        onDiscoveryFinished: () -> Unit,
    ) {
        try {
            discoveryManager?.stopDiscovery()
            discoveryManager = StarDeviceDiscoveryManagerFactory.create(
                listOf(InterfaceType.Usb, InterfaceType.Lan),
                // Bluetooth intentionally left out: it needs a manifest
                // permission the app doesn't request.
                // listOf(InterfaceType.Usb, InterfaceType.Lan, InterfaceType.Bluetooth),
                context,
            )
            discoveryManager?.discoveryTime = 1000
            discoveryManager?.callback = object : StarDeviceDiscoveryManager.Callback {
                override fun onPrinterFound(printer: StarPrinter) {
                    Log.d(TAG, "onPrinterFound id: ${printer.connectionSettings.identifier}")
                    onPrinterFound(
                        DiscoveredPrinter(
                            name = printer.information?.model?.name,
                            id = printer.connectionSettings.identifier,
                            interfaceType = printer.connectionSettings.interfaceType.toString(),
                        )
                    )
                }

                override fun onDiscoveryFinished() {
                    Log.d(TAG, "onDiscoveryFinished()")
                    onDiscoveryFinished()
                }
            }
            discoveryManager?.startDiscovery()
        } catch (e: Exception) {
            Log.d(TAG, "discover() - Error: $e")
        }
    }

    /**
     * Decodes each of [base64Slices] to a bitmap and prints them as one
     * document, in order.
     *
     * Slices are vertical bands of a single invoice, not separate receipts:
     * `actionPrintImage` adds no feed of its own and thermal paper is
     * continuous, so consecutive bands rejoin into one unbroken page with a
     * single cut at the end.
     *
     * A decode failure on any slice aborts the whole job. Printing the
     * survivors would emit a silently incomplete invoice, which is worse than
     * printing nothing and reporting the failure.
     */
    fun printBase64(
        printerId: String,
        context: Context,
        base64Slices: List<String>,
        widthDotsPaper: Int,
        printerType: String = "Usb",
        onResult: (success: Boolean) -> Unit,
    ) {
        val bitmaps = base64Slices.map { base64ToBitmap(it) }
        if (bitmaps.isEmpty() || bitmaps.any { it == null }) {
            Log.d(TAG, "printBase64() - ${bitmaps.count { it == null }} of ${bitmaps.size} slice(s) failed to decode")
            bitmaps.forEach { it?.recycle() }
            onResult(false)
            return
        }
        val pages = bitmaps.filterNotNull()

        val settings = StarConnectionSettings(toInterfaceType(printerType), printerId)
        val printer = StarPrinter(settings, context)

        CoroutineScope(Dispatchers.Default + SupervisorJob()).launch {
            try {
                // Reassigned rather than chained-and-discarded so this is
                // correct whether the SDK's builder mutates in place or returns
                // a new instance.
                var printerBuilder = PrinterBuilder()
                pages.forEach {
                    printerBuilder =
                        printerBuilder.actionPrintImage(ImageParameter(it, widthDotsPaper))
                }
                // These styles follow the images rather than preceding them,
                // which is where they have always sat on this path. They are
                // therefore no-ops for the images just emitted — moving them
                // above would start centring output that prints left-aligned
                // today, so the order is preserved deliberately.
                printerBuilder = printerBuilder
                    .styleInternationalCharacter(InternationalCharacterType.Usa)
                    .styleCharacterSpace(0.0)
                    .styleAlignment(Alignment.Center)
                    .actionCut(CutType.Partial)

                val builder = StarXpandCommandBuilder()
                builder.addDocument(DocumentBuilder().addPrinter(printerBuilder))
                val commands = builder.getCommands()

                printer.openAsync().await()
                printer.printAsync(commands).await()

                Log.d(TAG, "Success (${pages.size} slice(s))")
                onResult(true)
            } catch (e: Exception) {
                Log.d(TAG, "Error: $e")
                onResult(false)
            } finally {
                printer.closeAsync().await()
                // Safe here and not before: both awaits have returned, so the
                // SDK is done reading these. A long invoice can be a dozen
                // slices, so this is worth doing rather than waiting for GC.
                pages.forEach { it.recycle() }
            }
        }
    }

    /** Prints an already-rendered [bitmap] (used by the HTML capture path). */
    fun printBitmap(
        printerId: String,
        context: Context,
        bitmap: Bitmap,
        widthDotsPaper: Int,
        printerType: String = "Usb",
        onResult: (success: Boolean) -> Unit,
    ) {
        val settings = StarConnectionSettings(toInterfaceType(printerType), printerId)
        val printer = StarPrinter(settings, context)

        CoroutineScope(Dispatchers.Default + SupervisorJob()).launch {
            try {
                val builder = StarXpandCommandBuilder()
                builder.addDocument(
                    DocumentBuilder()
                        .addPrinter(
                            PrinterBuilder()
                                // image center
                                .styleAlignment(Alignment.Center)
                                .actionPrintImage(ImageParameter(bitmap, widthDotsPaper))
                                .styleInternationalCharacter(InternationalCharacterType.Usa)
                                .styleCharacterSpace(0.0)
                                .styleAlignment(Alignment.Center)
                                .actionCut(CutType.Partial)
                        )
                )
                val commands = builder.getCommands()

                printer.openAsync().await()
                printer.printAsync(commands).await()

                Log.d(TAG, "Success")
                onResult(true)
            } catch (e: Exception) {
                Log.d(TAG, "Error: $e")
                onResult(false)
            } finally {
                printer.closeAsync().await()
            }
        }
    }

    private fun base64ToBitmap(base64Str: String): Bitmap? {
        return try {
            val cleanedBase64 = base64Str.substringAfter(",")
            val decodedBytes = Base64.decode(cleanedBase64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)
        } catch (e: IllegalArgumentException) {
            Log.d(TAG, "base64ToBitmap() - exception: $e")
            null
        }
    }

    private fun toInterfaceType(printerType: String): InterfaceType = when (printerType) {
        "Usb" -> InterfaceType.Usb
        "Lan" -> InterfaceType.Lan
        "Bluetooth" -> InterfaceType.Bluetooth
        else -> InterfaceType.Usb
    }
}
