//
//  KeyboardTrackingViewManager.m
//  ReactNativeChat
//
//  Created by Artal Druk on 19/04/2016.
//  Copyright © 2016 Wix.com All rights reserved.
//

#import "KeyboardTrackingViewManager.h"
#import "ObservingInputAccessoryView.h"
#import "UIResponder+FirstResponder.h"

#import <React/RCTScrollView.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/UIView+React.h>
#import <React/RCTUIManagerUtils.h>

#import <objc/runtime.h>

#define DMZ_HEIGHT 54

NSUInteger const kInputViewKey = 101010;
NSUInteger const kMaxDeferedInitializeAccessoryViews = 15;
NSInteger  const kTrackingViewNotFoundErrorCode = 1;
NSInteger  const kBottomViewHeight = 100;
UIView *lastKnownInputView=nil;
BOOL requireScrollToStart=NO;


typedef NS_ENUM(NSUInteger, KeyboardTrackingScrollBehavior) {
    KeyboardTrackingScrollBehaviorNone,
    KeyboardTrackingScrollBehaviorScrollToBottomInvertedOnly,
    KeyboardTrackingScrollBehaviorFixedOffset
};

@interface KeyboardTrackingView : UIView
{
    Class _newClass;
    //    NSMapTable *_inputViewsMap;
    NSPointerArray *_inputViewsMap;
    ObservingInputAccessoryView *_observingInputAccessoryView;
    UIView *_bottomView;
    CGFloat _bottomViewHeight;
}

- (instancetype)initWithBridge:(RCTBridge*)bridge;
@property (nonatomic, strong) NSNumber *scrollViewRef;
@property (nonatomic, strong) UIScrollView *scrollViewToManage;
@property (nonatomic) CGFloat revealKeyboardThrottle;
@property (nonatomic) BOOL scrollIsInverted;
@property (nonatomic) BOOL revealKeyboardInteractive;
@property (nonatomic) BOOL hasBottomTab;
@property (nonatomic) BOOL isDraggingScrollView;
@property (nonatomic) BOOL manageScrollView;
@property (nonatomic) BOOL requiresSameParentToManageScrollView;
@property (nonatomic) NSUInteger deferedInitializeAccessoryViewsCount;
@property (nonatomic) CGFloat originalHeight;
@property (nonatomic) KeyboardTrackingScrollBehavior scrollBehavior;
@property (nonatomic) BOOL addBottomView;
@property (nonatomic) BOOL scrollToFocusedInput;
@property (nonatomic) BOOL allowHitsOutsideBounds;
@property (nonatomic, copy,nullable) RCTBubblingEventBlock onDismissAccessoryKeyboard;

@end

@interface KeyboardTrackingView () <ObservingInputAccessoryViewDelegate, UIScrollViewDelegate>

@end

@implementation KeyboardTrackingView
{
    RCTBridge *_bridge;
    CGFloat _lastContentOffsetY;
    CGFloat _lastGapInset;
    NSMutableDictionary *offsetMap;
    BOOL _shouldOpenKeyboard;
    BOOL _keyboardIsOpening;
    long long _callHideAccessoryTime;
    CGFloat _bottomTabBarHeight;
}

