//
//  DSEnvironment.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>

#define DSLocalizedString(key, comment) \
[[DSEnvironment sharedInstance].resourceBundle localizedStringForKey:(key) value:@"" table:nil]

@interface DSEnvironment : NSObject

@property (nonatomic, readonly) BOOL watchOnly; // true if this is a "watch only" wallet with no signing ability

@property (nonatomic,strong) NSBundle * resourceBundle;

+ (instancetype _Nullable)sharedInstance;

@end
