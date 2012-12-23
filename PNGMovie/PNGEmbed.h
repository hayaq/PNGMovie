//
//  PNGEmbed.h
//  PNGMovie
//
//  Created by hayashi on 12/23/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//

#ifndef PNGMovie_PNGEmbed_h
#define PNGMovie_PNGEmbed_h

NSData* PNGDataWithEmbededData(NSData *pngData,NSData *embedData,const char *chunkId);
NSData* EmbededDataFromPNGData(NSData *pngData,const char *chunkId);

#endif
