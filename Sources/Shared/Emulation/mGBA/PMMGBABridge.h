#ifndef PMMGBA_BRIDGE_H
#define PMMGBA_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PMMGBAEmulator PMMGBAEmulator;

typedef enum PMMGBAButton {
    PMMGBAButtonA = 0,
    PMMGBAButtonB = 1,
    PMMGBAButtonSelect = 2,
    PMMGBAButtonStart = 3,
    PMMGBAButtonRight = 4,
    PMMGBAButtonLeft = 5,
    PMMGBAButtonUp = 6,
    PMMGBAButtonDown = 7,
} PMMGBAButton;

PMMGBAEmulator* PMMGBAEmulatorCreate(const uint8_t* romData, size_t romSize);
void PMMGBAEmulatorDestroy(PMMGBAEmulator* emulator);

int PMMGBAEmulatorWidth(const PMMGBAEmulator* emulator);
int PMMGBAEmulatorHeight(const PMMGBAEmulator* emulator);

bool PMMGBAEmulatorRunFrame(PMMGBAEmulator* emulator);
bool PMMGBAEmulatorCopyFrameRGBA(const PMMGBAEmulator* emulator, uint8_t* destination, size_t destinationSize);

bool PMMGBAEmulatorLoadSaveData(PMMGBAEmulator* emulator, const uint8_t* data, size_t size);
size_t PMMGBAEmulatorSaveDataSize(PMMGBAEmulator* emulator);
bool PMMGBAEmulatorCopySaveData(PMMGBAEmulator* emulator, uint8_t* destination, size_t destinationSize);

size_t PMMGBAEmulatorStateSize(PMMGBAEmulator* emulator);
bool PMMGBAEmulatorSaveState(PMMGBAEmulator* emulator, uint8_t* destination, size_t destinationSize);
bool PMMGBAEmulatorLoadState(PMMGBAEmulator* emulator, const uint8_t* data, size_t size);

int PMMGBAEmulatorAudioSampleRate(const PMMGBAEmulator* emulator);
size_t PMMGBAEmulatorAudioAvailable(PMMGBAEmulator* emulator);
size_t PMMGBAEmulatorReadAudioS16(PMMGBAEmulator* emulator, int16_t* destination, size_t frames);

void PMMGBAEmulatorSetButton(PMMGBAEmulator* emulator, PMMGBAButton button, bool pressed);

#ifdef __cplusplus
}
#endif

#endif
