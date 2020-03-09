//
//  DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSAddressEntity+CoreDataClass.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSTransition.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"

@implementation DSBlockchainIdentityRegistrationTransitionEntity

- (instancetype)setAttributesFromTransition:(DSTransition *)tx {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransition:tx];
        //        DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransition = (DSBlockchainIdentityRegistrationTransition*)tx;
        //        self.specialTransitionVersion = blockchainIdentityRegistrationTransition.blockchainIdentityRegistrationTransitionVersion;
        //        self.publicKey = [NSData dataWithUInt160:blockchainIdentityRegistrationTransition.pubkeyHash];
        //        self.username = blockchainIdentityRegistrationTransition.username;
        //        self.payloadSignature = blockchainIdentityRegistrationTransition.payloadSignature;
        //
        //        //for when we switch to BLS -> [DSKey addressWithPublicKeyData:self.publicKey forChain:tx.chain];
        //        NSString * publicKeyAddress = [self.publicKey addressFromHash160DataForChain:tx.chain];
        //        NSArray * addressEntities = [DSAddressEntity objectsMatching:@"address == %@ && derivationPath.chain == %@",publicKeyAddress,tx.chain.chainEntity];
        //        if ([addressEntities count]) {
        //            NSAssert([addressEntities count] == 1, @"addresses should not be duplicates");
        //            [self addAddressesObject:[addressEntities firstObject]];
        //        } else {
        //            DSDLog(@"Address %@ is not known", publicKeyAddress);
        //        }
    }];

    return self;
}

- (DSTransition *)transitionForChain:(DSChain *)chain {
    DSBlockchainIdentityRegistrationTransition *transition = (DSBlockchainIdentityRegistrationTransition *)[super transitionForChain:chain];
    //transition.type = DSTransitionType_SubscriptionRegistration;
    [self.managedObjectContext performBlockAndWait:^{
        //        transition.blockchainIdentityRegistrationTransitionVersion = self.specialTransitionVersion;
        //        transition.pubkeyHash = self.publicKey.UInt160;
        //        DSDLog(@"%@",uint160_hex(transition.pubkeyHash));
        //        transition.username = self.username;
        //        transition.payloadSignature = self.payloadSignature;
    }];

    return transition;
}

- (Class)transitionClass {
    return [DSBlockchainIdentityRegistrationTransition class];
}

@end
