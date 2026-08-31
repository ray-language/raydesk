#import "SceneDelegate.h"
#import <WebKit/WebKit.h>

extern void ray_ui_set_handlers(void (*open)(const char *, const char *),
                                void (*eval)(const char *));
extern void ray_ui_push_event(const char *kind, long long window, const char *tag);
extern int ray_start(void);

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
    rayWebView = [[WKWebView alloc] initWithFrame:vc.view.bounds];
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
