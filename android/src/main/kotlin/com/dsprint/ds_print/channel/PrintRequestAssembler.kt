package com.dsprint.ds_print.channel

/**
 * Accumulates the base64/HTML chunks sent across multiple `fromFlutter`
 * calls and reassembles them into a single string once a transfer
 * completes. Replaces the old `BigDataNativeChannel` singleton, which mixed
 * this bookkeeping with progress-event emission and printer dispatch.
 *
 * Chunks are stored keyed by their `index` (rather than blindly appended in
 * call order) so the payload is reassembled correctly even if calls from
 * the platform channel ever arrive out of order.
 */
class PrintRequestAssembler {

    private val chunks = sortedMapOf<Int, String>()

    fun reset() {
        chunks.clear()
    }

    fun add(index: Int, data: String) {
        chunks[index] = data
    }

    fun assemble(): String = chunks.values.joinToString("")
}
