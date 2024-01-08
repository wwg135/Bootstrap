#import "ViewController.h"
#include "NSUserDefaults+appDefaults.h"
#include "common.h"
#include "AppDelegate.h"
#include "AppViewController.h"
#include "bootstrap.h"
#include "credits.h"
#include "AppList.h"
#import <sys/sysctl.h>
#include <sys/utsname.h>
#import "Bootstrap-Swift.h"

#include <Security/SecKey.h>
#include <Security/Security.h>
typedef struct CF_BRIDGED_TYPE(id) __SecCode const* SecStaticCodeRef; /* code on disk */
typedef enum { kSecCSDefaultFlags=0, kSecCSSigningInformation = 1 << 1 } SecCSFlags;
OSStatus SecStaticCodeCreateWithPathAndAttributes(CFURLRef path, SecCSFlags flags, CFDictionaryRef attributes, SecStaticCodeRef* CF_RETURNS_RETAINED staticCode);
OSStatus SecCodeCopySigningInformation(SecStaticCodeRef code, SecCSFlags flags, CFDictionaryRef* __nonnull CF_RETURNS_RETAINED information);


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *logView;
@property (weak, nonatomic) IBOutlet UIButton *bootstraBtn;
@property (weak, nonatomic) IBOutlet UISwitch *opensshState;
@property (weak, nonatomic) IBOutlet UIButton *appEnablerBtn;
@property (weak, nonatomic) IBOutlet UIButton *respringBtn;
@property (weak, nonatomic) IBOutlet UIButton *uninstallBtn;
@property (weak, nonatomic) IBOutlet UIButton *rebuildappsBtn;
@property (weak, nonatomic) IBOutlet UIButton *rebuildIconCacheBtn;
@property (weak, nonatomic) IBOutlet UIButton *reinstallPackageManagerBtn;
@property (weak, nonatomic) IBOutlet UILabel *opensshLabel;

@end

@implementation ViewController

