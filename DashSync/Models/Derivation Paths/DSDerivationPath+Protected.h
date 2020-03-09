//
//  DSDerivationPath+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSAccount.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSBLSKey.h"
#import "DSBlockchainIdentity.h"
#import "DSChain.h"
#import "DSDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSECDSAKey.h"
#import "DSKeySequence.h"
#import "DSPeerManager.h"
#import "DSPriceManager.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "DSWallet.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSString+Dash.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSDerivationPath ()

@property (nonatomic, assign) BOOL addressesLoaded;
@property (nonatomic, strong) NSManagedObjectContext *moc;
@property (nonatomic, strong) NSMutableSet *mAllAddresses, *mUsedAddresses;
@property (nonatomic, strong) NSData *extendedPublicKey; //master public key used to generate wallet addresses
@property (nonatomic, strong) NSString *standaloneExtendedPublicKeyUniqueID;
@property (nonatomic, weak) DSWallet *wallet;
@property (nonatomic, readonly) NSString *standaloneExtendedPublicKeyLocationString;
@property (nonatomic, readonly) DSDerivationPathEntity *derivationPathEntity;


@end

NS_ASSUME_NONNULL_END
