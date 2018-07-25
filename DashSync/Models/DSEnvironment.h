//
//  DSEnvironment.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>

@interface DSEnvironment : NSObject

@property (nonatomic, readonly) BOOL watchOnly; // true if this is a "watch only" wallet with no signing ability

+ (instancetype _Nullable)sharedInstance;

@end
