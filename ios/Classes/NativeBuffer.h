#ifndef NATIVE_BUFFER_H
#define NATIVE_BUFFER_H

#include <vector>
#include <memory>
#include <mutex>
#include <condition_variable>
#include <cstdint>
#include <exception>

typedef enum {
    VIDEO_CODEC_UNKNOWN = 0,
    VIDEO_CODEC_H264 = 1,
    VIDEO_CODEC_H265 = 2,
    VIDEO_CODEC_VP8 = 3,
    VIDEO_CODEC_VP9 = 4,
    VIDEO_CODEC_AV1 = 5,
} VideoCodecType;

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
    VideoCodecType codecType;
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

    explicit MediaFrame(size_t initial_buffer_capacity) :
        mediaType(MEDIA_TYPE_VIDEO),
        frameTime(0),
        buffer(std::make_unique<uint8_t[]>(initial_buffer_capacity)),
        bufferSize(0),
        bufferCapacity(initial_buffer_capacity),
        metadata{}
    {
        if (!buffer) {
             throw std::runtime_error("Failed to allocate initial MediaFrame buffer.");
        }
        metadata.video.codecType = VIDEO_CODEC_UNKNOWN;
    }

    MediaFrame(const MediaFrame&) = delete;
    MediaFrame& operator=(const MediaFrame&) = delete;
    MediaFrame(MediaFrame&&) = default;
    MediaFrame& operator=(MediaFrame&&) = default;

    bool hasBuffer() const { return buffer != nullptr; }
    bool ensureBufferCapacity(size_t required_capacity) {
        if (required_capacity <= bufferCapacity) {
            return true;
        }
        try {
            auto new_buffer = std::make_unique<uint8_t[]>(required_capacity);
            buffer = std::move(new_buffer);
            bufferCapacity = required_capacity;
            bufferSize = 0;
            return true;
        } catch (const std::bad_alloc&) {
            return false;
        }
    }
};

class NativeBuffer {
public:
    NativeBuffer(int capacity, int initial_max_buffer_size);
    ~NativeBuffer() = default;

    NativeBuffer(const NativeBuffer&) = delete;
    NativeBuffer& operator=(const NativeBuffer&) = delete;

    int pushVideoFrame(const uint8_t* data, size_t data_size,
                       int width, int height, uint64_t frame_time,
                       int rotation, int frame_type, VideoCodecType codec_type);
    int pushAudioFrame(const uint8_t* data, size_t data_size,
                       int sample_rate, int channels, uint64_t frame_time);
    MediaFrame* popFrame();

private:
    int pushInternal(const uint8_t* data, size_t data_size, MediaType type, MediaMetadata metadata_union, uint64_t frame_time);

    std::vector<std::unique_ptr<MediaFrame>> frames_;
    const size_t capacity_;
    size_t current_max_frame_buffer_size_;
    size_t write_index_;
    size_t read_index_;
    size_t count_;

    std::mutex mutex_;
    std::condition_variable not_empty_cv_;
    std::condition_variable not_full_cv_;
};

#endif // NATIVE_BUFFER_H
