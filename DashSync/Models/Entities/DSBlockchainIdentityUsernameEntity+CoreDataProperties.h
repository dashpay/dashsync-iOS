//
//  DSBlockchainIdentityUsernameEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 1/31/20.
//
//

#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityUsernameEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityUsernameEntity *> *)fetchRequest;

@property (nonatomic, assign) uint16_t status;
@property (nullable, nonatomic, copy) NSString *stringValue;
@property (nullable, nonatomic, copy) NSString *domain;
@property (nullable, nonatomic, retain) DSBlockchainIdentityEntity *blockchainIdentity;
@property (nullable, nonatomic, retain) NSData *salt;

@end

NS_ASSUME_NONNULL_END