- (instancetype)initWithBridge:(RCTBridge*)bridge
{
    self = [super init];
    _bridge=bridge;
    _callHideAccessoryTime=0;
    _bottomTabBarHeight=0;
    if (self)
    {
        [self addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:NULL];
        //        _inputViewsMap = [NSMapTable weakToWeakObjectsMapTable];
        _inputViewsMap=[NSPointerArray weakObjectsPointerArray];
        _deferedInitializeAccessoryViewsCount = 0;

        _observingInputAccessoryView = [ObservingInputAccessoryView new];
        _observingInputAccessoryView.delegate = self;

        _manageScrollView = YES;
        _allowHitsOutsideBounds = NO;
        offsetMap=[[NSMutableDictionary alloc] init];
        _lastContentOffsetY=0;
        _lastGapInset=0;
        _shouldOpenKeyboard=NO;
        _keyboardIsOpening=NO;
        _bottomViewHeight = kBottomViewHeight;

        self.addBottomView = NO;
        self.scrollToFocusedInput = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rctContentDidAppearNotification:) name:RCTContentDidAppearNotification object:nil];
        //    [[NSNotificationCenter defaultCenter] addObserver:self
        //                                             selector:@selector(keyboardDidHide:)
        //                                                 name:UIKeyboardDidHideNotification
        //                                               object:nil];
        UIWindow *_keyWindow=[UIApplication sharedApplication].keyWindow;
        if(_keyWindow!=nil)
        {
            UIViewController *_tempRootViewController= _keyWindow.rootViewController;
            if(_tempRootViewController!=nil)
            {
                if(_tempRootViewController.presentedViewController!=nil)
                {
                    _tempRootViewController=_tempRootViewController.presentedViewController;
                }
            }
            if([_tempRootViewController isKindOfClass:[UITabBarController class] ])
            {
                UITabBarController *_tabBarController=(UITabBarController*)_tempRootViewController;
                UITabBar *_tempTabBar=_tabBarController.tabBar;
                if(_tempTabBar!=nil)
                {
                    _bottomTabBarHeight=_tempTabBar.frame.size.height;
                }
            }
        }
    }

    return self;
}

-(RCTRootView*)getRootView
{
    UIView *view = self;
    while (view.superview != nil)
    {
        view = view.superview;
        if ([view isKindOfClass:[RCTRootView class]])
            break;
    }

    if ([view isKindOfClass:[RCTRootView class]])
    {
        return (RCTRootView*)view;
    }
    return nil;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!_allowHitsOutsideBounds) {
        return [super hitTest:point withEvent:event];
    }

    if (self.isHidden || self.alpha == 0 || self.clipsToBounds) {
        return nil;
    }

    UIView *subview = [super hitTest:point withEvent:event];
    if (subview == nil) {
        NSArray<UIView*>* allSubviews = [self getBreadthFirstSubviewsForView:self];
        for (UIView *tmpSubview in allSubviews) {
            CGPoint pointInSubview = [self convertPoint:point toView:tmpSubview];
            if ([tmpSubview pointInside:pointInSubview withEvent:event]) {
                subview = tmpSubview;
                break;
            }
        }
    }

    return subview;
}

- (void)setScrollViewRef:(NSNumber *)scrollViewRef
{
    if(_scrollViewRef!=scrollViewRef)
    {
        _scrollViewRef=scrollViewRef;
        _scrollViewToManage=nil;
        if(_scrollViewRef!=nil)
        {
            [self initializeAccessoryViewsAndHandleInsets];
        }
        //    if(_scrollViewToManage!=nil)
        //    {
        //      CGFloat _currentOffsetY=_scrollViewToManage.contentOffset.y;
        //      CGFloat bottomSafeArea = [self getBottomSafeArea];
        //      CGFloat bottomInset = MAX(self.bounds.size.height, _observingInputAccessoryView.keyboardHeight + _observingInputAccessoryView.height);
        //
        //      CGPoint originalOffset = self.scrollViewToManage.contentOffset;
        //    }
    }
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    [self updateBottomViewFrame];
}

