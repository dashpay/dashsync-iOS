//
//  DSMasternodeManager.m
//  DashSync
//
//  Created by Sam Westrich on 5/29/18.
//

#import "DSMasternodeManager.h"

@interface DSMasternodeManager()

@property(nonatomic,strong) NSMutableDictionary * masternodeSyncCountInfo;

@end

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

- (instancetype)init {
    if (!(self = [super init])) return nil;
    
    self.masternodeSyncCountInfo = [NSMutableDictionary dictionary];
    return self;
}

- (uint32_t)countForMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo {
    if (![self.masternodeSyncCountInfo objectForKey:@(masternodeSyncCountInfo)]) return 0;
    return (uint32_t)[[self.masternodeSyncCountInfo objectForKey:@(masternodeSyncCountInfo)] unsignedLongValue];
}

-(void)setCount:(uint32_t)count forMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo {
    [self.masternodeSyncCountInfo setObject:@(count) forKey:@(masternodeSyncCountInfo)];
}

@end
