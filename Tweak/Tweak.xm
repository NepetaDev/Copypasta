#import <Cephei/HBPreferences.h>
#import <AudioToolbox/AudioToolbox.h>
#import "Tweak.h"
#import "CPAObserver.h"
#import "CPAView.h"
#import "CPAManager.h"

#define PLIST_PATH @"/var/lib/dpkg/info/me.nepeta.copypasta.list"

HBPreferences *preferences;
CPAView *cpaView = nil;
CPAObserver *cpaObserver = nil;

bool dpkgInvalid = false;
bool enabled;
bool showIcons;
bool showNames;
bool dismissAfterPaste;
bool darkMode;
bool useBlur;
bool openAutomatically;
bool alwaysShowChevron;
bool useDictation;
bool placeUnder;
bool hapticFeedback;
bool dontPushKeyboardUp;
CGFloat height;
NSInteger numberOfItems;
NSInteger style;

%group Copypasta

%hook CALayer

- (id)actionForKey:(NSString *)key {
    if ([self.delegate respondsToSelector:@selector(isDescendantOfView:)] && [(UIView *)self.delegate isDescendantOfView:cpaView] && !cpaView.wantsAnimations) return nil;
    return %orig;
}

%end

%hook UIInputSetHostView

%property (nonatomic, assign) CGRect cpaFrame;
%property (nonatomic, assign) BOOL cpaHasFrame;

-(void)setFrame:(CGRect)frame {
    if (frame.origin.y > 0) {
        self.cpaHasFrame = TRUE;
        self.cpaFrame = frame;
    }

    if (enabled && alwaysShowChevron && !dontPushKeyboardUp) {
        if (placeUnder) {
            %orig(CGRectMake(frame.origin.x, frame.origin.y - 30, frame.size.width, frame.size.height + 30));
        } else {
            %orig(CGRectMake(frame.origin.x, frame.origin.y - 60, frame.size.width, frame.size.height + 60));
        }
    } else {
        %orig;
    }
}

-(void)layoutSubviews {
    %orig;
    if (!enabled || !alwaysShowChevron) return;
    
    if (placeUnder) {
        for (UIView *view in [self subviews]) {
            view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
        }
    } else {
        for (UIView *view in [self subviews]) {
            if ([view isKindOfClass:%c(CKMessageEntryView)]) {
                cpaView.baseFrame = CGRectMake(0, self.superview.bounds.size.height - self.frame.size.height + 110, self.superview.bounds.size.width, 0);
                continue;
            }
            if ([view isKindOfClass:%c(UIKBKeyView)]) continue;
            if ([view isKindOfClass:%c(CPAView)]) continue;
            view.frame = CGRectMake(view.frame.origin.x, view.frame.origin.y + 30, view.frame.size.width, view.frame.size.height);
        }
    }
}

%end

%hook UIInputWindowController

-(void)viewDidLoad {
    %orig;
    if (!enabled) {
        [cpaView hide:YES animated:NO];
        return;
    }

    if (!cpaView) {
        CGRect bounds = [[UIScreen mainScreen] bounds];
        cpaView = [[CPAView alloc] initWithFrame:CGRectMake(0, bounds.size.height, bounds.size.width, 0)];
        
        if (style == 1) cpaView.darkMode = false;
        else if (style == 2) cpaView.darkMode = true;
        cpaView.dismissAfterPaste = dismissAfterPaste;
        cpaView.showNames = showNames;
        cpaView.showIcons = showIcons;
        cpaView.useBlur = useBlur;
        cpaView.dismissesFully = !alwaysShowChevron;
        cpaView.tableHeight = height;
        cpaView.playsHapticFeedback = hapticFeedback;
        
        [cpaView recreateBlur];
        [cpaView refresh];
    }
    
    [cpaView hide:YES animated:NO];
    
    [self.view addSubview:cpaView];
    [self cpaRepositionEverything];
}

-(void)viewWillAppear {
    %orig;
    if (!enabled) {
        [cpaView hide:YES animated:NO];
        return;
    }

    [self cpaRepositionEverything];
}

