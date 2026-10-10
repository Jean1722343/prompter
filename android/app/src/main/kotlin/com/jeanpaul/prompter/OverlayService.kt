package com.jeanpaul.prompter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Ventana flotante del teleprompter.
 *
 * Dibuja un FlutterView (entrypoint `overlayMain`) encima de cualquier app,
 * por ejemplo la cámara. El movimiento se hace aquí, en nativo, con
 * coordenadas absolutas de pantalla para que la ventana siga al dedo sin
 * tirones. El tamaño lo decide Flutter (esquina o pellizco) vía `resize`.
 */
class OverlayService : Service() {

    companion object {
        const val ACTION_SHOW = "com.jeanpaul.prompter.SHOW"
        const val ACTION_CLOSE = "com.jeanpaul.prompter.CLOSE"
        const val WINDOW_CHANNEL = "prompter/overlay_window"

        private const val NOTIFICATION_CHANNEL = "prompter_overlay"
        private const val NOTIFICATION_ID = 4071
        private const val PREFS = "prompter_overlay_window"
        private const val MIN_W_DP = 56
        private const val MIN_H_DP = 56

        @Volatile
        var isRunning = false
            private set

        /** Guion (JSON) que debe mostrar la ventana; lo deja la app al abrirla. */
        @Volatile
        var script: String? = null

        /** Apariencia de la app (system, light o dark). */
        @Volatile
        var appearance: String? = null
    }

    private lateinit var windowManager: WindowManager
    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var params: WindowManager.LayoutParams? = null
    private var channel: MethodChannel? = null

