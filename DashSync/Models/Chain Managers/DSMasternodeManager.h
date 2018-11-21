//
//  DSMasternodeManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//

#import <Foundation/Foundation.h>
#import "DSChain.h"

FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListValidationErrorNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListCountUpdateNotification;

@class DSPeer,DSChain,DSSimplifiedMasternodeEntry,DSMasternodePing;

@interface DSMasternodeManager : NSObject

@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSUInteger simplifiedMasternodeEntryCount;

@property (nonatomic,readonly) UInt256 baseBlockHash;

-(instancetype)initWithChain:(DSChain*)chain;

-(void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData*)masternodeDiffMessage;

//-(void)addMasternodePrivateKey:(NSString*)privateKey atAddress:(NSString*)address;

-(DSSimplifiedMasternodeEntry*)masternodeHavingProviderRegistrationTransactionHash:(NSData*)providerRegistrationTransactionHash;

-(void)wipeMasternodeInfo;

-(BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port;

@end
