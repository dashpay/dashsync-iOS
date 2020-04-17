//
//  DSFriendRequestEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSFriendRequestEntity+CoreDataClass.h"
#import "BigIntTypes.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "NSData+Bitcoin.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@interface DSFriendRequestEntity()

@end

@implementation DSFriendRequestEntity

+(void)deleteFriendRequestsOnChain:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * friendRequestsToDelete = [self objectsMatching:@"(derivationPath.chain == %@)",chainEntity];
        for (DSFriendRequestEntity * friendRequest in friendRequestsToDelete) {
            [friendRequest.managedObjectContext deleteObject:friendRequest];
        }
    }];
}

-(NSData*)finalizeWithFriendshipIdentifier {
    NSAssert(self.sourceContact, @"source contact must exist");
    NSAssert(self.destinationContact, @"destination contact must exist");
    NSAssert(self.account, @"account must exist");
    UInt256 sourceIdentifier = self.sourceContact.associatedBlockchainIdentity.uniqueID.UInt256;
    UInt256 destinationIdentifier = self.destinationContact.associatedBlockchainIdentity.uniqueID.UInt256;
    UInt256 friendship = uint256_xor(sourceIdentifier, destinationIdentifier);
    if (uint256_sup(sourceIdentifier, destinationIdentifier)) {
        //the destination should always be bigger than the source, otherwise add 1 on the 32nd bit to differenciate them
        friendship = uInt256Add(friendship,uint256_from_int(1<<31));
    }
    UInt256 friendshipOnAccount = uint256_xor(friendship,uint256_from_int(self.account.index));
    self.friendshipIdentifier = uint256_data(friendshipOnAccount);
    return self.friendshipIdentifier;
}

-(NSString*)debugDescription {
    return [NSString stringWithFormat:@"%@ - { %@ -> %@ / %d }",[super debugDescription],self.sourceContact.associatedBlockchainIdentity.dashpayUsername.stringValue,self.destinationContact.associatedBlockchainIdentity.dashpayUsername.stringValue,self.account.index];
}

@end
