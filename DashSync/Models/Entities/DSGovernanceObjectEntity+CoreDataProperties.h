//
//  DSGovernanceObjectEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 6/14/18.
//
//

#import "DSGovernanceObjectEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceObjectEntity (CoreDataProperties)

+ (NSFetchRequest<DSGovernanceObjectEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *collateralHash;
@property (nullable, nonatomic, retain) NSData *parentHash;
@property (nonatomic, assign) uint32_t revision;
@property (nullable, nonatomic, retain) NSData *signature;
@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) uint32_t type;
@property (nullable, nonatomic, retain) DSGovernanceObjectHashEntity *governanceObjectHash;
@property (nullable, nonatomic, retain) NSString * governanceMessage;

@end

NS_ASSUME_NONNULL_END
