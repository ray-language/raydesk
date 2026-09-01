package org.raylang.shell;

import android.os.Handler;
import android.os.Looper;
import android.webkit.WebView;

public final class RayBridge {
    static {
        System.loadLibrary("ray_app");
    }

    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static WebView webView;
    static volatile String lastUrl;
    private static boolean started;

    static void attach(WebView w) {
        webView = w;
    }

    static void startOnce() {
        if (!started) {
            started = true;
            start(); // registra los handlers y lanza el programa raylang en su hilo
        }
    }

    public static native int start();

    public static native void pushEvent(String kind, long window, String tag);

    // Llamados desde NATIVO (el hilo del programa): siempre postear al main thread.
    public static void onOpen(String title, String url) {
        lastUrl = url;
        MAIN.post(() -> {
            if (webView != null) {
                webView.loadUrl(url);
            }
        });
    }

    public static void onEval(String js) {
        MAIN.post(() -> {
            if (webView != null) {
                webView.evaluateJavascript(js, null);
            }
        });
    }
}
