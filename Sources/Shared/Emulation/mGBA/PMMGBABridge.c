#include "PMMGBABridge.h"

// Keep these in sync with the mGBA static library CMake compile definitions.
// They affect public struct layouts such as struct mCore, so the bridge must
// see the same ABI as the compiled mGBA objects.
#ifndef ENABLE_DIRECTORIES
#define ENABLE_DIRECTORIES
#endif
#ifndef ENABLE_VFS_FD
#define ENABLE_VFS_FD
#endif
#ifndef HAVE_USELOCALE
#define HAVE_USELOCALE
#endif
#ifndef BUILD_STATIC
#define BUILD_STATIC
#endif

#include <stdlib.h>
#include <stddef.h>
#include <string.h>

#include <mgba/flags.h>
#include <mgba-util/audio-buffer.h>
#include <mgba-util/vfs.h>
#include <mgba/core/config.h>
#include <mgba/core/core.h>
#include <mgba/core/interface.h>
#include <mgba/gb/core.h>
#include <mgba/internal/gb/input.h>

#define PMMGBA_STRIDE 256
#define PMMGBA_MAX_HEIGHT 256
#define PMMGBA_AUDIO_QUEUE_FRAMES 32768
#define PMMGBA_AUDIO_COPY_FRAMES 2048

struct PMMGBAEmulator {
    struct mCore* core;
    struct mAVStream stream;
    struct VFile* romFile;
    uint8_t* romData;
    size_t romSize;
    mColor* videoBuffer;
    int16_t audioQueue[PMMGBA_AUDIO_QUEUE_FRAMES * 2];
    size_t audioReadIndex;
    size_t audioWriteIndex;
    size_t audioFramesQueued;
    unsigned width;
    unsigned height;
    uint32_t keys;
};

static PMMGBAEmulator* PMMGBAEmulatorFromStream(struct mAVStream* stream) {
    if (!stream) {
        return NULL;
    }

    return (PMMGBAEmulator*) ((uint8_t*) stream - offsetof(PMMGBAEmulator, stream));
}

static void PMMGBAEmulatorQueueAudio(PMMGBAEmulator* emulator, const int16_t* samples, size_t frames) {
    if (!emulator || !samples || frames == 0) {
        return;
    }

    for (size_t frame = 0; frame < frames; frame++) {
        if (emulator->audioFramesQueued == PMMGBA_AUDIO_QUEUE_FRAMES) {
            emulator->audioReadIndex = (emulator->audioReadIndex + 1) % PMMGBA_AUDIO_QUEUE_FRAMES;
            emulator->audioFramesQueued--;
        }

        size_t sampleIndex = emulator->audioWriteIndex * 2;
        emulator->audioQueue[sampleIndex] = samples[frame * 2];
        emulator->audioQueue[sampleIndex + 1] = samples[frame * 2 + 1];
        emulator->audioWriteIndex = (emulator->audioWriteIndex + 1) % PMMGBA_AUDIO_QUEUE_FRAMES;
        emulator->audioFramesQueued++;
    }
}

static void PMMGBAEmulatorPostAudioBuffer(struct mAVStream* stream, struct mAudioBuffer* buffer) {
    PMMGBAEmulator* emulator = PMMGBAEmulatorFromStream(stream);
    if (!emulator || !buffer) {
        return;
    }

    int16_t samples[PMMGBA_AUDIO_COPY_FRAMES * 2];
    size_t available = mAudioBufferAvailable(buffer);
    while (available > 0) {
        size_t framesToRead = available > PMMGBA_AUDIO_COPY_FRAMES ? PMMGBA_AUDIO_COPY_FRAMES : available;
        size_t framesRead = mAudioBufferRead(buffer, samples, framesToRead);
        if (framesRead == 0) {
            return;
        }

        PMMGBAEmulatorQueueAudio(emulator, samples, framesRead);
        available = mAudioBufferAvailable(buffer);
    }
}

static void PMMGBAEmulatorPostAudioFrame(struct mAVStream* stream, int16_t left, int16_t right) {
    PMMGBAEmulator* emulator = PMMGBAEmulatorFromStream(stream);
    if (!emulator) {
        return;
    }

    int16_t samples[2] = { left, right };
    PMMGBAEmulatorQueueAudio(emulator, samples, 1);
}

