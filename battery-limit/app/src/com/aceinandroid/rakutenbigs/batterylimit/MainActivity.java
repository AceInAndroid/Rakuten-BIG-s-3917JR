package com.aceinandroid.rakutenbigs.batterylimit;

import android.app.Activity;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Color;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class MainActivity extends Activity {
    private static final int[] LIMITS = {60, 70, 80, 85, 90, 100};
    private static final String STATE = "/data/adb/3917jr_battery_limit/limit";
    private static final String SERVICE = "/data/adb/modules/rakuten_big_s_battery_limit/service.sh";
    private final RadioButton[] choices = new RadioButton[LIMITS.length];
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable refresh = new Runnable() {
        @Override public void run() {
            refreshBattery();
            handler.postDelayed(this, 10000);
        }
    };
    private TextView battery;
    private TextView message;
    private Button apply;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        int ink = Color.rgb(28, 38, 40);
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setPadding(dp(24), dp(28), dp(24), dp(32));
        column.setBackgroundColor(Color.rgb(247, 249, 248));

        TextView title = new TextView(this);
        title.setText("充电上限");
        title.setTextSize(25);
        title.setTextColor(ink);
        column.addView(title);

        battery = new TextView(this);
        battery.setTextSize(18);
        battery.setTextColor(ink);
        battery.setPadding(0, dp(26), 0, dp(23));
        column.addView(battery);

        RadioGroup group = new RadioGroup(this);
        group.setOrientation(RadioGroup.VERTICAL);
        for (int i = 0; i < LIMITS.length; i++) {
            RadioButton choice = new RadioButton(this);
            choice.setId(View.generateViewId());
            choice.setText(LIMITS[i] == 100 ? "100% · 正常充电" : LIMITS[i] + "%");
            choice.setTextSize(18);
            choice.setTextColor(ink);
            choice.setMinHeight(dp(54));
            choices[i] = choice;
            group.addView(choice);
        }
        column.addView(group);

        apply = new Button(this);
        apply.setText("应用上限");
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(-1, dp(52));
        buttonParams.topMargin = dp(22);
        column.addView(apply, buttonParams);

        message = new TextView(this);
        message.setTextSize(14);
        message.setTextColor(Color.rgb(76, 90, 91));
        message.setPadding(0, dp(16), 0, 0);
        column.addView(message);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(column);
        setContentView(scroll);
        apply.setOnClickListener(view -> saveLimit());
        refreshBattery();
        loadLimit();
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

    private void refreshBattery() {
        Intent state = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if (state == null) {
            battery.setText("电量暂不可用");
            return;
        }
        int level = state.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        int status = state.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
        String charging = status == BatteryManager.BATTERY_STATUS_CHARGING ? "充电中"
                : status == BatteryManager.BATTERY_STATUS_FULL ? "已充满" : "未充电";
        battery.setText("当前电量 " + level + "%  ·  " + charging);
    }

    private String root(String command) throws Exception {
        Process process = new ProcessBuilder("su", "-c", command).redirectErrorStream(true).start();
        StringBuilder result = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) result.append(line).append('\n');
        }
        if (process.waitFor() != 0) throw new Exception(result.toString().trim());
        return result.toString().trim();
    }

    private void loadLimit() {
        new Thread(() -> {
            try {
                int saved = Integer.parseInt(root("cat " + STATE));
                runOnUiThread(() -> {
                    for (int i = 0; i < LIMITS.length; i++)
                        if (LIMITS[i] == saved) choices[i].setChecked(true);
                    message.setText("当前设置：" + saved + "%");
                });
            } catch (Exception error) {
                runOnUiThread(() -> message.setText("读取失败，请确认 Magisk 模块已安装并授予 Root 权限。"));
            }
        }).start();
    }

    private void saveLimit() {
        int selected = -1;
        for (int i = 0; i < LIMITS.length; i++) if (choices[i].isChecked()) selected = LIMITS[i];
        if (selected < 0) return;
        final int limit = selected;
        apply.setEnabled(false);
        message.setText("正在应用…");
        new Thread(() -> {
            try {
                root("test -f " + SERVICE + " && printf '" + limit + "\\n' > " + STATE
                        + " && chmod 600 " + STATE + " && sh " + SERVICE + " --once");
                runOnUiThread(() -> {
                    refreshBattery();
                    message.setText("已设置为 " + limit + "%");
                    apply.setEnabled(true);
                });
            } catch (Exception error) {
                runOnUiThread(() -> {
                    message.setText("应用失败，请检查 Root 授权和 Magisk 模块。" + error.getMessage());
                    apply.setEnabled(true);
                });
            }
        }).start();
    }
}
