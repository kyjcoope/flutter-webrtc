#ifndef NATIVE_BUFFER_H
#define NATIVE_BUFFER_H

#include <vector>
#include <memory>
#include <mutex>
#include <condition_variable>
#include <cstdint>

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

class MediaFrame {
public:
    MediaType mediaType;
    uint64_t frameTime;
    std::unique_ptr<uint8_t[]> buffer;
    size_t bufferSize;
    size_t bufferCapacity;
    MediaMetadata metadata;

    explicit MediaFrame(size_t max_buffer_size) :
        mediaType(MEDIA_TYPE_VIDEO),
        frameTime(0),
        buffer(std::make_unique<uint8_t[]>(max_buffer_size)),
        bufferSize(0),
        bufferCapacity(max_buffer_size),
        metadata{}
    {}

    MediaFrame(const MediaFrame&) = delete;
    MediaFrame& operator=(const MediaFrame&) = delete;
    MediaFrame(MediaFrame&&) = default;
    MediaFrame& operator=(MediaFrame&&) = default;

    bool hasBuffer() const { return buffer != nullptr; }
};

class NativeBuffer {
public:
    NativeBuffer(int capacity, int max_buffer_size);
    ~NativeBuffer() = default;

    NativeBuffer(const NativeBuffer&) = delete;
    NativeBuffer& operator=(const NativeBuffer&) = delete;
    int pushVideoFrame(const uint8_t* data, size_t data_size,
                       int width, int height, uint64_t frame_time, int rotation, int frame_type);
    int pushAudioFrame(const uint8_t* data, size_t data_size,
                       int sample_rate, int channels, uint64_t frame_time);
    MediaFrame* popFrame();
    MediaFrame* getLastPushedFrame();

private:
    std::vector<std::unique_ptr<MediaFrame>> frames_;
    const size_t capacity_;
    const size_t max_frame_buffer_size_;

    size_t write_index_;
    size_t read_index_;
    size_t count_;

    std::mutex mutex_;
    std::condition_variable not_empty_cv_;
    std::condition_variable not_full_cv_;
};

#endif // NATIVE_BUFFER_H
