#include "NativeBuffer.h"
#include <cstring>
#include <stdexcept>

NativeBuffer::NativeBuffer(int capacity, int initial_max_frame_size)
    : capacity_(static_cast<size_t>(capacity)),
      current_max_frame_size_(static_cast<size_t>(initial_max_frame_size)),
      write_index_(0),
      read_index_(0),
      count_(0) {
    if (capacity <= 0 || initial_max_frame_size <= 0) {
        throw std::invalid_argument("Capacity and initial_max_frame_size must be positive.");
    }
    frames_.reserve(capacity_);
    for (size_t i = 0; i < capacity_; ++i) {
        frames_.emplace_back(std::make_unique<MediaFrame>(current_max_frame_size_));
    }
}

int NativeBuffer::pushInternal(const uint8_t* data, size_t data_size,
                               int width, int height, int rotation, int color_format,
                               uint64_t frame_time) {
    std::unique_lock<std::mutex> lock(mutex_);

    MediaFrame* frame = frames_[write_index_].get();
    if (data_size > frame->bufferCapacity) {
        if (!frame->ensureCapacity(data_size)) {
            return -1;
        }
        if (data_size > current_max_frame_size_) {
            current_max_frame_size_ = data_size;
        }
    }
    if (count_ >= capacity_) {
        read_index_ = (read_index_ + 1) % capacity_;
        count_--;
    }

    std::memcpy(frame->buffer.get(), data, data_size);
    frame->bufferSize = data_size;
    frame->frameTime = frame_time;
    frame->width = width;
    frame->height = height;
    frame->rotation = rotation;
    frame->colorFormat = color_format;

    write_index_ = (write_index_ + 1) % capacity_;
    count_++;
    lock.unlock();
    not_empty_cv_.notify_one();
    return 0;
}

int NativeBuffer::pushVideoFrame(const uint8_t* data, size_t data_size,
                                 int width, int height, uint64_t frame_time_ms,
                                 int rotation, int color_format) {
    return pushInternal(data, data_size, width, height, rotation, color_format, frame_time_ms);
}

MediaFrame* NativeBuffer::popFrame() {
    std::unique_lock<std::mutex> lock(mutex_);
    not_empty_cv_.wait(lock, [this]{ return count_ > 0; });
    MediaFrame* frame = frames_[read_index_].get();
    read_index_ = (read_index_ + 1) % capacity_;
    count_--;
    return frame;
}
