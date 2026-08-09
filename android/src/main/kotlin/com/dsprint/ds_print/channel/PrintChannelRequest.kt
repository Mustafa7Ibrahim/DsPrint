package com.dsprint.ds_print.channel

/**
 * Type-safe view over the raw argument map the Dart side sends on every
 * `fromFlutter` call. All argument parsing/casting lives here, in one
 * place, instead of being inlined into the channel handler.
 *
 * Keys are fixed by the platform-channel contract and must not change:
 * `key`, `index` (Int), `data` (String), `status` (String, one of
 * `start`/`progress`/`completed`/`one-index`), `printer_id` (String),
 * `printerType` (String), `width_dots` (Int), `type_data` (String).
 */
data class PrintChannelRequest(
    val key: String,
    val index: Int,
    val data: String,
    val status: String,
    val printerId: String,
    val printerType: String,
    val widthDots: Int,
    val typeData: String,
) {
    companion object {
        fun fromMap(arguments: Map<*, *>): PrintChannelRequest {
            val stringKeyed = arguments.mapKeys { it.key.toString() }
            return PrintChannelRequest(
                key = stringKeyed["key"] as? String ?: "",
                index = stringKeyed["index"] as Int,
                data = stringKeyed["data"] as String,
                status = stringKeyed["status"] as String,
                printerId = stringKeyed["printer_id"].toString(),
                printerType = stringKeyed["printerType"].toString(),
                widthDots = stringKeyed["width_dots"] as Int,
                typeData = stringKeyed["type_data"] as String,
            )
        }
    }
}