static uint32_t PMMGBAKeyMask(PMMGBAButton button) {
    switch (button) {
        case PMMGBAButtonA: return 1u << GB_KEY_A;
        case PMMGBAButtonB: return 1u << GB_KEY_B;
        case PMMGBAButtonSelect: return 1u << GB_KEY_SELECT;
        case PMMGBAButtonStart: return 1u << GB_KEY_START;
        case PMMGBAButtonRight: return 1u << GB_KEY_RIGHT;
        case PMMGBAButtonLeft: return 1u << GB_KEY_LEFT;
        case PMMGBAButtonUp: return 1u << GB_KEY_UP;
        case PMMGBAButtonDown: return 1u << GB_KEY_DOWN;
    }
}

PMMGBAEmulator* PMMGBAEmulatorCreate(const uint8_t* romData, size_t romSize) {
    if (!romData || romSize == 0) {
        return NULL;
    }

    PMMGBAEmulator* emulator = calloc(1, sizeof(PMMGBAEmulator));
    if (!emulator) {
        return NULL;
    }

    emulator->romData = malloc(romSize);
    if (!emulator->romData) {
        PMMGBAEmulatorDestroy(emulator);
        return NULL;
    }
    memcpy(emulator->romData, romData, romSize);
    emulator->romSize = romSize;

    emulator->videoBuffer = calloc(PMMGBA_STRIDE * PMMGBA_MAX_HEIGHT, sizeof(mColor));
    if (!emulator->videoBuffer) {
        PMMGBAEmulatorDestroy(emulator);
        return NULL;
    }

    emulator->core = GBCoreCreate();
    if (!emulator->core) {
        PMMGBAEmulatorDestroy(emulator);
        return NULL;
    }

    if (!emulator->core->init(emulator->core)) {
        PMMGBAEmulatorDestroy(emulator);
        return NULL;
    }

    mCoreInitConfig(emulator->core, "pmemu");
    mCoreConfigSetDefaultValue(&emulator->core->config, "idleOptimization", "detect");
    mCoreConfigSetDefaultValue(&emulator->core->config, "mute", "0");
    mCoreConfigSetDefaultValue(&emulator->core->config, "volume", "256");
    mCoreConfigSetDefaultValue(&emulator->core->config, "audioBuffers", "512");
    mCoreLoadConfig(emulator->core);

    emulator->stream.postAudioFrame = PMMGBAEmulatorPostAudioFrame;
    emulator->core->setAVStream(emulator->core, &emulator->stream);
    emulator->core->setVideoBuffer(emulator->core, emulator->videoBuffer, PMMGBA_STRIDE);

    emulator->romFile = VFileFromConstMemory(emulator->romData, emulator->romSize);
    if (!emulator->romFile) {
        PMMGBAEmulatorDestroy(emulator);
        return NULL;
    }

    bool loaded = emulator->core->loadROM(emulator->core, emulator->romFile);

    if (!loaded) {
        PMMGBAEmulatorDestroy(emulator);
        return NULL;
    }

    emulator->core->reset(emulator->core);
    emulator->core->setAudioBufferSize(emulator->core, 512);
    emulator->core->currentVideoSize(emulator->core, &emulator->width, &emulator->height);
    if (emulator->width == 0 || emulator->height == 0 || emulator->width > PMMGBA_STRIDE || emulator->height > PMMGBA_MAX_HEIGHT) {
        emulator->width = 160;
        emulator->height = 144;
    }

    return emulator;
}

void PMMGBAEmulatorDestroy(PMMGBAEmulator* emulator) {
    if (!emulator) {
        return;
    }

    if (emulator->core) {
        emulator->core->setAVStream(emulator->core, NULL);
        emulator->core->unloadROM(emulator->core);
        mCoreConfigDeinit(&emulator->core->config);
        emulator->core->deinit(emulator->core);
    }

    // Do not close emulator->romFile here. mGBA takes ownership of the VFile
    // in GBLoadROM() and closes it from unloadROM()/GBDestroy(). Closing it
    // again causes a crash when leaving and reopening the emulator screen.

    free(emulator->videoBuffer);
    free(emulator->romData);
    free(emulator);
}

int PMMGBAEmulatorWidth(const PMMGBAEmulator* emulator) {
    return emulator ? (int) emulator->width : 0;
}

int PMMGBAEmulatorHeight(const PMMGBAEmulator* emulator) {
    return emulator ? (int) emulator->height : 0;
}

bool PMMGBAEmulatorRunFrame(PMMGBAEmulator* emulator) {
    if (!emulator || !emulator->core) {
        return false;
    }

    emulator->core->setKeys(emulator->core, emulator->keys);
    emulator->core->runFrame(emulator->core);
    return true;
}

