# Test signing key

`tool/test-signing.jks` signs the APKs that GitHub Actions builds for testing (Ten Apps and CareLoop)
when no upload key is set in the repository secrets.

Android only installs an update if it is signed with the same key as the installed app. Before this
key existed, every build was signed with a throwaway key made on the build server, so installing a
newer build failed with "App not installed" / "package conflicts with an existing package".
With one shared key, each new APK installs over the previous one.

- Alias `udapps-test`, password `udapps-test-signing` (both stores). SHA-256 certificate fingerprint:
  `3D:D1:89:68:AB:E0:D6:3E:DB:92:6F:AD:7E:D6:4C:39:BF:ED:4C:B8:D7:F2:74:24:BC:DE:08:79:EE:70:BB:5B`
- This key is **public** (it's in the repo). Use it for testing only.
- For Google Play or public distribution, create your own upload key and add `KEYSTORE_BASE64`,
  `KEYSTORE_PASSWORD` and `KEY_ALIAS` secrets (see the main README). The workflows then use that key
  instead. Switching keys means uninstalling the test build once before installing the new one.