- (void)initializeAccessoryViewsAndHandleInsets
{
    lastKnownInputView=nil;
    NSArray<UIView*>* allSubviews = [self getBreadthFirstSubviewsForView:[self getRootView]];
    NSMutableArray<RCTScrollView*>* rctScrollViewsArray = [NSMutableArray array];
    if(_scrollViewRef&&_manageScrollView&&(_scrollViewToManage == nil))
    {
        UIView *checkingView = [_bridge.uiManager viewForReactTag:_scrollViewRef];
        if(checkingView)
        {
            if(![checkingView isKindOfClass:[RCTScrollView class]]&&![checkingView isKindOfClass:[UIScrollView class]])
            {
                NSArray<UIView*>* allSubviews = [self getBreadthFirstSubviewsForView:checkingView];
                for (UIView* subview in allSubviews)
                {
                    if([subview isKindOfClass:[RCTScrollView class]]||[subview isKindOfClass:[UIScrollView class]])
                    {
                        checkingView = subview;
                        break;
                    }
                }
            }
            if(_requiresSameParentToManageScrollView && [checkingView isKindOfClass:[RCTScrollView class]])
            {
                _scrollViewToManage = ((RCTScrollView*)checkingView).scrollView;
            }
            else if(!_requiresSameParentToManageScrollView && [checkingView isKindOfClass:[UIScrollView class]])
            {
                _scrollViewToManage = (UIScrollView*)checkingView;
            }
        }
    }
    for (UIView* subview in allSubviews)
    {
        if(_manageScrollView)
        {
            if(_scrollViewToManage == nil)
            {
                if(_requiresSameParentToManageScrollView && [subview isKindOfClass:[RCTScrollView class]] && subview.superview == self.superview)
                {
                    _scrollViewToManage = ((RCTScrollView*)subview).scrollView;
                }
                else if(!_requiresSameParentToManageScrollView && [subview isKindOfClass:[UIScrollView class]])
                {
                    _scrollViewToManage = (UIScrollView*)subview;
                }
                //        if(_scrollViewToManage != nil)
                //        {
                //          _scrollIsInverted = CGAffineTransformEqualToTransform(_scrollViewToManage.superview.transform, CGAffineTransformMakeScale(1, -1));
                //        }
            }

            if([subview isKindOfClass:[RCTScrollView class]])
            {
                [rctScrollViewsArray addObject:(RCTScrollView*)subview];
            }
        }

        if ([subview isKindOfClass:NSClassFromString(@"RCTTextField")])
        {
            UITextField *textField = nil;
            Ivar backedTextInputIvar = class_getInstanceVariable([subview class], "_backedTextInput");
            if (backedTextInputIvar != NULL)
            {
                textField = [subview valueForKey:@"_backedTextInput"];
            }
            else if([subview isKindOfClass:[UITextField class]])
            {
                textField = (UITextField*)subview;
            }
            [self setupTextField:textField];
        }
        else if ([subview isKindOfClass:NSClassFromString(@"RCTUITextField")] && [subview isKindOfClass:[UITextField class]])
        {
            [self setupTextField:(UITextField*)subview];
        }
        else if ([subview isKindOfClass:NSClassFromString(@"RCTMultilineTextInputView")])
        {
            [self setupTextView:[subview valueForKey:@"_backedTextInputView"]];
        }
        else if ([subview isKindOfClass:NSClassFromString(@"RNTRichEditText")])
        {
            [self setupTextView:(UITextView*)subview];
        }
        else if ([subview isKindOfClass:NSClassFromString(@"RCTTextView")])
        {
            UITextView *textView = nil;
            Ivar backedTextInputIvar = class_getInstanceVariable([subview class], "_backedTextInput");
            if (backedTextInputIvar != NULL)
            {
                textView = [subview valueForKey:@"_backedTextInput"];
            }
            else if([subview isKindOfClass:[UITextView class]])
            {
                textView = (UITextView*)subview;
            }
            [self setupTextView:textView];
        }
        else if ([subview isKindOfClass:NSClassFromString(@"RCTUITextView")] && [subview isKindOfClass:[UITextView class]])
        {
            [self setupTextView:(UITextView*)subview];
        }
    }
    for (RCTScrollView *scrollView in rctScrollViewsArray)
    {
        if(scrollView.scrollView == _scrollViewToManage)
        {
            [scrollView removeScrollListener:self];
            [scrollView addScrollListener:self];
            break;
        }
    }

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11.0, *)) {
        if (_scrollViewToManage != nil) {
            _scrollViewToManage.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
    }
#endif
    _lastContentOffsetY=0;
    _lastGapInset=0;
    if(_scrollViewRef!=nil)
    {
        NSNumber *_tempValue=[offsetMap objectForKey:[NSString stringWithFormat:@"%li",[_scrollViewRef integerValue]]];
        if(_tempValue!=nil)
        {
            _lastGapInset=[_tempValue floatValue];
        }
    }
    [self _updateScrollViewInsets];

    _originalHeight = _observingInputAccessoryView.height;

    [self addBottomViewIfNecessary];
}

