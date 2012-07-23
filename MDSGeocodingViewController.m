//
//  MDSGeocodingViewController.m
//  Map Kit Demo
//
//  Created by Ryan Johnson on 3/18/12.
//  Copyright (c) 2012 mobile data solutions.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy 
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights 
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
// copies of the Software, and to permit persons to whom the Software is 
// furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
//  DEALINGS IN THE SOFTWARE.



#import <CoreLocation/CoreLocation.h>
#import <AddressBookUI/AddressBookUI.h>

#import "MDSGeocodingViewController.h"

@interface MDSGeocodingViewController ()
{
  IBOutlet MKMapView * _mapView;
  NSMutableArray * _geocodingResults;
  CLGeocoder * _geocoder;
  NSTimer * _searchTimer;
}
- (void) geocodeFromTimer:(NSTimer *)timer;
- (void) processForwardGeocodingResults:(NSArray *)placemarks;
- (void) processReverseGeocodingResults:(NSArray*)placemarks;
- (void) reverseGeocodeCoordinate:(CLLocationCoordinate2D)coord;
- (IBAction) didLongPress:(UILongPressGestureRecognizer*)gr;
- (void) addPinAnnotationForPlacemark:(CLPlacemark*)placemark;
- (void) zoomMapToPlacemark:(CLPlacemark *)selectedPlacemark;
-(void) setActivePlacemark:(CLPlacemark*)selectedPlacemark;
@end

@implementation MDSGeocodingViewController

+ (MDSGeocodingViewController*) viewController 
{
  return [[self alloc] initWithNibName:@"MDSGeocodingViewController" bundle:nil]; 
}

- (void) viewDidLoad {
  [super viewDidLoad];
	
  
	[self.searchDisplayController.searchBar setPlaceholder:NSLocalizedString(@"Custom Location", @"location name prompt on search bar")];
	
	[self setTitle:NSLocalizedString(@"Set Location", @"prompt for how to use location map")];
	[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Here!", @"Show user's current location on map") style:UIBarButtonItemStyleDone target:self action:@selector(currentLocationButtonPressed:)]];
	
  _geocodingResults = [NSMutableArray array];
  _geocoder = [[CLGeocoder alloc] init];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Geocoding Methods
NSString * const kSearchTextKey = @"Search Text"; /*< NSDictionary key for entered search text. Used by NSTimer userInfo.*/

- (void) geocodeFromTimer:(NSTimer *)timer {

  NSString * searchString = [timer.userInfo objectForKey:kSearchTextKey];

  // Cancel any active geocoding. Note: Cancelling calls the completion handler on the geocoder
  if (_geocoder.isGeocoding)
    [_geocoder cancelGeocode];

  [_geocoder geocodeAddressString:searchString
                completionHandler:^(NSArray *placemark, NSError *error) {
                  if (!error)
                    [self processForwardGeocodingResults:placemark];
                }
  ];
}
                  
- (void) processForwardGeocodingResults:(NSArray *)placemarks {
  [_geocodingResults removeAllObjects];
  [_geocodingResults addObjectsFromArray:placemarks];

  [self.searchDisplayController.searchResultsTableView reloadData];
}

- (void) didLongPress:(UILongPressGestureRecognizer *)gr {
  if (gr.state == UIGestureRecognizerStateBegan) {

    // convert the touch point to a CLLocationCoordinate & geocode
    CGPoint touchPoint = [gr locationInView:_mapView];
    CLLocationCoordinate2D coord = [_mapView convertPoint:touchPoint 
                                     toCoordinateFromView:_mapView];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"GeoSetCustomUserLocation" object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"location",[[CLLocation alloc] initWithCoordinate:coord altitude:0 horizontalAccuracy:0 verticalAccuracy:0 timestamp:nil], nil]];
    [self reverseGeocodeCoordinate:coord];
  }
}

- (void) reverseGeocodeCoordinate:(CLLocationCoordinate2D)coord {
  if ([_geocoder isGeocoding])
    [_geocoder cancelGeocode];
  
  CLLocation * location = [[CLLocation alloc] initWithLatitude:coord.latitude 
                                                     longitude:coord.longitude];
  
  [_geocoder reverseGeocodeLocation:location
                  completionHandler:^(NSArray *placemarks, NSError *error) {
                    if (!error)
                      [self processReverseGeocodingResults:placemarks];
                  }];
}


