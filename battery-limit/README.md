# 3917JR 充电上限

适用范围：已解锁并安装 Magisk 的 Rakuten BIG s `3917JR`，原厂 Android 10
`3917JR.230318.0S`。实机内核节点为
`/sys/class/power_supply/battery/battery_charging_enabled`。其他固件先核对节点，
不要直接安装。

提供 60、70、80、85、90、100% 六档。低于 100% 时，达到设定值暂停充电，
下降 3 个百分点后恢复。100% 档保持系统默认充电行为。服务每 10 秒检查一次；
控制的是电池充电开关，USB 仍可给手机供电。充电百分比是 Android 报告值，
实际停止点可能因采样间隔偏差约 1%。

## 构建与安装

在 macOS 上使用 Android SDK build-tools 35、platforms/android-35 和 JDK 17：

```sh
sh battery-limit/test_service.sh
sh battery-limit/build.sh
```

在 Magisk 中安装 `dist/3917jr-battery-limit-magisk.zip`，重启后安装
`dist/3917jr-battery-limit.apk`。首次打开 App 时授予 Root 权限。
选择档位并点击“应用上限”。App 使用本机调试证书签名，仅供本机安装。

## 状态与恢复

服务配置保存在 `/data/adb/3917jr_battery_limit/limit`。可用以下命令查看：

```sh
adb shell "su -c 'cat /data/adb/3917jr_battery_limit/limit /sys/class/power_supply/battery/capacity /sys/class/power_supply/battery/battery_charging_enabled'"
```

依次为上限、电量和充电开关（`0` 暂停，`1` 允许）。要恢复正常充电，
在 App 中选 100%。卸载 Magisk 模块也会恢复充电开关；App 可独立卸载。
禁用 Magisk 模块后，服务最多在 10 秒内退出并恢复开关。

已在实机验证 80% 档于当前 100% 电量暂停充电、重启后继续生效，
以及切回 100% 档恢复充电开关。尚未完成从低电量实际充到上限再回落的
完整周期验证。
