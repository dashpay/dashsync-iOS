//
//  DSFriendRequestEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import "DSFriendRequestEntity+CoreDataClass.h"
#import "BigIntTypes.h"
#import "DSContactEntity+CoreDataClass.h"

#import "NSData+Bitcoin.h"


@interface DSFriendRequestEntity()

@end

@implementation DSFriendRequestEntity

-(NSData*)friendshipIdentifier {
    if (self.friendshipIdentifier) return self.friendshipIdentifier;
    UInt256 sourceIdentifier = self.sourceContact.associatedBlockchainUserRegistrationHash.UInt256;
    UInt256 destinationIdentifier = self.destinationContact.associatedBlockchainUserRegistrationHash.UInt256;
    UInt256 friendship = uint256_xor(sourceIdentifier, destinationIdentifier);
    return uint256_data(friendship);
}

@end
