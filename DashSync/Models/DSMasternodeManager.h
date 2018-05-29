//
//  DSMasternodeManager.h
//  DashSync
//
//  Created by Sam Westrich on 5/29/18.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListChangedNotification;

@interface DSMasternodeManager : NSObject

+ (instancetype)sharedInstance;

@end
