//
//  Device.m
//  Rainbow
//
//  Created by Marcio Klepacz on 11/07/15.
//  Copyright (c) 2015 Marcio Klepacz. All rights reserved.
//

#import "Device.h"

@implementation Device


+ (NSArray *)appsInstalled
{
    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
    NSObject *workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
    
    NSArray *appInstalled = [workspace performSelector:@selector(allInstalledApplications)];
    
    NSMutableArray *bundleIds = [NSMutableArray array];
    [appInstalled enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *stringApp = [NSString stringWithFormat:@"%@", obj];
       
        [bundleIds addObject:[stringApp componentsSeparatedByString:@" "][2]];
        
    }];

    return [NSArray arrayWithArray:bundleIds];
}

@end
