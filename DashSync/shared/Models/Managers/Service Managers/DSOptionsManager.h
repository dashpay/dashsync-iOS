//
//  DSOptionsManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/5/18.
//

#import <DSDynamicOptions/DSDynamicOptions.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSSyncType)
{
    DSSyncType_None = 0,
    DSSyncType_BaseSPV = 1,
    DSSyncType_FullBlocks = 1 << 1,
    DSSyncType_Mempools = 1 << 2,
    DSSyncType_SPV = DSSyncType_BaseSPV | DSSyncType_Mempools,
    DSSyncType_MasternodeList = 1 << 3,
    DSSyncType_VerifiedMasternodeList = DSSyncType_MasternodeList | DSSyncType_SPV,
    DSSyncType_Governance = 1 << 4,
    DSSyncType_GovernanceVotes = 1 << 5,
    DSSyncType_GovernanceVoting = DSSyncType_Governance | DSSyncType_MasternodeList,
    DSSyncType_Sporks = 1 << 6,
    DSSyncType_BlockchainIdentities = 1 << 7,
    DSSyncType_DPNS = 1 << 8,
    DSSyncType_Dashpay = 1 << 9,
    DSSyncType_MultiAccountAutoDiscovery = 1 << 10,
    DSSyncType_Default = DSSyncType_SPV | DSSyncType_Mempools | DSSyncType_VerifiedMasternodeList | DSSyncType_Sporks | DSSyncType_BlockchainIdentities | DSSyncType_DPNS | DSSyncType_Dashpay | DSSyncType_MultiAccountAutoDiscovery,
    DSSyncType_NeedsWalletSyncType = DSSyncType_BaseSPV | DSSyncType_FullBlocks,
    DSSyncType_GetsNewBlocks = DSSyncType_SPV | DSSyncType_FullBlocks,
};

@interface DSOptionsManager : DSDynamicOptions

@property (nonatomic, assign) BOOL keepHeaders;
@property (nonatomic, assign) BOOL useCheckpointMasternodeLists;
@property (nonatomic, assign) BOOL smartOutputs;
@property (nonatomic, assign) BOOL syncFromGenesis;
@property (nonatomic, assign) BOOL retrievePriceInfo;
@property (nonatomic, assign) BOOL shouldSyncFromHeight;
@property (nonatomic, assign) BOOL shouldUseCheckpointFile;
@property (nonatomic, assign) uint32_t syncFromHeight;
@property (nonatomic, assign) NSTimeInterval syncGovernanceObjectsInterval;
@property (nonatomic, assign) NSTimeInterval syncMasternodeListInterval;
@property (nonatomic, assign) DSSyncType syncType;

+ (instancetype)sharedInstance;

- (void)addSyncType:(DSSyncType)syncType;
- (void)clearSyncType:(DSSyncType)syncType;

@end

NS_ASSUME_NONNULL_END
