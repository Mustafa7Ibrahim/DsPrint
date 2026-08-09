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

    /** Decodes [base64Image] straight to a bitmap and prints it. */
    fun printBase64(
        printerId: String,
        context: Context,
        base64Image: String,
        widthDotsPaper: Int,
        printerType: String = "Usb",
        onResult: (success: Boolean) -> Unit,
    ) {
        val bitmap = base64ToBitmap(base64Image)
        if (bitmap == null) {
            onResult(false)
            return
        }

        val settings = StarConnectionSettings(toInterfaceType(printerType), printerId)
        val printer = StarPrinter(settings, context)

        CoroutineScope(Dispatchers.Default + SupervisorJob()).launch {
            try {
                val builder = StarXpandCommandBuilder()
                builder.addDocument(
                    DocumentBuilder()
                        .addPrinter(
                            PrinterBuilder()
                                .actionPrintImage(
                                    ImageParameter(bitmap, widthDotsPaper)
                                )
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
