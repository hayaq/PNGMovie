#include <Foundation/Foundation.h>

static uint32_t FindIENDChunkPos(NSData *data);
static uint8_t* FindEmbedDataPos(NSData *data,const char *chunkId,int *length);
static NSData*  CreateExtraChunk(const char *name,NSData *data);

NSData* PNGDataWithEmbededData(NSData *pngData,NSData *embedData,const char *chunkId)
{
	uint32_t embedPos = FindIENDChunkPos(pngData);
	if( embedPos == 0 ){
		return nil;
	}
	NSData *embedData2 = CreateExtraChunk(chunkId,embedData);
	
	NSMutableData *dstData = [NSMutableData dataWithLength:[pngData length]+[embedData2 length]];
	uint8_t *dstBytes = (uint8_t*)[dstData bytes];
	
	memcpy(dstBytes, [pngData bytes], embedPos);
	dstBytes += embedPos;
	
	memcpy(dstBytes, [embedData2 bytes], [embedData2 length]);
	dstBytes += [embedData2 length];
	
	memcpy(dstBytes, (uint8_t*)[pngData bytes]+embedPos,[pngData length]-embedPos);
	
	return dstData;
}

NSData* EmbededDataFromPNGData(NSData *pngData,const char *chunkId)
{
	int length = 0;
	uint8_t *embedPtr = FindEmbedDataPos(pngData,chunkId,&length);
	if( embedPtr == NULL || length <= 0 ){
		return nil;
	}
	return [NSData dataWithBytes:embedPtr length:length];
	
}

////////////////////////////////////////////////////////////

#define MKDW(a,b,c,d) (((a)<<24)|((b)<<16)|((c)<<8)|(d))
#define RDDW(p) MKDW(*(p),*(p+1),*(p+2),*(p+3))
#define IHDR MKDW('I','H','D','R')
#define IDAT MKDW('I','D','A','T')
#define IEND MKDW('I','E','N','D')
#define EMBM MKDW('e','m','M','v')

typedef struct PNGChunk{
	uint32_t  chunkType;
	uint32_t  length;
	uint32_t  crc;
	uint8_t  *dataPtr;
	uint8_t  *chunkPos;
	uint8_t  *nextChunk;
}PNGChunk;

static uint32_t ReadChunk(uint8_t *buff,PNGChunk *chunk){
	chunk->chunkPos = buff;
	chunk->length = RDDW(buff);
	buff+=4;
	chunk->chunkType = RDDW(buff);
	buff+=4;
	chunk->dataPtr = buff;
	buff+=chunk->length;
	chunk->crc = RDDW(buff);
	chunk->nextChunk = buff+4;
	return chunk->chunkType;
}

static uint32_t FindIENDChunkPos(NSData *data)
{
	uint8_t *bytes = (uint8_t*)[data bytes];
	uint8_t *buff = bytes + 8;
	uint32_t nextChunkPos = 0;
	uint32_t type = 0;
	PNGChunk chunk;
	while( (type=ReadChunk(buff,&chunk))!=0 ){
		//uint8_t *tname = (uint8_t*)(&type);
		//printf("[%c%c%c%c]: %8d bytes\n",tname[3],tname[2],tname[1],tname[0],chunk.length);
		if( type == IEND ){
			break;
		}else{
			nextChunkPos = (uint32_t)(chunk.nextChunk-bytes);
		}
		buff = chunk.nextChunk;
	}
	return nextChunkPos;
}

static uint8_t* FindEmbedDataPos(NSData *data,const char *chunkId,int *length)
{
	uint8_t *bytes = (uint8_t*)[data bytes];
	uint8_t *buff = bytes + 8;
	uint8_t *dataPtr = NULL;
	uint32_t type = 0;
	PNGChunk chunk;
	uint32_t embid = RDDW(chunkId);
	while( (type=ReadChunk(buff,&chunk))!=0 ){
		//uint8_t *tname = (uint8_t*)(&type);
		//printf("[%c%c%c%c]: %8d bytes\n",tname[3],tname[2],tname[1],tname[0],chunk.length);
		if( type == IEND ){
			break;
		}else if( type == embid ){
			dataPtr = chunk.dataPtr;
			*length = (int)chunk.length;
			break;
		}
		buff = chunk.nextChunk;
	}
	return dataPtr;
}

//////////////////////////////////////////////////////////

static inline void WriteUnsignedInt(uint8_t *dat,uint32_t v){
	dat[3] = v&0xFF;
	dat[2] = (v>>8)&0xFF;
	dat[1] = (v>>16)&0xFF;
	dat[0] = (v>>24)&0xFF;
}

static uint32_t UpdateCRC(uint32_t crc, uint8_t *buf, int len)
{
	uint32_t c = crc;
	static uint32_t crc_table[256];
	static uint8_t  crc_table_computed = 0;
	if(!crc_table_computed){
		for(int n = 0; n < 256; n++) {
			uint32_t c = (uint32)n;
			for (int k = 0; k < 8; k++) {
				if (c & 1){ c = 0xedb88320L ^ (c >> 1); }
				else{ c = c >> 1; }
			}
			crc_table[n] = c;
		}
		crc_table_computed = 1;
	}
	for(int n = 0; n < len; n++) {
		c = crc_table[(c ^ buf[n]) & 0xff] ^ (c >> 8);
	}
	return c;
}

static uint32_t CRC(uint8_t *buf, int len){
	return UpdateCRC(0xffffffffL, buf, len) ^ 0xffffffffL;
}

static NSData* CreateExtraChunk(const char *name,NSData *data)
{
	NSData *dstData = [NSMutableData dataWithLength:[data length]+12];
	uint32_t length = (uint32_t)[data length];
	uint8_t *bytes  = (uint8_t*)[dstData bytes];
	WriteUnsignedInt(bytes, length);
	WriteUnsignedInt(bytes+4, MKDW(name[0],name[1],name[2],name[3]));
	memcpy(bytes+8,[data bytes],length);
	uint32_t crcval = CRC(bytes+4,length+4);
	WriteUnsignedInt(bytes+8+length,crcval);
	return dstData;
}

