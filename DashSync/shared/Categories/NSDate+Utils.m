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

@end
