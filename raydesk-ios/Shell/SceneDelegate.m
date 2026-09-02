#import "SceneDelegate.h"
#import <WebKit/WebKit.h>

extern void ray_ui_set_handlers(void (*open)(const char *, const char *),
                                void (*eval)(const char *));
extern void ray_ui_push_event(const char *kind, long long window, const char *tag);
extern int ray_start(void);

// M152 — el puente IPC: window.ray.send(text) llega aquí y se empuja como evento "message"
// (window 0: el shell no conoce el handle del programa; documentado). Clase DEDICADA — el
// SceneDelegate como handler crearía un ciclo de retención
// window -> ... -> userContentController -> (strong) delegate -> window.
@interface RayMsgHandler : NSObject <WKScriptMessageHandler>
@end

@implementation RayMsgHandler
- (void)userContentController:(WKUserContentController *)controller
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.body isKindOfClass:[NSString class]]) {
        return; // solo strings v1 (paridad con escritorio)
    }
    ray_ui_push_event("message", 0, [(NSString *)message.body UTF8String]);
}
@end

// El MISMO shim que inyecta el escritorio (ray_runtime::ui::RAY_JS_SHIM, M152/M157:
// send + request/Promise + _deliver).
static NSString *const rayJsShim =
    @"(function(){var p={},n=0;function e(t){return typeof t===\"string\"?t:JSON.stringify(t)}"
    @"function q(s){window.webkit.messageHandlers.ray.postMessage(String(s).replace(/\\u0000/g,\"\"))}"
    @"window.ray={send:function(t){q(e(t))},request:function(t){n=n+1;var i=n;"
    @"return new Promise(function(r){p[i]=r;q(\"\\u0001q\\u0001\"+i+\"\\u0001\"+e(t))})},"
    @"_deliver:function(i,v){var r=p[i];if(r){delete p[i];r(v)}}}})();";

static WKWebView *rayWebView = nil;
static NSString *rayLastURL = nil;

static void ray_open(const char *title, const char *url) {
    NSString *u = [NSString stringWithUTF8String:url]; // copiar ANTES de despachar
    dispatch_async(dispatch_get_main_queue(), ^{
      rayLastURL = u;
      [rayWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:u]]];
    });
}

static void ray_eval(const char *js) {
    NSString *s = [NSString stringWithUTF8String:js];
    dispatch_async(dispatch_get_main_queue(), ^{
      [rayWebView evaluateJavaScript:s completionHandler:nil];
    });
}

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    UIViewController *vc = [UIViewController new];
    // M152: el puente se (re)instala EN CADA conexión de escena — el webview muere y renace
    // con ella (sceneDidDisconnect lo anula), así que esto va fuera del dispatch_once.
    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    [cfg.userContentController addScriptMessageHandler:[RayMsgHandler new] name:@"ray"];
    [cfg.userContentController
        addUserScript:[[WKUserScript alloc] initWithSource:rayJsShim
                                             injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                          forMainFrameOnly:YES]];
    rayWebView = [[WKWebView alloc] initWithFrame:vc.view.bounds configuration:cfg];
    rayWebView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:rayWebView];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    if (rayLastURL != nil) { // reconexión: el programa ya entregó su URL
        [rayWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:rayLastURL]]];
    }
    static dispatch_once_t rayOnce;
    dispatch_once(&rayOnce, ^{
      ray_ui_set_handlers(ray_open, ray_eval);
      ray_start();
    });
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    rayWebView = nil; // la vista muere con la escena; el programa sigue
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    ray_ui_push_event("lifecycle", 0, "background");
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    ray_ui_push_event("lifecycle", 0, "foreground");
}

@end
