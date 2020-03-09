//
//  DSFriendRequestEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "BigIntTypes.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSContactEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "NSData+Bitcoin.h"


@interface DSFriendRequestEntity ()

@end

@implementation DSFriendRequestEntity

- (NSData *)finalizeWithFriendshipIdentifier {
    NSAssert(self.sourceContact, @"source contact must exist");
    NSAssert(self.destinationContact, @"destination contact must exist");
    NSAssert(self.account, @"account must exist");
    UInt256 sourceIdentifier = self.sourceContact.associatedBlockchainIdentityUniqueId.UInt256;
    UInt256 destinationIdentifier = self.destinationContact.associatedBlockchainIdentityUniqueId.UInt256;
    UInt256 friendship = uint256_xor(sourceIdentifier, destinationIdentifier);
    if (uint256_sup(sourceIdentifier, destinationIdentifier)) {
        //the destination should always be bigger than the source, otherwise add 1 on the 32nd bit to differenciate them
        friendship = uInt256Add(friendship, uint256_from_int(1 << 31));
    }
    UInt256 friendshipOnAccount = uint256_xor(friendship, uint256_from_int(self.account.index));
    self.friendshipIdentifier = uint256_data(friendshipOnAccount);
    return self.friendshipIdentifier;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ - { %@ -> %@ / %d }", [super debugDescription], self.sourceContact.username, self.destinationContact.username, self.account.index];
}

@end
