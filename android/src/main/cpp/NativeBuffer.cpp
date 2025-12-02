#include "NativeBuffer.h"
#include <cstring>
#include <stdexcept>
#include <new>

NativeBuffer::NativeBuffer(int capacity, int initial_max_buffer_size) :
    capacity_(static_cast<size_t>(capacity)),
    current_max_frame_buffer_size_(static_cast<size_t>(initial_max_buffer_size)),
    write_index_(0),
    read_index_(0),
    count_(0)
{
    if (capacity <= 0 || initial_max_buffer_size <= 0) {
        throw std::invalid_argument("Capacity and initial_max_buffer_size must be positive.");
    }

    frames_.reserve(capacity_);
    for (size_t i = 0; i < capacity_; ++i) {
        frames_.emplace_back(std::make_unique<MediaFrame>(current_max_frame_buffer_size_));
    }
}

int NativeBuffer::pushInternal(const uint8_t* data, size_t data_size, MediaType type, MediaMetadata metadata_union, uint64_t frame_time) {
    std::unique_lock<std::mutex> lock(mutex_);
    MediaFrame* frame_to_write = frames_[write_index_].get();
    if (data_size > frame_to_write->bufferCapacity) {
        if (!frame_to_write->ensureBufferCapacity(data_size)) {
            return -1;
        }
        if (data_size > current_max_frame_buffer_size_) {
            current_max_frame_buffer_size_ = data_size;
        }
    }
    
    if (count_ >= capacity_) {
        read_index_ = (read_index_ + 1) % capacity_;
        count_--;
    }

    std::memcpy(frame_to_write->buffer.get(), data, data_size);
    frame_to_write->bufferSize = data_size;
    frame_to_write->mediaType = type;
    frame_to_write->frameTime = frame_time;
    frame_to_write->metadata = metadata_union;
    write_index_ = (write_index_ + 1) % capacity_;
    count_++;
    lock.unlock();
    not_empty_cv_.notify_one();
    return 0;
}

int NativeBuffer::pushVideoFrame(const uint8_t* data, size_t data_size,
                                 int width, int height, uint64_t frame_time,
                                 int rotation, int frame_type, VideoCodecType codec_type) {
    MediaMetadata metadata_union;
    metadata_union.video.width = width;
    metadata_union.video.height = height;
    metadata_union.video.rotation = rotation;
    metadata_union.video.frameType = frame_type;
    metadata_union.video.codecType = codec_type;
    return pushInternal(data, data_size, MEDIA_TYPE_VIDEO, metadata_union, frame_time);
}

int NativeBuffer::pushAudioFrame(const uint8_t* data, size_t data_size,
                                 int sample_rate, int channels, uint64_t frame_time) {
    MediaMetadata metadata_union;
    metadata_union.audio.sampleRate = sample_rate;
    metadata_union.audio.channels = channels;
    return pushInternal(data, data_size, MEDIA_TYPE_AUDIO, metadata_union, frame_time);
}

MediaFrame* NativeBuffer::popFrame() {
    std::unique_lock<std::mutex> lock(mutex_);
    not_empty_cv_.wait(lock, [this] { return count_ > 0; });
    MediaFrame* frame_to_read = frames_[read_index_].get();
    read_index_ = (read_index_ + 1) % capacity_;
    count_--;
    lock.unlock();
    not_full_cv_.notify_one();
    return frame_to_read;
}
