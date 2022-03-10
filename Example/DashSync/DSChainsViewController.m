//
//  DSChainsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSChainsViewController.h"
#import "DSAddDevnetViewController.h"
#import "DSChainTableViewCell.h"
#import "DSSyncViewController.h"
#import <DashSync/DashSync.h>

@interface DSChainsViewController ()

@property (strong, nonatomic) id addChainsObserver;

@end

@implementation DSChainsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    //    NSArray *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    //    for (DSChain *chain in devnetChains) {
    //        [[DSChainsManager sharedInstance] removeDevnetChain:chain];
    //    }

    [self setupMalort];
    [self setupKrupnik];

    [self.tableView reloadData];

    self.addChainsObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainsDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          NSLog(@"Added/removed a chain");
                                                          [self.tableView reloadData];
                                                      }];
}

- (void)setupMalort {
    [self setupDevnetWithId:@"malort"
                   //               sporkAddress:@"yjPtiKh2uwk3bDutTEA2q9mCtXyiZRWn55"
                   sporkAddress:@"yZeZhBYxmxVkoKHsgGxbzj8snbU17DYeZJ"
                sporkPrivateKey:@"cSXWyRC3TtPyLhKuegihZ7wDoFjN71nLU4PbgjdvwSRbvPbyMVz6"
             minProtocolVersion:70219
                protocolVersion:70220
        minimumDifficultyBlocks:1000000
                      addresses:@[@"52.42.154.157", @"52.11.185.242"]];
}

- (void)setupKrupnik {
    [self setupDevnetWithId:@"krupnik"
                   sporkAddress:@"yPBtLENPQ6Ri1R7SyjevvvyMdopdFJUsRo"
                sporkPrivateKey:@"cW4VFwXvjAJusUyygeiCCf2CjnHGEpVkybp7Njg9j2apUZutFyAQ"
             minProtocolVersion:70219
                protocolVersion:70220
        minimumDifficultyBlocks:2200
                      addresses:@[
                          @"4.210.237.116",
                          @"54.69.65.231",
                          @"54.185.90.95",
                          @"54.186.234.0",
                          @"35.87.212.139",
                          @"34.212.52.44",
                          @"34.217.47.197",
                          @"34.220.79.131",
                          @"18.237.212.176",
                          @"54.188.17.188",
                          @"34.210.1.159",
                      ]];
}

- (void)setupDevnetWithId:(NSString *)identifier
               sporkAddress:(NSString *)sporkAddress
            sporkPrivateKey:(NSString *)sporkPrivateKey
         minProtocolVersion:(uint32_t)minProtocolVersion
            protocolVersion:(uint32_t)protocolVersion
    minimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks
                  addresses:(NSArray<NSString *> *)addresses {
    NSString *chainID = [NSString stringWithFormat:@"devnet-%@", identifier];
    NSMutableOrderedSet<NSString *> *insertedIPAddresses = [NSMutableOrderedSet orderedSetWithArray:addresses];
    NSArray<DSChain *> *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    DSChain *chain = nil;
    for (DSChain *devnetChain in devnetChains) {
        if ([devnetChain.devnetIdentifier isEqualToString:chainID]) {
            chain = devnetChain;
            break;
        }
    }
    uint32_t dashdPort = 20001;
    uint32_t dapiJRPCPort = DEVNET_DAPI_JRPC_STANDARD_PORT;
    uint32_t dapiGRPCPort = DEVNET_DAPI_GRPC_STANDARD_PORT;
    uint32_t instantSendLockQuorumType = DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE;
    uint32_t chainLockQuorumType = DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE;
    uint32_t platformQuorumType = DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE;
    UInt256 dpnsContractID = UINT256_ZERO;
    UInt256 dashpayContractID = UINT256_ZERO;
    uint32_t version = 1;

    if (chain) {
        [[DSChainsManager sharedInstance] updateDevnetChain:chain version:version forServiceLocations:insertedIPAddresses withMinimumDifficultyBlocks:minimumDifficultyBlocks standardPort:dashdPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey instantSendLockQuorumType:instantSendLockQuorumType chainLockQuorumType:chainLockQuorumType platformQuorumType:platformQuorumType];
    } else {
        [[DSChainsManager sharedInstance] registerDevnetChainWithIdentifier:chainID version:0 forServiceLocations:insertedIPAddresses withMinimumDifficultyBlocks:minimumDifficultyBlocks standardPort:dashdPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey instantSendLockQuorumType:instantSendLockQuorumType chainLockQuorumType:chainLockQuorumType platformQuorumType:platformQuorumType];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2 + [[[DSChainsManager sharedInstance] devnetChains] count];
}

- (DSChain *)chainForIndex:(NSInteger)index {
    if (index == 0) return [DSChain mainnet];
    if (index == 1) return [DSChain testnet];
    NSInteger devnetIndex = index - 2;
    NSArray *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    return [devnetChains objectAtIndex:devnetIndex];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSChainTableViewCell *cell = (DSChainTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"chainTableViewCell" forIndexPath:indexPath];
    DSChain *chain = [self chainForIndex:indexPath.row];
    if (cell) {
        cell.chainNameLabel.text = chain.name;
    }

    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row > 1;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"Delete"
                                                                             handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView, void (^_Nonnull completionHandler)(BOOL)) {
                                                                                 DSChain *chain = [self chainForIndex:indexPath.row];
                                                                                 [[DSChainsManager sharedInstance] removeDevnetChain:chain];
                                                                             }];
    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:@"Edit"
                                                                           handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView, void (^_Nonnull completionHandler)(BOOL)) {
                                                                               [self performSegueWithIdentifier:@"AddDevnetSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
                                                                           }];
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, editAction]];
    config.performsFirstActionWithFullSwipe = false;
    return config;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    UITableViewCell *cell = (UITableViewCell *)sender;
    NSInteger index = [self.tableView indexPathForCell:cell].row;
    if ([segue.identifier isEqualToString:@"ChainDetailsSegue"]) {
        DSSyncViewController *syncViewController = (DSSyncViewController *)segue.destinationViewController;
        DSChain *chain = [self chainForIndex:index];
        [[DSVersionManager sharedInstance] upgradeExtendedKeysForWallets:chain.wallets
                                                             withMessage:@"Upgrade keys"
                                                          withCompletion:^(BOOL success, BOOL neededUpgrade, BOOL authenticated, BOOL cancelled){

                                                          }];
        syncViewController.chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        syncViewController.title = chain.name;
    } else if ([segue.identifier isEqualToString:@"AddDevnetSegue"]) {
        if ([sender isKindOfClass:[UITableViewCell class]]) {
            DSAddDevnetViewController *addDevnetViewController = (DSAddDevnetViewController *)((UINavigationController *)segue.destinationViewController).topViewController;
            DSChain *chain = [self chainForIndex:index];
            addDevnetViewController.chain = chain;
        }
    }
}


@end
