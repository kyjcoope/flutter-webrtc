#ifndef NATIVE_BUFFER_H
#define NATIVE_BUFFER_H

#include <vector>
#include <memory>
#include <mutex>
#include <condition_variable>
#include <cstdint>
#include <exception>

enum VideoColorFormat {
    COLOR_FORMAT_UNKNOWN = 0,
    COLOR_FORMAT_I420   = 1,
    COLOR_FORMAT_NV12   = 2,
    COLOR_FORMAT_NV21   = 3,
    COLOR_FORMAT_RGBA   = 10,
};

class MediaFrame {
public:
    uint64_t frameTime;
    std::unique_ptr<uint8_t[]> buffer;
    size_t bufferSize;
    size_t bufferCapacity;
    
    int width;
    int height;
    int rotation;
    int colorFormat;

    explicit MediaFrame(size_t initial_capacity)
        : frameTime(0),
          buffer(std::make_unique<uint8_t[]>(initial_capacity)),
          bufferSize(0),
          bufferCapacity(initial_capacity),
          width(0),
          height(0),
          rotation(0),
          colorFormat(COLOR_FORMAT_UNKNOWN) {
        if (!buffer) {
            throw std::runtime_error("Failed to allocate MediaFrame buffer.");
        }
    }

    MediaFrame(const MediaFrame&) = delete;
    MediaFrame& operator=(const MediaFrame&) = delete;
    MediaFrame(MediaFrame&&) = default;
    MediaFrame& operator=(MediaFrame&&) = default;

    bool ensureCapacity(size_t required) {
        if (required <= bufferCapacity) return true;
        try {
            auto newBuf = std::make_unique<uint8_t[]>(required);
            buffer = std::move(newBuf);
            bufferCapacity = required;
            bufferSize = 0;
            return true;
        } catch (const std::bad_alloc&) {
            return false;
        }
    }
};

class NativeBuffer {
public:
    NativeBuffer(int capacity, int initial_max_frame_size);
    ~NativeBuffer() = default;

    NativeBuffer(const NativeBuffer&) = delete;
    NativeBuffer& operator=(const NativeBuffer&) = delete;

    int pushVideoFrame(const uint8_t* data, size_t data_size,
                       int width, int height, uint64_t frame_time_ms,
                       int rotation, int color_format);

    MediaFrame* popFrame();

private:
    int pushInternal(const uint8_t* data, size_t data_size,
                     int width, int height, int rotation, int color_format,
                     uint64_t frame_time);

    std::vector<std::unique_ptr<MediaFrame>> frames_;
    const size_t capacity_;
    size_t current_max_frame_size_;
    size_t write_index_;
    size_t read_index_;
    size_t count_;

    std::mutex mutex_;
    std::condition_variable not_empty_cv_;
};

#endif // NATIVE_BUFFER_H
