//
//  DSProviderUpdateServiceTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//
//

#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSProviderUpdateServiceTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSProviderUpdateServiceTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *ipAddress;
@property (nullable, nonatomic, retain) NSData *payloadSignature;
@property (assign, nonatomic) uint16_t port;
@property (nullable, nonatomic, retain) NSData *scriptPayout;
@property (nullable, nonatomic, retain) NSData *providerRegistrationTransactionHash;
@property (nullable, nonatomic, retain) DSLocalMasternodeEntity *localMasternode;

@end

NS_ASSUME_NONNULL_END
