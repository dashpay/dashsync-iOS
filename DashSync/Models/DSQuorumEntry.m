//
//  DSQuorumEntry.m
//  DashSync
//
//  Created by Sam Westrich on 5/19/19.
//

#import "DSQuorumEntry.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "NSData+Bitcoin.h"

@implementation DSQuorumEntry

-(DSQuorumEntryEntity*)matchingQuorumEntryEntity {
    return [DSQuorumEntryEntity anyObjectMatching:@"quorumPublicKeyData",uint384_data(self.quorumPublicKey)];
}

@end
