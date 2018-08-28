//
//  DSBlockchainUserRegistrationTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainUserRegistrationTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainUserRegistrationTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserRegistrationTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *username;
@property (nullable, nonatomic, retain) NSData * publicKey;
@property (nullable, nonatomic, retain) NSData * payloadSignature;

@end

NS_ASSUME_NONNULL_END
