package io.github.mariokovacevic.baresipkit

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * A summary of one network update, for logging or display.
 *
 * Constructors, `copy` and component functions of this type are not covered by Semantic Versioning; read its properties.
 */
data class BaresipNetworkPath(
    /** The transports and addresses of the default network, for example `"wifi 192.0.2.7"`. */
    val interfaceSummary: String,
    /** Whether the network is usable. */
    val isSatisfied: Boolean,
)

/**
 * Watches the default network and tells a [BaresipEngine] when it is worth reacting to.
 *
 * Wraps `ConnectivityManager.registerDefaultNetworkCallback`: it ignores the first network (the
 * one in effect when watching started), lost networks and repeats of the same summary, then calls
 * [BaresipEngine.networkDidChange] for the rest. Needs the `ACCESS_NETWORK_STATE` permission.
 *
 * ```kotlin
 * val monitor = BaresipNetworkMonitor(context, engine)
 * monitor.setChangeHandler { path -> Log.i("app", "network: ${path.interfaceSummary}") }
 * monitor.start()
 * ```
 */
class BaresipNetworkMonitor(
    context: Context,
    private val engine: BaresipEngine,
    private val reregister: Boolean = true,
    private val updateCalls: Boolean = true,
) {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private val lock = Any()
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var lastPath: BaresipNetworkPath? = null
    private var changeHandler: ((BaresipNetworkPath) -> Unit)? = null
    private var scope: CoroutineScope? = null

    /** Sets a handler called with every network update, usable or not, for logging. */
    fun setChangeHandler(handler: ((BaresipNetworkPath) -> Unit)?) {
        synchronized(lock) { changeHandler = handler }
    }

    /** Starts watching the default network. Does nothing if already started. */
    fun start() {
        synchronized(lock) {
            if (callback != null) return
            scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
            val watcher =
                object : ConnectivityManager.NetworkCallback() {
                    override fun onLinkPropertiesChanged(
                        network: Network,
                        linkProperties: LinkProperties,
                    ) {
                        val capabilities = connectivity.getNetworkCapabilities(network)
                        pathUpdated(BaresipNetworkPath(summary(capabilities, linkProperties), true))
                    }

                    override fun onLost(network: Network) {
                        pathUpdated(BaresipNetworkPath("", false))
                    }
                }
            connectivity.registerDefaultNetworkCallback(watcher)
            callback = watcher
        }
    }

    /** Stops watching the network. */
    fun stop() {
        synchronized(lock) {
            callback?.let { runCatching { connectivity.unregisterNetworkCallback(it) } }
            callback = null
            lastPath = null
            scope?.cancel()
            scope = null
        }
    }

    private fun pathUpdated(current: BaresipNetworkPath) {
        val (handler, notify, launcher) =
            synchronized(lock) {
                val previous = lastPath
                lastPath = current
                Triple(changeHandler, shouldNotifyEngine(current, previous), scope)
            }
        handler?.invoke(current)
        if (!notify) return
        launcher?.launch { engine.networkDidChange(reregister, updateCalls) }
    }

    private fun summary(
        capabilities: NetworkCapabilities?,
        properties: LinkProperties,
    ): String {
        val transports =
            listOf(
                NetworkCapabilities.TRANSPORT_WIFI to "wifi",
                NetworkCapabilities.TRANSPORT_CELLULAR to "cellular",
                NetworkCapabilities.TRANSPORT_ETHERNET to "ethernet",
                NetworkCapabilities.TRANSPORT_VPN to "vpn",
            ).filter { capabilities?.hasTransport(it.first) == true }.map { it.second }
        val addresses = properties.linkAddresses.map { it.address.hostAddress.orEmpty() }.sorted()
        return (transports + addresses).joinToString(" ")
    }

    internal companion object {
        /**
         * Decides whether a network update is worth telling the engine about. [previous] is
         * `null` for the first update, which is never notified: it is the network already in
         * effect when monitoring started.
         */
        fun shouldNotifyEngine(
            current: BaresipNetworkPath,
            previous: BaresipNetworkPath?,
        ): Boolean {
            if (previous == null || !current.isSatisfied) return false
            return current.interfaceSummary != previous.interfaceSummary
        }
    }
}
