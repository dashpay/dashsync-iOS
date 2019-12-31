//
//  DSTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransitionEntity *> *)fetchRequest;

@property (nonatomic) int16_t version;
@property (nonatomic) int16_t type;
@property (nonatomic) int64_t creditFee;
@property (nullable, nonatomic, retain) NSData *signatureData;
@property (nullable, nonatomic, retain) NSData *blockchainIdentityUniqueIdData;
@property (nonatomic) int32_t signatureId;
@property (nonatomic) double createdTimestamp;
@property (nonatomic) double registeredTimestamp;
@property (nullable, nonatomic, retain) DSBlockchainIdentityEntity *blockchainIdentity;
@property (nonatomic, retain) NSData *transitionHashData;

@end

NS_ASSUME_NONNULL_END
