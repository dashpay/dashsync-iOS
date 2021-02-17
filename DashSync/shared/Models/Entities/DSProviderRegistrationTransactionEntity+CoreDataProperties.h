//
//  DSProviderRegistrationTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//
//

#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSProviderRegistrationTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSProviderRegistrationTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *payloadSignature;
@property (nonatomic, assign) uint16_t providerType;
@property (nonatomic, assign) uint16_t providerMode;
@property (nullable, nonatomic, retain) NSData *collateralOutpoint;
@property (nullable, nonatomic, retain) NSData *ipAddress;
@property (nonatomic, assign) uint16_t port;
@property (nullable, nonatomic, retain) NSData *ownerKeyHash;
@property (nullable, nonatomic, retain) NSData *operatorKey;
@property (nullable, nonatomic, retain) NSData *votingKeyHash;
@property (nonatomic, assign) uint16_t operatorReward;
@property (nullable, nonatomic, retain) NSData *scriptPayout;
@property (nullable, nonatomic, retain) DSLocalMasternodeEntity *localMasternode;

@end

NS_ASSUME_NONNULL_END
