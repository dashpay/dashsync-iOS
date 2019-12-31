//
//  DSBlockchainIdentityResetTransitionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainIdentityResetTransitionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "DSTransaction.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSBlockchainIdentityResetTransitionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSBlockchainIdentityResetTransaction * blockchainIdentityResetTransaction = (DSBlockchainIdentityResetTransaction*)tx;
        self.specialTransactionVersion = blockchainIdentityResetTransaction.blockchainIdentityResetTransactionVersion;
        self.registrationTransactionHash = [NSData dataWithUInt256:blockchainIdentityResetTransaction.registrationTransactionHash];
        self.creditFee = blockchainIdentityResetTransaction.creditFee;
        self.oldPubKeyPayloadSignature = blockchainIdentityResetTransaction.oldPublicKeyPayloadSignature;
        self.replacementPublicKey = [NSData dataWithUInt160:blockchainIdentityResetTransaction.replacementPublicKeyHash];
        
        //for when we switch to BLS -> [DSKey addressWithPublicKeyData:self.publicKey forChain:tx.chain];
        NSString * publicKeyHash = [self.replacementPublicKey addressFromHash160DataForChain:tx.chain];
        NSArray * addressEntities = [DSAddressEntity objectsMatching:@"address == %@ && derivationPath.chain == %@",publicKeyHash,tx.chain.chainEntity];
        if ([addressEntities count]) {
            NSAssert([addressEntities count] == 1, @"addresses should not be duplicates");
            [self addAddressesObject:[addressEntities firstObject]];
        }
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSBlockchainIdentityResetTransaction * transaction = (DSBlockchainIdentityResetTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionResetKey;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainIdentityResetTransactionVersion = self.specialTransactionVersion;
        transaction.registrationTransactionHash = self.registrationTransactionHash.UInt256;
        transaction.creditFee = self.creditFee;
        transaction.oldPublicKeyPayloadSignature = self.oldPubKeyPayloadSignature;
        transaction.replacementPublicKeyHash = self.replacementPublicKey.UInt160;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainIdentityResetTransaction class];
}

@end
