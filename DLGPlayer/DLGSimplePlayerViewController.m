//
//  DLGSimplePlayerViewController.m
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 07/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

#import "DLGSimplePlayerViewController.h"
#import "DLGPlayerUtils.h"

typedef enum : NSUInteger {
    DLGPlayerOperationNone,
    DLGPlayerOperationOpen,
    DLGPlayerOperationPlay,
    DLGPlayerOperationPause,
    DLGPlayerOperationClose,
} DLGPlayerOperation;

@interface DLGSimplePlayerViewController () {
    BOOL restorePlay;
}
    
@property (nonatomic, readwrite) DLGPlayer *player;
@property (nonatomic, readwrite) DLGPlayerStatus status;
@property (nonatomic) DLGPlayerOperation nextOperation;
@end

@implementation DLGSimplePlayerViewController

#pragma mark - Constructors
- (instancetype)init {
    self = [super init];
    if (self) {
        [self initAll];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initAll];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self initAll];
    }
    return self;
}

#pragma mark - View controller life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addPlayerView];
}
    
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self registerNotification];
}
    
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self unregisterNotification];
}

#pragma mark - getter/setter
- (BOOL)hasUrl {
    return _url != nil && [_url stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length > 0;
}

- (BOOL)isPlaying {
    return _player.playing;
}
    
- (void)setStatus:(DLGPlayerStatus)status {
    _status = status;
    
    if ([_delegate respondsToSelector:@selector(viewController:didChangeStatus:)]) {
        [_delegate viewController:self didChangeStatus:status];
    }
}

- (BOOL)isMute {
    return _player.audio.mute;
}

- (void)setIsMute:(BOOL)isMute {
    _player.audio.mute = isMute;
}

- (double)minBufferDuration {
    return _player.minBufferDuration;
}

- (void)setMinBufferDuration:(double)minBufferDuration {
    _player.minBufferDuration = minBufferDuration;
}

- (double)maxBufferDuration {
    return _player.maxBufferDuration;
}

- (void)setMaxBufferDuration:(double)maxBufferDuration {
    _player.maxBufferDuration = maxBufferDuration;
}
    
#pragma mark - Init
- (void)initAll {
    _player = [[DLGPlayer alloc] init];
    _status = DLGPlayerStatusNone;
    self.nextOperation = DLGPlayerOperationNone;
}
    
- (void)open {
    if (_status == DLGPlayerStatusClosing) {
        self.nextOperation = DLGPlayerOperationOpen;
        return;
    }
    if (_status != DLGPlayerStatusNone &&
        _status != DLGPlayerStatusClosed) {
        return;
    }
    self.status = DLGPlayerStatusOpening;
    [_player open:_url];
}
    
- (void)close {
    if (_status == DLGPlayerStatusOpening) {
        self.nextOperation = DLGPlayerOperationClose;
        return;
    }
    self.status = DLGPlayerStatusClosing;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_player close];
}
    
- (void)play {
    if (_status == DLGPlayerStatusNone ||
        _status == DLGPlayerStatusClosed) {
        [self open];
        self.nextOperation = DLGPlayerOperationPlay;
    }
    if (_status != DLGPlayerStatusOpened &&
        _status != DLGPlayerStatusPaused &&
        _status != DLGPlayerStatusEOF) {
        return;
    }
    [UIApplication sharedApplication].idleTimerDisabled = _preventFromScreenLock;
    [_player play];
    self.status = DLGPlayerStatusPlaying;
}
    
- (void)replay {
    _player.position = 0;
    [self play];
}
    
- (void)pause {
    if (_status != DLGPlayerStatusOpened &&
        _status != DLGPlayerStatusPlaying &&
        _status != DLGPlayerStatusEOF) {
        return;
    }
    self.status = DLGPlayerStatusPaused;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_player pause];
}

- (void)reset {
    _status = DLGPlayerStatusNone;
    self.nextOperation = DLGPlayerOperationNone;
}
    
