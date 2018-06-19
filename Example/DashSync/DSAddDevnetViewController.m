//
//  DSAddDevnetViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/19/18.
//  Copyright © 2018 Andrew Podkovyrin. All rights reserved.
//

#import "DSAddDevnetViewController.h"
#import "DSAddDevnetNameTableViewCell.h"
#import "DSAddDevnetIPAddressTableViewCell.h"
#import "DSAddDevnetAddIPAddressTableViewCell.h"
#import <DashSync/DashSync.h>

@interface DSAddDevnetViewController ()

@property (nonatomic,strong) NSMutableArray<NSString*> * insertedIPAddresses;
@property (nonatomic,strong) DSAddDevnetNameTableViewCell * addDevnetNameTableViewCell;
@property (nonatomic,strong) DSAddDevnetAddIPAddressTableViewCell * addDevnetAddIPAddressTableViewCell;
@property (nonatomic,strong) DSAddDevnetIPAddressTableViewCell * activeAddDevnetIPAddressTableViewCell;

@end

@implementation DSAddDevnetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.insertedIPAddresses = [NSMutableArray array];
    self.addDevnetNameTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetNameCellIdentifier"];
    self.addDevnetAddIPAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"DevnetAddIPCellIdentifier"];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// MARK:- Table View Data Source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!section) return 1;
    else return 2 + _insertedIPAddresses.count;
}

-(DSAddDevnetIPAddressTableViewCell*)IPAddressCellAtIndex:(NSUInteger)index {
    static NSString * CellIdentifier = @"DevnetIPCellIdentifier";
    DSAddDevnetIPAddressTableViewCell * addDevnetIPAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (index < _insertedIPAddresses.count) {
        addDevnetIPAddressTableViewCell.IPAddressTextField.text = [_insertedIPAddresses objectAtIndex:index];
    } else {
        addDevnetIPAddressTableViewCell.IPAddressTextField.text = @"";
    }
    addDevnetIPAddressTableViewCell.IPAddressTextField.delegate = self;
    return addDevnetIPAddressTableViewCell;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath.section) return self.addDevnetNameTableViewCell;
    if (indexPath.row == _insertedIPAddresses.count + 1) return self.addDevnetAddIPAddressTableViewCell;
    return [self IPAddressCellAtIndex:indexPath.row];
}

// MARK:- Table View Data Delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section && indexPath.row == _insertedIPAddresses.count + 1) {
        if (self.activeAddDevnetIPAddressTableViewCell) {
            NSIndexPath * activeIndexPath = [self.tableView indexPathForCell:self.activeAddDevnetIPAddressTableViewCell];
            if (activeIndexPath.row == indexPath.row - 1) {
                [self.tableView beginUpdates];
                [self.insertedIPAddresses addObject:self.activeAddDevnetIPAddressTableViewCell.IPAddressTextField.text];
                [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:_insertedIPAddresses.count inSection:1]] withRowAnimation:UITableViewRowAnimationTop];
                [self.tableView endUpdates];
            }
        }
    }
}

// MARK:- Text Field Delegate

-(void)textFieldDidBeginEditing:(UITextField *)textField {
    for (UITableViewCell * tableViewCell in self.tableView.visibleCells) {
        if ([tableViewCell isMemberOfClass:[DSAddDevnetIPAddressTableViewCell class]]) {
            DSAddDevnetIPAddressTableViewCell * addDevnetIPAddressTableViewCell = (DSAddDevnetIPAddressTableViewCell *)tableViewCell;
            if (addDevnetIPAddressTableViewCell.IPAddressTextField == textField) {
                self.activeAddDevnetIPAddressTableViewCell = addDevnetIPAddressTableViewCell;
            }
        }
    }
}

// MARK:- Navigation

-(void)showError:(NSString*)errorMessage {
    
}

-(IBAction)save {
    NSString * identifier = self.addDevnetNameTableViewCell.identifierTextField.text;
    
    DSChain * chain = [[DSChainManager sharedInstance] registerDevnetChainWithIdentifier:identifier forServiceLocations:self.insertedIPAddresses withStandardPort:12999];
    //[DSChain chain]
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

-(IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
