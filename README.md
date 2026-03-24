# VoiceWriter

VoiceWriter は、音声を録音し、Whisper で文字起こしし、認識結果を現在アクティブなアプリへ貼り付ける macOS メニューバーアプリです。

## 主な機能

- グローバルホットキー（`⌘⌥V`）で録音の開始/停止
- ストリーミング文字起こしのプレビューをリアルタイムでオーバーレイ表示
- WhisperKit を使った日本語向け文字起こし設定
- 処理完了後、アクティブアプリへ自動貼り付け

## アーキテクチャ

このアプリは Swift Package として構成され、中央の状態管理コンポーネントを軸に動作します。

- `VoiceWriterApp` (`Sources/VoiceWriter/VoiceWriterApp.swift`)
  - メニューバー常駐アプリのエントリーポイントとステータス UI
- `AppState` (`Sources/VoiceWriter/AppState.swift`)
  - 録音、文字起こし、オーバーレイ表示、テキスト入力を統括
- `AudioRecorder` (`Sources/VoiceWriter/AudioRecorder.swift`)
  - マイク入力を取得し、16kHz モノラル Float32 へ変換して前処理を実施
- `WhisperTranscriber` (`Sources/VoiceWriter/WhisperTranscriber.swift`)
  - WhisperKit 経由でモデルを読み込み、文字起こしと後処理を実施
- `OverlayPanel` + `OverlayView`
  - 録音/文字起こしの状況を表示する、フォーカスを奪わないフローティング UI
- `TextInputSimulator` (`Sources/VoiceWriter/TextInputSimulator.swift`)
  - 最終テキストをアクティブアプリに貼り付け（AppleScript、失敗時は CGEvent）
- `HotkeyManager` (`Sources/VoiceWriter/HotkeyManager.swift`)
  - `HotKey` を使ってグローバルホットキーを登録

### データフロー

1. ユーザーが `⌘⌥V` を押す
2. `AppState` が `AudioRecorder` を開始
3. `AudioRecorder` が一定間隔でバッファを送り、ストリーミング文字起こし
4. `WhisperTranscriber` がオーバーレイ表示を更新
5. ユーザーが再度 `⌘⌥V` を押す
6. 最終文字起こしを後処理し、アクティブアプリへ貼り付け

## 動作要件

- macOS 14+
- Xcode command line tools (`xcode-select --install`)
- 初回起動時にインターネット接続（モデルダウンロードのため）

## ビルドと実行

### ソースから実行

```bash
swift build
swift run VoiceWriter
```

### `.app` バンドルを作成

```bash
./scripts/build.sh
open VoiceWriter.app
```

## 権限

VoiceWriter の利用には、以下の macOS 権限が必要です。

- **マイク**: 音声入力を取得するため
- **アクセシビリティ**: 他アプリへ文字起こし結果を貼り付けるため

以下から許可できます。

- `System Settings > Privacy & Security > Microphone`
- `System Settings > Privacy & Security > Accessibility`

## 補足

- 初回モデル初期化時に **約950MB**（`large-v3-turbo`）のダウンロードが発生する場合があります。
- 認識精度はマイク品質や周囲ノイズの影響を受けます。

## 依存ライブラリ

- [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- [HotKey](https://github.com/soffes/HotKey)

## ライセンス

MIT License。詳細は `LICENSE` を参照してください。
