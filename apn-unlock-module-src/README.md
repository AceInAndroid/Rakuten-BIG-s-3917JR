# Rakuten BIG s APN Edit Unlock (Magisk)

This source builds a reversible Magisk module **only for the locally verified Rakuten BIG s
Android 10 ROM**. Do not use it on other devices or ROM builds. It does **not** modify a physical
partition, install system files, alter `CarrierConfig.apk`, change the APN database, or change the
`user_editable` field.

The pure-Shell runtime uses this ROM's verified `carrier_config` Binder transaction 2. It discovers
every active subscription (`sim_id >= 0`) and sends an override bundle containing only:

```
read_only_apn_types_string_array = new String[] { "dun" }
```

Therefore APN types other than `dun` are not declared read-only by this setting. The APN UI's “+”
button should return and a new APN can be created. Existing database rows with `user_editable=0`
may still be non-editable because this module deliberately does not alter the APN database.

## Build on Windows

```powershell
.\build.ps1
```

The script creates `rakuten-big-s-apn-unlock.zip` with LF text files and no system payload. It does
not download dependencies. Flash the ZIP from the Magisk App (not stock recovery).

## Runtime and lifecycle

`service.sh` waits for `sys.boot_completed=1` and the `carrier_config` Binder service. It queries
`content://telephony/siminfo`, accepting only rows whose `sim_id` is non-negative, so subscription
IDs are discovered rather than hard-coded. Each Binder result is checked for a successful Parcel
and for the absence of Exception/Error text, then `dumpsys carrier_config` must globally show
`read_only_apn_types_string_array = [dun]`. It reapplies when the active subscription set, phone
process PID, or carrier-config service availability changes. The 20-second wait prevents a busy
loop. Results and verification are logged; logs are capped approximately at 64 KiB.

During normal uninstall, `uninstall.sh` best-effort clears known/current subscription overrides.
When a module is merely disabled, Magisk does not run its `service.sh` or `uninstall.sh`; the
existing in-memory override remains. **Reboot after disabling** to clear it. Normal uninstall
best-effort clears known/current subIds with the verified null-bundle transaction; rebooting also
restores stock state because nothing persistent is changed.
