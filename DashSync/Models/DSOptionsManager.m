//
//  DSOptionsManager.m
//  DashSync
//
//  Created by Sam Westrich on 6/5/18.
//

#import "DSOptionsManager.h"

#define OPTION_KEEP_HEADERS_KEY @"OPTION_KEEP_HEADERS_KEY"
#define OPTION_KEEP_HEADERS_DEFAULT FALSE
#define OPTION_SYNC_FROM_HEIGHT_KEY @"OPTION_SYNC_FROM_HEIGHT_KEY"
#define OPTION_SYNC_TYPE_KEY @"OPTION_SYNC_TYPE_KEY"
#define OPTION_SYNC_GOVERANCE_OBJECTS_INTERVAL_KEY @"OPTION_SYNC_GOVERANCE_OBJECTS_INTERVAL_KEY"
#define OPTION_SYNC_GOVERANCE_OBJECTS_INTERVAL_DEFAULT 600 //10 minutes
#define OPTION_SYNC_MASTERNODE_LIST_INTERVAL_KEY @"OPTION_SYNC_MASTERNODE_LIST_INTERVAL_KEY"
#define OPTION_SYNC_MASTERNODE_LIST_INTERVAL_DEFAULT 600 //10 minutes

@implementation DSOptionsManager

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

-(instancetype)init {
    if (!(self = [super init])) return nil;
    

    return self;
}

-(void)setKeepHeaders:(BOOL)keepHeaders {
    [[NSUserDefaults standardUserDefaults] setBool:keepHeaders forKey:OPTION_KEEP_HEADERS_KEY];
}

-(BOOL)keepHeaders {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:OPTION_KEEP_HEADERS_KEY]) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:OPTION_KEEP_HEADERS_KEY];
    } else {
        return OPTION_KEEP_HEADERS_DEFAULT;
    }
}

-(void)setSyncFromHeight:(uint32_t)syncFromHeight {
    [[NSUserDefaults standardUserDefaults] setInteger:syncFromHeight forKey:OPTION_SYNC_FROM_HEIGHT_KEY];
}

-(void)setSyncGovernanceObjectsInterval:(NSTimeInterval)syncGovernanceObjectsInterval {
    [[NSUserDefaults standardUserDefaults] setInteger:syncGovernanceObjectsInterval forKey:OPTION_SYNC_GOVERANCE_OBJECTS_INTERVAL_KEY];
}

-(NSTimeInterval)syncGovernanceObjectsInterval {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:OPTION_SYNC_GOVERANCE_OBJECTS_INTERVAL_KEY]) {
        return [[NSUserDefaults standardUserDefaults] integerForKey:OPTION_SYNC_GOVERANCE_OBJECTS_INTERVAL_KEY];
    } else {
        return OPTION_SYNC_GOVERANCE_OBJECTS_INTERVAL_DEFAULT;
    }
}

-(void)setSyncMasternodeListInterval:(NSTimeInterval)syncMasternodeListInterval {
    [[NSUserDefaults standardUserDefaults] setInteger:syncMasternodeListInterval forKey:OPTION_SYNC_MASTERNODE_LIST_INTERVAL_KEY];
}

-(NSTimeInterval)syncMasternodeListInterval {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:OPTION_SYNC_MASTERNODE_LIST_INTERVAL_KEY]) {
        return [[NSUserDefaults standardUserDefaults] integerForKey:OPTION_SYNC_MASTERNODE_LIST_INTERVAL_KEY];
    } else {
        return OPTION_SYNC_MASTERNODE_LIST_INTERVAL_DEFAULT;
    }
}

-(BOOL)shouldSyncFromHeight {
    return [[NSUserDefaults standardUserDefaults] objectForKey:OPTION_SYNC_FROM_HEIGHT_KEY];
}

-(uint32_t)syncFromHeight {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:OPTION_SYNC_FROM_HEIGHT_KEY]) {
        return (uint32_t)[[NSUserDefaults standardUserDefaults] integerForKey:OPTION_SYNC_FROM_HEIGHT_KEY];
    } else {
        return 0;
    }
}

-(void)setSyncFromGenesis:(BOOL)syncFromGenesis {
    if (syncFromGenesis) {
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:OPTION_SYNC_FROM_HEIGHT_KEY];
    } else if ([[NSUserDefaults standardUserDefaults] objectForKey:OPTION_SYNC_FROM_HEIGHT_KEY]) {
        uint32_t height = (uint32_t)[[NSUserDefaults standardUserDefaults] integerForKey:OPTION_SYNC_FROM_HEIGHT_KEY];
        if (height == 0) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:OPTION_SYNC_FROM_HEIGHT_KEY];
        }
    }
}

-(BOOL)syncFromGenesis {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:OPTION_SYNC_FROM_HEIGHT_KEY]) {
        return ![[NSUserDefaults standardUserDefaults] integerForKey:OPTION_SYNC_FROM_HEIGHT_KEY];
    } else {
        return NO;
    }
}

-(DSSyncType)syncType {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:OPTION_SYNC_TYPE_KEY]) {
        return (DSSyncType)[[NSUserDefaults standardUserDefaults] integerForKey:OPTION_SYNC_TYPE_KEY];
    } else {
        return DSSyncType_Default;
    }
}

-(void)addSyncType:(DSSyncType)addSyncType {
    [[NSUserDefaults standardUserDefaults] setInteger:self.syncType | addSyncType forKey:OPTION_SYNC_TYPE_KEY];
}

-(void)clearSyncType:(DSSyncType)clearSyncType {
    [[NSUserDefaults standardUserDefaults] setInteger:self.syncType & ~clearSyncType forKey:OPTION_SYNC_TYPE_KEY];
}

-(void)setSyncType:(DSSyncType)syncType {
    [[NSUserDefaults standardUserDefaults] setInteger:syncType forKey:OPTION_SYNC_TYPE_KEY];
}

@end
