# 3917JR 充电上限

适用范围：已解锁并安装 Magisk 的 Rakuten BIG s `3917JR`，原厂 Android 10
`3917JR.230318.0S`。实机内核节点为
`/sys/class/power_supply/battery/battery_charging_enabled`。其他固件先核对节点，
不要直接安装。

提供可拖动的 60、70、80、85、90、100% 六档。低于 100% 时，达到设定值
暂停充电，下降 3 个百分点后恢复。100% 档保持系统默认充电行为。
服务每 10 秒检查一次；正常限充只控制电池充电开关，USB 仍可给手机供电。
充电百分比是 Android 报告值，实际停止点可能因采样间隔偏差约 1%。

## 定期维护

默认关闭。开启后默认每 30 天运行一次，可设置 7 至 365 天；周期从每轮完成时间
重新计算。到期时须保持 USB 充电线连接，流程为：

1. 暂停 USB 输入，让手机从电池供电并放电至 10%。
2. 恢复 USB 输入，充电至 Android 显示 100%。
3. 再次暂停 USB 输入，放电至选定的充电上限，然后恢复 USB 供电和日常限充。

如果途中拔线，本轮立即中止并恢复输入，次日连接充电线后重试。也可在 App 中
明确确认后点击“立即开始”。关闭定期维护会在下一次 10 秒检查时中止本轮。
独立看护进程每 5 秒检查电量和主服务；到达 10% 或主服务消失时恢复 USB 输入。
放电阶段可能持续很久，取决于手机实际耗电。深度放电再充满并不能延长锂电池寿命，
反而增加循环磨损；此功能仅在有特定维护或电量计校准需求时开启。

设备的 `/sys/class/power_supply/battery/input_suspend` 已实测：写入 `1` 时
USB 保持连接，电池状态显示放电且电流为负；恢复 `0` 后 USB 输入恢复。

## 构建与安装

在 macOS 上使用 Android SDK build-tools 35、platforms/android-35 和 JDK 17：

```sh
sh battery-limit/test_service.sh
sh battery-limit/build.sh
```

在 Magisk 中安装 `dist/3917jr-battery-limit-magisk.zip`，重启后安装
`dist/3917jr-battery-limit.apk`。首次打开 App 时授予 Root 权限。
拖动滑块后松手即保存上限；维护开关立即保存状态，修改天数后点击“保存”。
App 使用本机调试证书签名，仅供本机安装。

## 状态与恢复

服务配置保存在 `/data/adb/3917jr_battery_limit/`。可用以下命令查看：

```sh
adb shell "su -c 'sh /data/adb/modules/rakuten_big_s_battery_limit/control.sh status; cat /sys/class/power_supply/battery/input_suspend /sys/class/power_supply/battery/battery_charging_enabled'"
```

状态后两行依次为 USB 输入暂停开关（`0` 恢复、`1` 暂停）和电池充电开关
（`0` 暂停、`1` 允许）。要恢复正常充电，在 App 中关闭维护并选 100%。
卸载 Magisk 模块也会恢复两个开关；App 可独立卸载。禁用 Magisk 模块后，
服务最多在 10 秒内退出并恢复两个开关。

已在实机验证 80% 档于当前 100% 电量暂停充电、切回 100% 档恢复充电，
以及开启 30 天周期后生成下次运行时间。完整的 10%→100%→所选上限
长周期仅用模拟电量测试；尚未在实机等待完整放充电过程完成。
