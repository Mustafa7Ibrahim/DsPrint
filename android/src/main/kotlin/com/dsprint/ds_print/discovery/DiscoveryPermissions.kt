package com.dsprint.ds_print.discovery

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.starmicronics.stario10.InterfaceType

/**
 * Maps the discovery channel's argument — `PrinterInterfaceType.nativeName`
 * on the Dart side — to the Star SDK interfaces to scan. `null` (or anything
 * unrecognised) keeps the legacy USB + LAN scan.
 */
internal fun discoveryInterfacesFor(argument: String?): List<InterfaceType> = when (argument) {
    "Usb" -> listOf(InterfaceType.Usb)
    "Lan" -> listOf(InterfaceType.Lan)
    "Bluetooth" -> listOf(InterfaceType.Bluetooth)
    else -> listOf(InterfaceType.Usb, InterfaceType.Lan)
}

/**
 * Runtime permissions the Star SDK needs before it can scan, per the official
 * StarXpand sample (`ContentView.kt`).
 *
 * The SDK's own manifest already declares `BLUETOOTH`, `BLUETOOTH_CONNECT`
 * and `INTERNET`, and they merge into the host app — but on Android 12+
 * `BLUETOOTH_CONNECT` must also be granted at runtime. `BLUETOOTH_SCAN` is
 * only for Bluetooth LE, which ds_print doesn't scan.
 */
internal object DiscoveryPermissions {

    private const val ACCESS_LOCAL_NETWORK = "android.permission.ACCESS_LOCAL_NETWORK"
    private const val ANDROID_17 = 37

    fun missing(context: Context, interfaces: List<InterfaceType>): List<String> =
        required(context, interfaces).filter {
            ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
        }

    private fun required(context: Context, interfaces: List<InterfaceType>): List<String> {
        val permissions = mutableListOf<String>()
        if (InterfaceType.Bluetooth in interfaces && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions += Manifest.permission.BLUETOOTH_CONNECT
        }
        // Android 17 blocks local-network traffic for apps *targeting* 37+
        // unless ACCESS_LOCAL_NETWORK is granted. Google's guidance is to
        // neither declare nor request it below that target (INTERNET still
        // covers the LAN there), so this library never declares it: a host
        // that targets 37 declares it itself, and only then is it requested.
        if (InterfaceType.Lan in interfaces &&
            Build.VERSION.SDK_INT >= ANDROID_17 &&
            context.applicationInfo.targetSdkVersion >= ANDROID_17 &&
            declaresPermission(context, ACCESS_LOCAL_NETWORK)
        ) {
            permissions += ACCESS_LOCAL_NETWORK
        }
        return permissions
    }

    private fun declaresPermission(context: Context, permission: String): Boolean = try {
        val packageManager = context.packageManager
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
        }
        info.requestedPermissions?.contains(permission) == true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
