package com.dsprint.ds_print

import android.content.Context
import com.dsprint.ds_print.channel.DsPrintEventSink
import com.dsprint.ds_print.channel.PrintChannelRequest
import com.dsprint.ds_print.channel.PrintRequestAssembler
import com.dsprint.ds_print.dispatch.PrintDispatcher
import com.dsprint.ds_print.star.StarPrinterGateway
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

private const val DISCOVERY_EVENT_CHANNEL = "com.printer.discover/event"
private const val PRINT_METHOD_CHANNEL = "com.printer.html/sendToNative"
private const val PRINT_RESULT_EVENT_CHANNEL = "com.printer.html/listenFromNative"
private const val METHOD_FROM_FLUTTER = "fromFlutter"

/**
 * Registers the three ds_print platform channels and wires them to the
 * chunk assembler / dispatcher / Star SDK gateway.
 *
 * This class ONLY does channel registration and delegation — no argument
 * parsing, no chunk accumulation, no dispatch-by-type logic, no Star SDK
 * calls. Compare to the legacy `MainActivity`, which did all of the above
 * plus discovery wiring in one 335-line Activity.
 */
class DsPrintPlugin : FlutterPlugin {

    private lateinit var applicationContext: Context
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

    //---------------------------------------------------------------------- print channel

    private val printMethodCallHandler = MethodChannel.MethodCallHandler { call, result ->
        if (call.method != METHOD_FROM_FLUTTER) {
            result.notImplemented()
            return@MethodCallHandler
        }
        val arguments = call.arguments as? Map<*, *>
        if (arguments == null) {
            result.success("no arguments")
            return@MethodCallHandler
        }
        handle(PrintChannelRequest.fromMap(arguments))
        result.success("Big Data Working")
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
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            starPrinterGateway.discover(
                context = applicationContext,
                onPrinterFound = { printer ->
                    events?.success(
                        mapOf(
                            "name" to printer.name,
                            "id" to printer.id,
                            "interfaceType" to printer.interfaceType,
                        )
                    )
                },
                onDiscoveryFinished = {
                    events?.success("finished")
                },
            )
        }

        override fun onCancel(arguments: Any?) {
            // Matches legacy behaviour: no explicit stopDiscovery() here.
        }
    }
}
