//
//  MJInterpolable.c
//
//

#import "MJInterpolable.h"

MJInterpolationBehavior const MJInterpolationBehaviorUseDefault = @"MJInterpolationBehaviorUseDefault";

double BackEaseOut(double p)
{
    double f = (1 - p);
    return 1 - (f * f * f - 0.4*f * sin(f * M_PI));
}

double QuarticEaseOut(double p)
{
    double f = (p - 1);
    return f * f * f * (1 - p) + 1;
}

double MJLinearInterpolate(double from, double to, double p)
{
	return from + QuarticEaseOut(p) * (to - from);
}