- (BOOL)checkTSVersion {
    
    CFURLRef binaryURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef)NSBundle.mainBundle.executablePath, kCFURLPOSIXPathStyle, false);
    if(binaryURL == NULL) return NO;
    
    SecStaticCodeRef codeRef = NULL;
    OSStatus result = SecStaticCodeCreateWithPathAndAttributes(binaryURL, kSecCSDefaultFlags, NULL, &codeRef);
    if(result != errSecSuccess) return NO;
    
    CFDictionaryRef signingInfo = NULL;
    result = SecCodeCopySigningInformation(codeRef, kSecCSSigningInformation, &signingInfo);
    if(result != errSecSuccess) return NO;
    
    NSString* teamID = (NSString*)CFDictionaryGetValue(signingInfo, CFSTR("teamid"));
    SYSLOG("teamID in trollstore: %@", teamID);
    
    return [teamID isEqualToString:@"T8ALTGMVXN"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    UIViewController *vc = [BootstrapViewWrapper createBootstrapView];
    
    UIView *bootstrapView = vc.view;
    bootstrapView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self addChildViewController:vc];
    [self.view addSubview:bootstrapView];
    
    [NSLayoutConstraint activateConstraints:@[
        [bootstrapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bootstrapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bootstrapView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [bootstrapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    
    [vc didMoveToParentViewController:self];
    
    self.logView.text = nil;
    self.logView.layer.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.01].CGColor;
    self.logView.layer.borderColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.01].CGColor;
    self.logView.layer.borderWidth = 1.0;
    self.logView.layer.cornerRadius = 5.0;
    
    [AppDelegate registerLogView:self.logView];
    
    if(isSystemBootstrapped())
    {
        self.bootstraBtn.enabled = NO;
        [self.bootstraBtn setTitle:NSLocalizedString(@"Bootstrapped", nil) forState:UIControlStateDisabled];

        self.respringBtn.enabled = YES;
        self.appEnablerBtn.enabled = YES;
        self.rebuildappsBtn.enabled = YES;
        self.rebuildIconCacheBtn.enabled = YES;
        self.reinstallPackageManagerBtn.enabled = YES;
        self.uninstallBtn.enabled = NO;
        self.uninstallBtn.hidden = NO;
        
        if([NSFileManager.defaultManager fileExistsAtPath:jbroot(@"/basebin/.rebuildiconcache")]) {
            [NSFileManager.defaultManager removeItemAtPath:jbroot(@"/basebin/.rebuildiconcache") error:nil];
            
            [AppDelegate showHudMsg:Localized(@"Rebuilding")];
        }
        
        if([NSFileManager.defaultManager fileExistsAtPath:jbroot(@"/basebin/.launchctl_support")]) {
            self.opensshState.hidden = YES;
            self.opensshLabel.hidden = YES;
        }
    }
    else if(isBootstrapInstalled())
    {
        
        self.bootstraBtn.enabled = YES;
        [self.bootstraBtn setTitle:NSLocalizedString(@"Bootstrap", nil) forState:UIControlStateNormal];

        self.respringBtn.enabled = NO;
        self.appEnablerBtn.enabled = NO;
        self.rebuildappsBtn.enabled = NO;
        self.rebuildIconCacheBtn.enabled = NO;
        self.reinstallPackageManagerBtn.enabled = NO;
        self.uninstallBtn.hidden = NO;
    }
    else if(NSProcessInfo.processInfo.operatingSystemVersion.majorVersion>=15)
    {
        self.bootstraBtn.enabled = YES;
        [self.bootstraBtn setTitle:NSLocalizedString(@"Install", nil) forState:UIControlStateNormal];

        self.respringBtn.enabled = NO;
        self.appEnablerBtn.enabled = NO;
        self.rebuildappsBtn.enabled = NO;
        self.rebuildIconCacheBtn.enabled = NO;
        self.reinstallPackageManagerBtn.enabled = NO;
        self.uninstallBtn.hidden = YES;
    } else {
        self.bootstraBtn.enabled = NO;
        [self.bootstraBtn setTitle:NSLocalizedString(@"Unsupported", nil) forState:UIControlStateDisabled];

        self.respringBtn.enabled = NO;
        self.appEnablerBtn.enabled = NO;
        self.rebuildappsBtn.enabled = NO;
        self.rebuildIconCacheBtn.enabled = NO;
        self.reinstallPackageManagerBtn.enabled = NO;
        self.uninstallBtn.hidden = YES;
        
        [AppDelegate showMesage:NSLocalizedString(@"The current iOS version is not supported yet, we may add support in a future version.", nil) title:NSLocalizedString(@"Unsupported", nil)];
    }
    
    
    [AppDelegate addLogText:[NSString stringWithFormat:NSLocalizedString(@"ios-version: %@", @""), UIDevice.currentDevice.systemVersion]];
    
    struct utsname systemInfo;
    uname(&systemInfo);
    [AppDelegate addLogText:[NSString stringWithFormat:NSLocalizedString(@"device-model: %s", @""), systemInfo.machine]];
    
    [AppDelegate addLogText:[NSString stringWithFormat:NSLocalizedString(@"app-version: %@/%@", @""), NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]]];
    
    [AppDelegate addLogText:[NSString stringWithFormat:NSLocalizedString(@"boot-session: %@", @""), getBootSession()]];
    
    [AppDelegate addLogText: isBootstrapInstalled()? NSLocalizedString(@"bootstrap installed", @"") : NSLocalizedString(@"bootstrap not installed", @"")];
    [AppDelegate addLogText: isSystemBootstrapped()? NSLocalizedString(@"system bootstrapped", @"") : NSLocalizedString(@"system not bootstrapped", @"")];
    
    if(!isBootstrapInstalled()) dispatch_async(dispatch_get_global_queue(0, 0), ^{
        usleep(1000*500);
        [AppDelegate addLogText:NSLocalizedString(@"\n:::Credits:::\n", @"")];
        usleep(1000*500);
        for(NSString* name in CREDITS) {
            usleep(1000*50);
            [AppDelegate addLogText:[NSString stringWithFormat:@"%@ - %@\n",name,CREDITS[name]]];
        }
        sleep(1);
        [AppDelegate addLogText:NSLocalizedString(@"\nThanks to these guys, we couldn't have completed this project without their help!", nil)];

    });
    
    SYSLOG("locale=%@", NSLocale.currentLocale.countryCode);
    SYSLOG("locale=%@", [NSUserDefaults.appDefaults valueForKey:@"locale"]);
    [NSUserDefaults.appDefaults setValue:NSLocale.currentLocale.countryCode forKey:@"locale"];
    [NSUserDefaults.appDefaults synchronize];
    SYSLOG("locale=%@", [NSUserDefaults.appDefaults valueForKey:@"locale"]);
    
    if(isSystemBootstrapped())
    {
        [self checkServer];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkServer)
                                              name:UIApplicationWillEnterForegroundNotification object:nil];
    }
}

