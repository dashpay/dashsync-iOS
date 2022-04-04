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

//    [self setupMalort];
//    [self setupKrupnik];
    [self setupOuzo];

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

- (void)setupOuzo {
    [self setupDevnetWithId:@"ouzo"
               sporkAddress:@"yVrSdGz3zZ8Z6PdzVPpNwNxhqrvNVdL81u"
            sporkPrivateKey:@"cMkAaT8o7JtefJgYgFC4DNnkqCEsohnXP74Bus7NdRiWPtnBPDym"
         minProtocolVersion:70221
            protocolVersion:70221
    minimumDifficultyBlocks:1000000
                  addresses:@[
        @"34.221.94.83",
        @"34.221.70.69",
        @"35.89.29.155",
        @"54.190.194.157",
        @"54.184.255.44",
        @"54.214.229.204",
        @"34.221.97.191",
        @"34.219.183.187",
        @"35.88.98.155",
        @"18.237.102.196",
        @"34.220.157.25",
    ]];
}

- (void)setupMalort {
    [self setupDevnetWithId:@"malort"
               sporkAddress:@"yZeZhBYxmxVkoKHsgGxbzj8snbU17DYeZJ"
            sporkPrivateKey:@"cSXWyRC3TtPyLhKuegihZ7wDoFjN71nLU4PbgjdvwSRbvPbyMVz6"
         minProtocolVersion:70221
            protocolVersion:70221
    minimumDifficultyBlocks:1000000
                  addresses:@[
        @"52.34.31.147",
        @"54.213.61.252",
        @"54.191.120.117",
        @"35.86.78.201",
        @"34.220.179.78",
        @"18.236.74.161",
        @"35.163.44.16",
        @"34.219.164.241",
        @"54.245.45.230",
        @"54.218.218.68",
        @"35.86.99.55",
        @"34.217.14.74",
        @"34.219.133.182",
        @"34.222.44.72",
        @"52.42.109.114",
        @"34.211.251.202",
        @"35.85.138.28",
        @"54.218.194.139",
        @"54.185.21.63",
        @"34.217.73.50",
        @"18.236.137.97",
        @"52.33.161.97",
        @"34.220.123.102",
        @"54.187.182.77",
        @"34.209.126.0",
        @"35.163.107.163",
        @"54.245.152.61",
        @"52.24.238.164",
        @"54.188.107.79",
        @"54.213.192.216",
        @"35.86.149.148",
        @"54.190.193.121",
        @"52.43.73.71",
        @"35.87.20.54",
        @"34.219.58.173",
        @"54.202.151.84",
        @"34.219.75.221",
        @"54.202.207.208",
        @"34.220.211.198",
        @"54.244.57.1",
        @"34.220.186.10",
        @"34.220.123.29",
        @"35.165.178.67",
        @"54.186.65.28",
        @"35.87.81.221",
        @"34.216.175.122",
        @"54.189.165.128",
        @"34.213.130.133",
        @"54.201.217.127",
        @"54.244.199.173",
        @"54.212.32.236",
        @"18.236.98.67",
        @"34.220.197.17",
        @"52.35.69.248",
        @"34.221.97.12",
        @"52.11.173.127",
        @"52.36.61.61",
        @"34.209.213.128",
        @"54.214.77.189",
        @"54.149.120.130",
        @"54.244.174.171",
        @"35.85.42.157",
        @"54.191.137.89",
        @"54.186.188.65",
        @"52.34.55.6",
        @"52.13.174.225",
        @"54.202.150.18",
        @"35.85.156.176",
        @"54.191.155.214",
        @"54.245.222.76",
        @"35.89.18.145",
        @"52.39.14.21",
        @"35.85.144.176",
        @"34.208.98.219",
        @"34.219.154.153",
        @"34.217.45.208",
        @"54.202.83.5",
        @"54.218.2.2",
        @"34.214.98.30",
        @"35.86.137.144",
        @"34.219.178.212",
        @"34.217.91.253",
        @"34.208.56.172",
        @"52.43.12.114",
        @"54.245.35.160",
        @"52.12.65.37",
        @"52.33.181.36",
        @"34.217.78.109",
        @"34.209.59.11",
        @"34.222.139.115",
        @"35.86.125.32",
        @"34.217.14.71",
        @"35.87.147.43",
        @"34.221.170.109",
        @"34.208.204.117",
        @"35.87.78.165",
        @"34.220.148.191",
        @"54.201.216.109",
        @"54.202.202.166",
        @"54.190.57.236",
        @"18.236.131.99",
        @"54.201.155.183",
        @"54.203.182.111",
        @"54.149.168.162",
        @"35.87.4.127",
        @"52.10.161.70",
        @"34.208.17.38",
        @"52.13.8.133",
        @"52.25.163.168",
        @"35.86.149.245",
        @"52.25.167.202",
        @"34.222.9.55",
        @"34.215.165.165",
        @"52.27.116.102",
        @"54.202.18.66",
        @"52.39.47.246",
        @"34.220.205.71",
        @"52.38.59.142",
        @"54.191.251.160",
        @"34.222.46.23",
        @"34.208.178.237",
        @"34.222.160.48",
        @"35.167.117.204",
        @"34.208.78.45",
        @"34.220.166.106",
        @"18.236.166.127",
        @"34.217.40.250",
        @"54.190.18.139",
        @"18.237.106.197",
        @"34.221.168.125",
        @"35.86.247.41",
        @"54.244.68.224",
        @"54.244.4.235",
        @"54.202.80.189",
        @"34.213.170.7",
        @"35.87.183.85",
        @"54.69.174.96",
        @"54.189.170.31",
        @"35.87.51.235",
        @"54.244.156.217",
        @"35.86.101.10",
        @"52.27.38.147",
        @"54.71.74.28",
        @"34.214.133.253",
        @"54.200.9.115",
        @"34.217.63.51",
        @"54.189.154.233",
        @"35.86.77.58",
        @"18.236.145.86",
        @"52.32.100.38",
        @"54.188.34.255",
        @"54.244.74.59",
        @"35.86.112.165",
        @"54.149.160.155",
        @"35.87.97.63",
        @"34.219.143.118",
        @"35.86.92.210",
        @"54.244.173.193",
        @"35.86.91.184",
        @"54.200.250.215",
        @"35.86.82.140",
        @"54.187.0.153",
        @"54.203.55.220",
        @"34.213.44.14",
        @"18.236.176.244",
        @"34.222.144.163",
        @"34.217.4.182",
        @"52.13.113.11",
        @"18.236.170.147",
        @"54.244.61.21",
        @"34.219.158.122",
        @"34.216.149.154",
        @"54.201.178.136",
        @"54.191.51.201",
        @"34.213.36.85",
        @"18.237.101.254",
        @"54.201.114.17",
        @"54.201.137.238",
        @"35.88.159.80",
        @"34.217.73.156",
        @"52.43.22.92",
        @"54.214.110.151",
        @"34.216.142.124",
        @"34.220.148.180",
        @"34.221.147.7",
        @"35.160.210.241",
        @"35.87.41.220",
        @"34.217.81.77",
        @"34.218.234.78",
        @"54.191.86.204",
        @"54.212.24.21",
        @"18.237.71.5",
        @"54.218.47.18",
        @"35.164.193.45",
        @"35.86.164.67",
        @"35.163.3.253",
        @"35.87.114.110",
        @"18.237.79.227",
        @"54.186.161.115",
        @"34.219.10.20",
    ]];
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
