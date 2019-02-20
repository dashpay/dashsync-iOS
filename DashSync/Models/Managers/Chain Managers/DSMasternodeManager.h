//
//  DSMasternodeManager.h
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
#import <Foundation/Foundation.h>
#import "DSPeer.h"
#import "DSChain.h"

FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListDidChangeNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListValidationErrorNotification;
FOUNDATION_EXPORT NSString* _Nonnull const DSMasternodeListCountUpdateNotification;

#define MASTERNODE_COST 100000000000

@class DSPeer,DSChain,DSSimplifiedMasternodeEntry,DSWallet,DSLocalMasternode,DSProviderRegistrationTransaction;

@interface DSMasternodeManager : NSObject <DSPeerMasternodeDelegate>

@property (nonatomic,readonly) DSChain * chain;
@property (nonatomic,readonly) NSUInteger simplifiedMasternodeEntryCount;
@property (nonatomic,readonly) NSUInteger localMasternodesCount;

@property (nonatomic,readonly) UInt256 baseBlockHash;


-(instancetype)initWithChain:(DSChain*)chain;

-(void)setUp;

//-(void)addMasternodePrivateKey:(NSString*)privateKey atAddress:(NSString*)address;

-(DSSimplifiedMasternodeEntry*)masternodeHavingProviderRegistrationTransactionHash:(NSData*)providerRegistrationTransactionHash;

-(NSArray<DSSimplifiedMasternodeEntry*>*)masternodesForQuorumHash:(UInt256)quorumHash quorumCount:(NSUInteger)quorumCount forBlockHash:(UInt256)blockHash;

-(NSArray<DSSimplifiedMasternodeEntry*>*)masternodesForQuorumHash:(UInt256)quorumHash quorumCount:(NSUInteger)quorumCount;

-(UInt256)masternodeScore:(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry quorumHash:(UInt256)quorumHash;

-(void)wipeMasternodeInfo;

-(BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port;

-(DSLocalMasternode*)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet*)wallet;

-(DSLocalMasternode*)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet*)fundsWallet inOperatorWallet:(DSWallet*)operatorWallet inOwnerWallet:(DSWallet*)ownerWallet inVotingWallet:(DSWallet*)votingWallet;

-(DSLocalMasternode*)localMasternodeFromProviderRegistrationTransaction:(DSProviderRegistrationTransaction*)providerRegistrationTransaction;

@end
