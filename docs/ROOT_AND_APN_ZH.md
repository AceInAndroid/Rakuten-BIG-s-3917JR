# 3917JR：原厂 boot、Magisk Root 与 APN 新增

## 适用范围与实测结果

设备为 Rakuten BIG s `3917JR`，代号 `gaea`，原厂 Android 10，固件
`3917JR.230318.0S`，A/B 分区，当前槽位 `_a`，Bootloader 已解锁。
刷入本机修补的 `boot_a` 后，系统正常启动，`su -c id` 返回
`uid=0(root)`，设备端分区 SHA-256 与修补镜像一致。

APN 模块已安装并在重启后启动。测试时没有活动 SIM，因此**尚未验证**
有卡时 APN 新增和保存成功。本文命令以槽位 `a` 为例；型号、固件、
槽位、分区大小或哈希不一致时应停止。解锁 Bootloader 可能清除用户数据；
本次设备在开始前已经解锁。

## 1. 核对设备

需要 Android Platform Tools。临时系统镜像处理需要 Linux 的 `xz`、
`simg2img`、`debugfs`、`e2fsck`、`gzip`；macOS 可用 Linux 容器或
虚拟机处理镜像。保持 USB 连接并给手机供电。

```sh
adb devices
adb shell getprop ro.product.model
adb shell getprop ro.product.device
adb shell getprop ro.build.fingerprint
adb shell getprop ro.boot.slot_suffix
adb reboot bootloader
fastboot getvar unlocked
fastboot getvar current-slot
fastboot getvar partition-size:boot_a
fastboot reboot
```

实测 `boot_a` 大小为 `100663296` 字节（96 MiB）。

## 2. 用 DSU 临时系统读取原厂 boot

