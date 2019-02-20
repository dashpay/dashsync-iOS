//
//  DSProviderRegistrationTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import "DSProviderRegistrationTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSMasternodeManager.h"
#import "DSChainManager.h"

@interface DSProviderRegistrationTransaction()

@end

@implementation DSProviderRegistrationTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderRegistration;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;
    
    if (length - off < 2) return nil;
    self.providerRegistrationTransactionVersion = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 2) return nil;
    self.providerType = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 2) return nil;
    self.providerMode = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 36) return nil;
    self.collateralOutpoint = (DSUTXO) { .hash = [message UInt256AtOffset:off], .n = [message UInt32AtOffset:off + 32]};
    off += 36;
    
    if (length - off < 16) return nil;
    self.ipAddress = [message UInt128AtOffset:off];
    off += 16;
    
    if (length - off < 2) return nil;
    self.port = CFSwapInt16HostToBig([message UInt16AtOffset:off]);
    off += 2;
    
    if (length - off < 20) return nil;
    self.ownerKeyHash = [message UInt160AtOffset:off];
    off += 20;
    
    if (length - off < 48) return nil;
    self.operatorKey = [message UInt384AtOffset:off];
    off += 48;
    
    if (length - off < 20) return nil;
    self.votingKeyHash = [message UInt160AtOffset:off];
    off += 20;
    
    if (length - off < 2) return nil;
    self.operatorReward = [message UInt16AtOffset:off];
    off += 2;
    
    NSNumber * scriptPayoutLength = nil;
    self.scriptPayout = [message dataAtOffset:off length:&scriptPayoutLength];
    off += scriptPayoutLength.unsignedIntegerValue;
    
    if (length - off < 32) return nil;
    self.inputsHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 1) return nil;
    NSNumber * messageSignatureSizeLength = nil;
    NSUInteger messageSignatureSize = (NSUInteger)[message varIntAtOffset:off length:&messageSignatureSizeLength];
    off += messageSignatureSizeLength.unsignedIntegerValue;
    if (length - off < messageSignatureSize) return nil;
    self.payloadSignature = [message subdataWithRange:NSMakeRange(off, messageSignatureSize)];
    off+= messageSignatureSize;
    self.payloadOffset = off;
    
    //todo verify inputs hash
    
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;
    
    return self;
}



