//
//  DSProviderUpdateRegistrarTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 2/22/19.
//
//

#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSProviderUpdateRegistrarTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSProviderUpdateRegistrarTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *operatorKey;
@property (nullable, nonatomic, retain) NSData *payloadSignature;
@property (assign, nonatomic) uint16_t providerMode;
@property (nullable, nonatomic, retain) NSData *scriptPayout;
@property (nullable, nonatomic, retain) NSData *votingKeyHash;
@property (nullable, nonatomic, retain) NSData *providerRegistrationTransactionHash;
@property (nullable, nonatomic, retain) DSLocalMasternodeEntity *localMasternode;

@end

NS_ASSUME_NONNULL_END
