//
// YADMJSONApiModel.m
//
// Created by Csongor Nagy on 15/04/14.
// Copyright (c) 2014 Csongor Nagy
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <objc/message.h>
#import <objc/runtime.h>

#import "PNYADMJSONApiModel.h"
#import "PNYADMApiCall.h"
#import "PNYADMApiCallResult.h"
#import "PNYADMJSONToDomainModelParser.h"

@interface PNYADMJSONApiModel() <PNYADMApiCallDelegate>

@property (nonatomic, strong) PNYADMApiCall                       *call;
@property (nonatomic, strong) PNYADMJSONApiModelCompletionBlock   block;

@end



@implementation PNYADMJSONApiModel

#pragma mark - Class Methods

- (id)initWithURL:(NSURL*)url
           method:(NSString*)method
           params:(NSDictionary*)params
          headers:(NSDictionary*)headers
      cachePolicy:(NSURLRequestCachePolicy)policy
          timeout:(NSTimeInterval)timeout
andCompletionBlock:(PNYADMJSONApiModelCompletionBlock)block
{
    self = [super init];
    
    if (self) {
        self.block = block;
        [self requestWith:url
                   method:method
                   params:params
                  headers:headers
              cachePolicy:policy
                  timeout:timeout];
    }
    
    return self;
}



#pragma mark - Instance Methods

- (void)requestWith:(NSURL*)url
             method:(NSString*)method
             params:(NSDictionary*)params
            headers:(NSDictionary*)headers
        cachePolicy:(NSURLRequestCachePolicy)policy
            timeout:(NSTimeInterval)timeout
{
    self.call = [PNYADMApiCall requestWith:url
                                method:method
                                params:params
                               headers:headers
                           cachePolicy:policy
                               timeout:timeout
                              delegate:(id<PNYADMApiCallDelegate>)self
                      startImmediately:YES];
}



#pragma mark - ALApiCallDelegate Methods

- (void)apiCall:(PNYADMApiCall*)call didFinishedWithResult:(PNYADMApiCallResult*)callResult
{
    PNYADMJSONModelError *error = nil;
    id jsonObject = nil;
    
    if (!callResult.responseData)
    {
        error = (PNYADMJSONModelError*)[NSError errorWithDomain:kPNYADMJSONModelErrorDomain
                                                         code:kPNALJSONModelErrorJSONUnreachable
                                                     userInfo:@{NSLocalizedDescriptionKey:@"Bad response or JSON is unreachable."}];
    }
    
    if (error == nil)
    {
        if(callResult.responseData.length > 0)
        {
            jsonObject = [NSJSONSerialization JSONObjectWithData:callResult.responseData options:NSJSONReadingAllowFragments error:&error];
        }
    }
    else if (error && callResult.responseData)
    {
        jsonObject = [NSJSONSerialization JSONObjectWithData:callResult.responseData options:NSJSONReadingAllowFragments error:nil];
    }
    
    if (!error)
    {
        NSString *selfClassString =  NSStringFromClass([self class]);
        PNYADMJSONToDomainModelParser *parser = [PNYADMJSONToDomainModelParser initToParseResult:jsonObject
                                                                                 onModel:selfClassString];
        unsigned int propertyCount;
        objc_property_t *properties =  class_copyPropertyList([self class], &propertyCount);
        
        for(NSInteger i = 0; i < propertyCount; i++)
        {
            objc_property_t property = properties[i];
            const char *propName = property_getName(property);
            if(propName) {
                NSString *propertyName = [NSString stringWithCString:propName
                                                            encoding:[NSString defaultCStringEncoding]];
                NSString* setMethod = [NSString stringWithFormat:@"set%@:",
                                       [propertyName stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                                                             withString:[[propertyName substringToIndex:1] uppercaseString]]];
                SEL setSelector = NSSelectorFromString(setMethod);
                if ([self respondsToSelector:setSelector])
                {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [self performSelector:setSelector withObject:[parser.result performSelector:NSSelectorFromString(propertyName)]];
#pragma clang diagnostic pop
                }
            }
        }
        
        free(properties);
        
        self.block(nil);
    }
    else
    {
        self.block(error);
    }
}

- (void)apiCall:(PNYADMApiCall*)call didFailedWithError:(NSError*)error
{
    self.block(error);
}

@end