-(void)_updatePlacementWithPlacement:(UIInputViewSetPlacement *)arg1 {
    %orig;
    if (enabled && [arg1 showsKeyboard]) {
        if (style == 0) {
            cpaView.darkMode = ![self.hostView _lightStyleRenderConfig];
            [cpaView recreateBlur];
        }

        [self cpaRepositionEverything];
        [self.hostView setNeedsLayout];
        [self.hostView layoutIfNeeded];

        if (alwaysShowChevron || openAutomatically) [cpaView show:openAutomatically animated:NO];
    } else {
        [cpaView hide:YES animated:NO];
    }
}

-(void)viewWillLayoutSubviews {
    %orig;
    [self cpaRepositionEverything];
}

-(void)viewDidLayoutSubviews {
    %orig;
    [self cpaRepositionEverything];
}

%new
-(void)cpaRepositionEverything {
    if (!enabled) return;
    if (placeUnder) {
        cpaView.baseFrame = CGRectMake(0, self.view.bounds.size.height, self.view.bounds.size.width, 0);
        if (alwaysShowChevron) {
            cpaView.tableHeight = self.hostView.frame.size.height;
            if (!self.hostView.cpaHasFrame) self.hostView.frame = self.hostView.frame;
            else self.hostView.frame = self.hostView.cpaFrame;
        }
    } else {
        if (alwaysShowChevron) cpaView.baseFrame = CGRectMake(0, self.view.bounds.size.height - self.hostView.frame.size.height + 60, self.view.bounds.size.width, 0);
        else cpaView.baseFrame = CGRectMake(0, self.view.bounds.size.height - self.hostView.frame.size.height, self.view.bounds.size.width, 0);
    }
}

%end

%hook UIKeyboardImpl

-(BOOL)shouldShowDictationKey {
    if (enabled && useDictation) return YES;
    return %orig;
}

%end

%hook UIKeyboardLayoutStar

-(UIKBTree*)keyHitTest:(CGPoint)arg1 {
    if (!enabled || !useDictation) return %orig;

    UIKBTree* orig = %orig;
    if (orig && [orig.name isEqualToString:@"Dictation-Key"]) {
        orig.properties[@"KBinteractionType"] = @(0);
        
        if (hapticFeedback) AudioServicesPlaySystemSound(1519);
        if (cpaView.isOpenFully) [cpaView hide:!alwaysShowChevron animated:YES];
        else [cpaView show:YES animated:YES];

        return orig;
    }

    return orig;
}

%end

%hook UISystemKeyboardDockController

-(void)dictationItemButtonWasPressed:(id)a withEvent:(id)b {
    if (!enabled || !useDictation) {
        %orig;
        return;
    }

    if (hapticFeedback && !cpaView.isOpenFully) AudioServicesPlaySystemSound(1519);
    [cpaView show:YES animated:YES];
    //else [cpaView hide];
}

%end

%end

%group CopypastaFail

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)arg1 {
    %orig;
    if (!dpkgInvalid) return;
    UIAlertController *alertController = [UIAlertController
        alertControllerWithTitle:@"😡😡😡"
        message:@"The build of Copypasta you're using comes from an untrusted source. Pirate repositories can distribute malware and you will get subpar user experience using any tweaks from them.\nRemember: Copypasta is free. Uninstall this build and install the proper version of Copypasta from:\nhttps://repo.nepeta.me/\n(it's free, damnit, why would you pirate that!?)"
        preferredStyle:UIAlertControllerStyleAlert
    ];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Damn!" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [((UIApplication*)self).keyWindow.rootViewController dismissViewControllerAnimated:YES completion:NULL];
    }]];

    [((UIApplication*)self).keyWindow.rootViewController presentViewController:alertController animated:YES completion:NULL];
}

%end

%end

void reloadItems() {
    [[CPAManager sharedInstance] reload];
    if (cpaView) {
        [cpaView refresh];
        [cpaView.tableView setContentOffset:CGPointZero animated:YES];
    }
}

