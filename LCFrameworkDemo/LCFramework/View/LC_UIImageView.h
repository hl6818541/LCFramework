//
//  LC_UIImageView.h
//  LCFramework

//  Created by 郭历成 ( titm@tom.com ) on 13-9-26.
//  Copyright (c) 2013年 Like Say Developer ( https://github.com/titman/LCFramework / USE IN PROJECT http://www.likesay.com ).
//  All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <UIKit/UIKit.h>

#pragma mark -

@interface LC_ImageCache : NSObject

+ (LC_ImageCache *) sharedInstance;

- (BOOL)hasCachedForURL:(NSString *)url;
- (UIImage *)imageForURL:(NSString *)url;

- (void)saveImage:(UIImage *)image forURL:(NSString *)url;
- (void)saveData:(NSData *)data forURL:(NSString *)url;
- (void)deleteImageForURL:(NSString *)url;
- (void)deleteAllImages;

@end

#pragma mark -

@interface LC_UIImageView : UIImageView

@property (nonatomic, assign) BOOL							gray;			// 是否变为灰色
@property (nonatomic, assign) BOOL							round;			// 是否裁剪为圆型
@property (nonatomic, assign) BOOL							strech;			// 是否裁剪为圆型
@property (nonatomic, assign) UIEdgeInsets					strechInsets;	// 是否裁剪为圆型
@property (nonatomic, assign) BOOL							loading;
@property (nonatomic, assign) BOOL							loaded;
@property (nonatomic, assign) BOOL                          showIndicator;  // 是否显示菊花
@property (nonatomic, retain) LC_UIActivityIndicatorView *	indicator;
@property (nonatomic, assign) UIActivityIndicatorViewStyle	indicatorStyle;
@property (nonatomic, retain) NSString *					loadedURL;

@property (nonatomic, assign) NSString *					url;
@property (nonatomic, assign) NSString *					file;
@property (nonatomic, assign) NSString *					resource;

- (void)GET:(NSString *)url useCache:(BOOL)useCache;
- (void)GET:(NSString *)url useCache:(BOOL)useCache placeHolder:(UIImage *)defaultImage;

- (void)clear;

@end