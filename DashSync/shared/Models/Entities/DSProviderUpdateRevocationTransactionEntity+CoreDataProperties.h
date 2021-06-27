//
//  DSProviderUpdateRevocationTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 2/26/19.
//
//

#import "DSProviderUpdateRevocationTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSProviderUpdateRevocationTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSProviderUpdateRevocationTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *payloadSignature;
@property (nonatomic, assign) uint16_t reason;
@property (nullable, nonatomic, retain) NSData *providerRegistrationTransactionHash;
@property (nullable, nonatomic, retain) DSLocalMasternodeEntity *localMasternode;

@end

NS_ASSUME_NONNULL_END
