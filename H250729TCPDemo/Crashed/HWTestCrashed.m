//
//  HWTestCrashed.m
//  H250729TCPDemo
//
//  Created by hwacdx on 2025/10/23.
//

#import "HWTestCrashed.h"

@implementation HWTestCrashed

- (void)test2 {
    
    //1 野指针
    NSString *str = @"test";
    //[str release];
    NSLog(@"-->> %@", str);
    
    //2 数组越界
    NSArray *arr = @[@1, @2];
    NSLog(@"%@", arr[10]);
}

@end