- (void)setupTextView:(UITextView*)textView
{
    if (textView != nil)
    {
        [textView setInputAccessoryView:_observingInputAccessoryView];
        [textView reloadInputViews];
        [_inputViewsMap addPointer:(__bridge void *)textView];
        //        [_inputViewsMap setObject:textView forKey:@(kInputViewKey)];
    }
}

- (void)setupTextField:(UITextField*)textField
{
    if (textField != nil)
    {
        [textField setInputAccessoryView:_observingInputAccessoryView];
        [textField reloadInputViews];
        [_inputViewsMap addPointer:(__bridge void *)textField];
        //        [_inputViewsMap setObject:textField forKey:@(kInputViewKey)];
    }
}

-(void) deferedInitializeAccessoryViewsAndHandleInsets
{
    if(self.window == nil)
    {
        return;
    }

    if (_observingInputAccessoryView.height == 0 && self.deferedInitializeAccessoryViewsCount < kMaxDeferedInitializeAccessoryViews)
    {
        self.deferedInitializeAccessoryViewsCount++;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self deferedInitializeAccessoryViewsAndHandleInsets];
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initializeAccessoryViewsAndHandleInsets];
        });
    }
}

- (void)willMoveToWindow:(nullable UIWindow *)newWindow
{
    if (newWindow == nil && [ObservingInputAccessoryViewManager sharedInstance].activeObservingInputAccessoryView == _observingInputAccessoryView)
    {
        [ObservingInputAccessoryViewManager sharedInstance].activeObservingInputAccessoryView = nil;
    }
    else if (newWindow != nil)
    {
        [ObservingInputAccessoryViewManager sharedInstance].activeObservingInputAccessoryView = _observingInputAccessoryView;
    }
}

-(void)didMoveToWindow
{
    [super didMoveToWindow];

    self.deferedInitializeAccessoryViewsCount = 0;

    [self deferedInitializeAccessoryViewsAndHandleInsets];
}

-(void)dealloc
{
    [self removeObserver:self forKeyPath:@"bounds"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RCTContentDidAppearNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidHideNotification object:nil];
    [offsetMap removeAllObjects];
    offsetMap=nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    _observingInputAccessoryView.height = self.bounds.size.height;
}

