//
//  MJFrameAnimator.h
//  KeyboardTransitionDemo
//
//

@import UIKit;

@protocol MJAnimation <NSObject>

@property (nonatomic) CGFloat progress;

@end

@interface MJViewAnimation : NSObject <MJAnimation>

@property (nonatomic, strong, readonly) UIView* view;
@property (nonatomic, strong, readonly) NSString* keyPath;
@property (nonatomic, strong, readonly) id toValue;

+ (instancetype)animationWithView:(UIView*)view keyPath:(NSString*)keyPath toValue:(id)toValue;

@end

@interface MJAnimator : NSObject

@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, strong, readonly) NSArray<id<MJAnimation>>* animations;

+ (instancetype)animatorWithDuration:(NSTimeInterval)duration animations:(NSArray<id<MJAnimation>>*)animations completionHandler:(void(^)(BOOL completed))completionHandler;

- (void)start;

@end
