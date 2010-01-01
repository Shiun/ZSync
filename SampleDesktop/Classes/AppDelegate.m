#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window;

- (NSString *)applicationSupportDirectory 
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
  return [basePath stringByAppendingPathComponent:@"SampleDesktop"];
}

#pragma mark -
#pragma mark Application Delegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSString *clientIdentifier = [[NSBundle mainBundle] bundleIdentifier];
  
  [self managedObjectContext];
  
  //Register the sync client
  NSString *path = [[NSBundle mainBundle] pathForResource:@"ZSyncSample" ofType:@"syncschema"];
  ZAssert([[ISyncManager sharedManager] registerSchemaWithBundlePath:path], @"Failed to register sync schema");
  
  client = [[ISyncManager sharedManager] registerClientWithIdentifier:clientIdentifier descriptionFilePath:[[NSBundle mainBundle] pathForResource:@"clientDescription" ofType:@"plist"]];
  [client setShouldSynchronize:YES withClientsOfType:ISyncClientTypeApplication];
  [client setShouldSynchronize:YES withClientsOfType:ISyncClientTypeDevice];
  [client setShouldSynchronize:YES withClientsOfType:ISyncClientTypeServer];
  [client setShouldSynchronize:YES withClientsOfType:ISyncClientTypePeer];  
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender 
{
  if (!managedObjectContext) return NSTerminateNow;
  
  if (![managedObjectContext commitEditing]) {
    NSLog(@"%@:%s unable to commit editing to terminate", [self class], _cmd);
    return NSTerminateCancel;
  }
  
  if (![managedObjectContext hasChanges]) return NSTerminateNow;
  
  NSError *error = nil;
  if (![managedObjectContext save:&error]) {
    
    BOOL result = [sender presentError:error];
    if (result) return NSTerminateCancel;
    
    NSString *question = NSLocalizedString(@"Could not save changes while quitting.  Quit anyway?", @"Quit without saves error question message");
    NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
    NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
    NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:question];
    [alert setInformativeText:info];
    [alert addButtonWithTitle:quitButton];
    [alert addButtonWithTitle:cancelButton];
    
    NSInteger answer = [alert runModal];
    [alert release];
    alert = nil;
    
    if (answer == NSAlertAlternateReturn) return NSTerminateCancel;
    
  }
  
  return NSTerminateNow;
}

#pragma mark -
#pragma mark Window Delegate

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window 
{
  return [[self managedObjectContext] undoManager];
}

#pragma mark -
#pragma mark Core Data

- (NSManagedObjectModel *)managedObjectModel 
{
  if (managedObjectModel) return managedObjectModel;
	
  managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
  return managedObjectModel;
}

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator 
{
  if (persistentStoreCoordinator) return persistentStoreCoordinator;
  
  NSManagedObjectModel *mom = [self managedObjectModel];
  
  if (!mom) {
    ALog(@"Managed object model is nil");
    NSLog(@"%@:%s No model to generate a store from", [self class], _cmd);
    return nil;
  }
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *applicationSupportDirectory = [self applicationSupportDirectory];
  NSError *error = nil;
  
  if (![fileManager fileExistsAtPath:applicationSupportDirectory isDirectory:NULL]) {
		if (![fileManager createDirectoryAtPath:applicationSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
      ALog(@"Failed to create App Support directory %@ : %@", applicationSupportDirectory, error);
      return nil;
		}
  }
  
  NSURL *url = [NSURL fileURLWithPath: [applicationSupportDirectory stringByAppendingPathComponent: @"storedata"]];
  persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: mom];
  
  NSPersistentStore *store = nil;
  store = [persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType 
                                                   configuration:nil 
                                                             URL:url 
                                                         options:nil 
                                                           error:&error];
  ZAssert(store != nil, @"Error creating store: %@", [error localizedDescription]);
  
  NSURL *fastSyncFileURL = [NSURL fileURLWithPath:[applicationSupportFolder stringByAppendingPathComponent:@"DepartmentsAndEmployeesSyncApp.fastsyncstore"]];
  [persistentStoreCoordinator setStoresFastSyncDetailsAtURL:fastSyncFileURL forPersistentStore:store];
  
  
  return persistentStoreCoordinator;
}

- (NSManagedObjectContext *) managedObjectContext 
{
  if (managedObjectContext) return managedObjectContext;
  
  NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
  if (!coordinator) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
    [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
    NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
    [[NSApplication sharedApplication] presentError:error];
    return nil;
  }
  managedObjectContext = [[NSManagedObjectContext alloc] init];
  [managedObjectContext setPersistentStoreCoordinator: coordinator];
  
  return managedObjectContext;
}

#pragma mark -
#pragma mark Actions

- (IBAction)addData:(id)sender;
{
}

- (IBAction)changeData:(id)sender;
{
}

- (IBAction) saveAction:(id)sender 
{
  NSError *error = nil;
  
  ZAssert([[self managedObjectContext] commitEditing], @"Failed to commit");
  ZAssert([[self managedObjectContext] save:&error], @"Error saving context: %@", [error localizedDescription]);
}

@end