#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")" && pwd)"
android_sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$android_sdk_root" ]]; then
  echo "ANDROID_SDK_ROOT または ANDROID_HOME を設定してください。" >&2
  exit 2
fi

android_jar="$android_sdk_root/platforms/android-35/android.jar"
build_tools="$android_sdk_root/build-tools/35.0.0"
for required in "$android_jar" "$build_tools/aapt2" "$build_tools/d8" "$build_tools/zipalign" "$build_tools/apksigner"; do
  if [[ ! -e "$required" ]]; then
    echo "必要なAndroid SDKファイルがありません: $required" >&2
    exit 2
  fi
done

build_dir="$project_root/app/build/manual"
classes_dir="$build_dir/classes"
dex_dir="$build_dir/dex"
aar_dir="$build_dir/onnxruntime"
output_dir="$project_root/app/build/outputs/apk/debug"
keystore="$build_dir/debug.keystore"
unsigned_apk="$build_dir/local-voice-unsigned.apk"
aligned_apk="$build_dir/local-voice-aligned.apk"
output_apk="$output_dir/local-voice-debug.apk"

mkdir -p "$build_dir" "$output_dir"
find "$build_dir" -mindepth 1 -maxdepth 1 ! -name debug.keystore -exec rm -rf -- {} +
mkdir -p "$classes_dir" "$dex_dir"

onnx_aar="$project_root/app/libs/onnxruntime-mobile.aar"
if [[ ! -f "$onnx_aar" ]]; then
  echo "ONNX Runtime AARがありません: $onnx_aar" >&2
  exit 2
fi
mkdir -p "$aar_dir"
unzip -oq "$onnx_aar" -d "$aar_dir"
if [[ ! -f "$aar_dir/classes.jar" ]]; then
  echo "ONNX Runtime AARにclasses.jarがありません" >&2
  exit 2
fi

mapfile -d '' source_files < <(find "$project_root/app/src/main/java" -type f -name '*.java' -print0 | sort -z)
if [[ ${#source_files[@]} -eq 0 ]]; then
  echo "Javaソースがありません。" >&2
  exit 2
fi

java com.sun.tools.javac.Main \
  -encoding UTF-8 --release 8 -Xlint:all -Werror \
  -classpath "$android_jar:$aar_dir/classes.jar" -d "$classes_dir" "${source_files[@]}"

mapfile -d '' class_files < <(find "$classes_dir" -type f -name '*.class' -print0 | sort -z)
dex_inputs=("${class_files[@]}")
dex_inputs+=("$aar_dir/classes.jar")
"$build_tools/d8" --min-api 26 --lib "$android_jar" --output "$dex_dir" "${dex_inputs[@]}"

asset_args=()
if [[ -d "$project_root/app/src/main/assets" ]]; then asset_args=(-A "$project_root/app/src/main/assets" -0 onnx); fi
"$build_tools/aapt2" link \
  -I "$android_jar" \
  --manifest "$project_root/app/src/main/AndroidManifest.xml" \
  --min-sdk-version 26 --target-sdk-version 34 \
  --version-code 10 --version-name 0.5.1 \
  "${asset_args[@]}" \
  -o "$unsigned_apk"

zip -q -j "$unsigned_apk" "$dex_dir"/classes*.dex
if [[ -d "$aar_dir/jni" ]]; then
  mkdir -p "$aar_dir/apk/lib"
  if [[ ! -f "$aar_dir/jni/arm64-v8a/libonnxruntime.so" ]]; then
    echo "arm64-v8a 用のONNX Runtimeがありません" >&2
    exit 2
  fi
  cp -R "$aar_dir/jni/arm64-v8a" "$aar_dir/apk/lib/"
  (cd "$aar_dir/apk" && zip -qr "$unsigned_apk" lib)
fi
"$build_tools/zipalign" -p -f 4 "$unsigned_apk" "$aligned_apk"

if [[ ! -f "$keystore" ]]; then
  keytool -genkeypair -noprompt \
    -keystore "$keystore" -storepass android \
    -alias androiddebugkey -keypass android \
    -dname "CN=Android Debug,O=Android,C=US" \
    -keyalg RSA -keysize 2048 -validity 10000 >/dev/null
fi

"$build_tools/apksigner" sign \
  --ks "$keystore" --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android \
  --out "$output_apk" "$aligned_apk"

"$build_tools/apksigner" verify --verbose --print-certs "$output_apk"
"$build_tools/zipalign" -c -p 4 "$output_apk"
sha256sum "$output_apk"
echo "$output_apk"