- (void)observingInputAccessoryViewKeyboardWillDisappear:(ObservingInputAccessoryView *)observingInputAccessoryView
{
    long long currentTimeMs=(long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    if((currentTimeMs-_callHideAccessoryTime)>=1000)
    {
        if(_onDismissAccessoryKeyboard!=nil)
        {
            _onDismissAccessoryKeyboard(nil);
        }
    }
    _callHideAccessoryTime=currentTimeMs;
    _bottomViewHeight = kBottomViewHeight;
    //Xử lý trường hợp vuốt nhanh để tắt bàn phím
    if(_scrollViewToManage.contentOffset.y<=0&&_scrollViewToManage.contentOffset.y>=-_scrollViewToManage.contentInset.top)
    {
        requireScrollToStart=YES;
    }
    [self updateBottomViewFrame];
}

//- (void)keyboardDidHide: (NSNotification *) notif{
//}

- (void)observingInputAccessoryViewKeyboardDidDisappear:(ObservingInputAccessoryView *)observingInputAccessoryView
{
    if(requireScrollToStart)
    {
        requireScrollToStart=NO;
        if (self.scrollViewToManage != nil)
        {
            [self.scrollViewToManage setContentOffset:CGPointMake(self.scrollViewToManage.contentOffset.x, -self.scrollViewToManage.contentInset.top) animated:NO];
        }
    }
}

- (NSArray*)getBreadthFirstSubviewsForView:(UIView*)view
{
    if(view == nil)
    {
        return nil;
    }

    NSMutableArray *allSubviews = [NSMutableArray new];
    NSMutableArray *queue = [NSMutableArray new];

    [allSubviews addObject:view];
    [queue addObject:view];

    while ([queue count] > 0) {
        UIView *current = [queue lastObject];
        [queue removeLastObject];

        for (UIView *n in current.subviews)
        {
            [allSubviews addObject:n];
            [queue insertObject:n atIndex:0];
        }
    }
    return allSubviews;
}

- (NSArray*)getAllReactSubviewsForView:(UIView*)view
{
    NSMutableArray *allSubviews = [NSMutableArray new];
    for (UIView *subview in view.reactSubviews)
    {
        [allSubviews addObject:subview];
        [allSubviews addObjectsFromArray:[self getAllReactSubviewsForView:subview]];
    }
    return allSubviews;
}

- (CGFloat) _getBottomTabHeight{
    if(self.hasBottomTab)
    {
        return _bottomTabBarHeight;
    }
    return 0;
}

- (void)_updateScrollViewInsets
{
    if(self.scrollViewToManage != nil)
    {
        CGFloat _currentScrollY=self.scrollViewToManage.contentOffset.y;
        UIEdgeInsets insets = self.scrollViewToManage.contentInset;
        CGFloat bottomSafeArea = [self getBottomSafeArea];
        CGFloat _bottomInset = MAX(self.bounds.size.height, _observingInputAccessoryView.keyboardHeight + _observingInputAccessoryView.height-[self _getBottomTabHeight]);
        CGFloat originalBottomInset = self.scrollIsInverted ? insets.top : insets.bottom;
        CGPoint originalOffset = self.scrollViewToManage.contentOffset;

        _bottomInset += (_observingInputAccessoryView.keyboardHeight == 0 ? bottomSafeArea : 0);
        if(self.scrollIsInverted)
        {
            insets.top = _bottomInset;
        }
        else
        {
            insets.bottom = _bottomInset;
        }
        CGFloat _insetDiff=_bottomInset-_lastGapInset;
        self.scrollViewToManage.contentInset = insets;

        if(self.scrollBehavior == KeyboardTrackingScrollBehaviorScrollToBottomInvertedOnly && _scrollIsInverted)
        {
            BOOL fisrtTime = _observingInputAccessoryView.keyboardHeight == 0 && _observingInputAccessoryView.keyboardState == KeyboardStateHidden;
            BOOL willOpen = _observingInputAccessoryView.keyboardHeight != 0 && _observingInputAccessoryView.keyboardState == KeyboardStateHidden;
            BOOL isOpen = _observingInputAccessoryView.keyboardHeight != 0 && _observingInputAccessoryView.keyboardState == KeyboardStateShown;
            if(fisrtTime || willOpen || (isOpen && !self.isDraggingScrollView))
            {
                if(_insetDiff==_bottomInset)
                {
                    [self.scrollViewToManage setContentOffset:CGPointMake(originalOffset.x,-_bottomInset) animated:NO];
                }
                else{
                    CGFloat _scrollY=_currentScrollY-_insetDiff;
                    if(_currentScrollY<=-(_lastGapInset-DMZ_HEIGHT))
                    {
                        _scrollY=-_bottomInset;
                    }
                    if(_scrollY<-_bottomInset)
                    {
                        _scrollY=-_bottomInset;
                    }
                    [self.scrollViewToManage setContentOffset:CGPointMake(originalOffset.x,_scrollY) animated:!fisrtTime];
                }
            }
        }
        else if(self.scrollBehavior == KeyboardTrackingScrollBehaviorFixedOffset && !self.isDraggingScrollView)
        {
            CGFloat insetsDiff = (_bottomInset - originalBottomInset) * (self.scrollIsInverted ? -1 : 1);
            self.scrollViewToManage.contentOffset = CGPointMake(originalOffset.x, originalOffset.y + insetsDiff);
        }
        _lastGapInset=_bottomInset;
        if(_scrollViewRef!=nil)
        {
            [offsetMap setObject:[NSNumber numberWithFloat:_lastGapInset] forKey:[NSString stringWithFormat:@"%li",[_scrollViewRef integerValue]]];
        }
    }
}

#pragma mark - bottom view

-(void)setAddBottomView:(BOOL)addBottomView
{
    _addBottomView = addBottomView;
    [self addBottomViewIfNecessary];
}

-(void)addBottomViewIfNecessary
{
    if (self.addBottomView && _bottomView == nil)
    {
        _bottomView = [UIView new];
        _bottomView.backgroundColor = [UIColor whiteColor];
        [self addSubview:_bottomView];
        [self updateBottomViewFrame];
    }
    else if (!self.addBottomView && _bottomView != nil)
    {
        [_bottomView removeFromSuperview];
        _bottomView = nil;
    }
}

-(void)updateBottomViewFrame
{
    if (_bottomView != nil)
    {
        _bottomView.frame = CGRectMake(0, self.frame.size.height, self.frame.size.width, _bottomViewHeight);
    }
}

#pragma mark - safe area

-(void)safeAreaInsetsDidChange
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11.0, *)) {
        [super safeAreaInsetsDidChange];
    }