-(instancetype)initWithProviderRegistrationTransactionVersion:(uint16_t)version type:(uint16_t)providerType mode:(uint16_t)providerMode ipAddress:(UInt128)ipAddress port:(uint16_t)port ownerKeyHash:(UInt160)ownerKeyHash operatorKey:(UInt384)operatorKey votingKeyHash:(UInt160)votingKeyHash operatorReward:(uint16_t)operatorReward scriptPayout:(NSData*)scriptPayout onChain:(DSChain * _Nonnull)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_ProviderRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.providerRegistrationTransactionVersion = version;
    self.providerType = providerType;
    self.providerMode = providerMode;
    self.ipAddress = ipAddress;
    self.collateralOutpoint = DSUTXO_ZERO;
    self.port = port;
    self.ownerKeyHash = ownerKeyHash;
    self.operatorKey = operatorKey;
    self.votingKeyHash = votingKeyHash;
    self.operatorReward = operatorReward;
    self.scriptPayout = scriptPayout;
    DSDLog(@"Creating provider (masternode) with ownerKeyHash %@",uint160_data(ownerKeyHash));
    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerRegistrationTransactionVersion:(uint16_t)version type:(uint16_t)providerType mode:(uint16_t)providerMode collateralOutpoint:(DSUTXO)collateralOutpoint ipAddress:(UInt128)ipAddress port:(uint16_t)port ownerKeyHash:(UInt160)ownerKeyHash operatorKey:(UInt384)operatorKey votingKeyHash:(UInt160)votingKeyHash operatorReward:(uint16_t)operatorReward scriptPayout:(NSData*)scriptPayout onChain:(DSChain * _Nonnull)chain {
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.providerRegistrationTransactionVersion = version;
    self.providerType = providerType;
    self.providerMode = providerMode;
    self.collateralOutpoint = collateralOutpoint;
    self.ipAddress = ipAddress;
    self.port = port;
    self.ownerKeyHash = ownerKeyHash;
    self.operatorKey = operatorKey;
    self.votingKeyHash = votingKeyHash;
    self.operatorReward = operatorReward;
    self.scriptPayout = scriptPayout;
    DSDLog(@"Creating provider (masternode) with ownerKeyHash %@",uint160_data(ownerKeyHash));
    return self;
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(BOOL)checkPayloadSignature {
    DSECDSAKey * providerOwnerPublicKey = [DSECDSAKey keyRecoveredFromCompactSig:self.payloadSignature andMessageDigest:[self payloadHash]];
    return uint160_eq([providerOwnerPublicKey hash160], self.ownerKeyHash);
}

-(void)signPayloadWithKey:(DSECDSAKey*)privateKey {
    //ATTENTION If this ever changes from ECDSA, change the max signature size defined above
    DSDLog(@"Private Key is %@",[privateKey privateKeyStringForChain:self.chain]);
    self.payloadSignature = [privateKey compactSign:[self payloadHash]];
}

-(NSData*)basePayloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.providerRegistrationTransactionVersion]; //16
    [data appendUInt16:self.providerType]; //32
    [data appendUInt16:self.providerMode]; //48
    [data appendUTXO:self.collateralOutpoint]; //84
    [data appendUInt128:self.ipAddress]; //212
    [data appendUInt16:CFSwapInt16BigToHost(self.port)]; //228
    [data appendUInt160:self.ownerKeyHash]; //388
    [data appendUInt384:self.operatorKey]; //772
    [data appendUInt160:self.votingKeyHash]; //788
    [data appendUInt16:self.operatorReward]; //804
    [data appendVarInt:self.scriptPayout.length];
    [data appendData:self.scriptPayout];
    [data appendUInt256:self.inputsHash];
    return data;
}

-(NSData*)payloadDataForHash {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    [data appendUInt8:0];
    return data;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    [data appendUInt8:self.payloadSignature.length];
    [data appendData:self.payloadSignature];
    return data;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
{
    NSMutableData * data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
    [data appendVarInt:self.payloadData.length];
    [data appendData:[self payloadData]];
    if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
    return data;
}

- (size_t)maxSizeEstimatedBeforePayloadSigning
{
    return [super size] + [self basePayloadData].length + MAX_SIGNATURE_SIZE;
}

- (size_t)size
{
    if (self.payloadSignature) {
        return [super size] + [self payloadData].length;
    } else {
        return [self maxSizeEstimatedBeforePayloadSigning];
    }
}

-(Class)entityClass {
    return [DSProviderRegistrationTransactionEntity class];
}

-(void)updateInputsHash {
    NSMutableData * data = [NSMutableData data];
    for (NSUInteger i =0; i<self.inputHashes.count;i++) {
        UInt256 hash = UINT256_ZERO;
        NSValue * inputHash = self.inputHashes[i];
        [inputHash getValue:&hash];
        [data appendUInt256:hash];
        [data appendUInt32:[self.inputIndexes[i] unsignedIntValue]];
    }
    self.inputsHash = [data SHA256_2];
}

-(void)hasSetInputsAndOutputs {
    [self updateInputsHash];
    if (dsutxo_is_zero(self.collateralOutpoint) && [self.outputAmounts containsObject:@(MASTERNODE_COST)]) {
        NSUInteger index = [self.outputAmounts indexOfObject:@(MASTERNODE_COST)];
        self.collateralOutpoint = (DSUTXO) { .hash = UINT256_ZERO, .n = index};
        self.payloadSignature = [NSData data];
    }
}

-(DSLocalMasternode*)localMasternode {
    return [self.chain.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:self];
}

-(DSWallet*)masternodeHoldingWallet {
    return [self.chain walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:self foundAtIndex:nil];
}


@end
