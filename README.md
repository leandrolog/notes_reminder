# Notes Reminder App

Aplicativo Flutter para criar, editar, buscar e excluir notas com lembretes locais agendados.

## Funcionalidades

- Criacao de notas com titulo e conteudo
- Edicao e exclusao de notas
- Busca por titulo ou conteudo
- Lembretes locais por data/hora
- Persistencia local com SQLite
- Ordenacao priorizando notas com lembrete

## Tecnologias

- Flutter (SDK >= 3.3.0)
- Provider (gerenciamento de estado)
- Sqflite (banco local)
- flutter_local_notifications (notificacoes locais)
- timezone (agendamento com fuso horario)

## Pre-requisitos

Antes de rodar o projeto, instale:

1. Flutter SDK compativel com `>=3.3.0 <4.0.0`
2. Android Studio (com Android SDK e emulador) ou dispositivo Android fisico
3. Git

## Instalacao

1. Instale as dependencias:

```bash
flutter pub get
```

## Executando o aplicativo

1. Inicie um emulador Android ou conecte um dispositivo fisico com depuracao USB habilitada.
2. Verifique se o dispositivo foi reconhecido:

```bash
flutter devices
```

3. Rode o app:

```bash
flutter run
```

## Permissoes importantes (Android)

O app usa as seguintes permissoes no `AndroidManifest.xml`:

- `POST_NOTIFICATIONS`: exibir notificacoes (Android 13+)
- `RECEIVE_BOOT_COMPLETED`: restaurar lembretes apos reinicializar o aparelho
- `SCHEDULE_EXACT_ALARM`: agendar lembretes com horario exato

Observacoes:

- Em Android 13+, aceite a permissao de notificacao quando o sistema solicitar.
- Em alguns dispositivos, pode ser necessario permitir alarmes exatos nas configuracoes do sistema para entrega precisa do lembrete.

## Como usar o app

1. Toque em **Nova Nota**.
2. Preencha titulo e/ou conteudo (pelo menos um dos dois).
3. Opcional: adicione um lembrete tocando no icone de calendario.
4. Salve a nota.
5. Para editar, toque em uma nota existente.
6. Para excluir, deslize a nota para a esquerda e confirme.
7. Para buscar, use o campo de pesquisa na tela inicial.

## Build para distribuicao

Gerar APK de release:

```bash
flutter build apk --release
```

Arquivo gerado em:

`build/app/outputs/flutter-apk/app-release.apk`

## Observacoes tecnicas

- O fuso horario local para agendamento esta configurado como `America/Sao_Paulo`.
- Notas e lembretes sao armazenados localmente no dispositivo.
