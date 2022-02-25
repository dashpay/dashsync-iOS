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

    [self setupDevnetWithId:@"malort"];
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
- (void)setupKrupnik {
    NSArray<NSString *> *addresses = @[@"34.210.237.116"];
    NSMutableOrderedSet<NSString *> *insertedIPAddresses = [NSMutableOrderedSet orderedSetWithArray:addresses];
    NSString *chainID = [NSString stringWithFormat:@"devnet-%@", @"krupnik"];
    uint32_t protocolVersion = 70219;
    uint32_t minProtocolVersion = 70219;
    NSString *sporkAddress = @"yPBtLENPQ6Ri1R7SyjevvvyMdopdFJUsRo";
    NSString *sporkPrivateKey = @"cW4VFwXvjAJusUyygeiCCf2CjnHGEpVkybp7Njg9j2apUZutFyAQ";
    uint32_t dashdPort = 20001;
    uint32_t minimumDifficultyBlocks = 1000000;

    uint32_t dapiJRPCPort = DEVNET_DAPI_JRPC_STANDARD_PORT;
    uint32_t dapiGRPCPort = DEVNET_DAPI_GRPC_STANDARD_PORT;
    uint32_t instantSendLockQuorumType = DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE;
    uint32_t chainLockQuorumType = DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE;
    uint32_t platformQuorumType = DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE;
    UInt256 dpnsContractID = UINT256_ZERO;
    UInt256 dashpayContractID = UINT256_ZERO;

    NSArray<DSChain *> *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    DSChain *chain = nil;
    for (DSChain *devnetChain in devnetChains) {
        if ([devnetChain.name isEqualToString:chainID]) {
            chain = devnetChain;
            break;
        }
    }
    if (chain) {
        [[DSChainsManager sharedInstance] updateDevnetChain:chain forServiceLocations:insertedIPAddresses withMinimumDifficultyBlocks:minimumDifficultyBlocks standardPort:dashdPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey instantSendLockQuorumType:instantSendLockQuorumType chainLockQuorumType:chainLockQuorumType platformQuorumType:platformQuorumType];
    } else {
        [[DSChainsManager sharedInstance] registerDevnetChainWithIdentifier:chainID forServiceLocations:insertedIPAddresses withMinimumDifficultyBlocks:minimumDifficultyBlocks standardPort:dashdPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey instantSendLockQuorumType:instantSendLockQuorumType chainLockQuorumType:chainLockQuorumType platformQuorumType:platformQuorumType];
    }
}

