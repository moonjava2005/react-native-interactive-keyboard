//
//  MJCustomKeyboardViewController.m
//
//  Created by Leo Natan (Wix) on 12/12/2016.
//  Copyright © 2016 Leo Natan. All rights reserved.
//

#import "MJCustomKeyboardViewController.h"
#import "ObservingInputAccessoryView.h"

@implementation MJCustomKeyboardViewController

- (instancetype)initWithKeyboardHeight:(CGFloat)_keyboardHeight
{
  self = [super init];
  
  if(self)
  {
    self.inputView = [[UIInputView alloc] initWithFrame:CGRectZero inputViewStyle:UIInputViewStyleKeyboard];
    
    self.heightConstraint = [self.inputView.heightAnchor constraintEqualToConstant:0];
    
    
    ObservingInputAccessoryView *activeObservingInputAccessoryView = [ObservingInputAccessoryViewManager sharedInstance].activeObservingInputAccessoryView;
    if (activeObservingInputAccessoryView != nil)
    {
      CGFloat maxHeight=216;
      if (@available(iOS 11.0, *)) {
        if( [[[UIApplication sharedApplication] delegate] window].safeAreaInsets.bottom > 0.0)
        {
          maxHeight=291.00002034505201;
        }
      }
      CGFloat keyboardHeight = activeObservingInputAccessoryView.keyboardHeight;
      if(keyboardHeight==0)
      {
        keyboardHeight=_keyboardHeight;
        if(keyboardHeight==0)
        {
          keyboardHeight=maxHeight;
        }
      }
      keyboardHeight=MIN(keyboardHeight, maxHeight);
      if (keyboardHeight > 0)
      {
        self.heightConstraint.constant = keyboardHeight;
        [self setAllowsSelfSizing:YES];
      }
    }
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
  }
  
  return self;
}

- (void) setAllowsSelfSizing:(BOOL)allowsSelfSizing
{
  if(self.inputView.allowsSelfSizing != allowsSelfSizing)
  {
    self.inputView.allowsSelfSizing = allowsSelfSizing;
    self.heightConstraint.active = allowsSelfSizing;
  }
}

-(void)setRootView:(RCTRootView*)rootView
{
  if(_rootView != nil)
  {
    [_rootView removeFromSuperview];
  }
  
  _rootView = rootView;
  _rootView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.inputView addSubview:_rootView];
  
  [_rootView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
  [_rootView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
  [_rootView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
  
  NSLayoutYAxisAnchor *yAxisAnchor = self.view.bottomAnchor;
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_3
  if (@available(iOS 11.0, *)) {
    yAxisAnchor = self.view.safeAreaLayoutGuide.bottomAnchor;
  }
#endif
  [_rootView.bottomAnchor constraintEqualToAnchor:yAxisAnchor].active = YES;
}

@end
