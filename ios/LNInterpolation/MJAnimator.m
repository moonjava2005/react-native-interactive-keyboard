//
//  MJFrameAnimator.m
//  KeyboardTransitionDemo
//
//

#import "MJAnimator.h"

#import "MJInterpolation.h"

@implementation MJViewAnimation
{
	id _fromValue;
}

@synthesize progress = _progress;

- (instancetype)init
{
	[NSException raise:NSInvalidArgumentException format:@"Use animationWithView:keyPath:toValue: to create MJViewAnimation objects."];
	return nil;
}

- (instancetype)_init
{
	return [super init];
}

+ (instancetype)animationWithView:(UIView*)view keyPath:(NSString*)keyPath toValue:(id)toValue
{
	MJViewAnimation* rv = [[MJViewAnimation alloc] _init];
	
	if(rv)
	{
		rv->_view = view;
		rv->_keyPath = keyPath;
		rv->_toValue = toValue;
		rv->_fromValue = [view valueForKeyPath:keyPath];
	}
	
	return rv;
}

- (void)setProgress:(CGFloat)progress
{
	_progress = progress;
	[_view setValue:[_fromValue interpolateToValue:_toValue progress:progress] forKeyPath:_keyPath];
	[_view layoutIfNeeded];
}

@end

@implementation MJAnimator
{
	void (^_completionHandler)(BOOL);
	CADisplayLink* _displayLink;
	CFTimeInterval _previousFrameTimestamp;
	CFTimeInterval _elapsedTime;
}

- (instancetype)init
{
	[NSException raise:NSInvalidArgumentException format:@"Use animationWithView:keyPath:toValue: to create MJViewAnimation objects."];
	return nil;
}

- (instancetype)_init
{
	return [super init];
}

+ (instancetype)animatorWithDuration:(NSTimeInterval)duration animations:(NSArray<id<MJAnimation>>*)animations completionHandler:(void(^)(BOOL completed))completionHandler
{
	MJAnimator* rv = [[MJAnimator alloc] _init];
	if(rv)
	{
		rv->_duration = duration;
		
		NSAssert(animations.count > 0, @"At least one animation must be provided.");
		
		rv->_animations = animations;
        rv->_completionHandler = completionHandler;
	}
	
	return rv;
}

- (void)start
{
	_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_displayLinkDidTick)];
//	_displayLink.preferredFramesPerSecond = 30;
	[_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)_displayLinkDidTick
{
	if(_previousFrameTimestamp != 0)
	{
		_elapsedTime += _displayLink.timestamp - _previousFrameTimestamp;
	}
	_previousFrameTimestamp = _displayLink.timestamp;
	
	[_animations enumerateObjectsUsingBlock:^(id<MJAnimation>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		obj.progress = MIN(_elapsedTime / _duration, 1.0);
	}];
	
	if(_elapsedTime / _duration >= 1.0)
	{
		[_displayLink invalidate];
		_displayLink = nil;
        
        if(_completionHandler)
        {
            _completionHandler(YES);
        }
	}
}

@end
