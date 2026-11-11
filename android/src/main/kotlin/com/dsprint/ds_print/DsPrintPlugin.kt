package com.dsprint.ds_print

import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import com.dsprint.ds_print.channel.DsPrintEventSink
import com.dsprint.ds_print.channel.PrintChannelRequest
import com.dsprint.ds_print.channel.PrintRequestAssembler
import com.dsprint.ds_print.discovery.DiscoveryPermissions
import com.dsprint.ds_print.discovery.discoveryInterfacesFor
import com.dsprint.ds_print.dispatch.PrintDispatcher
import com.dsprint.ds_print.star.StarPrinterGateway
import com.starmicronics.stario10.InterfaceType
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

private const val DISCOVERY_EVENT_CHANNEL = "com.printer.discover/event"
private const val PRINT_METHOD_CHANNEL = "com.printer.html/sendToNative"
private const val PRINT_RESULT_EVENT_CHANNEL = "com.printer.html/listenFromNative"
private const val METHOD_FROM_FLUTTER = "fromFlutter"
private const val METHOD_CHECK_CONNECTION = "checkConnection"
private const val TAG = "DsPrintPlugin"

// Discovery channel events beyond device maps. Must match the constants in
// `printer_discovery_datasource.dart`.
private const val EVENT_FINISHED = "finished"
private const val EVENT_PERMISSION_REQUESTED = "permission-requested"
private const val EVENT_PERMISSION_GRANTED = "permission-granted"
private const val EVENT_PERMISSION_DENIED = "failed-permission-denied"

// Arbitrary, but unique within this plugin: the host app's own permission
// requests arrive at the same listener chain and must be left alone.
private const val DISCOVERY_PERMISSION_REQUEST_CODE = 0x4453

/**
 * Registers the three ds_print platform channels and wires them to the
 * chunk assembler / dispatcher / Star SDK gateway.
 *
 * This class ONLY does channel registration and delegation — no argument
 * parsing, no chunk accumulation, no dispatch-by-type logic, no Star SDK
 * calls. Compare to the legacy `MainActivity`, which did all of the above
 * plus discovery wiring in one 335-line Activity.
 */
