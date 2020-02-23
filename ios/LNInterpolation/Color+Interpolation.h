//
//  Color+Interpolation.h
//
//

#if __has_include(<UIKit/UIKit.h>) || __has_include(<AppKit/AppKit.h>)

#import "MJInterpolable.h"

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

/**
 Interpolate using the LAB color space for optimal quality. This constant is equal to @c MJUseDefaultInterpolationBehavior.
 */
extern MJInterpolationBehavior const MJInterpolationBehaviorUseLABColorSpace;

/**
 Interpolate using the RGB color space.
 */
extern MJInterpolationBehavior const MJInterpolationBehaviorUseRGBColorSpace;

/**
 Interpolates between colors.
 
 By default, colors are interpolated in the Lab color space for optimal quality at the expense of some performance. Use @c MJUseRGBInterpolationBehavior for better performance but suboptimal quality.
 */
#if __has_include(<UIKit/UIKit.h>)
@interface UIColor (MJInterpolation) <MJInterpolable> @end
#else
@interface NSColor (MJInterpolation) <MJInterpolable> @end
#endif

#endif
