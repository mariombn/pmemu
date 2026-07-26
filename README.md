# PMEmu

PMEmu é um MVP de emulador para iPhone e Apple Watch.

Estado atual:

- App iOS em SwiftUI.
- App watchOS em SwiftUI.
- Core mGBA integrado via `mGBA.xcframework`.
- ROM homebrew `2048.gb` embutida para teste.
- Tela de emulação funcional no iPhone com controles básicos.

## Roadmap

1. Game Boy / Game Boy Color no iPhone.
2. Game Boy / Game Boy Color no Apple Watch.
3. Importação de ROMs via Files.
4. Saves `.sav`.
5. Sincronização iPhone ↔ Apple Watch.
6. Nintendo 64 no iPhone.

## Requisitos

```bash
brew install xcodegen cmake
```

Também é necessário Xcode completo instalado em:

```txt
/Applications/Xcode.app
```

## Setup

Após clonar o projeto:

```bash
git submodule update --init --recursive
```

Gere o framework do mGBA:

```bash
./Scripts/build-mgba.sh
```

Gere o projeto Xcode:

```bash
xcodegen generate
```

Abra no Xcode:

```bash
open PMEmu.xcodeproj
```

## Build pelo terminal

iOS Simulator:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project PMEmu.xcodeproj \
  -scheme PMEmu \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build CODE_SIGNING_ALLOWED=NO
```

## Rodar no iPhone físico

No Xcode:

1. Abra `PMEmu.xcodeproj`.
2. Selecione o target `PMEmu`.
3. Vá em **Signing & Capabilities**.
4. Marque **Automatically manage signing**.
5. Escolha seu Team/Personal Team.
6. Repita para `PMEmuWatchApp`.
7. Se necessário, troque os Bundle Identifiers para valores únicos.

## Estrutura principal

```txt
External/mGBA/                  # submodule mGBA
Resources/ROMs/2048.gb          # ROM homebrew de teste
Scripts/build-mgba.sh           # gera Vendor/mGBA/mGBA.xcframework
Sources/iOS/                    # app iOS
Sources/WatchApp/               # app watchOS
Sources/Shared/Emulation/       # código compartilhado de emulação
Vendor/mGBA/mGBA.xcframework    # framework estático gerado
```

## Aviso legal

PMEmu não deve incluir ROMs comerciais, BIOS ou conteúdo protegido por copyright. Use apenas homebrew, domínio público ou backups legalmente obtidos pelo usuário.