class DsPrintPlugin : FlutterPlugin, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var applicationContext: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Needed only to show Android's runtime-permission dialog. */
    private var activityBinding: ActivityPluginBinding? = null

    /** A scan waiting on the user's answer to the permission dialog. */
    private var pendingDiscovery: PendingDiscovery? = null

    private class PendingDiscovery(
        val events: EventChannel.EventSink,
        val interfaces: List<InterfaceType>,
    )
    private val requestAssembler = PrintRequestAssembler()
    private val starPrinterGateway = StarPrinterGateway()
    private var printDispatcher: PrintDispatcher? = null

    private var discoveryEventChannel: EventChannel? = null
    private var printMethodChannel: MethodChannel? = null
    private var printResultEventChannel: EventChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        printDispatcher = PrintDispatcher(applicationContext)

        discoveryEventChannel = EventChannel(binding.binaryMessenger, DISCOVERY_EVENT_CHANNEL).apply {
            setStreamHandler(discoveryStreamHandler)
        }
        printMethodChannel = MethodChannel(binding.binaryMessenger, PRINT_METHOD_CHANNEL).apply {
            setMethodCallHandler(printMethodCallHandler)
        }
        printResultEventChannel = EventChannel(binding.binaryMessenger, PRINT_RESULT_EVENT_CHANNEL).apply {
            setStreamHandler(printResultStreamHandler)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        discoveryEventChannel?.setStreamHandler(null)
        printMethodChannel?.setMethodCallHandler(null)
        printResultEventChannel?.setStreamHandler(null)
        discoveryEventChannel = null
        printMethodChannel = null
        printResultEventChannel = null
        printDispatcher = null
        DsPrintEventSink.clear()
    }

    //---------------------------------------------------------------------- activity

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != DISCOVERY_PERMISSION_REQUEST_CODE) return false
        val pending = pendingDiscovery ?: return true
        pendingDiscovery = null
        // An empty result means the request was interrupted — treat it as a
        // denial rather than scanning without the permission.
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (granted) {
            emit(pending.events, EVENT_PERMISSION_GRANTED)
            startDiscovery(pending.events, pending.interfaces)
        } else {
            emit(pending.events, EVENT_PERMISSION_DENIED)
            emit(pending.events, EVENT_FINISHED)
        }
        return true
    }

    //---------------------------------------------------------------------- print channel

    private val printMethodCallHandler = MethodChannel.MethodCallHandler { call, result ->
        when (call.method) {
            METHOD_FROM_FLUTTER -> {
                val arguments = call.arguments as? Map<*, *>
                if (arguments == null) {
                    result.success("no arguments")
                    return@MethodCallHandler
                }
                handle(PrintChannelRequest.fromMap(arguments))
                result.success("Big Data Working")
            }
            METHOD_CHECK_CONNECTION -> checkConnection(call.arguments as? Map<*, *>, result)
            else -> result.notImplemented()
        }
    }

    private fun checkConnection(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val printerId = arguments?.get("printerId") as? String
        val printerType = arguments?.get("printerType") as? String
        val timeoutMs = (arguments?.get("timeoutMs") as? Number)?.toInt()
        if (printerId.isNullOrBlank() || printerType == null || timeoutMs == null || timeoutMs <= 0) {
            result.error("bad-args", "checkConnection needs printerId, printerType and timeoutMs", null)
            return
        }
        CoroutineScope(Dispatchers.Default + SupervisorJob()).launch {
            val reachable = try {
                starPrinterGateway.isReachable(
                    context = applicationContext,
                    printerId = printerId,
                    printerType = printerType,
                    timeoutMs = timeoutMs,
                )
            } catch (e: Throwable) {
                Log.d(TAG, "checkConnection() - Error: $e")
                false
            }
            mainHandler.post { result.success(reachable) }
        }
    }

    private fun handle(request: PrintChannelRequest) {
        if (request.status == "start" || request.status == "one-index") {
            requestAssembler.reset()
        }
        requestAssembler.add(request.index, request.data)
        if (request.status == "completed" || request.status == "one-index") {
            val payload = requestAssembler.assemble()
            printDispatcher?.dispatch(request, payload)
        }
    }

    private val printResultStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            DsPrintEventSink.setSink(events)
        }

        override fun onCancel(arguments: Any?) {
            DsPrintEventSink.clear()
        }
    }

    //---------------------------------------------------------------------- discovery channel

    private val discoveryStreamHandler = object : EventChannel.StreamHandler {
        /**
         * [arguments] is the Dart side's `PrinterInterfaceType.nativeName`
         * (`"Usb"` / `"Lan"` / `"Bluetooth"`), or null for the legacy
         * USB + LAN scan.
         */
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            if (events == null) return
            val interfaces = discoveryInterfacesFor(arguments as? String)
            val missing = DiscoveryPermissions.missing(applicationContext, interfaces)
            if (missing.isEmpty()) {
                startDiscovery(events, interfaces)
                return
            }
            val activity = activityBinding?.activity
            if (activity == null) {
                emit(events, EVENT_PERMISSION_DENIED)
                emit(events, EVENT_FINISHED)
                return
            }
            pendingDiscovery = PendingDiscovery(events, interfaces)
            // Lets Dart suspend its scan timeout while the dialog is up.
            emit(events, EVENT_PERMISSION_REQUESTED)
            ActivityCompat.requestPermissions(
                activity,
                missing.toTypedArray(),
                DISCOVERY_PERMISSION_REQUEST_CODE,
            )
        }

        override fun onCancel(arguments: Any?) {
            pendingDiscovery = null
            starPrinterGateway.stopDiscovery()
        }
    }

    private fun startDiscovery(events: EventChannel.EventSink, interfaces: List<InterfaceType>) {
        starPrinterGateway.discover(
            context = applicationContext,
            interfaces = interfaces,
            onPrinterFound = { printer ->
                emit(
                    events,
                    mapOf(
                        "name" to printer.name,
                        "id" to printer.id,
                        "interfaceType" to printer.interfaceType,
                    )
                )
            },
            onDiscoveryFinished = { emit(events, EVENT_FINISHED) },
            onError = { code, message ->
                mainHandler.post { events.error(code, message, null) }
                emit(events, EVENT_FINISHED)
            },
        )
    }

    /**
     * EventSink calls are `@UiThread`-only and the Star SDK doesn't document
     * which thread its callbacks run on, so every discovery event is posted
     * to the main looper — same as [DsPrintEventSink] does for print results.
     * A sink whose stream Dart already cancelled ignores the call.
     */
    private fun emit(events: EventChannel.EventSink, event: Any?) {
        mainHandler.post { events.success(event) }
    }
}
