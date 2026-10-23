#!/bin/sh
# Build BatteryLimit.apk without Android Studio (Ubuntu / Debian).
#
# One-time setup:
#   sudo apt install aapt android-sdk-platform-23 dalvik-exchange \
#                    apksigner zipalign openjdk-17-jdk-headless
#
# Output: bin/BatteryLimit.apk
set -e
cd "$(dirname "$0")"

JAR=/usr/lib/android-sdk/platforms/android-23/android.jar
JDK=/usr/lib/jvm/java-17-openjdk-amd64/bin

rm -rf gen obj bin
mkdir -p gen obj bin

aapt package -f -m -J gen -M AndroidManifest.xml -S res -I $JAR
$JDK/javac -source 7 -target 7 -Xlint:-options -bootclasspath $JAR -classpath $JAR \
    -d obj $(find src gen -name '*.java')
dalvik-exchange --dex --output=bin/classes.dex obj
aapt package -f -M AndroidManifest.xml -S res -I $JAR -F bin/unsigned.apk
(cd bin && aapt add unsigned.apk classes.dex > /dev/null)
zipalign -f 4 bin/unsigned.apk bin/aligned.apk

# Signing key: kept OUT of git (see .gitignore). Created on first build.
# Keep key.jks safe - updates to an installed app must use the same key.
if [ ! -f key.jks ]; then
  keytool -genkeypair -keystore key.jks -storepass android -keypass android \
    -alias bl -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=BatteryLimit"
fi
apksigner sign --ks key.jks --ks-pass pass:android --key-pass pass:android \
    --min-sdk-version 14 --out bin/BatteryLimit.apk bin/aligned.apk
apksigner verify --min-sdk-version 14 bin/BatteryLimit.apk && echo "Built bin/BatteryLimit.apk"
