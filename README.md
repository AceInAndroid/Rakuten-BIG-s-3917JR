# Rakuten BIG s (3917JR)

This repository contains device-specific files for the Rakuten BIG s (`3917JR`, codename `gaea`).
Build Target: 3917JR.230318.0S

## `boot_a-stock.img`

Stock `boot_a` image extracted from this device's Android 10 firmware. The Build Target:"3917JR.230318.0S". Keep it as a rollback/reference image. Do not flash it to a different device or firmware build without verifying compatibility.

## `apn-unlock-module-src/`

Source and release ZIP for a reversible Magisk module that restores APN creation on the verified Rakuten BIG s Android 10 ROM. It applies an in-memory CarrierConfig Binder override and does not modify physical partitions, `CarrierConfig.apk`, or the APN database.

Install `rakuten-big-s-apn-unlock.zip` from the Magisk app. See `apn-unlock-module-src/README.md` for requirements, behaviour, and uninstall instructions.
