package app.payk.payk

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val REFERRAL_CHANNEL = "app.payk.payk/referral"
    }

    private var referralChannel: MethodChannel? = null
    private var initialReferralLink: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = captureLink(intent)
        if (link != null) {
            referralChannel?.invokeMethod("onLink", link)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REFERRAL_CHANNEL)
        referralChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallReferrer" -> readInstallReferrer(result)
                "getDeviceInfo" -> result.success(collectDeviceInfo())
                "getInitialLink" -> result.success(initialReferralLink)
                else -> result.notImplemented()
            }
        }
    }

    private fun captureLink(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent.dataString ?: return null
        initialReferralLink = uri
        return uri
    }

    private fun collectDeviceInfo(): Map<String, Any?> {
        // screen на Android намеренно не отправляем (docs/loyalty-referral-deeplink.md):
        // CSS-размер в мобильном Chrome может отличаться от нативных метрик экрана.
        return mapOf(
            "platform" to "android",
            "os_version" to Build.VERSION.RELEASE,
            "model" to Build.MODEL,
            "language" to Locale.getDefault().toLanguageTag(),
            "timezone" to TimeZone.getDefault().id,
        )
    }

    private fun readInstallReferrer(result: MethodChannel.Result) {
        val finished = AtomicBoolean(false)
        fun complete(value: String?) {
            if (!finished.compareAndSet(false, true)) return
            mainHandler.post { result.success(value) }
        }

        val client = try {
            InstallReferrerClient.newBuilder(applicationContext).build()
        } catch (_: Throwable) {
            complete(null)
            return
        }

        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    var referrerUrl: String? = null
                    if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        referrerUrl = try {
                            client.installReferrer?.installReferrer
                        } catch (_: Throwable) {
                            null
                        }
                    }
                    runCatching { client.endConnection() }
                    complete(referrerUrl)
                }

                override fun onInstallReferrerServiceDisconnected() {
                    complete(null)
                }
            })
        } catch (_: Throwable) {
            runCatching { client.endConnection() }
            complete(null)
        }
    }
}
