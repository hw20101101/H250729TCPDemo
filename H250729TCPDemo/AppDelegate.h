//
//  AppDelegate.h
//  H250729TCPDemo
//
//  Created by hwacdx on 2025/7/29.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;

@property (strong, nonatomic) UIWindow * window;

- (void)saveContext;


@end

