//
//  ViewController.m
//  H250729TCPDemo
//
//  Created by hwacdx on 2025/7/29.
//

#import "ViewController.h"
#import "TCPServerViewController.h"
#import "TCPClientViewController.h"
#import "HWTestCrashed.h"

@interface ViewController ()

@property (strong, nonatomic) TCPClientViewController *clientVC;
@property (strong, nonatomic) TCPServerViewController *serverVC;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    //test 25.10.22
    HWTestCrashed *test = [HWTestCrashed new];
    [test test2];
}

- (TCPClientViewController *)clientVC {
    if (!_clientVC) {
        _clientVC = [[TCPClientViewController alloc] init];
    }
    return _clientVC;
}

- (TCPServerViewController *)serverVC {
    if (!_serverVC) {
        _serverVC = [[TCPServerViewController alloc] init];
    }
    return _serverVC;
}

- (IBAction)serverClick:(id)sender {
    
    [self.navigationController pushViewController:self.serverVC animated:YES];
}

- (IBAction)clientClick:(id)sender {
    
    [self.navigationController pushViewController:self.clientVC animated:YES];
}


@end