    private var moving = false
    private var lastRawX = Float.NaN
    private var lastRawY = Float.NaN

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CLOSE) {
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        if (flutterView == null) {
            createWindow()
        } else {
            // Ya estaba abierta: que Flutter recargue el guion y los ajustes.
            channel?.invokeMethod("reload", null)
        }
        isRunning = true
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        flutterView?.let { view ->
            saveGeometry()
            try {
                windowManager.removeView(view)
            } catch (_: Exception) {
            }
            view.detachFromFlutterEngine()
        }
        flutterView = null
        channel?.setMethodCallHandler(null)
        engine?.destroy()
        engine = null
        super.onDestroy()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val p = params ?: return
        val (sw, sh) = screenSizePx()
        p.width = min(p.width, sw)
        p.height = min(p.height, sh)
        p.x = p.x.coerceIn(0, max(0, sw - p.width))
        p.y = p.y.coerceIn(0, max(0, sh - p.height))
        updateLayout()
    }

    // region Ventana

    private fun createWindow() {
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val entrypoint = DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "overlayMain")
        val newEngine = FlutterEngineGroup(applicationContext)
            .createAndRunEngine(applicationContext, entrypoint)
        engine = newEngine

        channel = MethodChannel(newEngine.dartExecutor.binaryMessenger, WINDOW_CHANNEL).also {
            it.setMethodCallHandler(::onMethodCall)
        }

        val view = FlutterView(applicationContext, FlutterTextureView(applicationContext))
        view.attachToFlutterEngine(newEngine)
        view.setBackgroundColor(Color.TRANSPARENT)
        view.setOnTouchListener { _, event ->
            handleTouch(event)
            false // Flutter siempre recibe el evento también.
        }
        newEngine.lifecycleChannel.appIsResumed()

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val (sw, sh) = screenSizePx()
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val defaultW = (sw * 0.92f).roundToInt()
        val defaultH = (sh * 0.30f).roundToInt()
        val w = prefs.getInt("w", defaultW).coerceIn(dp(MIN_W_DP), sw)
        val h = prefs.getInt("h", defaultH).coerceIn(dp(MIN_H_DP), sh)
        // Por defecto arriba y centrada: cerca de la cámara frontal.
        val x = prefs.getInt("x", (sw - w) / 2).coerceIn(0, max(0, sw - w))
        val y = prefs.getInt("y", statusBarPx()).coerceIn(0, max(0, sh - h))

        val p = WindowManager.LayoutParams(
            w, h, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = x
            this.y = y
        }
        params = p
        flutterView = view
        windowManager.addView(view, p)
    }

    private fun handleTouch(event: MotionEvent) {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                moving = false
                lastRawX = Float.NaN
                lastRawY = Float.NaN
            }
            MotionEvent.ACTION_POINTER_DOWN -> moving = false
            MotionEvent.ACTION_MOVE -> {
                if (!moving) return
                val p = params ?: return
                if (lastRawX.isNaN()) {
                    lastRawX = event.rawX
                    lastRawY = event.rawY
                    return
                }
                val dx = event.rawX - lastRawX
                val dy = event.rawY - lastRawY
                lastRawX = event.rawX
                lastRawY = event.rawY
                val (sw, sh) = screenSizePx()
                p.x = (p.x + dx).roundToInt().coerceIn(0, max(0, sw - p.width))
                p.y = (p.y + dy).roundToInt().coerceIn(0, max(0, sh - p.height))
                updateLayout()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (moving) saveGeometry()
                moving = false
            }
        }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "beginMove" -> {
                moving = true
                lastRawX = Float.NaN
                lastRawY = Float.NaN
                result.success(null)
            }
            "resize" -> {
                val p = params
                if (p == null) {
                    result.success(null)
                    return
                }
                val (sw, sh) = screenSizePx()
                val w = dp(call.argument<Double>("width") ?: 0.0)
                val h = dp(call.argument<Double>("height") ?: 0.0)
                if (call.argument<Boolean>("shift") == true) {
                    // Al restaurar desde la burbuja: se desplaza si no cabe.
                    p.width = w.coerceIn(min(dp(MIN_W_DP), sw), sw)
                    p.height = h.coerceIn(min(dp(MIN_H_DP), sh), sh)
                    p.x = p.x.coerceIn(0, max(0, sw - p.width))
                    p.y = p.y.coerceIn(0, max(0, sh - p.height))
                } else {
                    // Crece hacia la derecha/abajo sin moverse ni salirse de la pantalla.
                    p.width = w.coerceIn(min(dp(MIN_W_DP), sw), max(dp(MIN_W_DP), sw - p.x))
                    p.height = h.coerceIn(min(dp(MIN_H_DP), sh), max(dp(MIN_H_DP), sh - p.y))
                }
                updateLayout()
                if (call.argument<Boolean>("persist") == true) saveGeometry()
                result.success(geometry())
            }
            "geometry" -> result.success(geometry())
            "script" -> result.success(script)
            "appearance" -> result.success(appearance)
            "openApp" -> {
                packageManager.getLaunchIntentForPackage(packageName)?.let {
                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    startActivity(it)
                }
                result.success(null)
            }
            "close" -> {
                result.success(null)
                stopSelf()
            }
            else -> result.notImplemented()
        }
    }

    private fun geometry(): Map<String, Double> {
        val p = params
        val (sw, sh) = screenSizePx()
        val d = resources.displayMetrics.density.toDouble()
        return mapOf(
            "width" to (p?.width ?: 0) / d,
            "height" to (p?.height ?: 0) / d,
            "x" to (p?.x ?: 0) / d,
            "y" to (p?.y ?: 0) / d,
            "screenWidth" to sw / d,
            "screenHeight" to sh / d,
        )
    }

    private fun updateLayout() {
        val view = flutterView ?: return
        val p = params ?: return
        try {
            windowManager.updateViewLayout(view, p)
        } catch (_: Exception) {
        }
    }

    private fun saveGeometry() {
        val p = params ?: return
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("x", p.x)
            .putInt("y", p.y)
            .putInt("w", p.width)
            .putInt("h", p.height)
            .apply()
    }

    // endregion

    // region Notificación (obligatoria para el servicio en primer plano)

    private fun startInForeground() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL,
                    "Teleprompter flotante",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) }
            )
        }

        val immutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val openIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            immutable or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val closeIntent = PendingIntent.getService(
            this, 1,
            Intent(this, OverlayService::class.java).setAction(ACTION_CLOSE),
            immutable or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_prompter)
            .setContentTitle("Teleprompter flotante activo")
            .setContentText("Toca para volver a Prompter")
            .setContentIntent(openIntent)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Cerrar", closeIntent).build())
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    // endregion

    // region Utilidades

    private fun screenSizePx(): Pair<Int, Int> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            bounds.width() to bounds.height()
        } else {
            val dm = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(dm)
            dm.widthPixels to dm.heightPixels
        }
    }

    private fun statusBarPx(): Int {
        val id = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else dp(24)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()

    private fun dp(value: Double): Int = (value * resources.displayMetrics.density).roundToInt()

    // endregion
}