- (void)setupDevnetWithId:(NSString *)identifier {
    //    NSArray<NSString *> *addresses = @[
    //        @"18.237.252.92",
    //        @"54.70.175.91",
    //        @"18.237.141.114",
    //        @"52.27.98.239",
    //        @"34.222.107.24",
    //        @"35.89.13.46",
    //        @"52.35.109.107",
    //        @"35.166.27.56",
    //        @"34.221.125.132",
    //        @"35.88.254.151",
    //        @"54.191.254.244",
    //        @"54.186.19.51",
    //        @"34.208.33.201",
    //        @"54.190.191.15",
    //        @"54.202.226.206",
    //        @"35.161.52.77",
    //        @"34.216.132.145",
    //        @"54.202.203.197",
    //        @"54.202.7.31",
    //        @"54.191.61.174",
    //        @"34.221.198.190",
    //        @"52.39.21.163",
    //        @"35.87.152.197",
    //        @"52.33.50.210",
    //        @"34.220.186.181",
    //        @"54.218.97.70",
    //        @"54.149.225.130",
    //        @"54.202.57.238",
    //        @"52.32.176.236",
    //        @"54.189.76.182",
    //        @"35.87.102.5",
    //    ];
    //    NSArray<NSString *> *addresses = @[
    //        @"35.87.82.87",
    //        @"52.42.154.157",
    //        @"52.11.185.242",
    //        @"54.184.87.141",
    //        @"54.201.188.15",
    //        @"54.189.24.195",
    //        @"54.186.154.71",
    //        @"34.210.88.30",
    //        @"18.237.201.80",
    //        @"54.191.157.233",
    //        @"52.11.29.182",
    //        @"18.237.134.48",
    //        @"54.188.47.140",
    //        @"35.87.213.85",
    //        @"52.37.54.4",
    //        @"34.222.0.41",
    //        @"34.213.235.240",
    //        @"54.70.58.217",
    //        @"34.213.3.43",
    //        @"54.71.64.108",
    //        @"34.221.116.72",
    //        @"54.202.3.151",
    //        @"34.220.150.226",
    //        @"34.212.137.236",
    //        @"34.222.43.203",
    //        @"54.203.114.28",
    //        @"54.149.208.129",
    //        @"52.41.124.138",
    //        @"35.162.139.6",
    //        @"54.189.5.184",
    //        @"54.212.206.221",
    //    ];

    NSArray<NSString *> *addresses = @[
        @"35.87.82.87"
        //        masternode-2 ansible_user='ubuntu' ansible_host=52.42.154.157 public_ip=52.42.154.157 private_ip=10.0.32.68
        //        masternode-3 ansible_user='ubuntu' ansible_host=52.11.185.242 public_ip=52.11.185.242 private_ip=10.0.62.100
        //        masternode-4 ansible_user='ubuntu' ansible_host=54.184.87.141 public_ip=54.184.87.141 private_ip=10.0.29.164
        //        masternode-5 ansible_user='ubuntu' ansible_host=54.201.188.15 public_ip=54.201.188.15 private_ip=10.0.41.249
        //        masternode-6 ansible_user='ubuntu' ansible_host=54.189.24.195 public_ip=54.189.24.195 private_ip=10.0.56.248
        //        masternode-7 ansible_user='ubuntu' ansible_host=54.186.154.71 public_ip=54.186.154.71 private_ip=10.0.21.81
        //        masternode-8 ansible_user='ubuntu' ansible_host=34.210.88.30 public_ip=34.210.88.30 private_ip=10.0.38.111
        //        masternode-9 ansible_user='ubuntu' ansible_host=18.237.201.80 public_ip=18.237.201.80 private_ip=10.0.58.104
    ];


    NSMutableOrderedSet<NSString *> *insertedIPAddresses = [NSMutableOrderedSet orderedSetWithArray:addresses];
    NSString *chainID = [NSString stringWithFormat:@"devnet-%@", identifier];
    uint32_t protocolVersion = 70220;
    uint32_t minProtocolVersion = 70219;
    //    NSString *sporkAddress = @"yZeZhBYxmxVkoKHsgGxbzj8snbU17DYeZJ";
    //    NSString *sporkPrivateKey = nil;
    NSString *sporkAddress = @"yZeZhBYxmxVkoKHsgGxbzj8snbU17DYeZJ";
    NSString *sporkPrivateKey = @"cSXWyRC3TtPyLhKuegihZ7wDoFjN71nLU4PbgjdvwSRbvPbyMVz6";

    uint32_t dashdPort = 20001;
    uint32_t minimumDifficultyBlocks = 1000000;

    uint32_t dapiJRPCPort = DEVNET_DAPI_JRPC_STANDARD_PORT;
    uint32_t dapiGRPCPort = DEVNET_DAPI_GRPC_STANDARD_PORT;
    uint32_t instantSendLockQuorumType = DEVNET_ISLOCK_DEFAULT_QUORUM_TYPE;
    uint32_t chainLockQuorumType = DEVNET_CHAINLOCK_DEFAULT_QUORUM_TYPE;
    uint32_t platformQuorumType = DEVNET_PLATFORM_DEFAULT_QUORUM_TYPE;
    UInt256 dpnsContractID = UINT256_ZERO;
    UInt256 dashpayContractID = UINT256_ZERO;

    NSArray<DSChain *> *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    DSChain *malortChain = nil;
    for (DSChain *devnetChain in devnetChains) {
        if ([devnetChain.name isEqualToString:chainID]) {
            malortChain = devnetChain;
            break;
        }
    }

    if (malortChain) {
        [[DSChainsManager sharedInstance] updateDevnetChain:malortChain forServiceLocations:insertedIPAddresses withMinimumDifficultyBlocks:minimumDifficultyBlocks standardPort:dashdPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey instantSendLockQuorumType:instantSendLockQuorumType chainLockQuorumType:chainLockQuorumType platformQuorumType:platformQuorumType];
    } else {
        [[DSChainsManager sharedInstance] registerDevnetChainWithIdentifier:chainID forServiceLocations:insertedIPAddresses withMinimumDifficultyBlocks:minimumDifficultyBlocks standardPort:dashdPort dapiJRPCPort:dapiJRPCPort dapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID dashpayContractID:dashpayContractID protocolVersion:protocolVersion minProtocolVersion:minProtocolVersion sporkAddress:sporkAddress sporkPrivateKey:sporkPrivateKey instantSendLockQuorumType:instantSendLockQuorumType chainLockQuorumType:chainLockQuorumType platformQuorumType:platformQuorumType];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
