//
//  DSEnvironment.h
//  DashSync
//
//  Created by Sam Westrich on 7/20/18.
//

#import <Foundation/Foundation.h>

#import "DSLogger.h"

#define DSLocalizedString(key, comment) \
    [[DSEnvironment sharedInstance].resourceBundle localizedStringForKey:(key) value:@"" table:nil]

#define DSLocalizedFormat(key, comment, ...) \
    [NSString stringWithFormat:DSLocalizedString(key, comment), ##__VA_ARGS__]

@interface DSEnvironment : NSObject

@property (nonatomic, readonly) BOOL watchOnly; // true if this is a "watch only" wallet with no signing ability

@property (nonatomic, strong) NSBundle *_Nonnull resourceBundle;

+ (instancetype _Nullable)sharedInstance;

@end
