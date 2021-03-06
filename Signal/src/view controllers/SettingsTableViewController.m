//
//  SettingsTableViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 03/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "SettingsTableViewController.h"

#import "Environment.h"
#import "PropertyListPreferences.h"
#import "TSAccountManager.h"
#import "UIUtil.h"

#import "RPServerRequestsManager.h"

#import "TSSocketManager.h"

#import "OWSContactsManager.h"

#import "AboutTableViewController.h"
#import "AdvancedSettingsTableViewController.h"
#import "NotificationSettingsViewController.h"
#import "PrivacySettingsTableViewController.h"
#import "PushManager.h"

#define kProfileCellHeight 87.0f
#define kStandardCellHeight 44.0f

#define kNumberOfSections 4

#define kRegisteredNumberRow 0
#define kPrivacyRow 0
#define kNotificationRow 1
#define kAdvancedRow 3
#define kAboutRow 4
#define kNetworkRow 0
#define kUnregisterRow 0

typedef enum {
    kRegisteredRows = 1,
    kGeneralRows = 5,
    kNetworkStatusRows = 1,
    kUnregisterRows = 1,
} kRowsForSection;

typedef enum {
    kRegisteredNumberSection = 0,
    kNetworkStatusSection    = 1,
    kGeneralSection          = 2,
    kUnregisterSection       = 3,
} kSection;

@interface SettingsTableViewController () <UIAlertViewDelegate>

@end

@implementation SettingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setHidesBackButton:YES];

    [self.navigationController.navigationBar setTranslucent:NO];

    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.registeredNumber.text =
        [PhoneNumber bestEffortFormatPartialUserSpecifiedTextToLookLikeAPhoneNumber:[TSAccountManager localNumber]];
    self.registeredName.text = NSLocalizedString(@"REGISTERED_NUMBER_TEXT", @"");

    [self initializeObserver];
    [TSSocketManager sendNotification];

    self.title = NSLocalizedString(@"SETTINGS_NAV_BAR_TITLE", @"Title for settings activity");
    self.networkStatusHeader.text = NSLocalizedString(@"NETWORK_STATUS_HEADER", @"");
    self.privacyLabel.text = NSLocalizedString(@"SETTINGS_PRIVACY_TITLE", @"");
    self.advancedLabel.text = NSLocalizedString(@"SETTINGS_ADVANCED_TITLE", @"");
    self.aboutLabel.text = NSLocalizedString(@"SETTINGS_ABOUT", @"");
    self.notificationsLabel.text = NSLocalizedString(@"SETTINGS_NOTIFICATIONS", nil);
    self.linkedDevicesLabel.text
        = NSLocalizedString(@"LINKED_DEVICES_TITLE", @"Menu item and navbar title for the device manager");
    [self.destroyAccountButton setTitle:NSLocalizedString(@"SETTINGS_DELETE_ACCOUNT_BUTTON", @"")
                               forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // HACK to unselect rows when swiping back
    // http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SocketOpenedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SocketClosedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SocketConnectingNotification object:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kNumberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case kRegisteredNumberSection:
            return kRegisteredRows;
        case kGeneralSection:
            return kGeneralRows;
        case kNetworkStatusSection:
            return kNetworkStatusRows;
        case kUnregisterSection:
            return kUnregisterRows;
        default:
            return 0;
    }
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case kGeneralSection: {
            switch (indexPath.row) {
                case kPrivacyRow: {
                    PrivacySettingsTableViewController *vc = [[PrivacySettingsTableViewController alloc] init];
                    NSAssert(self.navigationController != nil, @"Navigation controller must not be nil");
                    NSAssert(vc != nil, @"Privacy Settings View Controller must not be nil");
                    [self.navigationController pushViewController:vc animated:YES];
                    break;
                }
                case kNotificationRow: {
                    NotificationSettingsViewController *vc = [[NotificationSettingsViewController alloc] init];
                    [self.navigationController pushViewController:vc animated:YES];
                    break;
                }
                case kAdvancedRow: {
                    AdvancedSettingsTableViewController *vc = [[AdvancedSettingsTableViewController alloc] init];
                    NSAssert(self.navigationController != nil, @"Navigation controller must not be nil");
                    NSAssert(vc != nil, @"Advanced Settings View Controller must not be nil");
                    [self.navigationController pushViewController:vc animated:YES];
                    break;
                }
                case kAboutRow: {
                    AboutTableViewController *vc = [[AboutTableViewController alloc] init];
                    NSAssert(self.navigationController != nil, @"Navigation controller must not be nil");
                    NSAssert(vc != nil, @"About View Controller must not be nil");
                    [self.navigationController pushViewController:vc animated:YES];
                    break;
                }
                default:
                    break;
            }

            break;
        }

        case kNetworkStatusSection: {
            break;
        }

        case kUnregisterSection: {
            [self unregisterUser:nil];
            break;
        }

        default:
            break;
    }
}


- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case kNetworkStatusSection: {
            return NO;
        }

        case kUnregisterSection: {
            return NO;
        }

        default:
            return YES;
    }
}


- (IBAction)unregisterUser:(id)sender {
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:NSLocalizedString(@"CONFIRM_ACCOUNT_DESTRUCTION_TITLE", @"")
                                            message:NSLocalizedString(@"CONFIRM_ACCOUNT_DESTRUCTION_TEXT", @"")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"PROCEED_BUTTON", @"")
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
                                                        [self proceedToUnregistration];
                                                      }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)proceedToUnregistration {
    [TSAccountManager unregisterTextSecureWithSuccess:^{
      [Environment resetAppData];
    }
        failure:^(NSError *error) {
          SignalAlertView(NSLocalizedString(@"UNREGISTER_SIGNAL_FAIL", @""), @"");
        }];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kNetworkStatusSection) {
        UIAlertView *info = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"NETWORK_STATUS_HEADER", @"")
                                                       message:NSLocalizedString(@"NETWORK_STATUS_TEXT", @"")
                                                      delegate:self
                                             cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                             otherButtonTitles:nil];
        [info show];
    }
}

#pragma mark - Socket Status Notifications

- (void)initializeObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(socketDidOpen)
                                                 name:SocketOpenedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(socketDidClose)
                                                 name:SocketClosedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(socketIsConnecting)
                                                 name:SocketConnectingNotification
                                               object:nil];
}

- (void)socketDidOpen {
    self.networkStatusLabel.text      = NSLocalizedString(@"NETWORK_STATUS_CONNECTED", @"");
    self.networkStatusLabel.textColor = [UIColor ows_greenColor];
}

- (void)socketDidClose {
    self.networkStatusLabel.text      = NSLocalizedString(@"NETWORK_STATUS_OFFLINE", @"");
    self.networkStatusLabel.textColor = [UIColor ows_redColor];
}

- (void)socketIsConnecting {
    self.networkStatusLabel.text      = NSLocalizedString(@"NETWORK_STATUS_CONNECTING", @"");
    self.networkStatusLabel.textColor = [UIColor ows_yellowColor];
}

@end