#endif
    [self updateTransformAndInsets];
}

-(CGFloat)getBottomSafeArea
{
    CGFloat bottomSafeArea = 0;
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
    if (@available(iOS 11.0, *)) {
        bottomSafeArea = self.superview ? self.superview.safeAreaInsets.bottom : self.safeAreaInsets.bottom;
    }
#endif
    return bottomSafeArea;
}

#pragma RCTRootView notifications

- (void) rctContentDidAppearNotification:(NSNotification*)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(notification.object == [self getRootView] && _manageScrollView && _scrollViewToManage == nil)
        {
            [self initializeAccessoryViewsAndHandleInsets];
        }
    });
}

#pragma mark - ObservingInputAccessoryViewDelegate methods

-(void)updateTransformAndInsets
{
    CGFloat bottomSafeArea = [self getBottomSafeArea];
    CGFloat _currentAccessoryKeyboardHeight=_observingInputAccessoryView.keyboardHeight;
    CGFloat accessoryTranslation = MIN(-bottomSafeArea, -_currentAccessoryKeyboardHeight+[self _getBottomTabHeight]);
    if (_observingInputAccessoryView.keyboardHeight <= bottomSafeArea) {
        _bottomViewHeight = kBottomViewHeight;
    } else if (_observingInputAccessoryView.keyboardState != KeyboardStateWillHide) {
        _bottomViewHeight = 0;
    }
    [self updateBottomViewFrame];
    self.transform = CGAffineTransformMakeTranslation(0, accessoryTranslation);
    [self _updateScrollViewInsets];
}

- (void)performScrollToFocusedInput
{
    if (_scrollViewToManage != nil && self.scrollToFocusedInput)
    {
        UIResponder *currentFirstResponder = [UIResponder currentFirstResponder];
        if (currentFirstResponder != nil && [currentFirstResponder isKindOfClass:[UIView class]])
        {
            UIView *reponderView = (UIView*)currentFirstResponder;
            if ([reponderView isDescendantOfView:_scrollViewToManage])
            {
                CGRect frame = [_scrollViewToManage convertRect:reponderView.frame fromView:reponderView];
                frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height + 20);
                [_scrollViewToManage scrollRectToVisible:frame animated:NO];
            }
        }
    }
}

- (void)observingInputAccessoryViewDidChangeFrame:(ObservingInputAccessoryView*)observingInputAccessoryView
{
    [self updateTransformAndInsets];
}

- (void) observingInputAccessoryViewKeyboardWillAppear:(ObservingInputAccessoryView *)observingInputAccessoryView keyboardDelta:(CGFloat)delta
{
    _callHideAccessoryTime=0;
    if (observingInputAccessoryView.keyboardHeight > 0) //prevent hiding the bottom view if an external keyboard is in use
    {
        _bottomViewHeight = 0;
        [self updateBottomViewFrame];
    }

    [self performScrollToFocusedInput];
}

