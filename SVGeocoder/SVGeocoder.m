//
//  SVGeocoder.m
//
//  Created by Sam Vermette on 07.02.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//

#import "SVGeocoder.h" 
#import <RestKit/Support/JSON/JSONKit/JSONKit.h>

@interface SVGeocoder ()

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;

@property (nonatomic, retain) NSString *requestString;
@property (nonatomic, assign) NSMutableData *responseData;
@property (nonatomic, assign) NSURLConnection *rConnection;
@property (nonatomic, retain) NSURLRequest *request;

@end

@implementation SVGeocoder

@synthesize delegate, requestString, responseData, rConnection, request;

#pragma mark -

- (SVGeocoder*)initWithCoordinate:(CLLocationCoordinate2D)coordinate {
	if ((self = [super init])) {
		requestString = [[NSString alloc] initWithFormat:@"http://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true",
						 coordinate.latitude, coordinate.longitude];
	
		NSLog(@"SVGeocoder -> %@", requestString);
	}
	return self;
}

- (SVGeocoder*)initWithAddress:(NSString *)address inRegion:(MKCoordinateRegion)region {
	if ((self = [super init])) {
		requestString = [[NSString alloc] initWithFormat:@"http://maps.googleapis.com/maps/api/geocode/json?address=%@&bounds=%f,%f|%f,%f&sensor=true", 
						  address,
						  region.center.latitude-(region.span.latitudeDelta/2.0),
						  region.center.longitude-(region.span.longitudeDelta/2.0),
						  region.center.latitude+(region.span.latitudeDelta/2.0),
						  region.center.longitude+(region.span.longitudeDelta/2.0)];
	
		NSLog(@"SVGeocoder -> %@", requestString);
	}
	return self;
}


- (SVGeocoder*)initWithAddress:(NSString*)address {
	if ((self = [super init])) {
		requestString = [[NSString alloc] initWithFormat:@"http://maps.googleapis.com/maps/api/geocode/json?address=%@&sensor=true", address];
	
		NSLog(@"SVGeocoder -> %@", requestString);
	}
	return self;
}

#pragma mark -

- (void)setDelegate:(id <SVGeocoderDelegate>)newDelegate {
	
	delegate = newDelegate;
}


- (void)startAsynchronous {
	
	NSString *escapedString = [self.requestString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	self.request = [NSURLRequest requestWithURL:[NSURL URLWithString:escapedString]];
	
	responseData = [[NSMutableData alloc] init];
	rConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
	if (!responseData)
		return;
	
	[responseData appendData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {	
	NSError *jsonError = NULL;
	NSDictionary *responseDict = [responseData objectFromJSONData];
	
	if(responseDict == nil || [responseDict valueForKey:@"results"] == nil || [[responseDict valueForKey:@"results"] count] == 0) {
		[self connection:connection didFailWithError:jsonError];
		return;
	}
	
	NSDictionary *addressDict = [[[responseDict valueForKey:@"results"] objectAtIndex:0] valueForKey:@"address_components"];
	NSDictionary *coordinateDict = [[[[responseDict valueForKey:@"results"] objectAtIndex:0] valueForKey:@"geometry"] valueForKey:@"location"];
	
	float lat = [[coordinateDict valueForKey:@"lat"] floatValue];
	float lng = [[coordinateDict valueForKey:@"lng"] floatValue];
	
	NSMutableDictionary *formattedAddressDict = [[NSMutableDictionary alloc] init];
	
	for(NSDictionary *component in addressDict) {
		
		NSArray *types = [component valueForKey:@"types"];
		
		if([types containsObject:@"street_number"])
			[formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressStreetKey];
		
		if([types containsObject:@"route"])
			[formattedAddressDict setValue:[[formattedAddressDict valueForKey:(NSString*)kABPersonAddressStreetKey] stringByAppendingFormat:@" %@",[component valueForKey:@"long_name"]] forKey:(NSString*)kABPersonAddressStreetKey];
		
		if([types containsObject:@"locality"])
			[formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressCityKey];
		
		if([types containsObject:@"administrative_area_level_1"])
			[formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressStateKey];
		
		if([types containsObject:@"postal_code"])
			[formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressZIPKey];
		
		if([types containsObject:@"country"]) {
			[formattedAddressDict setValue:[component valueForKey:@"long_name"] forKey:(NSString*)kABPersonAddressCountryKey];
			[formattedAddressDict setValue:[component valueForKey:@"short_name"] forKey:(NSString*)kABPersonAddressCountryCodeKey];
		}
	}
	
	SVPlacemark *placemark = [[SVPlacemark alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lng) addressDictionary:formattedAddressDict];
	[formattedAddressDict release];
	
	NSLog(@"SVGeocoder -> Found Placemark");
	if (self.delegate) {
		[self.delegate geocoder:self didFindPlacemark:placemark];
	}
	[placemark release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
	NSLog(@"SVGeocoder -> Failed with error: %@, (%@)", [error localizedDescription], [[request URL] absoluteString]);
	
	if (self.delegate) {
		[self.delegate geocoder:self didFailWithError:error];
	}
}

#pragma mark -

- (void)dealloc {
	if (rConnection) {
		[rConnection cancel];
	}
	self.request = nil;
	self.requestString = nil;
	self.delegate = nil;
	nice_release(responseData);
	nice_release(rConnection);
	
	[super dealloc];
}

@end
