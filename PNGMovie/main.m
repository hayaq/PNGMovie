//
//  main.m
//  PNGMovie
//
//  Created by hayashi on 12/23/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <QTKit/QTKit.h>
#import "PNGEmbed.h"

#define EMBEDED_MOVIE_CHUNK_ID "emMv"

static CGImageRef CGImageFromMovieFrameAtTime(NSString *moviePath, double t);

int main(int argc, const char * argv[])
{
	@autoreleasepool {
		if( argc < 2 ){
			printf("Usage pngmovie <path_to_mov> [-o <path_to_png>]\n"
				   "      pngmovie -x <path_to_png> -o [-o <path_to_mov>]\n");
			return -1;
		}
		NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
		
		if( [ud objectForKey:@"x"] ){
			NSString *pngPath = [ud stringForKey:@"x"];
			if( ![pngPath hasPrefix:@"/"] ){
				pngPath = [[[NSFileManager defaultManager] currentDirectoryPath]
						   stringByAppendingPathComponent:pngPath];
			}
			
			NSString *dstPath = [[pngPath stringByDeletingPathExtension]
								 stringByAppendingPathExtension:@"mov"];
			if( [ud objectForKey:@"o"] ){
				dstPath = [ud stringForKey:@"o"];
			}
			
			NSData *pngData = [NSData dataWithContentsOfFile:pngPath];
			NSData *movieData = EmbededDataFromPNGData(pngData,EMBEDED_MOVIE_CHUNK_ID);
			if( !movieData ){
				printf("No movie data is embeded\n");
				return -1;
			}
			[movieData writeToFile:dstPath atomically:YES];
			return 0;
		}
		
		NSString *moviePath = [NSString stringWithUTF8String:argv[1]];
		if( ![moviePath hasPrefix:@"/"] ){
			moviePath = [[[NSFileManager defaultManager] currentDirectoryPath]
						 stringByAppendingPathComponent:moviePath];
		}
		
		NSString *dstPath = [[moviePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
		if( [ud objectForKey:@"o"] ){
			dstPath = [ud stringForKey:@"o"];
		}
		
		double movieTime = 0;
		if( [ud objectForKey:@"t"] ){
			movieTime = [ud doubleForKey:@"t"];
		}
		
		CGImageRef cgImage = CGImageFromMovieFrameAtTime(moviePath,movieTime);
		if( !cgImage ){
			printf("Failed to decode movie\n");
			return -1;
		}
		
		NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
		NSData *pngData = [rep representationUsingType:NSPNGFileType properties: nil];
		NSData *movieData = [NSData dataWithContentsOfFile:moviePath];
		
		NSData *dstData = PNGDataWithEmbededData(pngData,movieData,EMBEDED_MOVIE_CHUNK_ID);
		
		[dstData writeToFile:dstPath atomically:YES];
		
		CGImageRelease(cgImage);
	}
    return 0;
}

static CGImageRef CGImageFromMovieFrameAtTime(NSString *moviePath, double t)
{
	NSError *error = nil;
	QTMovie *movie = [QTMovie movieWithFile:moviePath error:&error];
	if( error ){
		printf("Error: %s\n",[[error description] UTF8String]);
		return NULL;
	}
	QTTime movieTime = movie.currentTime;
	if( (long long)(t*movie.duration.timeScale) > movie.duration.timeValue ){
		movieTime = movie.duration;
	}else{
		movieTime.timeValue = (long long)(t*movieTime.timeScale);
	}
	NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
						  QTMovieFrameImageTypeCGImageRef,QTMovieFrameImageType,
						  [NSNumber numberWithBool:YES],QTMovieFrameImageHighQuality,
						  nil];
	CGImageRef videoFrame = [movie frameImageAtTime:movieTime withAttributes:attr error:&error];
	if( error ){
		printf("Error: %s\n",[[error description] UTF8String]);
		return NULL;
	}
	
	return videoFrame;
}
