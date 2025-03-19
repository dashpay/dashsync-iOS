//
//  DSDerivationPath+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSWallet.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSDerivationPath ()

@property (nonatomic, assign) BOOL addressesLoaded;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSMutableSet *mAllAddresses, *mUsedAddresses;
@property (nonatomic, assign) DMaybeOpaqueKey *extendedPublicKey; //master public key used to generate wallet addresses
@property (nonatomic, strong) NSString *standaloneExtendedPublicKeyUniqueID;
@property (nonatomic, weak) DSWallet *wallet;
@property (nonatomic, nullable, readonly) NSString *standaloneExtendedPublicKeyLocationString;
//@property (nonatomic, readonly) DSDerivationPathEntity *derivationPathEntity;
@property (nonatomic, strong, readonly) NSData *extendedPrivateKeyData;

//- (DSDerivationPathEntity *)derivationPathEntityInContext:(NSManagedObjectContext *)context;
- (NSString *)walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:(NSString *)uniqueID;
- (NSString *)createIdentifierForDerivationPath;

@end

NS_ASSUME_NONNULL_END
