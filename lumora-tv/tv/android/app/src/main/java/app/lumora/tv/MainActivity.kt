package app.lumora.tv

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.Base64
import android.view.KeyEvent
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Lumora for Google TV / Android TV.
 *
 * The interface is the Lumora web app bundled in assets/index.html. Every service runs as the
 * real app installed on the TV: Lumora only lists apps and launches them with Android's own
 * launch intents, so sign-in, subscriptions and playback all happen inside each app.
 */
class MainActivity : Activity() {

    private lateinit var web: WebView
    private var tts: TextToSpeech? = null
    private var recognizer: SpeechRecognizer? = null
    private var listenAfterPermission = false
    private var appsCache: String? = null

    private val HOME_URL = "file:///android_asset/index.html?native=1"
    private val PICK_IMAGE = 41
    private val MIC_PERMISSION = 42

    private val packageWatcher = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            appsCache = null
            js("window.__lumoraAppsChanged && window.__lumoraAppsChanged()")
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        web = WebView(this)
        web.setBackgroundColor(Color.BLACK)
        web.isFocusable = true
        web.isFocusableInTouchMode = true
        with(web.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            allowFileAccess = true
            @Suppress("DEPRECATION")
            allowFileAccessFromFileURLs = true
        }
        // Websites opened from Lumora's Browser load full screen inside Lumora; Back returns.
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val scheme = request.url.scheme ?: return false
                if (scheme == "http" || scheme == "https" || scheme == "file") return false
                return try { startActivity(Intent(Intent.ACTION_VIEW, request.url)); true } catch (e: Exception) { true }
            }
        }
        web.addJavascriptInterface(Bridge(), "LumoraNative")
        setContentView(web)
        web.loadUrl(HOME_URL)
        web.requestFocus()

        tts = TextToSpeech(this) { }

        val f = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addDataScheme("package")
        }
        registerReceiver(packageWatcher, f)
    }

    override fun onDestroy() {
        try { unregisterReceiver(packageWatcher) } catch (e: Exception) { }
        tts?.shutdown()
        recognizer?.destroy()
        super.onDestroy()
    }

    /** Pressing Home while Lumora is the home screen. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.hasCategory(Intent.CATEGORY_HOME)) {
            if (web.url?.startsWith("file:") != true) web.loadUrl(HOME_URL) else js("window.__lumoraKey && __lumoraKey('home')")
        }
    }

    override fun onResume() {
        super.onResume()
        appsCache = null
    }

    @Deprecated("Back is forwarded to the web interface")
    override fun onBackPressed() {
        val onLumora = web.url?.startsWith("file:") == true
        when {
            !onLumora && web.canGoBack() -> web.goBack()
            !onLumora -> web.loadUrl(HOME_URL)
            else -> js("window.__lumoraKey && __lumoraKey('back')")   // a home screen never closes itself
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val name = when (event.keyCode) {
            KeyEvent.KEYCODE_PROG_RED -> "red"
            KeyEvent.KEYCODE_PROG_GREEN -> "green"
            KeyEvent.KEYCODE_PROG_YELLOW -> "yellow"
            KeyEvent.KEYCODE_PROG_BLUE -> "blue"
            KeyEvent.KEYCODE_MENU -> "menu"
            KeyEvent.KEYCODE_SEARCH -> "assist"
            else -> null
        }
        if (name != null && web.url?.startsWith("file:") == true) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) js("window.__lumoraKey && __lumoraKey('$name')")
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun js(code: String) = web.post { web.evaluateJavascript(code, null) }

    private fun drawableToDataUrl(d: Drawable, w: Int, h: Int): String {
        val bmp = if (d is BitmapDrawable && d.bitmap != null && d.bitmap.width <= w * 2) d.bitmap else {
            val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = Canvas(b); d.setBounds(0, 0, w, h); d.draw(c); b
        }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        return "data:image/png;base64," + Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    private fun listApps(): String {
        appsCache?.let { return it }
        val pm = packageManager
        val seen = LinkedHashMap<String, JSONObject>()
        val lookups = listOf(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER),
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        )
        for (intent in lookups) {
            for (ri in pm.queryIntentActivities(intent, 0)) {
                val pkg = ri.activityInfo.packageName
                if (pkg == packageName || seen.containsKey(pkg)) continue
                val o = JSONObject()
                o.put("pkg", pkg)
                o.put("label", ri.loadLabel(pm).toString())
                try {
                    val banner = ri.activityInfo.loadBanner(pm) ?: ri.activityInfo.applicationInfo.loadBanner(pm)
                    if (banner != null) o.put("banner", drawableToDataUrl(banner, 320, 180))
                    else o.put("icon", drawableToDataUrl(ri.loadIcon(pm), 144, 144))
                } catch (e: Exception) { }
                seen[pkg] = o
            }
        }
        val arr = JSONArray(); seen.values.sortedBy { it.optString("label").lowercase() }.forEach { arr.put(it) }
        return arr.toString().also { appsCache = it }
    }

    private fun startRecognizer() {
        recognizer?.destroy()
        val r = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(v: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(t: Int, p: Bundle?) {}
            override fun onPartialResults(b: Bundle) {
                val t = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: return
                js("window.__lumoraSpeech && __lumoraSpeech({partial:${JSONObject.quote(t)}})")
            }
            override fun onResults(b: Bundle) {
                val t = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
                js("window.__lumoraSpeech && __lumoraSpeech({final:${JSONObject.quote(t)}})")
            }
            override fun onError(code: Int) {
                val kind = if (code == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) "permission" else "other"
                js("window.__lumoraSpeech && __lumoraSpeech({error:'$kind'})")
            }
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        r.startListening(i)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray) {
        if (requestCode == MIC_PERMISSION) {
            if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED && listenAfterPermission) startRecognizer()
            else js("window.__lumoraSpeech && __lumoraSpeech({error:'permission'})")
            listenAfterPermission = false
        }
    }

    @Deprecated("Photo picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_IMAGE || resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        Thread {
            try {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
                var sample = 1
                while (bounds.outWidth / sample > 3840) sample *= 2
                val bmp = contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) } ?: return@Thread
                val scale = minOf(1f, 1920f / bmp.width)
                val sized = if (scale < 1f) Bitmap.createScaledBitmap(bmp, (bmp.width * scale).toInt(), (bmp.height * scale).toInt(), true) else bmp
                val out = ByteArrayOutputStream(); sized.compress(Bitmap.CompressFormat.JPEG, 85, out)
                val url = "data:image/jpeg;base64," + Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
                js("window.__lumoraImage && __lumoraImage(${JSONObject.quote(url)})")
            } catch (e: Exception) { }
        }.start()
    }

    /** What the web interface can ask the TV to do. */
    inner class Bridge {
        @JavascriptInterface fun apps(): String = listApps()

        @JavascriptInterface fun launch(pkg: String): Boolean {
            val pm = packageManager
            val i = pm.getLeanbackLaunchIntentForPackage(pkg) ?: pm.getLaunchIntentForPackage(pkg) ?: return false
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            runOnUiThread { try { startActivity(i) } catch (e: Exception) { } }
            return true
        }

        /** Opens Google Play on the app's page ("pkg:<id>") or a search. */
        @JavascriptInterface fun store(what: String) {
            val market = if (what.startsWith("pkg:")) "market://details?id=${what.substring(4)}" else "market://search?q=${Uri.encode(what)}"
            val web = if (what.startsWith("pkg:")) "https://play.google.com/store/apps/details?id=${what.substring(4)}" else "https://play.google.com/store/search?q=${Uri.encode(what)}&c=apps"
            runOnUiThread {
                try { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(market)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                catch (e: ActivityNotFoundException) { try { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(web)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (e2: Exception) { } }
            }
        }

        @JavascriptInterface fun say(text: String) {
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "lumora")
        }

        @JavascriptInterface fun canListen(): Boolean = SpeechRecognizer.isRecognitionAvailable(this@MainActivity)

        @JavascriptInterface fun listen() = runOnUiThread {
            if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                listenAfterPermission = true
                requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MIC_PERMISSION)
            } else startRecognizer()
        }

        @JavascriptInterface fun stopListening() = runOnUiThread { recognizer?.cancel() }

        @JavascriptInterface fun pickImage() = runOnUiThread {
            val i = Intent(Intent.ACTION_GET_CONTENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE)
            try { @Suppress("DEPRECATION") startActivityForResult(Intent.createChooser(i, "Choose a wallpaper"), PICK_IMAGE) } catch (e: Exception) { }
        }

        /** Opens the TV's input list on Android TV sets; on streaming sticks, the system settings. */
        @JavascriptInterface fun openInputs() = runOnUiThread {
            val tries = listOf(Intent("com.android.tv.action.VIEW_INPUTS"), Intent(Settings.ACTION_SETTINGS))
            for (i in tries) { try { startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); break } catch (e: Exception) { } }
        }

        @JavascriptInterface fun openSettings() = runOnUiThread {
            try { startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (e: Exception) { }
        }
    }
}
