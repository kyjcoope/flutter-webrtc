#ifndef NATIVE_BUFFER_H
#define NATIVE_BUFFER_H

#include <stddef.h>
#include <stdint.h>
#include <pthread.h>

typedef struct {
  int width;
  int height;
  uint64_t frameTime;
  int rotation;
  int frameType;
  uint8_t* buffer;
  int bufferSize;
} EncodedFrame;

typedef struct {
  EncodedFrame** frames;
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
EncodedFrame* nativeBufferPop(NativeBuffer* rb);
void nativeBufferFree(NativeBuffer* rb);

#endif // NATIVE_BUFFER_H
