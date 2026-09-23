# GitHub Actions でAPKを作る

このリポジトリでは、ZIPを置くだけでは中のソースはビルドされません。`app/`、`models/`、`tools/`、`tests/`、`build-apk.sh`、`.github/workflows/build-apk.yml` を、ZIPの中の相対パスを保ったまま**リポジトリのファイルとして**登録します。音声モデルのONNXと `onnxruntime-mobile.aar` はGitHubへ登録する必要がありません。

ワークフローは公開配布されているLLVCのチェックポイントとONNX Runtime AARをビルド中に取得し、SHA-256を照合してからモデルをCPUでONNXへ変換し、APKを署名・検証します。元のモデルを変更する工程ではありません。生成したAPKはActionsの `local-voice-debug-apk` に保存されます。モデルの音質・実機性能はこのビルドでは検証できません。

1. GitHubのリポジトリに展開済みのソース一式を配置する。
2. `Actions` → `Build Android APK` → `Run workflow` を押す。または `main` ブランチへ更新を反映する。
3. 実行結果の `Artifacts` から `local-voice-debug-apk` を取得し、ZIPを展開してAPKをインストールする。

失敗したときは、まず該当ステップのログを確認します。ワークフローを実行した事実や端末で動いた事実がない段階では、新しいAPKの完成とはしません。APKのサイズはログの `APK bytes` に表示されます。
