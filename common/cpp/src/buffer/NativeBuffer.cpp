#include "buffer/NativeBuffer.h"
#include <stdlib.h>
#include <string.h>

NativeBuffer* nativeBufferInit(int capacity, int maxBufferSize) {
    NativeBuffer* rb = (NativeBuffer*)malloc(sizeof(NativeBuffer));
    if (!rb) return NULL;
    rb->capacity = capacity;
    rb->maxBufferSize = maxBufferSize;
    rb->writeIndex = 0;
    rb->readIndex = 0;
    rb->count = 0;
    rb->frames = (EncodedFrame**)malloc(capacity * sizeof(EncodedFrame*));
    if (!rb->frames) {
        free(rb);
        return NULL;
    }

    for (int i = 0; i < capacity; i++) {
       rb->frames[i] = (EncodedFrame*)malloc(sizeof(EncodedFrame));
       if (!rb->frames[i]) {
          for (int j = 0; j < i; j++) free(rb->frames[j]);
          free(rb->frames);
          free(rb);
          return NULL;
       }
       rb->frames[i]->width = 0;
       rb->frames[i]->height = 0;
       rb->frames[i]->frameTime = 0;
       rb->frames[i]->rotation = 0;
       rb->frames[i]->frameType = 0;
       rb->frames[i]->bufferSize = 0;
       rb->frames[i]->buffer = (uint8_t*)malloc(maxBufferSize);
       if (!rb->frames[i]->buffer) {
          for (int j = 0; j <= i; j++) {
              if (rb->frames[j]) free(rb->frames[j]);
          }
          free(rb->frames);
          free(rb);
          return NULL;
       }
    }
    pthread_mutex_init(&rb->mutex, NULL);
    pthread_cond_init(&rb->notEmpty, NULL);
    pthread_cond_init(&rb->notFull, NULL);
    return rb;
}

int nativeBufferPush(NativeBuffer* rb, const uint8_t* data, int dataSize,
                   int width, int height, uint64_t frameTime, int rotation, int frameType) {
    pthread_mutex_lock(&rb->mutex);
    while (rb->count == rb->capacity) {
       pthread_cond_wait(&rb->notFull, &rb->mutex);
    }
    if (dataSize > rb->maxBufferSize) {
      pthread_mutex_unlock(&rb->mutex);
      return -1;
    }

    EncodedFrame* frame = rb->frames[rb->writeIndex];
    memcpy(frame->buffer, data, dataSize);
    frame->bufferSize = dataSize;
    frame->width = width;
    frame->height = height;
    frame->frameTime = frameTime;
    frame->rotation = rotation;
    frame->frameType = frameType;
    
    rb->writeIndex = (rb->writeIndex + 1) % rb->capacity;
    rb->count++;
    pthread_cond_signal(&rb->notEmpty);
    pthread_mutex_unlock(&rb->mutex);
    return 0;
}

EncodedFrame* nativeBufferPop(NativeBuffer* rb) {
    if (!rb) return NULL;
    pthread_mutex_lock(&rb->mutex);
    while (rb->count == 0) {
       pthread_cond_wait(&rb->notEmpty, &rb->mutex);
    }
    EncodedFrame* frame = rb->frames[rb->readIndex];
    rb->readIndex = (rb->readIndex + 1) % rb->capacity;
    rb->count--;
    pthread_cond_signal(&rb->notFull);
    pthread_mutex_unlock(&rb->mutex);
    return frame;
}

void nativeBufferFree(NativeBuffer* rb) {
    if (!rb) return;
    for (int i = 0; i < rb->capacity; i++) {
      if (rb->frames[i]) {
          if (rb->frames[i]->buffer) free(rb->frames[i]->buffer);
          free(rb->frames[i]);
      }
    }
    free(rb->frames);
    pthread_mutex_destroy(&rb->mutex);
    pthread_cond_destroy(&rb->notEmpty);
    pthread_cond_destroy(&rb->notFull);
    free(rb);
}
