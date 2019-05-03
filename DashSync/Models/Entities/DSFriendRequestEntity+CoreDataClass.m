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

@property (nonatomic,strong) NSData * _friendshipIdentifier;

@end

@implementation DSFriendRequestEntity

@synthesize _friendshipIdentifier;

-(NSData*)friendshipIdentifier {
    if (_friendshipIdentifier) return _friendshipIdentifier;
    UInt256 sourceIdentifier = self.sourceContact.associatedBlockchainUserRegistrationHash.UInt256;
    UInt256 destinationIdentifier = self.destinationContact.associatedBlockchainUserRegistrationHash.UInt256;
    UInt256 friendship = uint256_xor(sourceIdentifier, destinationIdentifier);
    _friendshipIdentifier = uint256_data(friendship);
    return _friendshipIdentifier;
}

@end
