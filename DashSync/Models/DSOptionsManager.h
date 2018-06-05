//
//  DSOptionsManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/5/18.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, DSSyncType) {
    DSSyncType_None = 0,
    DSSyncType_SPV = 1,
    DSSyncType_FullBlocks = 1 << 1,
    DSSyncType_Governance = 1 << 2,
    DSSyncType_Sporks = 1 << 3,
    DSSyncType_Default = DSSyncType_SPV | DSSyncType_Governance | DSSyncType_Sporks,
};

@interface DSOptionsManager : NSObject

@property (nonatomic,assign) BOOL keepHeaders;
@property (nonatomic,assign) BOOL syncFromGenesis;
@property (nonatomic,assign) DSSyncType syncType;

+ (instancetype _Nullable)sharedInstance;

-(void)addSyncType:(DSSyncType)syncType;
-(void)clearSyncType:(DSSyncType)syncType;

@end
