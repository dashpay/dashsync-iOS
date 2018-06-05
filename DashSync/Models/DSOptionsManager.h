//
//  DSOptionsManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/5/18.
//

#import <Foundation/Foundation.h>

@interface DSOptionsManager : NSObject

@property (nonatomic,assign) BOOL keepHeaders;
@property (nonatomic,assign) BOOL syncFromGenesis;

+ (instancetype _Nullable)sharedInstance;

@end
