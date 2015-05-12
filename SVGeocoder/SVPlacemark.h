//
//  SVPlacemark.h
//  SVGeocoder
//
//  Created by Sam Vermette on 01.05.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

@interface SVPlacemark : MKPlacemark;

- (instancetype)initWithPlacemark:(CLPlacemark *)placemark;

@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;

@end
