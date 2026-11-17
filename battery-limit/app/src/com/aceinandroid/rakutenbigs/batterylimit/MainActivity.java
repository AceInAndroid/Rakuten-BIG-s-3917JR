package com.aceinandroid.rakutenbigs.batterylimit;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.Gravity;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.Switch;
import android.widget.TextView;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public class MainActivity extends Activity {
    private static final int[] LIMITS = {60, 70, 80, 85, 90, 100};
    private static final String CONTROL = "/data/adb/modules/rakuten_big_s_battery_limit/control.sh";
    private static final int INK = Color.rgb(31, 39, 41);
    private static final int MUTED = Color.rgb(112, 122, 126);
    private static final int ACCENT = Color.rgb(15, 123, 102);

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final TextView[] marks = new TextView[LIMITS.length];
    private final Runnable refresh = new Runnable() {
        @Override public void run() {
            refreshBattery();
            loadStatus();
            handler.postDelayed(this, 10000);
        }
    };
    private SeekBar limitSlider;
    private Switch cycleSwitch;
    private EditText daysInput;
    private Button saveDays;
    private Button startNow;
    private TextView battery;
    private TextView batteryState;
    private TextView phaseView;
    private TextView nextView;
    private TextView feedback;
    private boolean initialized;
    private boolean statusLoading;
    private boolean saving;
    private boolean suppressSwitch;
    private boolean savedCycleEnabled;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(24), dp(24), dp(24), dp(32));
        page.setBackgroundColor(Color.rgb(245, 247, 248));

        TextView title = label("充电", 25, INK);
        title.setTypeface(null, Typeface.BOLD);
        page.addView(title);

        battery = label("--%", 36, INK);
        battery.setTypeface(null, Typeface.BOLD);
        LinearLayout.LayoutParams batteryParams = new LinearLayout.LayoutParams(-1, -2);
        batteryParams.topMargin = dp(28);
        page.addView(battery, batteryParams);
        batteryState = label("", 15, MUTED);
        page.addView(batteryState);

        TextView limitTitle = label("充电上限", 16, MUTED);
        limitTitle.setTypeface(null, Typeface.BOLD);
        LinearLayout.LayoutParams sectionParams = new LinearLayout.LayoutParams(-1, -2);
        sectionParams.topMargin = dp(34);
        page.addView(limitTitle, sectionParams);

        LinearLayout sliderPanel = new LinearLayout(this);
        sliderPanel.setOrientation(LinearLayout.VERTICAL);
        sliderPanel.setPadding(dp(10), dp(10), dp(10), dp(10));
        sliderPanel.setBackground(rounded(Color.WHITE, 8));
        LinearLayout.LayoutParams panelParams = new LinearLayout.LayoutParams(-1, -2);
        panelParams.topMargin = dp(10);
        page.addView(sliderPanel, panelParams);

        limitSlider = new SeekBar(this);
        limitSlider.setMax(LIMITS.length - 1);
        limitSlider.setProgress(LIMITS.length - 1);
        limitSlider.setMinHeight(dp(48));
        limitSlider.setProgressTintList(ColorStateList.valueOf(ACCENT));
        limitSlider.setProgressBackgroundTintList(ColorStateList.valueOf(Color.rgb(222, 226, 226)));
        GradientDrawable thumb = rounded(Color.WHITE, 18);
        thumb.setSize(dp(36), dp(36));
        thumb.setStroke(dp(1), Color.rgb(181, 191, 191));
        limitSlider.setThumb(thumb);
        limitSlider.setThumbTintList(null);
        sliderPanel.addView(limitSlider, new LinearLayout.LayoutParams(-1, dp(54)));

        LinearLayout markRow = new LinearLayout(this);
        for (int i = 0; i < LIMITS.length; i++) {
            final int index = i;
            TextView mark = label(LIMITS[i] + "%", 14, MUTED);
            mark.setGravity(Gravity.CENTER);
            mark.setMinHeight(dp(38));
            mark.setOnClickListener(view -> {
                if (saving) return;
                limitSlider.setProgress(index);
                saveLimit(index);
            });
            marks[i] = mark;
            markRow.addView(mark, new LinearLayout.LayoutParams(0, dp(38), 1));
        }
        sliderPanel.addView(markRow);
        updateMarks(limitSlider.getProgress());
        limitSlider.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar bar, int progress, boolean fromUser) {
                updateMarks(progress);
            }
            @Override public void onStartTrackingTouch(SeekBar bar) { }
            @Override public void onStopTrackingTouch(SeekBar bar) {
                saveLimit(bar.getProgress());
            }
        });

        TextView cycleTitle = label("电池维护", 16, MUTED);
        cycleTitle.setTypeface(null, Typeface.BOLD);
        LinearLayout.LayoutParams cycleTitleParams = new LinearLayout.LayoutParams(-1, -2);
        cycleTitleParams.topMargin = dp(34);
        page.addView(cycleTitle, cycleTitleParams);

        LinearLayout cycleRow = new LinearLayout(this);
        cycleRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(-1, dp(56));
        rowParams.topMargin = dp(10);
        page.addView(cycleRow, rowParams);
        cycleRow.addView(label("定期维护", 18, INK), new LinearLayout.LayoutParams(0, -2, 1));
        cycleSwitch = new Switch(this);
        cycleRow.addView(cycleSwitch);

        LinearLayout periodRow = new LinearLayout(this);
        periodRow.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams periodParams = new LinearLayout.LayoutParams(-1, dp(56));
        periodParams.topMargin = dp(8);
        page.addView(periodRow, periodParams);
        periodRow.addView(label("周期", 17, INK), new LinearLayout.LayoutParams(0, -2, 1));
        daysInput = new EditText(this);
        daysInput.setInputType(InputType.TYPE_CLASS_NUMBER);
        daysInput.setSingleLine(true);
        daysInput.setText("30");
        daysInput.setTextSize(17);
        daysInput.setGravity(Gravity.CENTER);
        daysInput.setSelectAllOnFocus(true);
        periodRow.addView(daysInput, new LinearLayout.LayoutParams(dp(58), dp(48)));
        TextView daysLabel = label("天", 16, MUTED);
        daysLabel.setGravity(Gravity.CENTER);
        periodRow.addView(daysLabel, new LinearLayout.LayoutParams(dp(28), dp(48)));
        saveDays = new Button(this);
        saveDays.setText("保存");
        periodRow.addView(saveDays, new LinearLayout.LayoutParams(dp(76), dp(48)));

        phaseView = label("维护状态：未开启", 15, INK);
        LinearLayout.LayoutParams phaseParams = new LinearLayout.LayoutParams(-1, -2);
        phaseParams.topMargin = dp(18);
        page.addView(phaseView, phaseParams);
        nextView = label("", 14, MUTED);
        LinearLayout.LayoutParams nextParams = new LinearLayout.LayoutParams(-1, -2);
        nextParams.topMargin = dp(6);
        page.addView(nextView, nextParams);

        startNow = new Button(this);
        startNow.setText("立即开始");
        startNow.setTextColor(Color.WHITE);
        startNow.setBackgroundTintList(ColorStateList.valueOf(ACCENT));
        LinearLayout.LayoutParams startParams = new LinearLayout.LayoutParams(-1, dp(52));
        startParams.topMargin = dp(22);
        page.addView(startNow, startParams);
        startNow.setEnabled(false);

        feedback = label("", 14, MUTED);
        LinearLayout.LayoutParams feedbackParams = new LinearLayout.LayoutParams(-1, -2);
        feedbackParams.topMargin = dp(14);
        page.addView(feedback, feedbackParams);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.addView(page);
        setContentView(scroll);

        cycleSwitch.setOnCheckedChangeListener((button, checked) -> {
            if (initialized && !suppressSwitch) saveCycle();
        });
        saveDays.setOnClickListener(view -> saveCycle());
        startNow.setOnClickListener(view -> new AlertDialog.Builder(this)
                .setTitle("开始电池维护")
                .setMessage("电池将放电至 10%，再充至 100%，最后放电至所选上限。期间需保持充电线连接。深度循环会增加电池磨损。")
                .setNegativeButton("取消", null)
                .setPositiveButton("开始", (dialog, which) -> runCommand("start-now", "维护已开始"))
                .show());
    }

    @Override protected void onResume() {
        super.onResume();
        handler.post(refresh);
    }

    @Override protected void onPause() {
        handler.removeCallbacks(refresh);
        super.onPause();
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private TextView label(String text, int size, int color) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(size);
        view.setTextColor(color);
        return view;
    }

    private GradientDrawable rounded(int color, int radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radius));
        return drawable;
    }

    private void updateMarks(int selected) {
        for (int i = 0; i < marks.length; i++) {
            marks[i].setTextColor(i == selected ? INK : MUTED);
            marks[i].setTypeface(null, i == selected ? Typeface.BOLD : Typeface.NORMAL);
        }
    }

    private void refreshBattery() {
        Intent state = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if (state == null) return;
        int level = state.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        int status = state.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
        battery.setText(level + "%");
        batteryState.setText(status == BatteryManager.BATTERY_STATUS_CHARGING ? "正在充电"
                : status == BatteryManager.BATTERY_STATUS_FULL ? "已充满"
                : status == BatteryManager.BATTERY_STATUS_DISCHARGING ? "正在放电" : "未充电");
    }

    private String root(String command) throws Exception {
        Process process = new ProcessBuilder("su", "-c", command).redirectErrorStream(true).start();
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) output.append(line).append('\n');
        }
        if (process.waitFor() != 0) {
            String detail = output.toString().trim();
            throw new Exception(detail.isEmpty() ? "命令执行失败" : detail);
        }
        return output.toString().trim();
    }

    private void loadStatus() {
        if (statusLoading || saving) return;
        statusLoading = true;
        new Thread(() -> {
            try {
                String result = root("sh " + CONTROL + " status");
                Map<String, String> values = new HashMap<>();
                for (String line : result.split("\n")) {
                    int equal = line.indexOf('=');
                    if (equal > 0) values.put(line.substring(0, equal), line.substring(equal + 1));
                }
                runOnUiThread(() -> showStatus(values));
            } catch (Exception error) {
                runOnUiThread(() -> feedback.setText("读取失败，请检查 Magisk 模块和 Root 授权。"));
            } finally {
                runOnUiThread(() -> statusLoading = false);
            }
        }).start();
    }

    private void showStatus(Map<String, String> values) {
        if (!initialized) {
            int limit = number(values.get("limit"), 100);
            for (int i = 0; i < LIMITS.length; i++) {
                if (LIMITS[i] == limit) limitSlider.setProgress(i);
            }
            daysInput.setText(values.getOrDefault("days", "30"));
            initialized = true;
        }
        savedCycleEnabled = "1".equals(values.get("enabled"));
        suppressSwitch = true;
        cycleSwitch.setChecked(savedCycleEnabled);
        suppressSwitch = false;
        String phase = values.getOrDefault("phase", "idle");
        int selected = LIMITS[limitSlider.getProgress()];
        String phaseText;
        switch (phase) {
            case "draining": phaseText = "正在放电至 10%"; break;
            case "charging": phaseText = "正在充电至 100%"; break;
            case "returning": phaseText = "正在放电至 " + selected + "%"; break;
            default: phaseText = savedCycleEnabled ? "等待下次维护" : "未开启";
        }
        phaseView.setText("维护状态：" + phaseText);
        long due = numberLong(values.get("next_due"));
        if (savedCycleEnabled && "idle".equals(phase) && due > 0) {
            String date = new SimpleDateFormat("M月d日 HH:mm", Locale.CHINA)
                    .format(new Date(due * 1000));
            nextView.setText("下次维护：" + date);
        } else {
            nextView.setText("");
        }
        startNow.setEnabled(savedCycleEnabled && "idle".equals(phase) && !saving);
    }

    private int number(String text, int fallback) {
        try { return Integer.parseInt(text); } catch (Exception ignored) { return fallback; }
    }

    private long numberLong(String text) {
        try { return Long.parseLong(text); } catch (Exception ignored) { return 0; }
    }

    private void saveLimit(int index) {
        if (saving) return;
        int limit = LIMITS[index];
        runCommand("set-limit " + limit, "充电上限已设为 " + limit + "%");
    }

    private void saveCycle() {
        if (saving) return;
        int days = number(daysInput.getText().toString(), -1);
        if (days < 7 || days > 365) {
            feedback.setText("周期请设为 7 至 365 天。");
            suppressSwitch = true;
            cycleSwitch.setChecked(savedCycleEnabled);
            suppressSwitch = false;
            return;
        }
        runCommand("set-cycle " + (cycleSwitch.isChecked() ? 1 : 0) + " " + days,
                cycleSwitch.isChecked() ? "定期维护已开启" : "定期维护已关闭");
    }

    private void runCommand(String command, String success) {
        if (saving) return;
        saving = true;
        limitSlider.setEnabled(false);
        cycleSwitch.setEnabled(false);
        daysInput.setEnabled(false);
        saveDays.setEnabled(false);
        startNow.setEnabled(false);
        feedback.setText("正在保存…");
        new Thread(() -> {
            try {
                root("sh " + CONTROL + " " + command);
                runOnUiThread(() -> feedback.setText(success));
            } catch (Exception error) {
                runOnUiThread(() -> {
                    feedback.setText("保存失败：" + error.getMessage());
                    suppressSwitch = true;
                    cycleSwitch.setChecked(savedCycleEnabled);
                    suppressSwitch = false;
                });
            } finally {
                runOnUiThread(() -> {
                    saving = false;
                    limitSlider.setEnabled(true);
                    cycleSwitch.setEnabled(true);
                    daysInput.setEnabled(true);
                    saveDays.setEnabled(true);
                    loadStatus();
                });
            }
        }).start();
    }
}
