sdkmanager "system-images;android-28;default;x86"
avdmanager create avd --name "Mini_AVD_28" --package "system-images;android-28;default;x86" --device "Nexus 5" --force
emulator -avd Mini_AVD_28
