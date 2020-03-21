//
//  DSBlockchainIdentityKeyPathEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/29/19.
//
//

#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"
#import "DSKey.h"
#import "DSBlockchainIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityKeyPathEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityKeyPathEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSObject *path;
@property (nullable, nonatomic, retain) DSDerivationPathEntity *derivationPath;
@property (nullable, nonatomic, retain) DSBlockchainIdentityEntity *blockchainIdentity;
@property (nonatomic, assign) uint16_t keyType;
@property (nonatomic, assign) uint16_t keyStatus;
@property (nonatomic, assign) uint32_t keyID;
@property (nullable, nonatomic, retain) NSData *publicKeyData;

@end

@interface DSBlockchainIdentityKeyPathEntity (CoreDataGeneratedAccessors)

@end

NS_ASSUME_NONNULL_END
