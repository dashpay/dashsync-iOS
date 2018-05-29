//
//  DSMasternodeManager.m
//  DashSync
//
//  Created by Sam Westrich on 5/29/18.
//

#import "DSMasternodeManager.h"

@implementation DSMasternodeManager

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

@end
