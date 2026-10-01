package es.ecotrap.ecotrap

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "es.ecotrap.ecotrap/wifi_network"
    private var boundNetwork: Network? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFolder" -> {
                    try {
                        val uri = android.net.Uri.parse(
                            "content://com.android.externalstorage.documents/document/primary%3ADownload%2FEntomoLab-EcoTrap"
                        )
                        val intent = android.content.Intent(
                            android.content.Intent.ACTION_VIEW
                        ).apply {
                            data = uri
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            val fallback = android.content.Intent(
                                android.content.Intent.ACTION_OPEN_DOCUMENT_TREE
                            ).apply {
                                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getWifiIpAddress" -> {
                    val ip = getWifiIpAddress()
                    if (ip != null) result.success(ip)
                    else result.error("WIFI_ERROR", "No se pudo obtener IP WiFi", null)
                }
                "bindToWifi" -> {
                    val success = bindProcessToWifi()
                    result.success(success)
                }
                "unbindNetwork" -> {
                    unbindNetwork()
                    result.success(true)
                }
                "connectToWifi" -> {
                    val ssid = call.argument<String>("ssid")
                    val bssid = call.argument<String>("bssid")
                    val password = call.argument<String>("password")

                    if (ssid == null || password == null) {
                        result.error("INVALID_ARGS", "ssid y password son requeridos", null)
                        return@setMethodCallHandler
                    }

                    connectToWifi(ssid, bssid, password, result)
                }
                "getConnectedSsid" -> {
                    val ssid = getConnectedSsid()
                    result.success(ssid)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // WIFI NETWORK — búsqueda mejorada
    // ─────────────────────────────────────────────────────────────

    private fun getWifiNetwork(): Network? {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        // ✅ Buscar en TODAS las redes disponibles
        val allNetworks = cm.allNetworks

        println("🔍 Buscando WiFi en ${allNetworks.size} redes disponibles")

        // ✅ Primero buscar red WiFi SIN internet (trampa IoT)
        // La trampa no tiene internet, así que tiene prioridad sobre el WiFi doméstico
        for (network in allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                println("✅ Red WiFi IoT encontrada (sin internet)")
                return network
            }
        }

        // ✅ Si no hay IoT WiFi, usar cualquier WiFi disponible (con internet)
        for (network in allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                println("✅ Red WiFi encontrada")
                return network
            }
        }

        // ✅ Último recurso: intentar por WifiManager
        return getWifiNetworkFromWifiManager()
    }

    private fun getWifiNetworkFromWifiManager(): Network? {
        return try {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

            @Suppress("DEPRECATION")
            if (!wifiManager.isWifiEnabled) {
                println("❌ WiFi desactivado según WifiManager")
                return null
            }

            @Suppress("DEPRECATION")
            val connectionInfo = wifiManager.connectionInfo
            if (connectionInfo != null && connectionInfo.networkId != -1) {
                println("✅ WiFi conectado según WifiManager: ${connectionInfo.ssid}")
                // Intentar encontrar la red correspondiente en ConnectivityManager
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                // Buscar entre todas las redes sin filtro de capabilities
                for (network in cm.allNetworks) {
                    val caps = cm.getNetworkCapabilities(network) ?: continue
                    if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                        return network
                    }
                }
            }
            null
        } catch (e: Exception) {
            println("❌ Error en WifiManager fallback: ${e.message}")
            null
        }
    }

    private fun getWifiIpAddress(): String? {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            // ✅ Buscar IP en cualquier red WiFi
            val wifiNetwork = getWifiNetwork() ?: run {
                println("❌ No se encontró red WiFi para IP")
                return null
            }

            val linkProperties = cm.getLinkProperties(wifiNetwork)
            val ip = linkProperties?.linkAddresses
                ?.firstOrNull { it.address.hostAddress?.contains('.') == true }
                ?.address?.hostAddress

            println("📶 IP WiFi: $ip")
            ip
        } catch (e: Exception) {
            println("❌ Error obteniendo IP WiFi: ${e.message}")
            null
        }
    }

    private fun bindProcessToWifi(): Boolean {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            // Reusar red ya vinculada (p.ej. la trampa conectada via connectAndroid10Plus)
            boundNetwork?.let { existing ->
                val caps = cm.getNetworkCapabilities(existing)
                if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                    cm.bindProcessToNetwork(existing)
                    println("✅ Proceso vinculado a red WiFi (reutilizada)")
                    return true
                }
                // La red ya no es válida, limpiar
                boundNetwork = null
            }

            val wifiNetwork = getWifiNetwork()

            if (wifiNetwork != null) {
                cm.bindProcessToNetwork(wifiNetwork)
                boundNetwork = wifiNetwork
                println("✅ Proceso vinculado a red WiFi")
                true
            } else {
                println("❌ No se encontró red WiFi")
                false
            }
        } catch (e: Exception) {
            println("❌ Error vinculando a WiFi: ${e.message}")
            false
        }
    }

    private fun unbindNetwork() {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        networkCallback?.let {
            try { cm.unregisterNetworkCallback(it) } catch (_: Exception) {}
        }
        cm.bindProcessToNetwork(null)
        boundNetwork = null
        networkCallback = null
        println("🔓 Proceso desvinculado de red específica")
    }

    // ─────────────────────────────────────────────────────────────
    // CONEXIÓN WIFI NATIVA
    // ─────────────────────────────────────────────────────────────

    private fun connectToWifi(
        ssid: String,
        bssid: String?,
        password: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectAndroid10Plus(ssid, bssid, password, result)
        } else {
            connectLegacy(ssid, password, result)
        }
    }

    @Suppress("DEPRECATION")
    private fun connectLegacy(
        ssid: String,
        password: String,
        result: MethodChannel.Result
    ) {
        try {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

            if (!wifiManager.isWifiEnabled) {
                wifiManager.isWifiEnabled = true
                Thread.sleep(1000)
            }

            val wifiConfig = WifiConfiguration().apply {
                SSID = "\"$ssid\""
                preSharedKey = "\"$password\""
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
            }

            val existingNetworks = wifiManager.configuredNetworks
            existingNetworks?.forEach { config ->
                if (config.SSID == "\"$ssid\"") {
                    wifiManager.removeNetwork(config.networkId)
                }
            }

            val networkId = wifiManager.addNetwork(wifiConfig)
            if (networkId == -1) {
                result.success(mapOf("success" to false, "message" to "No se pudo agregar la red"))
                return
            }

            wifiManager.disconnect()
            wifiManager.enableNetwork(networkId, true)
            wifiManager.reconnect()

            var connected = false
            for (i in 0..15) {
                Thread.sleep(1000)
                val info = wifiManager.connectionInfo
                val connectedSsid = info?.ssid?.replace("\"", "") ?: ""
                if (connectedSsid.equals(ssid, ignoreCase = true)) {
                    connected = true
                    break
                }
            }

            result.success(mapOf(
                "success" to connected,
                "message" to if (connected) "Conectado a $ssid" else "No se pudo conectar. Verifica la contraseña."
            ))
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "message" to "Error: ${e.message}"))
        }
    }

    private fun connectAndroid10Plus(
        ssid: String,
        bssid: String?,
        password: String,
        result: MethodChannel.Result
    ) {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            // Liberar red anterior antes de solicitar una nueva
            networkCallback?.let {
                try { cm.unregisterNetworkCallback(it) } catch (_: Exception) {}
                networkCallback = null
            }
            cm.bindProcessToNetwork(null)
            boundNetwork = null

            val specifierBuilder = WifiNetworkSpecifier.Builder()
                .setSsid(ssid)
                .setWpa2Passphrase(password)

            if (!bssid.isNullOrEmpty()) {
                try {
                    val mac = android.net.MacAddress.fromString(bssid)
                    specifierBuilder.setBssid(mac)
                } catch (_: Exception) {
                    println("⚠️ BSSID inválido, conectando solo por SSID")
                }
            }

            val networkRequest = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
                .setNetworkSpecifier(specifierBuilder.build())
                .build()

            var responded = false

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    if (responded) return
                    responded = true
                    println("✅ Red disponible: $ssid")
                    boundNetwork = network
                    cm.bindProcessToNetwork(network)
                    networkCallback = this
                    runOnUiThread {
                        result.success(mapOf(
                            "success" to true,
                            "message" to "Conectado a $ssid"
                        ))
                    }
                }

                override fun onUnavailable() {
                    if (responded) return
                    responded = true
                    println("❌ Red no disponible: $ssid")
                    runOnUiThread {
                        result.success(mapOf(
                            "success" to false,
                            "message" to "No se pudo conectar. Verifica la contraseña."
                        ))
                    }
                }

                override fun onLost(network: Network) {
                    println("📶 Red perdida: $ssid")
                    if (boundNetwork == network) {
                        boundNetwork = null
                        cm.bindProcessToNetwork(null)
                    }
                }
            }

            cm.requestNetwork(networkRequest, callback, 30000)
            networkCallback = callback

        } catch (e: Exception) {
            result.success(mapOf("success" to false, "message" to "Error: ${e.message}"))
        }
    }

    private fun getConnectedSsid(): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val network = cm.activeNetwork ?: return null
                val caps = cm.getNetworkCapabilities(network) ?: return null
                if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return null
                val wifiInfo = caps.transportInfo as? android.net.wifi.WifiInfo
                wifiInfo?.ssid?.replace("\"", "")?.trim()
            } else {
                @Suppress("DEPRECATION")
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                wm.connectionInfo?.ssid?.replace("\"", "")?.trim()
            }
        } catch (e: Exception) {
            null
        }
    }
}