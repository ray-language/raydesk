#import "AppDelegate.h"
#import <WebKit/WebKit.h>

extern void ray_ui_set_handlers(void (*open)(const char *, const char *),
                                void (*eval)(const char *));
extern void ray_ui_push_event(const char *kind, long long window, const char *tag);
extern int ray_start(void);

static WKWebView *rayWebView = nil;

static void ray_open(const char *title, const char *url) {
    NSString *u = [NSString stringWithUTF8String:url]; // copiar ANTES de despachar
    dispatch_async(dispatch_get_main_queue(), ^{
      [rayWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:u]]];
    });
}

static void ray_eval(const char *js) {
    NSString *s = [NSString stringWithUTF8String:js];
    dispatch_async(dispatch_get_main_queue(), ^{
      [rayWebView evaluateJavaScript:s completionHandler:nil];
    });
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *vc = [UIViewController new];
    rayWebView = [[WKWebView alloc] initWithFrame:vc.view.bounds];
    rayWebView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [vc.view addSubview:rayWebView];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    ray_ui_set_handlers(ray_open, ray_eval);
    ray_start();
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    ray_ui_push_event("lifecycle", 0, "background");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    ray_ui_push_event("lifecycle", 0, "foreground");
}

@end
