//
//  DSInstantSendTransactionLock.h
//  DashSync
//
//  Created by Sam Westrich on 4/5/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain,DSSimplifiedMasternodeEntry,DSQuorumEntry,DSMasternodeList;

@interface DSInstantSendTransactionLock : NSObject

@property (nonatomic, readonly) DSChain * chain;
@property (nonatomic, readonly) UInt256 transactionHash;
@property (nonatomic, readonly) UInt768 signature;
@property (nonatomic, readonly) NSArray * inputOutpoints;
@property (nonatomic, readonly) BOOL signatureVerified; //verifies the signature and quorum together
@property (nonatomic, readonly) DSQuorumEntry * intendedQuorum;
@property (nonatomic, readonly) BOOL saved;
@property (nonatomic, readonly) UInt256 requestID;

- (BOOL)verifySignature;

- (void)save;

+ (instancetype)instantSendTransactionLockWithMessage:(NSData *)message onChain:(DSChain*)chain;

- (instancetype)initWithTransactionHash:(UInt256)transactionHash withInputOutpoints:(NSArray*)inputOutpoints signatureVerified:(BOOL)signatureVerified quorumVerified:(BOOL)quorumVerified onChain:(DSChain*)chain;

- (DSQuorumEntry*)findSigningQuorumReturnMasternodeList:(DSMasternodeList*_Nullable*_Nullable)returnMasternodeList;

@end

NS_ASSUME_NONNULL_END
