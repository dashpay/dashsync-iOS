//
//  NSDate+Utils.h
//  DashSync
//
//  Created by Sam Westrich on 11/7/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (Utils)

+ (NSTimeInterval)timeIntervalSince1970;
+ (NSTimeInterval)timeIntervalSince1970Minus:(NSTimeInterval)interval;
+ (NSTimeInterval)timeIntervalSince1970MinusHour;

@end

NS_ASSUME_NONNULL_END
