# Android SDK セットアップ

このプロジェクトはSDK本体をZIPへ同梱しません。端末やOSごとに公式のAndroid Command-line Toolsを導入し、`tools/setup-android-sdk.sh`で同じSDKパッケージを取得します。

必要な固定パッケージは次の通りです。

- `platform-tools`
- `platforms;android-35`
- `build-tools;35.0.0`

JDK 17を用意します。SDK未導入のLinux環境では、[Android公式のCommand-line Tools](https://developer.android.com/studio#command-line-tools-only)から `commandlinetools-linux-15859902_latest.zip` を取得してください。スクリプトはZIPのSHA-256を検査し、SDKへ展開します。SDKライセンスの表示には対話的に応答してください。既存の `sdkmanager` を使う場合は `SDKMANAGER` でそのパスを指定できます。

```bash
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
./tools/setup-android-sdk.sh /path/to/commandlinetools-linux-15859902_latest.zip
./build-apk.sh
```

ビルドは `arm64-v8a` のみを対象にします。SDKの初回導入にはインターネット接続が必要ですが、ビルド後のアプリはオフライン動作です。
