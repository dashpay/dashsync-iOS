//
//  DSDerivationPath+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSKey.h"
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
#import "DSBlockchainUser.h"
#import "DSBLSKey.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSDerivationPath ()

@property (nonatomic, assign) BOOL addressesLoaded;
@property (nonatomic, strong) NSManagedObjectContext * moc;
@property (nonatomic, strong) NSMutableSet *mAllAddresses, *mUsedAddresses;
@property (nonatomic, weak) DSWallet * wallet;

@end

NS_ASSUME_NONNULL_END