-(void)checkServer
{
    static bool alerted = false;
    if(alerted) return;
    
    if(spawnRoot(jbroot(@"/basebin/bootstrapd"), @[@"check"], nil, nil) != 0)
    {
        alerted = true;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:Localized(@"Server Not Running") message:Localized(@"for unknown reasons the bootstrap server is not running, the only thing we can do is to restart it now.") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:Localized(@"Restart Server") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            
            alerted = false;
            
            NSString* log=nil;
            NSString* err=nil;
            if(spawnRoot(jbroot(@"/basebin/bootstrapd"), @[@"daemon",@"-f"], &log, &err)==0) {
                [AppDelegate addLogText:Localized(@"bootstrap server restart successful")];
                [self updateOpensshStatus];
            } else {
                [AppDelegate showMesage:[NSString stringWithFormat:@"%@\nERR:%@"] title:Localized(@"Error")];
            }
            
        }]];
        
        [AppDelegate showAlert:alert];
    } else {
        [AppDelegate addLogText:Localized(@"bootstrap server check successful")];
        [self updateOpensshStatus];
    }
}

-(void)updateOpensshStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(isSystemBootstrapped()) {
            self.opensshState.on = spawnRoot(jbroot(@"/basebin/bootstrapd"), @[@"openssh",@"check"], nil, nil)==0;
        } else {
            self.opensshState.on = [NSUserDefaults.appDefaults boolForKey:@"openssh"];
        }
    });
}

- (IBAction)respring:(id)sender {
    
    NSString* log=nil;
    NSString* err=nil;
    int status = spawnBootstrap((char*[]){"/usr/bin/sbreload", NULL}, &log, &err);
    if(status!=0) [AppDelegate showMesage:[NSString stringWithFormat:@"%@\n\nstderr:\n%@",log,err] title:[NSString stringWithFormat:@"code (%d)",status]];
}

- (IBAction)rebuildapps:(id)sender {
    [AppDelegate addLogText:@"状态：正在重建应用程序"];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [AppDelegate showHudMsg:NSLocalizedString(@"Applying", nil)];

        NSString* log=nil;
        NSString* err=nil;
        int status = spawnBootstrap((char*[]){"/bin/sh", "/basebin/rebuildapps.sh", NULL}, nil, nil);
        if(status==0) {
            killAllForApp("/usr/libexec/backboardd");
        } else {
            [AppDelegate showMesage:[NSString stringWithFormat:@"%@\n\nstderr:\n%@",log,err] title:[NSString stringWithFormat:@"code (%d)",status]];
        }
        [AppDelegate dismissHud];
    });
}

- (IBAction)reinstallPackageManager:(id)sender {
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [AppDelegate showHudMsg:Localized(@"Applying")];
        
        NSString* log=nil;
        NSString* err=nil;
        
        BOOL success=YES;
        
        [AppDelegate addLogText:@"Status: Reinstalling Sileo"];
        NSString* sileoDeb = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"sileo.deb"];
        if(spawnBootstrap((char*[]){"/usr/bin/dpkg", "-i", rootfsPrefix(sileoDeb).fileSystemRepresentation, NULL}, &log, &err) != 0) {
            [AppDelegate addLogText:[NSString stringWithFormat:@"failed:%@\nERR:%@", log, err]];
            success = NO;
        }
        
        if(spawnBootstrap((char*[]){"/usr/bin/uicache", "-p", "/Applications/Sileo.app", NULL}, &log, &err) != 0) {
            [AppDelegate addLogText:[NSString stringWithFormat:@"failed:%@\nERR:%@", log, err]];
            success = NO;
        }
        
        if(success) {
            [AppDelegate showMesage:@"Sileo reinstalled!" title:@""];
        }
        [AppDelegate dismissHud];
    });
}

