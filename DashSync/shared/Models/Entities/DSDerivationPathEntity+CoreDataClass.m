//
//  DSDerivationPathEntity+CoreDataClass.m
//
//
//  Created by Sam Westrich on 5/20/18.
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

#import "DSAccount.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSBIP39Mnemonic.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSWallet.h"
#import "NSManagedObject+Sugar.h"

@implementation DSDerivationPathEntity

+ (DSDerivationPathEntity *_Nonnull)derivationPathEntityMatchingDerivationPath:(DSDerivationPath *)derivationPath inContext:(NSManagedObjectContext *)context {
    NSAssert(derivationPath.standaloneExtendedPublicKeyUniqueID, @"standaloneExtendedPublicKeyUniqueID must be set");
    //DSChain * chain = derivationPath.chain;
    NSArray *derivationPathEntities;
    NSError *archivingError = nil;
    NSData *archivedDerivationPath = [NSKeyedArchiver archivedDataWithRootObject:derivationPath requiringSecureCoding:NO error:&archivingError];
    NSAssert(archivedDerivationPath != nil && archivingError == nil, @"Archived derivation path should have been created");
    DSChainEntity *chainEntity = [derivationPath.chain chainEntityInContext:context];
    //NSUInteger count = [chainEntity.derivationPaths count];
    derivationPathEntities = [[chainEntity.derivationPaths objectsPassingTest:^BOOL(DSDerivationPathEntity *_Nonnull obj, BOOL *_Nonnull stop) {
        return ([obj.publicKeyIdentifier isEqualToString:derivationPath.standaloneExtendedPublicKeyUniqueID]);
    }] allObjects];

    //&& [obj.derivationPath isEqualToData:archivedDerivationPath]
    if ([derivationPathEntities count]) {
        return [derivationPathEntities firstObject];
    } else {
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity managedObjectInBlockedContext:context];
        derivationPathEntity.derivationPath = archivedDerivationPath;
        derivationPathEntity.chain = chainEntity;
        derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
        derivationPathEntity.syncBlockHeight = BIP39_CREATION_TIME;
        if (derivationPath.account) {
            derivationPathEntity.account = [DSAccountEntity accountEntityForWalletUniqueID:derivationPath.account.wallet.uniqueIDString index:derivationPath.account.accountNumber onChain:derivationPath.chain inContext:context];
        }
        if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
            //NSLog(@"--->creating derivation path entity on path %@ (%@) with no friendship identifier %@", derivationPath, derivationPath.stringRepresentation, [NSThread callStackSymbols]);
            DSIncomingFundsDerivationPath *incomingFundsDerivationPath = (DSIncomingFundsDerivationPath *)derivationPath;
            NSPredicate *predicatee = [NSPredicate predicateWithFormat:@"sourceContact.associatedBlockchainIdentity.uniqueID == %@ && destinationContact.associatedBlockchainIdentity.uniqueID == %@", uint256_data(incomingFundsDerivationPath.contactSourceBlockchainIdentityUniqueId), uint256_data(incomingFundsDerivationPath.contactDestinationBlockchainIdentityUniqueId)];
            DSFriendRequestEntity *friendRequest = [DSFriendRequestEntity anyObjectForPredicate:predicatee inContext:context];
            if (friendRequest) {
                derivationPathEntity.friendRequest = friendRequest;
            }
            //NSLog(@"--->associated friendship identifier %@", friendRequest.friendshipIdentifier.hexString);
        }
        return derivationPathEntity;
    }
}

+ (DSDerivationPathEntity *_Nonnull)derivationPathEntityMatchingDerivationPath:(DSIncomingFundsDerivationPath *)derivationPath associateWithFriendRequest:(DSFriendRequestEntity *)friendRequest inContext:(NSManagedObjectContext *)context {
    NSAssert(derivationPath.standaloneExtendedPublicKeyUniqueID, @"standaloneExtendedPublicKeyUniqueID must be set");
    NSParameterAssert(friendRequest);
    
    //DSChain * chain = derivationPath.chain;
    NSError *archivingError = nil;
    NSData *archivedDerivationPath = [NSKeyedArchiver archivedDataWithRootObject:derivationPath requiringSecureCoding:NO error:&archivingError];
    NSAssert(archivedDerivationPath != nil && archivingError == nil, @"Archived derivation path should have been created");
    DSChainEntity *chainEntity = [derivationPath.chain chainEntityInContext:context];
    
    NSSet *derivationPathEntities = [chainEntity.derivationPaths filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"publicKeyIdentifier == %@ && chain == %@", derivationPath.standaloneExtendedPublicKeyUniqueID, [derivationPath.chain chainEntityInContext:context]]];
    if (![derivationPathEntities count]) {
        //NSLog(@"-->creating derivation path entity on derivation path (%@) with friendship identifier %@ %@", derivationPath.stringRepresentation, friendRequest.friendshipIdentifier.hexString, [NSThread callStackSymbols]);
        //NSLog(@"-->friend request is %@ %@", friendRequest, friendRequest.derivationPath);
        NSAssert(friendRequest.derivationPath == nil, @"The friend request should not already have a derivationPath");
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity managedObjectInBlockedContext:context];
        derivationPathEntity.derivationPath = archivedDerivationPath;
        derivationPathEntity.chain = chainEntity;
        derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
        derivationPathEntity.syncBlockHeight = BIP39_CREATION_TIME;
        if (derivationPath.account) {
            derivationPathEntity.account = [DSAccountEntity accountEntityForWalletUniqueID:derivationPath.account.wallet.uniqueIDString index:derivationPath.account.accountNumber onChain:derivationPath.chain inContext:context];
        }
        derivationPathEntity.friendRequest = friendRequest;
        
        return derivationPathEntity;
    } else {
        DSDerivationPathEntity *derivationPathEntity = [derivationPathEntities anyObject];
        //            if (derivationPathEntity.friendRequest) {
        //                //DSLog(@"Derivation path entity found with friendship identifier %@ %@", derivationPathEntity.friendRequest.friendshipIdentifier.hexString, [NSThread callStackSymbols]);
        //                //DSFriendRequestEntity *a = [DSFriendRequestEntity existingFriendRequestEntityOnFriendshipIdentifier:derivationPathEntity.friendRequest.friendshipIdentifier inContext:friendRequest.managedObjectContext];
        //                //DSLog(@"%@", a);
        //            }
        return derivationPathEntity;
    }
}

+ (DSDerivationPathEntity *_Nonnull)derivationPathEntityMatchingDerivationPath:(DSIncomingFundsDerivationPath *)derivationPath associateWithFriendRequest:(DSFriendRequestEntity *)friendRequest {
    return [self derivationPathEntityMatchingDerivationPath:derivationPath inContext:friendRequest.managedObjectContext];
}

+ (void)deleteDerivationPathsOnChainEntity:(DSChainEntity *)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray *derivationPathsToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)", chainEntity];
        for (DSDerivationPathEntity *derivationPath in derivationPathsToDelete) {
            [chainEntity.managedObjectContext deleteObject:derivationPath];
        }
    }];
}

@end
