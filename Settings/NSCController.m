#import <UIKit/UIKit.h>
#import <Preferences/PSViewController.h>
#import "../NSCPaths.h"
#import "NSCSettings.h"

@interface NSCRootController : PSViewController <UITableViewDataSource,UITableViewDelegate>
@property(nonatomic,strong) UITableView *settingsTable;
@property(nonatomic,strong) UISwitch *enabledSwitch;
@end
@implementation NSCRootController
- (void)loadView {
    UIView *view=[UIView new];view.backgroundColor=UIColor.systemGroupedBackgroundColor;self.view=view;
    self.settingsTable=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.settingsTable.translatesAutoresizingMaskIntoConstraints=NO;
    self.settingsTable.dataSource=self;self.settingsTable.delegate=self;
    [view addSubview:self.settingsTable];
    [NSLayoutConstraint activateConstraints:@[
        [self.settingsTable.topAnchor constraintEqualToAnchor:view.topAnchor],
        [self.settingsTable.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        [self.settingsTable.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.settingsTable.trailingAnchor constraintEqualToAnchor:view.trailingAnchor]]];
    self.title=@"No Shutter & Screenshot Sounds";
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,320,132)];
    header.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    NSBundle *bundle=[NSBundle bundleForClass:self.class];
    UIImage *icon=[UIImage imageNamed:@"HeaderIcon" inBundle:bundle compatibleWithTraitCollection:nil];
    UIImageView *iconView=[[UIImageView alloc] initWithImage:icon];
    iconView.translatesAutoresizingMaskIntoConstraints=NO;
    iconView.contentMode=UIViewContentModeScaleAspectFit;
    iconView.layer.cornerRadius=18;iconView.clipsToBounds=YES;
    [header addSubview:iconView];
    [NSLayoutConstraint activateConstraints:@[
        [iconView.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [iconView.topAnchor constraintEqualToAnchor:header.topAnchor constant:24],
        [iconView.widthAnchor constraintEqualToConstant:88],
        [iconView.heightAnchor constraintEqualToConstant:88]]];
    self.settingsTable.tableHeaderView=header;
    UILabel *credits=[[UILabel alloc] initWithFrame:CGRectMake(0,0,320,70)];
    credits.text=@"No Shutter & Screenshot Sounds\nby sahinkaa";
    credits.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];credits.textColor=UIColor.secondaryLabelColor;
    credits.numberOfLines=0;credits.textAlignment=NSTextAlignmentCenter;
    self.settingsTable.tableFooterView=credits;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated];[self.settingsTable reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Silences the camera shutter and screenshot sounds whether the ringer switch is on or off. Settings apply immediately without a respring. Respring once after installation.";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text=@"Enabled";cell.selectionStyle=UITableViewCellSelectionStyleNone;
    UISwitch *control=[UISwitch new];control.on=NSCEnabledAtPath(NSCPath(NSCPreferenceFile));
    [control addTarget:self action:@selector(changeEnabled:) forControlEvents:UIControlEventValueChanged];
    self.enabledSwitch=control;cell.accessoryView=control;return cell;
}
- (void)changeEnabled:(UISwitch *)control {
    NSError *error=nil;
    if(NSCSaveEnabled(NSCPath(NSCPreferenceFile),control.on,&error)) return;
    control.on=NSCEnabledAtPath(NSCPath(NSCPreferenceFile));
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Settings were not saved" message:error.localizedDescription ?: @"Please try again." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
