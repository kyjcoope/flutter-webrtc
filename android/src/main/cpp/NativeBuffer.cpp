#include "NativeBuffer.h"
#include <cstring>
#include <stdexcept>

NativeBuffer::NativeBuffer(int capacity, int max_buffer_size) :
    capacity_(static_cast<size_t>(capacity)),
    max_frame_buffer_size_(static_cast<size_t>(max_buffer_size)),
    write_index_(0),
    read_index_(0),
    count_(0)
{
    if (capacity <= 0 || max_buffer_size <= 0) {
        throw std::invalid_argument("Capacity and max_buffer_size must be positive.");
    }
    frames_.reserve(capacity_);
    for (size_t i = 0; i < capacity_; ++i) {
        frames_.emplace_back(std::make_unique<MediaFrame>(max_frame_buffer_size_));
        if (!frames_.back() || !frames_.back()->hasBuffer()) {
             throw std::runtime_error("Failed to allocate MediaFrame buffer.");
        }
    }
}

int NativeBuffer::pushVideoFrame(const uint8_t* data, size_t data_size,
                                 int width, int height, uint64_t frame_time, int rotation, int frame_type) {
    if (data_size > max_frame_buffer_size_) {
        return -1;
    }
    std::unique_lock<std::mutex> lock(mutex_);
    not_full_cv_.wait(lock, [this] { return count_.load() < capacity_; });
    MediaFrame* frame_to_write = frames_[write_index_].get();
    std::memcpy(frame_to_write->buffer.get(), data, data_size);
    frame_to_write->bufferSize = data_size;
    frame_to_write->mediaType = MEDIA_TYPE_VIDEO;
    frame_to_write->frameTime = frame_time;
    frame_to_write->metadata.video.width = width;
    frame_to_write->metadata.video.height = height;
    frame_to_write->metadata.video.rotation = rotation;
    frame_to_write->metadata.video.frameType = frame_type;
    write_index_ = (write_index_ + 1) % capacity_;
    count_++;
    lock.unlock();
    not_empty_cv_.notify_one();
    return 0;
}

int NativeBuffer::pushAudioFrame(const uint8_t* data, size_t data_size,
                                 int sample_rate, int channels, uint64_t frame_time) {
    if (data_size > max_frame_buffer_size_) {
        return -1;
    }
    std::unique_lock<std::mutex> lock(mutex_);
    not_full_cv_.wait(lock, [this] { return count_.load() < capacity_; });
    MediaFrame* frame_to_write = frames_[write_index_].get();
    std::memcpy(frame_to_write->buffer.get(), data, data_size);
    frame_to_write->bufferSize = data_size;
    frame_to_write->mediaType = MEDIA_TYPE_AUDIO;
    frame_to_write->frameTime = frame_time;
    frame_to_write->metadata.audio.sampleRate = sample_rate;
    frame_to_write->metadata.audio.channels = channels;
    write_index_ = (write_index_ + 1) % capacity_;
    count_++;
    lock.unlock();
    not_empty_cv_.notify_one();
    return 0;
}

MediaFrame* NativeBuffer::popFrame() {
    std::unique_lock<std::mutex> lock(mutex_);
    not_empty_cv_.wait(lock, [this] { return count_.load() > 0; });
    MediaFrame* frame_to_read = frames_[read_index_].get();
    read_index_ = (read_index_ + 1) % capacity_;
    count_--;
    lock.unlock();
    not_full_cv_.notify_one();
    return frame_to_read;
}

MediaFrame* NativeBuffer::getLastPushedFrame() {
     std::lock_guard<std::mutex> lock(mutex_);
     if (count_.load() == 0) {
         return nullptr;
     }
     size_t last_write_index = (write_index_ == 0) ? (capacity_ - 1) : (write_index_ - 1);
     return frames_[last_write_index].get();
}
