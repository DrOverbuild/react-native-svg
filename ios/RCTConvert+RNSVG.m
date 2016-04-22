/**
 * Copyright (c) 2015-present, Horcrux.
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTConvert+RNSVG.h"

#import "RNSVGLinearGradient.h"
#import "RNSVGPattern.h"
#import "RNSVGRadialGradient.h"
#import "RNSVGSolidColor.h"
#import "RCTLog.h"
#import "RNSVGCGFCRule.h"

@implementation RCTConvert (RNSVG)

+ (CGPathRef)CGPath:(id)json
{
  NSArray *arr = [self NSNumberArray:json];

  NSUInteger count = [arr count];

#define NEXT_VALUE [self double:arr[i++]]

  CGMutablePathRef path = CGPathCreateMutable();
  CGPathMoveToPoint(path, NULL, 0, 0);

  @try {
    NSUInteger i = 0;
    while (i < count) {
      NSUInteger type = [arr[i++] unsignedIntegerValue];
      switch (type) {
        case 0:
          CGPathMoveToPoint(path, NULL, NEXT_VALUE, NEXT_VALUE);
          break;
        case 1:
          CGPathCloseSubpath(path);
          break;
        case 2:
          CGPathAddLineToPoint(path, NULL, NEXT_VALUE, NEXT_VALUE);
          break;
        case 3:
          CGPathAddCurveToPoint(path, NULL, NEXT_VALUE, NEXT_VALUE, NEXT_VALUE, NEXT_VALUE, NEXT_VALUE, NEXT_VALUE);
          break;
        case 4:
          CGPathAddArc(path, NULL, NEXT_VALUE, NEXT_VALUE, NEXT_VALUE, NEXT_VALUE, NEXT_VALUE, NEXT_VALUE == 0);
          break;
        default:
          RCTLogError(@"Invalid CGPath type %zd at element %zd of %@", type, i, arr);
          CGPathRelease(path);
          return NULL;
      }
    }
  }
  @catch (NSException *exception) {
    RCTLogError(@"Invalid CGPath format: %@", arr);
    CGPathRelease(path);
    return NULL;
  }

  return (CGPathRef)CFAutorelease(path);
}

RCT_ENUM_CONVERTER(CTTextAlignment, (@{
  @"auto": @(kCTTextAlignmentNatural),
  @"left": @(kCTTextAlignmentLeft),
  @"center": @(kCTTextAlignmentCenter),
  @"right": @(kCTTextAlignmentRight),
  @"justify": @(kCTTextAlignmentJustified),
}), kCTTextAlignmentNatural, integerValue)

RCT_ENUM_CONVERTER(RNSVGCGFCRule, (@{
  @"evenodd": @(kRNSVGCGFCRuleEvenodd),
  @"nonzero": @(kRNSVGCGFCRuleNonzero),
}), kRNSVGCGFCRuleNonzero, intValue)

// This takes a tuple of text lines and a font to generate a CTLine for each text line.
// This prepares everything for rendering a frame of text in RNSVGText.
+ (RNSVGTextFrame)RNSVGTextFrame:(id)json
{
  NSDictionary *dict = [self NSDictionary:json];
  RNSVGTextFrame frame;
  frame.count = 0;

  NSArray *lines = [self NSArray:dict[@"lines"]];
  NSUInteger lineCount = [lines count];
  if (lineCount == 0) {
    return frame;
  }

  NSDictionary *fontDict = dict[@"font"];
  CTFontRef font = (__bridge CTFontRef)[self UIFont:nil withFamily:fontDict[@"fontFamily"] size:fontDict[@"fontSize"] weight:fontDict[@"fontWeight"] style:fontDict[@"fontStyle"] scaleMultiplier:1.0];
  if (!font) {
    return frame;
  }

  // Create a dictionary for this font
  CFDictionaryRef attributes = (__bridge CFDictionaryRef)@{
    (NSString *)kCTFontAttributeName: (__bridge id)font,
    (NSString *)kCTForegroundColorFromContextAttributeName: @YES
  };

  // Set up text frame with font metrics
  CGFloat size = CTFontGetSize(font);
  frame.count = lineCount;
  frame.baseLine = size; // estimate base line
  frame.lineHeight = size * 1.1; // Base on RNSVG canvas line height estimate
  frame.lines = malloc(sizeof(CTLineRef) * lineCount);
  frame.widths = malloc(sizeof(CGFloat) * lineCount);

  [lines enumerateObjectsUsingBlock:^(NSString *text, NSUInteger i, BOOL *stop) {

    CFStringRef string = (__bridge CFStringRef)text;
    CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, string, attributes);
    CTLineRef line = CTLineCreateWithAttributedString(attrString);
    CFRelease(attrString);

    frame.lines[i] = line;
    frame.widths[i] = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
  }];

  return frame;
}

+ (RNSVGCGFloatArray)RNSVGCGFloatArray:(id)json
{
  NSArray *arr = [self NSNumberArray:json];
  NSUInteger count = arr.count;

  RNSVGCGFloatArray array;
  array.count = count;
  array.array = NULL;

  if (count) {
    // Ideally, these arrays should already use the same memory layout.
    // In that case we shouldn't need this new malloc.
    array.array = malloc(sizeof(CGFloat) * count);
    for (NSUInteger i = 0; i < count; i++) {
      array.array[i] = [arr[i] doubleValue];
    }
  }

  return array;
}

+ (RNSVGBrush *)RNSVGBrush:(id)json
{
  NSArray *arr = [self NSArray:json];
  NSUInteger type = [self NSUInteger:arr.firstObject];
  switch (type) {
    case 0: // solid color
      // These are probably expensive allocations since it's often the same value.
      // We should memoize colors but look ups may be just as expensive.
      return [[RNSVGSolidColor alloc] initWithArray:arr];
    case 1: // linear gradient
      return [[RNSVGLinearGradient alloc] initWithArray:arr];
    case 2: // radial gradient
      return [[RNSVGRadialGradient alloc] initWithArray:arr];
    case 3: // pattern
      return [[RNSVGPattern alloc] initWithArray:arr];
    default:
      RCTLogError(@"Unknown brush type: %zd", type);
      return nil;
  }
}

+ (CGPoint)CGPoint:(id)json offset:(NSUInteger)offset
{
  NSArray *arr = [self NSArray:json];
  if (arr.count < offset + 2) {
    RCTLogError(@"Too few elements in array (expected at least %zd): %@", 2 + offset, arr);
    return CGPointZero;
  }
  return (CGPoint){
    [self CGFloat:arr[offset]],
    [self CGFloat:arr[offset + 1]],
  };
}

+ (CGRect)CGRect:(id)json offset:(NSUInteger)offset
{
  NSArray *arr = [self NSArray:json];
  if (arr.count < offset + 4) {
    RCTLogError(@"Too few elements in array (expected at least %zd): %@", 4 + offset, arr);
    return CGRectZero;
  }
  return (CGRect){
    {[self CGFloat:arr[offset]], [self CGFloat:arr[offset + 1]]},
    {[self CGFloat:arr[offset + 2]], [self CGFloat:arr[offset + 3]]},
  };
}

+ (CGColorRef)CGColor:(id)json offset:(NSUInteger)offset
{
  NSArray *arr = [self NSArray:json];
  if (arr.count < offset + 4) {
    RCTLogError(@"Too few elements in array (expected at least %zd): %@", 4 + offset, arr);
    return NULL;
  }
  return [self CGColor:[arr subarrayWithRange:(NSRange){offset, 4}]];
}

+ (CGGradientRef)CGGradient:(id)json offset:(NSUInteger)offset
{
  NSArray *arr = [self NSArray:json];
  if (arr.count < offset) {
    RCTLogError(@"Too few elements in array (expected at least %zd): %@", offset, arr);
    return NULL;
  }
  arr = [arr subarrayWithRange:(NSRange){offset, arr.count - offset}];
  RNSVGCGFloatArray colorsAndOffsets = [self RNSVGCGFloatArray:arr];
  size_t stops = colorsAndOffsets.count / 5;
  CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
  CGGradientRef gradient = CGGradientCreateWithColorComponents(
    rgb,
    colorsAndOffsets.array,
    colorsAndOffsets.array + stops * 4,
    stops
  );
  CGColorSpaceRelease(rgb);
  free(colorsAndOffsets.array);
  return (CGGradientRef)CFAutorelease(gradient);
}

@end