int rebuildIconCache()
{
    AppList* tsapp = [AppList appWithBundleIdentifier:@"com.opa334.TrollStore"];
    if(!tsapp) {
        STRAPLOG("trollstore not found!");
        return -1;
    }
        
    STRAPLOG("rebuild icon cache...");
    ASSERT([LSApplicationWorkspace.defaultWorkspace _LSPrivateRebuildApplicationDatabasesForSystemApps:YES internal:YES user:YES]);
    
    NSString* log=nil;
    NSString* err=nil;
    
    if(spawnRoot([tsapp.bundleURL.path stringByAppendingPathComponent:@"trollstorehelper"], @[@"refresh"], &log, &err) != 0) {
        STRAPLOG("refresh tsapps failed:%@\nERR:%@", log, err);
        return -1;
    }
    
    [[NSString new] writeToFile:jbroot(@"/basebin/.rebuildiconcache") atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [LSApplicationWorkspace.defaultWorkspace openApplicationWithBundleID:NSBundle.mainBundle.bundleIdentifier];
    
    int status = spawnBootstrap((char*[]){"/bin/sh", "/basebin/rebuildapps.sh", NULL}, &log, &err);
    if(status==0) {
        killAllForApp("/usr/libexec/backboardd");
    } else {
        STRAPLOG("rebuildapps failed:%@\nERR:\n%@",log,err);
    }
    
    if([NSFileManager.defaultManager fileExistsAtPath:jbroot(@"/basebin/.rebuildiconcache")]) {
        [NSFileManager.defaultManager removeItemAtPath:jbroot(@"/basebin/.rebuildiconcache") error:nil];
    }
    
    return status;
}

- (IBAction)rebuildIconCache:(id)sender {
    [AppDelegate addLogText:@"Status: Rebuilding Icon Cache"];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [AppDelegate showHudMsg:Localized(@"Rebuilding") detail:Localized(@"Don't exit Bootstrap app until show the lock screen.")];
        
        NSString* log=nil;
        NSString* err=nil;
        int status = spawnRoot(NSBundle.mainBundle.executablePath, @[@"rebuildiconcache"], &log, &err);
        if(status != 0) {
            [AppDelegate showMesage:[NSString stringWithFormat:@"%@\n\nstderr:\n%@",log,err] title:[NSString stringWithFormat:@"code(%d)",status]];
        }
        
        [AppDelegate dismissHud];
    });
}

- (IBAction)appenabler:(id)sender {
    
    AppViewController *vc = [[AppViewController alloc] init];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:navigationController animated:YES completion:^{}];
}

- (IBAction)openssh:(id)sender {
    UISwitch* enabled = (UISwitch*)sender;
    
    if(!isSystemBootstrapped()) {
        [NSUserDefaults.appDefaults setValue:@(enabled.on) forKey:@"openssh"];
        [NSUserDefaults.appDefaults synchronize];
        return;
    }
    
    if(![NSFileManager.defaultManager fileExistsAtPath:jbroot(@"/usr/libexec/sshd-keygen-wrapper")]) {
        [AppDelegate showMesage:NSLocalizedString(@"OpenSSH package is not installed.", nil) title:NSLocalizedString(@"Developer", nil)];
        enabled.on = NO;
        return;
    }
    
    NSString* log=nil;
    NSString* err=nil;
    int status = spawnRoot(jbroot(@"/basebin/bootstrapd"), @[@"openssh",enabled.on?@"start":@"stop"], &log, &err);
    
    //try
    if(!enabled.on) spawnBootstrap((char*[]){"/usr/bin/killall","-9","sshd",NULL}, nil, nil);
    
    if(status==0)
    {
        [NSUserDefaults.appDefaults setValue:@(enabled.on) forKey:@"openssh"];
        [NSUserDefaults.appDefaults synchronize];
    }
    else
    {
        [AppDelegate showMesage:[NSString stringWithFormat:@"%@\n\nstderr:\n%@",log,err] title:[NSString stringWithFormat:@"code (%d)",status]];
        if(enabled.on) [enabled setOn:NO];
    }
}