- (BOOL)doNextOperation {
    if (self.nextOperation == DLGPlayerOperationNone) return NO;
    switch (self.nextOperation) {
        case DLGPlayerOperationOpen:
        [self open];
        break;
        case DLGPlayerOperationPlay:
        [self play];
        break;
        case DLGPlayerOperationPause:
        [self pause];
        break;
        case DLGPlayerOperationClose:
        [self close];
        break;
        default:
        break;
    }
    self.nextOperation = DLGPlayerOperationNone;
    return YES;
}
    
    
#pragma mark - UI
- (void)addPlayerView {
    _player.playerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:_player.playerView];
    
    // Add constraints
    NSDictionary *views = NSDictionaryOfVariableBindings(_player.playerView);
    NSArray<NSLayoutConstraint *> *ch = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[v]|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:views];
    [self.view addConstraints:ch];
    NSArray<NSLayoutConstraint *> *cv = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[v]|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:views];
    [self.view addConstraints:cv];
}
    
#pragma mark - Notifications
- (void)registerNotification {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(notifyAppDidEnterBackground:)
               name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(notifyAppWillEnterForeground:)
               name:UIApplicationWillEnterForegroundNotification object:nil];
    [nc addObserver:self selector:@selector(notifyPlayerOpened:) name:DLGPlayerNotificationOpened object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerClosed:) name:DLGPlayerNotificationClosed object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerEOF:) name:DLGPlayerNotificationEOF object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerBufferStateChanged:) name:DLGPlayerNotificationBufferStateChanged object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerError:) name:DLGPlayerNotificationError object:_player];
}

- (void)unregisterNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)notifyAppDidEnterBackground:(NSNotification *)notif {
    if (_player.playing) {
        [self pause];
        if (_restorePlayAfterAppEnterForeground) restorePlay = YES;
    }
}
    
- (void)notifyAppWillEnterForeground:(NSNotification *)notif {
    if (restorePlay) {
        restorePlay = NO;
        [self play];
    }
}
    
- (void)notifyPlayerEOF:(NSNotification *)notif {
    self.status = DLGPlayerStatusEOF;
    if (_isRepeat) [self replay];
    else [self close];
}
    
- (void)notifyPlayerClosed:(NSNotification *)notif {
    self.status = DLGPlayerStatusClosed;
    
    [self doNextOperation];
}
    
- (void)notifyPlayerOpened:(NSNotification *)notif {
    self.status = DLGPlayerStatusOpened;
    
    if (![self doNextOperation]) {
        if (_isAutoplay) [self play];
    }
}
    
- (void)notifyPlayerBufferStateChanged:(NSNotification *)notif {
    NSDictionary *userInfo = notif.userInfo;
    BOOL state = [userInfo[DLGPlayerNotificationBufferStateKey] boolValue];
    if (state) {
        self.status = DLGPlayerStatusBuffering;
    } else {
        self.status = DLGPlayerStatusPlaying;
    }
}
    
- (void)notifyPlayerError:(NSNotification *)notif {
    NSDictionary *userInfo = notif.userInfo;
    NSError *error = userInfo[DLGPlayerNotificationErrorKey];
    
    if ([error.domain isEqualToString:DLGPlayerErrorDomainDecoder]) {
        __weak typeof(self)weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            strongSelf.status = DLGPlayerStatusNone;
            strongSelf.nextOperation = DLGPlayerOperationNone;
        });
        
        NSLog(@"Player decoder error: %@", error);
    } else if ([error.domain isEqualToString:DLGPlayerErrorDomainAudioManager]) {
        NSLog(@"Player audio error: %@", error);
    }
    
    if ([_delegate respondsToSelector:@selector(viewController:didReceiveError:)]) {
        [_delegate viewController:self didReceiveError:error];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationError object:self userInfo:notif.userInfo];
}
    
@end