- (void) processReverseGeocodingResults:(NSArray *)placemarks {
  
  if ([placemarks count] == 0)
    return;
  
  CLPlacemark * placemark = [placemarks objectAtIndex:0];

	[self setActivePlacemark:placemark];
}

- (void) addPinAnnotationForPlacemark:(CLPlacemark*)placemark {
  MKPointAnnotation * placemarkAnnotation = [[MKPointAnnotation alloc] init];
  placemarkAnnotation.coordinate = placemark.location.coordinate;
  placemarkAnnotation.title = ABCreateStringWithAddressDictionary(placemark.addressDictionary, NO);
  [_mapView addAnnotation:placemarkAnnotation];
}

- (void) zoomMapToPlacemark:(CLPlacemark *)selectedPlacemark {
  CLLocationCoordinate2D coordinate = selectedPlacemark.location.coordinate;
  MKMapPoint mapPoint = MKMapPointForCoordinate(coordinate);
  double radius = (MKMapPointsPerMeterAtLatitude(coordinate.latitude) * selectedPlacemark.region.radius)/2;
	if (radius == 0)
		radius = 10000;
  MKMapSize size = {radius, radius};
  MKMapRect mapRect = {mapPoint, size};
  mapRect = MKMapRectOffset(mapRect, -radius/2, -radius/2); // adjust the rect so the coordinate is in the middle
  [_mapView setVisibleMapRect:mapRect animated:YES];
}

#pragma mark - UISearchDisplayController Delegate Methods

- (BOOL) searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString{
    
  // Use a timer to only start geocoding when the user stops typing
  if ([_searchTimer isValid])
    [_searchTimer invalidate];
  
  const NSTimeInterval kSearchDelay = .25;
  NSDictionary * userInfo = [NSDictionary dictionaryWithObject:searchString
                                                        forKey:kSearchTextKey];
  _searchTimer = [NSTimer scheduledTimerWithTimeInterval:kSearchDelay
                                                  target:self
                                                selector:@selector(geocodeFromTimer:)
                                                userInfo:userInfo
                                                 repeats:NO];
  
  return NO;
}

#pragma mark - UITableView Data Source + Delegate Methods
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [_geocodingResults count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString * const  kCellIdentifier = @"Cell";
  UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
  if (!cell)
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:kCellIdentifier];


  CLPlacemark * placemark = [_geocodingResults objectAtIndex:indexPath.row];
  
  NSString * formattedAddress = ABCreateStringWithAddressDictionary(placemark.addressDictionary, NO);
  cell.textLabel.text = formattedAddress;

  return cell;

}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
  CLPlacemark * selectedPlacemark = [_geocodingResults objectAtIndex:indexPath.row];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"GeoSetCustomUserLocation" object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[selectedPlacemark location],@"location", nil]];
	[self setActivePlacemark:selectedPlacemark];
}

-(void) setActivePlacemark:(CLPlacemark*)selectedPlacemark{
	[_mapView setShowsUserLocation:FALSE];
		
	// Clear the map
	[_mapView removeAnnotations:_mapView.annotations];
		
	[self addPinAnnotationForPlacemark:selectedPlacemark];
	
	[self.searchDisplayController.searchBar setPlaceholder:[selectedPlacemark locality]];
	
	// hide the search display controller and reset the search results
	[self.searchDisplayController setActive:NO animated:YES];
	[_geocodingResults removeAllObjects];
	
	[self zoomMapToPlacemark:selectedPlacemark];

}

-(void)currentLocationButtonPressed:(id)sender{
	[self.searchDisplayController.searchBar setPlaceholder:NSLocalizedString(@"Custom Location", @"location name prompt on search bar")];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"GeoTrackActiveUserLocation" object:self userInfo:nil];
	[_mapView removeAnnotations:_mapView.annotations];
	[_mapView setUserTrackingMode:MKUserTrackingModeFollow];
	[_mapView setShowsUserLocation:TRUE];
}

-(void) setCustomUserLocation:(CLLocation*)userLocation{
	[self reverseGeocodeCoordinate:userLocation.coordinate];
}

#pragma mark - MKMapView Delegate Methods

- (MKAnnotationView*) mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
  static NSString * const kPinIdentifier = @"Pin";
  MKPinAnnotationView * pin = (MKPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:kPinIdentifier];
  if (!pin)
    pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kPinIdentifier];
  
  pin.annotation = annotation;
  
  return pin;
}


@end
