# AGENTS.md

Instruções para agentes trabalhando neste projeto.

## Visão geral

PMEmu é um MVP de emulador iOS/watchOS em SwiftUI.

Objetivo atual:

1. Rodar Game Boy / Game Boy Color no iPhone usando mGBA.
2. Rodar Game Boy / Game Boy Color no Apple Watch.
3. Depois adicionar importação de ROMs, saves e sincronização.
4. Nintendo 64 entra só depois que o fluxo GBC estiver estável.

## Comandos importantes

Instalar dependências:

```bash
brew install xcodegen cmake
```

Inicializar submodules:

```bash
git submodule update --init --recursive
```

Gerar o framework do mGBA:

```bash
./Scripts/build-mgba.sh
```

Gerar o projeto Xcode:

```bash
xcodegen generate
```

Abrir o projeto:

```bash
open PMEmu.xcodeproj
```

Build iOS Simulator sem assinatura:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project PMEmu.xcodeproj \
  -scheme PMEmu \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build CODE_SIGNING_ALLOWED=NO
```

## Arquitetura

Arquivos principais:

```txt
Sources/Shared/Emulation/
  EmulatorCore.swift
  GBCGameViewModel.swift
  EmulatorImageView.swift
  PMEmu-Bridging-Header.h
  mGBA/
    MGBAEmulator.swift
    PMMGBABridge.h
    PMMGBABridge.c
```

O app Swift não deve chamar APIs internas do mGBA diretamente. Use a bridge C em `PMMGBABridge.*` e o wrapper Swift `MGBAEmulator.swift`.

## mGBA

O mGBA é submodule em:

```txt
External/mGBA
```

O artefato linkado pelo app é:

```txt
Vendor/mGBA/mGBA.xcframework
```

Não edite arquivos dentro de `External/mGBA` a menos que seja intencionalmente um patch no submodule.

Importante: a bridge C precisa compilar com flags ABI-compatíveis com o mGBA. Veja o topo de:

```txt
Sources/Shared/Emulation/mGBA/PMMGBABridge.c
```

## ROMs

Não commitar ROMs comerciais, BIOS ou saves pessoais.

Permitido no repo:

- ROMs homebrew/open-source com licença clara.
- Licenças correspondentes em `Resources/Licenses/`.

Atualmente há uma ROM homebrew de teste:

```txt
Resources/ROMs/2048.gb
Resources/Licenses/2048-gb-LICENSE.txt
```

## Regras de desenvolvimento

- Regenerar `PMEmu.xcodeproj` via XcodeGen após editar `project.yml`.
- Não editar manualmente `PMEmu.xcodeproj` se a mudança puder ser expressa no `project.yml`.
- Testar iOS Simulator antes de iPhone físico.
- Para iPhone físico, signing/provisioning deve ser configurado pelo usuário no Xcode.
- Evitar adicionar N64 antes de estabilizar GBC no iPhone e Apple Watch.