下载 phhusson 官方 Android 10 v222 的
[`system-quack-arm64-ab-vanilla.img.xz`](https://github.com/phhusson/treble_experimentations/releases/download/v222/system-quack-arm64-ab-vanilla.img.xz)。
本次下载文件的 SHA-256 为
`725c2b0d0b32a8d7ae3e7a747db181dc7933976fe820bcf26deca8a6718ba56e`。
在 Linux 中解压并将 Android sparse image 转成 raw ext4：

```sh
xz -dk system-quack-arm64-ab-vanilla.img.xz
simg2img system-quack-arm64-ab-vanilla.img system.raw
cp system.raw system-patched.raw
```

临时 GSI 的 ADB 授权需要操作者**自己的公钥**。将电脑的
`~/.android/adbkey.pub` 复制到镜像处理目录，用 Linux `debugfs`
写入 raw ext4 文件系统根目录的 `/adb_keys`：

```sh
cp ~/.android/adbkey.pub ./adbkey.pub
debugfs -w system-patched.raw <<'EOF'
rm /adb_keys
write adbkey.pub /adb_keys
set_inode_field /adb_keys uid 0
set_inode_field /adb_keys gid 0
set_inode_field /adb_keys mode 0100644
ea_set /adb_keys security.selinux u:object_r:adb_keys_file:s0
close -a
EOF
e2fsck -fn system-patched.raw
gzip -1 -c system-patched.raw > system-patched.raw.gz
stat -c %s system-patched.raw
```

`rm /adb_keys` 在文件原本不存在时可以报“未找到”；其他命令应检查
输出。`e2fsck -fn` 是只读检查，不能忽略文件系统错误。**不要发布**
`system-patched.raw` 或 `.gz`：它包含操作者的 ADB 公钥。实测 raw
大小为 `1774190592` 字节；在自己的环境中以 `stat` 结果为准。

在原厂系统启动 DSU 安装：

```sh
adb shell setprop persist.sys.fflag.override.settings_dynamic_system true
adb push system-patched.raw.gz /sdcard/Download/system-patched.raw.gz
adb shell am start-activity --user 0 \
  -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \
  -a android.os.image.action.START_INSTALL \
  -d file:///storage/emulated/0/Download/system-patched.raw.gz \
  --el KEY_SYSTEM_SIZE 1774190592 \
  --el KEY_USERDATA_SIZE 8589934592
```

用手机锁屏凭据确认。安装完成后，在 Dynamic System Updates 通知中
手动点 **Restart**。进入临时系统后打开 USB 调试并授权电脑。
临时系统应支持 `adb root`：

```sh
adb wait-for-device
adb root
adb wait-for-device
adb shell id
adb shell blockdev --getsize64 /dev/block/by-name/boot_a
adb shell sha256sum /dev/block/by-name/boot_a
adb pull /dev/block/by-name/boot_a boot_a-stock-local.img
shasum -a 256 boot_a-stock-local.img
```

最后一行是 macOS 命令；Linux 可用 `sha256sum`。这台设备的设备端和
电脑端结果均为
`626b5a3c44263a9e97778130a117c6525fee502b7ceb6ff12bbbca8bfa99a37b`。
只有大小为 `100663296` 字节且**两端哈希一致**时才信任备份。
本次 `adb exec-out su 0 cat` 曾导出损坏文件，不能只看命令返回码。
重启回原厂系统；完成 Root 验证后，可用 `su -c gsi_tool wipe`
删除停用的临时 DSU 系统及其数据。

## 3. Magisk 修补与启动验证

从 [Magisk 官方 Releases](https://github.com/topjohnwu/Magisk/releases/tag/v31.1)
获取 v31.1 APK。本次 APK SHA-256 为
`89cefac0a318afa39fb3880c45c87b036c05bc1ebf02a7a715b7f8d7c26ac6e7`。
在原厂系统安装并推送已备份的 boot：

```sh
adb install -r Magisk-v31.1.apk
adb push boot_a-stock-local.img /sdcard/Download/boot_a-stock-local.img
```

Magisk 中选 **安装 → Patch firmware / image → Select from storage**，
选择 boot 文件并确认。如果修补到“Repacking boot image”后报
`Failed to output to /storage/emulated/0/Download`，检查存储权限。
本次设备需要执行以下命令后重试：

```sh
adb shell pm grant com.topjohnwu.magisk android.permission.WRITE_EXTERNAL_STORAGE
```

成功后用 `adb pull` 拉回手机 `Download/magisk_patched-*.img`，
核对大小及两端 SHA-256。实测修补结果仍为 `100663296` 字节，
SHA-256 为
`aa2e57ab4817485891cdd11510b6c996e29c2bf7ab2b2abbef178e9315820723`。
该镜像作为 [Release 附件](https://github.com/AceInAndroid/Rakuten-BIG-s-3917JR/releases/tag/v2026.11.16-root-apn)
提供；仍建议从**自己的设备和当前固件**提取、修补。

先临时启动验证，不写入分区：

```sh
adb reboot bootloader
fastboot getvar current-slot
fastboot getvar unlocked
fastboot boot magisk_patched-*.img
adb wait-for-device
adb shell getprop sys.boot_completed
adb shell su -c id
adb shell su -c sha256sum /dev/block/by-name/boot_a
```

若 Magisk 首次拒绝 ADB shell 请求，在 Magisk 的“超级用户”页按需
给 **Shell (`com.android.shell`)** 授权。实测临时启动后 `su -c id`
返回 `uid=0(root) ... context=u:r:magisk:s0`，设备端 `boot_a`
仍为前述原厂哈希。确认这两点后才刷当前槽位：

```sh
adb reboot bootloader
fastboot getvar current-slot
fastboot flash boot_a magisk_patched-*.img
fastboot reboot
adb wait-for-device
adb shell getprop sys.boot_completed
adb shell su -c id
adb shell su -c sha256sum /dev/block/by-name/boot_a
```

实测刷写后系统正常启动，`boot_a` 哈希为修补镜像值。回退时，
先确认设备固件、槽位 `a` 和原厂备份哈希，再运行：

```sh
adb reboot bootloader
fastboot flash boot_a boot_a-stock-local.img
fastboot reboot
```

## 4. 恢复 APN 新增

同型号原厂固件的 Vodafone UK 配置可能将
`read_only_apn_types_string_array` 设为 `[*]`，使 APN 不可新增。
参见 [Qiui 的同型号分析](https://blog.qiui.net/posts/2026-08-13-rakuten-big-s-boot-apn/)。
本仓库的 [Magisk 模块](../apn-unlock-module-src/README.md) 不修改
`CarrierConfig.apk`、APN 数据库或系统分区；它在**有活动 SIM 时**
查找实际 subId，并施加运行时 `[dun]` 覆盖。手机重启、电话进程重启
或订阅变化后，模块会重新施加覆盖。

在已 Root 的原厂系统安装：

```sh
adb push apn-unlock-module-src/rakuten-big-s-apn-unlock.zip /data/local/tmp/
adb shell su -c magisk --install-module /data/local/tmp/rakuten-big-s-apn-unlock.zip
adb reboot
```

重启并插入/启用 SIM 后，检查活动 subId、覆盖和模块日志：

```sh
adb shell su -c 'content query --uri content://telephony/siminfo --projection _id:sim_id'
adb shell su -c 'dumpsys carrier_config'
adb shell su -c 'tail -n 30 /data/adb/modules/rakuten_big_s_apn_unlock/apn-unlock.log'
```

活动 SIM 应有 `sim_id >= 0`；日志应记录实际 subId 和成功的 Binder
调用，`mOverrideConfigs` 中应能看到
`read_only_apn_types_string_array = [dun]`。之后在 APN 页面实际
创建并保存运营商 APN，确认它出现在列表中。**本次无活动 SIM，
尚不能宣称此项有卡验收通过。**模块只解除新增的只读限制；
已有且 `user_editable=0` 的 APN 行可能仍不可编辑。禁用模块后应
重启手机清除内存覆盖；卸载脚本会尝试清除已记录的订阅覆盖。

## 文件与来源

根目录 [`SHA256SUMS`](../SHA256SUMS) 记录原厂 boot、模块 ZIP 和
Release 修补 boot 的哈希。仓库不打包第三方 Magisk APK、GSI 或
带操作者 ADB 公钥的临时镜像；请从各自官方上游获取并按本教程处理。