bool PMMGBAEmulatorCopyFrameRGBA(const PMMGBAEmulator* emulator, uint8_t* destination, size_t destinationSize) {
    if (!emulator || !emulator->videoBuffer || !destination) {
        return false;
    }

    size_t requiredSize = (size_t) emulator->width * (size_t) emulator->height * 4;
    if (destinationSize < requiredSize) {
        return false;
    }

    for (unsigned y = 0; y < emulator->height; y++) {
        const mColor* sourceRow = emulator->videoBuffer + (y * PMMGBA_STRIDE);
        uint8_t* destRow = destination + ((size_t) y * (size_t) emulator->width * 4);

        for (unsigned x = 0; x < emulator->width; x++) {
            uint32_t color = (uint32_t) sourceRow[x];
            destRow[x * 4 + 0] = (uint8_t) (color & 0xFF);         // R
            destRow[x * 4 + 1] = (uint8_t) ((color >> 8) & 0xFF);  // G
            destRow[x * 4 + 2] = (uint8_t) ((color >> 16) & 0xFF); // B
            destRow[x * 4 + 3] = 0xFF;                             // A
        }
    }

    return true;
}

bool PMMGBAEmulatorLoadSaveData(PMMGBAEmulator* emulator, const uint8_t* data, size_t size) {
    if (!emulator || !emulator->core || !data || size == 0) {
        return false;
    }

    return emulator->core->savedataRestore(emulator->core, data, size, false);
}

size_t PMMGBAEmulatorSaveDataSize(PMMGBAEmulator* emulator) {
    if (!emulator || !emulator->core) {
        return 0;
    }

    void* saveData = NULL;
    size_t size = emulator->core->savedataClone(emulator->core, &saveData);
    free(saveData);
    return size;
}

bool PMMGBAEmulatorCopySaveData(PMMGBAEmulator* emulator, uint8_t* destination, size_t destinationSize) {
    if (!emulator || !emulator->core || !destination) {
        return false;
    }

    void* saveData = NULL;
    size_t size = emulator->core->savedataClone(emulator->core, &saveData);
    if (!saveData || size == 0 || destinationSize < size) {
        free(saveData);
        return false;
    }

    memcpy(destination, saveData, size);
    free(saveData);
    return true;
}

size_t PMMGBAEmulatorStateSize(PMMGBAEmulator* emulator) {
    if (!emulator || !emulator->core) {
        return 0;
    }

    return emulator->core->stateSize(emulator->core);
}

bool PMMGBAEmulatorSaveState(PMMGBAEmulator* emulator, uint8_t* destination, size_t destinationSize) {
    if (!emulator || !emulator->core || !destination) {
        return false;
    }

    size_t size = emulator->core->stateSize(emulator->core);
    if (size == 0 || destinationSize < size) {
        return false;
    }

    return emulator->core->saveState(emulator->core, destination);
}

bool PMMGBAEmulatorLoadState(PMMGBAEmulator* emulator, const uint8_t* data, size_t size) {
    if (!emulator || !emulator->core || !data) {
        return false;
    }

    size_t expectedSize = emulator->core->stateSize(emulator->core);
    if (expectedSize == 0 || size != expectedSize) {
        return false;
    }

    return emulator->core->loadState(emulator->core, data);
}

int PMMGBAEmulatorAudioSampleRate(const PMMGBAEmulator* emulator) {
    if (!emulator || !emulator->core) {
        return 0;
    }

    return (int) emulator->core->audioSampleRate(emulator->core);
}

size_t PMMGBAEmulatorAudioAvailable(PMMGBAEmulator* emulator) {
    if (!emulator) {
        return 0;
    }

    return emulator->audioFramesQueued;
}

size_t PMMGBAEmulatorReadAudioS16(PMMGBAEmulator* emulator, int16_t* destination, size_t frames) {
    if (!emulator || !destination || frames == 0) {
        return 0;
    }

    size_t framesRead = 0;
    while (framesRead < frames && emulator->audioFramesQueued > 0) {
        size_t sourceIndex = emulator->audioReadIndex * 2;
        destination[framesRead * 2] = emulator->audioQueue[sourceIndex];
        destination[framesRead * 2 + 1] = emulator->audioQueue[sourceIndex + 1];
        emulator->audioReadIndex = (emulator->audioReadIndex + 1) % PMMGBA_AUDIO_QUEUE_FRAMES;
        emulator->audioFramesQueued--;
        framesRead++;
    }

    return framesRead;
}

void PMMGBAEmulatorSetButton(PMMGBAEmulator* emulator, PMMGBAButton button, bool pressed) {
    if (!emulator) {
        return;
    }

    uint32_t mask = PMMGBAKeyMask(button);
    if (pressed) {
        emulator->keys |= mask;
    } else {
        emulator->keys &= ~mask;
    }
}