- (IBAction)bootstrap:(id)sender {
    if(![self checkTSVersion]) {
        [AppDelegate showMesage:NSLocalizedString(@"Your TrollStore version is out of date. Bootstrap only supports TrollStore 2.", nil) title:NSLocalizedString(@"Error", nil)];
        return;
    }
    
    if(spawnRoot([NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"basebin/devtest"], nil, nil, nil) != 0) {
        [AppDelegate showMesage:NSLocalizedString(@"Your device does not seem to have developer mode enabled.\n\nPlease enable developer mode in Settings > Privacy & Security and reboot your device.", nil) title:NSLocalizedString(@"Error", nil)];
        return;
    }
    
    UIImpactFeedbackGenerator* generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    generator.impactOccurred;
    
    if(find_jbroot()) //make sure jbroot() function available
    {
        if([NSFileManager.defaultManager fileExistsAtPath:jbroot(@"/.installed_dopamine")]) {
            [AppDelegate showMesage:NSLocalizedString(@"RootHide Dopamine has been installed on this device, now install this bootstrap may break it!", nil) title:NSLocalizedString(@"Error", nil)];
            return;
        }
        
        if([NSFileManager.defaultManager fileExistsAtPath:jbroot(@"/.bootstrapped")]) {
            NSString* strappedVersion = [NSString stringWithContentsOfFile:jbroot(@"/.bootstrapped") encoding:NSUTF8StringEncoding error:nil];
            if(strappedVersion.intValue != BOOTSTRAP_VERSION) {
                [AppDelegate showMesage:NSLocalizedString(@"You've installed an old beta version, please disable all app tweaks and reboot the device to uninstall it so that you can install the latest version.", nil) title:NSLocalizedString(@"Error", nil)];
                return;
            }
        }
    }
    
    [self.bootstraBtn setEnabled:NO];
    [self.uninstallBtn setEnabled:NO];

    [AppDelegate showHudMsg:NSLocalizedString(@"Bootstrapping", nil)];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        const char* argv[] = {NSBundle.mainBundle.executablePath.fileSystemRepresentation, "bootstrap", NULL};
        int status = spawn(argv[0], argv, environ, ^(char* outstr){
            [AppDelegate addLogText:@(outstr)];
        }, ^(char* errstr){
            [AppDelegate addLogText:[NSString stringWithFormat:@"ERR: %s\n",errstr]];
        });
        
        [AppDelegate dismissHud];
        
        if(status != 0)
        {
            [AppDelegate showMesage:@"" title:[NSString stringWithFormat:@"code (%d)",status]];
            return;
        }
        
        NSString* log=nil;
        NSString* err=nil;
            
        if([NSUserDefaults.appDefaults boolForKey:@"openssh"] && [NSFileManager.defaultManager fileExistsAtPath:jbroot(@"/usr/libexec/sshd-keygen-wrapper")])
        {
            NSString* log=nil;
            NSString* err=nil;
            status = spawnRoot(jbroot(@"/basebin/bootstrapd"), @[@"openssh",@"start"], &log, &err);
            if(status==0)
                [AppDelegate addLogText:NSLocalizedString(@"openssh launch successful", nil)];
            else
                [AppDelegate addLogText:[NSString stringWithFormat:@"openssh launch faild(%d):\n%@\n%@", status, log, err]];
        }
        
        [AppDelegate addLogText:NSLocalizedString(@"respring now...", nil)]; sleep(1);
        
         status = spawnBootstrap((char*[]){"/usr/bin/sbreload", NULL}, &log, &err);
        if(status!=0) [AppDelegate showMesage:[NSString stringWithFormat:@"%@\n\nstderr:\n%@",log,err] title:[NSString stringWithFormat:@"code (%d)",status]];

    });
}

- (IBAction)unbootstrap:(id)sender {

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warnning", nil) message:NSLocalizedString(@"Are you sure to uninstall bootstrap?\n\nPlease make sure you have disabled tweaks for all apps before uninstalling.", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleDefault handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Uninstall", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){

        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [AppDelegate showHudMsg:NSLocalizedString(@"Uninstalling", nil)];

            NSString* log=nil;
            NSString* err=nil;
            int status = spawnRoot(NSBundle.mainBundle.executablePath, @[@"unbootstrap"], &log, &err);
            
            [AppDelegate dismissHud];
            
            NSString* msg = (status==0) ? @"bootstrap uninstalled" : [NSString stringWithFormat:@"code(%d)\n%@\n\nstderr:\n%@",status,log,err];
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:Localized(@"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                exit(0);
            }]];
            
            [AppDelegate showAlert:alert];
            
        });
        
    }]];
    [AppDelegate showAlert:alert];
    
}


@end