#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if(_observingInputAccessoryView.keyboardState != KeyboardStateHidden || !self.revealKeyboardInteractive)
    {
        return;
    }

    UIView *inputView=lastKnownInputView;
    if(inputView==nil)
    {
        for (UIView *subview in _inputViewsMap)
        {
            if(subview!=nil)
            {
                //        lastKnownInputView=subview;
                inputView=subview;
                break;
            }
        }
    }
    //    UIView *inputView = [_inputViewsMap objectForKey:@(kInputViewKey)];

    CGFloat contentOffsetY=scrollView.contentOffset.y * (self.scrollIsInverted ? -1 : 1);
    CGFloat revealKeyboardThrottle=self.revealKeyboardThrottle;
    if(revealKeyboardThrottle==0)
    {
        revealKeyboardThrottle=50;
    }
    CGFloat limitInset=(self.scrollIsInverted ? scrollView.contentInset.top : scrollView.contentInset.bottom) + revealKeyboardThrottle;
    BOOL scrollDown=YES;
    if(contentOffsetY<_lastContentOffsetY)
    {
        scrollDown=NO;
    }
    _lastContentOffsetY=contentOffsetY;
    if(scrollDown)
    {
        if(_shouldOpenKeyboard)
        {
            if(inputView != nil)
            {
                if(![inputView isFocused])
                {
                    _keyboardIsOpening=YES;
                    _shouldOpenKeyboard=NO;
                }
                else{
                    _shouldOpenKeyboard=NO;
                }
            }
        }
    }
    else{
        _shouldOpenKeyboard=NO;
        if (!_keyboardIsOpening&& contentOffsetY > limitInset)
        {
            if(inputView != nil&&![inputView isFocused])
            {
                for (UIGestureRecognizer *gesture in scrollView.gestureRecognizers)
                {
                    if([gesture isKindOfClass:[UIPanGestureRecognizer class]])
                    {
                        gesture.enabled = NO;
                        gesture.enabled = YES;
                    }
                }
                [inputView reactFocus];
                //              [inputView becomeFirstResponder];
            }
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    _keyboardIsOpening=NO;
    if(_lastContentOffsetY>=(10*(self.scrollIsInverted?-1:1)))
    {
        _shouldOpenKeyboard=YES;
    }
    else{
        _shouldOpenKeyboard=NO;
    }
    self.isDraggingScrollView = YES;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    self.isDraggingScrollView = NO;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    self.isDraggingScrollView = NO;
}

- (CGFloat)getKeyboardHeight
{
    return _observingInputAccessoryView ? _observingInputAccessoryView.keyboardHeight : 0;
}

-(CGFloat)getScrollViewTopContentInset
{
    return (self.scrollViewToManage != nil) ? -self.scrollViewToManage.contentInset.top : 0;
}

-(void)scrollToStart
{
    if (self.scrollViewToManage != nil)
    {
        [self.scrollViewToManage setContentOffset:CGPointMake(self.scrollViewToManage.contentOffset.x, -self.scrollViewToManage.contentInset.top) animated:YES];
    }
}

//-(void)setScrollIsInverted:(BOOL)scrollIsInverted
//{
//  _scrollIsInverted=scrollIsInverted;
//}

@end

@implementation RCTConvert (KeyboardTrackingScrollBehavior)
RCT_ENUM_CONVERTER(KeyboardTrackingScrollBehavior, (@{ @"KeyboardTrackingScrollBehaviorNone": @(KeyboardTrackingScrollBehaviorNone),
                                                       @"KeyboardTrackingScrollBehaviorScrollToBottomInvertedOnly": @(KeyboardTrackingScrollBehaviorScrollToBottomInvertedOnly),
                                                       @"KeyboardTrackingScrollBehaviorFixedOffset": @(KeyboardTrackingScrollBehaviorFixedOffset)}),
                   KeyboardTrackingScrollBehaviorNone, unsignedIntegerValue)
@end

@implementation KeyboardTrackingViewManager

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

RCT_REMAP_VIEW_PROPERTY(onDismissAccessoryKeyboard,onDismissAccessoryKeyboard, RCTBubblingEventBlock)
RCT_REMAP_VIEW_PROPERTY(scrollBehavior, scrollBehavior, KeyboardTrackingScrollBehavior)
RCT_REMAP_VIEW_PROPERTY(revealKeyboardThrottle, revealKeyboardThrottle, CGFloat)
RCT_REMAP_VIEW_PROPERTY(revealKeyboardInteractive, revealKeyboardInteractive, BOOL)
RCT_REMAP_VIEW_PROPERTY(hasBottomTab, hasBottomTab, BOOL)
RCT_REMAP_VIEW_PROPERTY(scrollIsInverted, scrollIsInverted, BOOL)
RCT_REMAP_VIEW_PROPERTY(manageScrollView, manageScrollView, BOOL)
RCT_REMAP_VIEW_PROPERTY(requiresSameParentToManageScrollView, requiresSameParentToManageScrollView, BOOL)
RCT_REMAP_VIEW_PROPERTY(addBottomView, addBottomView, BOOL)
RCT_REMAP_VIEW_PROPERTY(scrollToFocusedInput, scrollToFocusedInput, BOOL)
RCT_REMAP_VIEW_PROPERTY(allowHitsOutsideBounds, allowHitsOutsideBounds, BOOL)
RCT_REMAP_VIEW_PROPERTY(scrollViewRef, scrollViewRef, NSNumber)

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

//Hàm dùng để export constants ra JS
- (NSDictionary<NSString *, id> *)constantsToExport
{
    return @{
        @"KeyboardTrackingScrollBehaviorNone": @(KeyboardTrackingScrollBehaviorNone),
        @"KeyboardTrackingScrollBehaviorScrollToBottomInvertedOnly": @(KeyboardTrackingScrollBehaviorScrollToBottomInvertedOnly),
        @"KeyboardTrackingScrollBehaviorFixedOffset": @(KeyboardTrackingScrollBehaviorFixedOffset),
    };
}

- (UIView *)view
{
    UIView *trackingView=[[KeyboardTrackingView alloc] initWithBridge:_bridge];
    return trackingView;
}

RCT_EXPORT_METHOD(getNativeProps:(nonnull NSNumber *)reactTag resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.bridge.uiManager addUIBlock:
     ^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, KeyboardTrackingView *> *viewRegistry) {
        KeyboardTrackingView *view = viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[KeyboardTrackingView class]]) {
            NSString *errorMessage = [NSString stringWithFormat:@"Error: cannot find KeyboardTrackingView with tag #%@", reactTag];
            RCTLogError(@"%@", errorMessage);
            [self rejectPromise:reject withErrorMessage:errorMessage errorCode:kTrackingViewNotFoundErrorCode];
            return;
        }
        resolve(@{@"trackingViewHeight": @(view.bounds.size.height),
                  @"keyboardHeight": @([view getKeyboardHeight]),
                  @"contentTopInset": @([view getScrollViewTopContentInset])});
    }];
}

RCT_EXPORT_METHOD(scrollToStart:(nonnull NSNumber *)reactTag)
{
    [self.bridge.uiManager addUIBlock:
     ^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, KeyboardTrackingView *> *viewRegistry) {
        KeyboardTrackingView *view = viewRegistry[reactTag];
        if (!view || ![view isKindOfClass:[KeyboardTrackingView class]]) {
            RCTLogError(@"Error: cannot find KeyboardTrackingView with tag #%@", reactTag);
            return;
        }

        [view scrollToStart];
    }];
}

#pragma mark - helper methods

-(void)rejectPromise:(RCTPromiseRejectBlock)reject withErrorMessage:(NSString*)errorMessage errorCode:(NSInteger)errorCode
{
    NSString *errorDescription = NSLocalizedString(errorMessage, nil);
    NSError *error = [NSError errorWithDomain:@"com.keyboardTrackingView" code:errorCode userInfo:@{NSLocalizedFailureReasonErrorKey: errorDescription}];
    reject([NSString stringWithFormat:@"%ld", (long)errorCode], errorDescription, error);
}

@end

