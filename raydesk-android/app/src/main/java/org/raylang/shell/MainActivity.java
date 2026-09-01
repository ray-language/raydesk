package org.raylang.shell;

import android.app.Activity;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView web = new WebView(this);
        web.getSettings().setJavaScriptEnabled(true);
        web.getSettings().setDomStorageEnabled(true);
        web.addJavascriptInterface(new RayJs(), "RayAndroid");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageStarted(WebView v, String url, Bitmap favicon) {
                // M152: el MISMO contrato que el user script de WKWebView — window.ray.send.
                v.evaluateJavascript(
                    "window.ray={send:function(t){RayAndroid.send(String(t).replace(/\\u0000/g,''))}}",
                    null);
            }
        });
        setContentView(web);
        RayBridge.attach(web);
        if (RayBridge.lastUrl != null) {
            web.loadUrl(RayBridge.lastUrl); // recreación: el programa sigue vivo, recargar
        }
        RayBridge.startOnce();
    }

    @Override
    protected void onPause() {
        super.onPause();
        RayBridge.pushEvent("lifecycle", 0, "background");
    }

    @Override
    protected void onResume() {
        super.onResume();
        RayBridge.pushEvent("lifecycle", 0, "foreground");
    }

    static final class RayJs {
        @JavascriptInterface
        public void send(String text) {
            RayBridge.pushEvent("message", 0, text == null ? "" : text);
        }
    }
}