%ctor {
    dpkgInvalid = ![[NSFileManager defaultManager] fileExistsAtPath:PLIST_PATH];
    // Someone smarter than me invented this.
    // https://www.reddit.com/r/jailbreak/comments/4yz5v5/questionremote_messages_not_enabling/d6rlh88/
    bool shouldLoad = NO;

    NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
    NSUInteger count = args.count;
    if (count != 0) {
        NSString *executablePath = args[0];
        if (executablePath) {
            NSString *processName = [executablePath lastPathComponent];
            BOOL isApplication = [executablePath rangeOfString:@"/Application/"].location != NSNotFound || [executablePath rangeOfString:@"/Applications/"].location != NSNotFound;
            BOOL isFileProvider = [[processName lowercaseString] rangeOfString:@"fileprovider"].location != NSNotFound;
            BOOL skip = [processName isEqualToString:@"AdSheet"]
                        || [processName isEqualToString:@"CoreAuthUI"]
                        || [processName isEqualToString:@"InCallService"]
                        || [processName isEqualToString:@"MessagesNotificationViewService"]
                        || [executablePath rangeOfString:@".appex/"].location != NSNotFound
                        || ![[NSFileManager defaultManager] fileExistsAtPath:PLIST_PATH];
            if (!isFileProvider && isApplication && !skip && [[NSFileManager defaultManager] fileExistsAtPath:PLIST_PATH]) {
                shouldLoad = !dpkgInvalid;
            }
        }
    }

    if (dpkgInvalid) {
        %init(CopypastaFail);
        return;
    }
    if (!shouldLoad) return;

    cpaObserver = [[CPAObserver alloc] init];

    preferences = [[HBPreferences alloc] initWithIdentifier:@"me.nepeta.copypasta"];

    [preferences registerBool:&enabled default:YES forKey:@"Enabled"];
    [preferences registerBool:&darkMode default:NO forKey:@"DarkMode"];
    [preferences registerBool:&showIcons default:YES forKey:@"ShowIcons"];
    [preferences registerBool:&showNames default:YES forKey:@"ShowNames"];
    [preferences registerBool:&dismissAfterPaste default:YES forKey:@"DismissAfterPaste"];
    [preferences registerBool:&useBlur default:YES forKey:@"UseBlur"];
    [preferences registerFloat:&height default:150 forKey:@"Height"];
    [preferences registerInteger:&numberOfItems default:10 forKey:@"NumberOfItems"];
    [preferences registerBool:&openAutomatically default:NO forKey:@"OpenAutomatically"];
    [preferences registerBool:&useDictation default:NO forKey:@"UseDictation"];
    [preferences registerBool:&hapticFeedback default:YES forKey:@"HapticFeedback"];
    [preferences registerInteger:&style default:0 forKey:@"Style"];
    placeUnder = YES;
    alwaysShowChevron = YES;
    [preferences registerBool:&dontPushKeyboardUp default:NO forKey:@"DontPushKeyboardUp"];

    [preferences registerPreferenceChangeBlock:^() {
        [[CPAManager sharedInstance] setNumberOfItems:numberOfItems];
        placeUnder = !useDictation;
        alwaysShowChevron = !useDictation;
        if (!cpaView) return;

        if (style == 1) cpaView.darkMode = false;
        else if (style == 2) cpaView.darkMode = true;
        cpaView.dismissAfterPaste = dismissAfterPaste;
        cpaView.showNames = showNames;
        cpaView.showIcons = showIcons;
        if (!placeUnder) cpaView.tableHeight = height;
        cpaView.useBlur = useBlur;
        cpaView.dismissesFully = !alwaysShowChevron;
        cpaView.playsHapticFeedback = hapticFeedback;

        [cpaView recreateBlur];
        [cpaView refresh];
    }];

    %init(Copypasta);

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadItems, (CFStringRef)@"me.nepeta.copypasta/ReloadItems", NULL, (CFNotificationSuspensionBehavior)kNilOptions);
}
