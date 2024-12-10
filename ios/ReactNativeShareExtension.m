#import <React/RCTRootView.h>

#import <MobileCoreServices/MobileCoreServices.h>


#if __has_include(<React/RCTUtilsUIOverride.h>)

    #import <React/RCTUtilsUIOverride.h>

#endif


#import "ReactNativeShareExtension.h"

#import <React/RCTConvert.h>

#import <React/RCTUtils.h>


NSExtensionContext* extensionContext;


static NSString *const FIELD_URI = @"value";

static NSString *const FIELD_FILE_COPY_URI = @"fileCopyUri";

static NSString *const FIELD_COPY_ERR = @"copyError";

static NSString *const FIELD_NAME = @"name";

static NSString *const FIELD_TYPE = @"type";

static NSString *const FIELD_SIZE = @"size";


@implementation ReactNativeShareExtension


- (UIView*) shareView

{

    return nil;

}


RCT_EXPORT_MODULE();


- (void)viewDidLoad

{

    [super viewDidLoad];


    extensionContext = self.extensionContext;


    UIView *rootView = [self shareView];

    if (rootView.backgroundColor == nil) {

        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];

    }


    #if __has_include(<React/RCTUtilsUIOverride.h>)

        [RCTUtilsUIOverride setPresentedViewController:self];

    #endif


    self.view = rootView;

}


RCT_EXPORT_METHOD(openURL:(NSString *)url)

{

    UIApplication *application = [UIApplication sharedApplication];

    NSURL *openUrl = [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    if (@available(iOS 10.0, *)) {

        [application openURL:openUrl options:@{} completionHandler: nil];

    }

}


RCT_EXPORT_METHOD(close)

{

    [extensionContext completeRequestReturningItems:nil

                                  completionHandler:nil];

}


RCT_REMAP_METHOD(data, resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

{

    [self extractDataFromContext:extensionContext withCallback:^(NSArray* items, NSException* err) {

        resolve(items);

    }];

}


+ (NSURL *)copyToUniqueDestinationFrom:(NSURL *)url usingDestinationPreset:(NSString *)copyToDirectory error:(NSError *)error

{

    NSURL *destinationRootDir = [self getDirectoryForFileCopy];

    // we don't want to rename the file so we put it into a unique location

    NSString *uniqueSubDirName = [[NSUUID UUID] UUIDString];

    NSURL *destinationDir = [destinationRootDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/", uniqueSubDirName]];

    NSURL *destinationUrl = [destinationDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@", url.lastPathComponent]];


    [NSFileManager.defaultManager createDirectoryAtURL:destinationDir withIntermediateDirectories:YES attributes:nil error:&error];

    if (error) {

        return url;

    }

    [NSFileManager.defaultManager copyItemAtURL:url toURL:destinationUrl error:&error];

    if (error) {

        return url;

    } else {

        return destinationUrl;

    }

}


+ (NSURL *)getDirectoryForFileCopy

{

   return [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:[[NSBundle mainBundle].infoDictionary valueForKey:@"appGroupId"]];

}


- (NSMutableDictionary *)getMetadataForUrl:(NSURL *)url error:(NSError **)error

{

    __block NSMutableDictionary *result = [NSMutableDictionary dictionary];


    NSFileCoordinator *coordinator = [NSFileCoordinator new];

    NSError *fileError;


    // TODO double check this implemenation, see eg. https://developer.apple.com/documentation/foundation/nsfilecoordinator/1412420-prepareforreadingitemsaturls

    [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingResolvesSymbolicLink error:&fileError byAccessor:^(NSURL *newURL) {

        // If the coordinated operation fails, then the accessor block never runs

     

        NSError *copyError;

        NSString *maybeFileCopyPath = [ReactNativeShareExtension copyToUniqueDestinationFrom:newURL usingDestinationPreset:@"cachesDirectory" error:copyError].absoluteString;

        

        if (!copyError) {

            result[FIELD_URI] = RCTNullIfNil(maybeFileCopyPath);

        } else {

            result[FIELD_COPY_ERR] = copyError.localizedDescription;

            result[FIELD_URI] = [NSNull null];

        }


        result[FIELD_NAME] = newURL.lastPathComponent;


        NSError *attributesError = nil;

        NSDictionary *fileAttributes = [NSFileManager.defaultManager attributesOfItemAtPath:newURL.path error:&attributesError];

        if(!attributesError) {

            result[FIELD_SIZE] = fileAttributes[NSFileSize];

        } else {

            result[FIELD_SIZE] = [NSNull null];

            NSLog(@"ReactNativeShareExtension: %@", attributesError);

        }


        if (newURL.pathExtension != nil) {

            CFStringRef extension = (__bridge CFStringRef) newURL.pathExtension;

            CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, extension, NULL);

            CFStringRef mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);

            if (uti) {

                CFRelease(uti);

            }


            NSString *mimeTypeString = (__bridge_transfer NSString *)mimeType;

            result[FIELD_TYPE] = mimeTypeString;

        } else {

            result[FIELD_TYPE] = [NSNull null];

        }

    }];


    if (fileError) {

        *error = fileError;

        return nil;

    } else {

        return result;

    }

}


- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSArray *items, NSException *exception))callback

{

    __block NSMutableArray *data = [NSMutableArray new];


    NSExtensionItem *item = [context.inputItems firstObject];

    NSArray *attachments = item.attachments;

    __block NSUInteger index = 0;


    [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop)

    {

        [provider.registeredTypeIdentifiers enumerateObjectsUsingBlock:^(NSString *identifier, NSUInteger idx, BOOL *stop)

        {

            [provider loadItemForTypeIdentifier:identifier options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error)

            {

                index += 1;


                NSString *string;

                NSString *type;

                

                // is an URL - Can be a path or Web URL

                if ([(NSObject *)item isKindOfClass:[NSURL class]]) {

                    NSURL *url = (NSURL *) item;

                    string = [url absoluteString];

                    

                    if (([[string pathExtension] isEqualToString:@""]) || [url.scheme containsString:@"http"]) {

                        type = @"text";

                        [data addObject:@{ @"value": string, @"type": type }];

                    } else {

                        NSError *error;

                        NSMutableDictionary *fileInfo = [self getMetadataForUrl:url error:&error];

                        [data addObject:fileInfo];

                    }

                

                // is a String

                } else if ([(NSObject *)item isKindOfClass:[NSString class]]) {

                    string = (NSString *)item;

                    type = @"text";


                    [data addObject:@{ @"value": string, @"type": type }];


                // is an Image

                } else if ([(NSObject *)item isKindOfClass:[UIImage class]]) {

                    UIImage *sharedImage = (UIImage *)item;

                    

                    NSString *fileName =  [[@"share-" stringByAppendingString:[NSNumber numberWithDouble:NSDate.date.timeIntervalSince1970].stringValue]  stringByAppendingString:@".png"];

                    

                    NSString *path = [[ReactNativeShareExtension getDirectoryForFileCopy].absoluteString stringByAppendingPathComponent:fileName];

                    

                    [UIImagePNGRepresentation(sharedImage) writeToFile:path atomically:YES];

                    string = [NSString stringWithFormat:@"%@%@", @"file://", path];

                    type = @"media";


                    [data addObject:@{ @"value": string, @"type": type }];

                }


                if (index == [attachments count]) {

                    callback(data, nil);

                }

            }];


            // We'll only use the first provider

            *stop = YES;

        }];

    }];

}


@end