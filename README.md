# Rakuten BIG s (3917JR)

本仓库记录 `3917JR` (`gaea`) 原厂 Android 10、固件
`3917JR.230318.0S` 的 boot 备份、Magisk Root 和 APN 新增功能恢复方法。
**先核对设备型号、固件、当前槽位和镜像 SHA-256；其他固件不要直接刷入这些镜像。**

## 教程

- [提取原厂 boot、安装 Magisk 和恢复 APN](docs/ROOT_AND_APN_ZH.md)
- [APN Magisk 模块说明及源码](apn-unlock-module-src/README.md)
- [充电上限 App 和 Magisk 模块](battery-limit/README.md)
- [文件 SHA-256](SHA256SUMS)

## 文件

| 文件 | 用途 |
| --- | --- |
| [`boot_a-stock.img`](boot_a-stock.img) | 当前固件的原厂 `boot_a`，可作为回退备份 |
| [`rakuten-big-s-apn-unlock.zip`](apn-unlock-module-src/rakuten-big-s-apn-unlock.zip) | APN 运行时覆盖模块，源码在同一目录 |
| [`3917jr-battery-limit-magisk.zip`](battery-limit/dist/3917jr-battery-limit-magisk.zip) | 六档充电上限的 Magisk 开机服务 |
| [`3917jr-battery-limit.apk`](battery-limit/dist/3917jr-battery-limit.apk) | 在手机上选择和应用充电上限 |
| [Magisk 修补 boot（Release 附件）](https://github.com/AceInAndroid/Rakuten-BIG-s-3917JR/releases/tag/v2026.11.16-root-apn) | 本机实测可临时启动并刷入的 Magisk 31.1 boot；仅适用于相同固件和已解锁 Bootloader |

Magisk APK 和 phhusson GSI 请从教程中的官方上游地址获取。临时 GSI
镜像包含操作者自己的 ADB 公钥，因此这里不发布；教程提供了重建方法。

## 验证范围

这台设备在刷入修补的 `boot_a` 后正常进入原厂系统，`su -c id` 返回
`uid=0(root)`；APN 模块安装并在重启后启动。测试时没有活动 SIM，
因此尚未验证特定运营商下新增 APN 的保存结果。

方法参考并核对了 [Qiui 的同型号记录](https://blog.qiui.net/posts/2026-08-13-rakuten-big-s-boot-apn/)。
