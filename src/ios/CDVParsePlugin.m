#import "CDVParsePlugin.h"
#import <Cordova/CDV.h>
#import <Parse/Parse.h>
#import <objc/runtime.h>
#import <objc/message.h>

@implementation CDVParsePlugin

- (void)initialize: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString *appId = [command.arguments objectAtIndex:0];
    NSString *clientKey = [command.arguments objectAtIndex:1];
    [Parse setApplicationId:appId clientKey:clientKey];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

//SETH
- (NSMutableDictionary*) createReturnDictionary: (int) returnCode withText:(NSString*) returnText{
    
    NSMutableDictionary* returnDictionary = [[NSMutableDictionary alloc] init];
    
    [returnDictionary setObject:[NSNumber numberWithInt:returnCode] forKey:@"returnCode"];
    [returnDictionary setObject:returnText forKey:@"returnText"];
    
    return returnDictionary;
    
}

- (void)getInstallationId:(CDVInvokedUrlCommand*) command
{
    [self.commandDelegate runInBackground:^{
        __block CDVPluginResult* pluginResult = nil;
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        [currentInstallation saveEventually:^(BOOL succeeded, NSError *error) {
            if(!error) {
                //GET TOKEN TO LOGIN JAVASCRIPT
                if([PFUser currentUser] != nil) {
                    PFUser *cu = [PFUser currentUser];
                    NSString *installationId = currentInstallation.installationId;
                    NSMutableDictionary *returnDictionary = [self createReturnDictionary:0 withText: @"Success"];
                    [returnDictionary setObject:installationId forKey:@"installationId"];
                    [returnDictionary setObject:cu.sessionToken forKey:@"token"];
                    NSLog(@"TOKEN: %@", cu.sessionToken);
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:returnDictionary];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                    
                } else {
                    [PFAnonymousUtils logInWithBlock:^(PFUser *user, NSError *error) {
                        if (error) {
                            NSLog(@"Anonymous login failed.");
                        } else {
                            NSLog(@"Anonymous user logged in.");
                            [user saveEventually:^(BOOL succeeded, NSError *error) {
                                PFUser *cu = [PFUser currentUser];
                                NSString *installationId = currentInstallation.installationId;
                                NSMutableDictionary *returnDictionary = [self createReturnDictionary:0 withText: @"Success"];
                                [returnDictionary setObject:installationId forKey:@"installationId"];
                                [returnDictionary setObject:cu.sessionToken forKey:@"token"];
                                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:returnDictionary];
                                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                
                            }];
                        }
                    }];
                }
            }
        }];
    }];
}

- (void)getInstallationObjectId:(CDVInvokedUrlCommand*) command
{
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSString *objectId = currentInstallation.objectId;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:objectId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getSubscriptions: (CDVInvokedUrlCommand *)command
{
    NSArray *channels = [PFInstallation currentInstallation].channels;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:channels];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)subscribe: (CDVInvokedUrlCommand *)command
{
    // Not sure if this is necessary
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
        UIRemoteNotificationTypeBadge |
        UIRemoteNotificationTypeAlert |
        UIRemoteNotificationTypeSound];

    CDVPluginResult* pluginResult = nil;
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSString *channel = [command.arguments objectAtIndex:0];
    [currentInstallation addUniqueObject:channel forKey:@"channels"];
    [currentInstallation saveInBackground];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

//SETH
- (void)unsubscribe: (CDVInvokedUrlCommand *)command
{
//    CDVPluginResult* pluginResult = nil;
//    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
//    NSString *channel = [command.arguments objectAtIndex:0];
//    [currentInstallation removeObject:channel forKey:@"channels"];
//    [currentInstallation saveInBackground];
//    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
//    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    
    // Login PFUser using Facebook
    NSArray *permissionsArray = @[ @"user_about_me", @"user_relationships", @"user_birthday", @"user_location"];
    [PFFacebookUtils initializeFacebook];
    [PFFacebookUtils logInWithPermissions:permissionsArray block:^(PFUser *user, NSError *error) {
         if (!user) {
             NSLog(@"PF LINK ERROR");
         } else {
             NSLog(@"PF LINK SUCCESS");
         }
    }];
}

@end

@implementation AppDelegate (CDVParsePlugin)

void MethodSwizzle(Class c, SEL originalSelector) {
    NSString *selectorString = NSStringFromSelector(originalSelector);
    SEL newSelector = NSSelectorFromString([@"swizzled_" stringByAppendingString:selectorString]);
    SEL noopSelector = NSSelectorFromString([@"noop_" stringByAppendingString:selectorString]);
    Method originalMethod, newMethod, noop;
    originalMethod = class_getInstanceMethod(c, originalSelector);
    newMethod = class_getInstanceMethod(c, newSelector);
    noop = class_getInstanceMethod(c, noopSelector);
    if (class_addMethod(c, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSelector, method_getImplementation(originalMethod) ?: method_getImplementation(noop), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

+ (void)load
{
    MethodSwizzle([self class], @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    MethodSwizzle([self class], @selector(application:didReceiveRemoteNotification:));
}

- (void)noop_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken
{
}

- (void)swizzled_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken
{
    // Call existing method
    [self swizzled_application:application didRegisterForRemoteNotificationsWithDeviceToken:newDeviceToken];
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:newDeviceToken];
    [currentInstallation saveInBackground];
}

- (void)noop_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
}

- (void)swizzled_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    // Call existing method
    [self swizzled_application:application didReceiveRemoteNotification:userInfo];
    [PFPush handlePush:userInfo];
}

@end
