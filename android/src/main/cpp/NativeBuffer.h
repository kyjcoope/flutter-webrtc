#ifndef NATIVE_BUFFER_H
#define NATIVE_BUFFER_H

#include <stddef.h>
#include <stdint.h>
#include <pthread.h>

typedef enum {
  MEDIA_TYPE_VIDEO = 0,
  MEDIA_TYPE_AUDIO = 1
} MediaType;

typedef union {
  struct {
    int width;
    int height;
    int rotation;
    int frameType;
  } video;
  
  struct {
    int sampleRate;
    int channels;
  } audio;
} MediaMetadata;

typedef struct {
  MediaType mediaType;
  uint64_t frameTime;
  uint8_t* buffer;
  int bufferSize;
  
  MediaMetadata metadata;
} MediaFrame;

typedef struct {
  MediaFrame** frames;
  int capacity;
  int maxBufferSize;
  int writeIndex;
  int readIndex;
  int count;
  pthread_mutex_t mutex;
  pthread_cond_t notEmpty;
  pthread_cond_t notFull;
} NativeBuffer;

NativeBuffer* nativeBufferInit(int capacity, int maxBufferSize);
int nativeBufferPush(NativeBuffer* rb, const uint8_t* data, int dataSize,
  int width, int height, uint64_t frameTime, int rotation, int frameType);

int nativeBufferPushAudio(NativeBuffer* rb, const uint8_t* data, int dataSize,
  int sampleRate, int channels, uint64_t frameTime);

MediaFrame* nativeBufferPop(NativeBuffer* rb);
void nativeBufferFree(NativeBuffer* rb);

#endif // NATIVE_BUFFER_H
