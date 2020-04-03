//
//  DSDerivationPath+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSECDSAKey.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSPeerManager.h"
#import "DSKeySequence.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "DSPriceManager.h"
#import "NSString+Bitcoin.h"
#import "NSString+Dash.h"
#import "NSData+Bitcoin.h"
#import "DSBlockchainIdentity.h"
#import "DSBLSKey.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSDerivationPath ()

@property (nonatomic, assign) BOOL addressesLoaded;
@property (nonatomic, strong) NSManagedObjectContext * moc;
@property (nonatomic, strong) NSMutableSet *mAllAddresses, *mUsedAddresses;
@property (nonatomic, strong) NSData * extendedPublicKey;//master public key used to generate wallet addresses
@property (nonatomic, strong) NSString * standaloneExtendedPublicKeyUniqueID;
@property (nonatomic, weak) DSWallet * wallet;
@property (nonatomic, readonly) NSString * standaloneExtendedPublicKeyLocationString;
@property (nonatomic, readonly) DSDerivationPathEntity * derivationPathEntity;

-(BOOL)isHardenedAtPosition:(NSUInteger)position;

- (NSData *)generateExtendedECDSAPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId storePrivateKey:(BOOL)storePrivateKey;

- (NSData *)generateExtendedBLSPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId storePrivateKey:(BOOL)storePrivateKey;


@end

NS_ASSUME_NONNULL_END
