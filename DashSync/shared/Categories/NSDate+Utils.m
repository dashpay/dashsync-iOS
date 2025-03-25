//
//  NSDate+Utils.m
//  DashSync
//
//  Created by Sam Westrich on 11/7/18.
//

#import "NSDate+Utils.h"

@implementation NSDate (Utils)

+ (NSTimeInterval)timeIntervalSince1970 {
    return [[NSDate date] timeIntervalSince1970];
}
+ (NSTimeInterval)timeIntervalSince1970Minus:(NSTimeInterval)interval {
    return [NSDate timeIntervalSince1970] - interval;
}
+ (NSTimeInterval)timeIntervalSince1970MinusHour {
    return [NSDate timeIntervalSince1970] - 3600;
}

@end
