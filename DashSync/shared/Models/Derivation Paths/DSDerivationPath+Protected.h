//
//  DSDerivationPath+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSAccount.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSBlockchainIdentity.h"
#import "DSChain.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSKeySequence.h"
#import "DSPeerManager.h"
#import "DSPriceManager.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSString+Dash.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSDerivationPath ()

@property (nonatomic, assign) BOOL addressesLoaded;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSMutableSet *mAllAddresses, *mUsedAddresses;
//@property (nonatomic, strong) DSKey *extendedPublicKey; //master public key used to generate wallet addresses
@property (nonatomic, assign) OpaqueKey *extendedPublicKey; //master public key used to generate wallet addresses
@property (nonatomic, strong) NSString *standaloneExtendedPublicKeyUniqueID;
@property (nonatomic, weak) DSWallet *wallet;
@property (nonatomic, nullable, readonly) NSString *standaloneExtendedPublicKeyLocationString;
@property (nonatomic, readonly) DSDerivationPathEntity *derivationPathEntity;

- (DSDerivationPathEntity *)derivationPathEntityInContext:(NSManagedObjectContext *)context;
- (NSData *)indexPathToData;

//- (DerivationPathData *)ffi_malloc;
//+ (void)ffi_free:(DerivationPathData *)path;

@end

NS_ASSUME_NONNULL_END
