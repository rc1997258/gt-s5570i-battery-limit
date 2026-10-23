package com.diy.batterylimit;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.InputStreamReader;

/**
 * Battery Limit - one-screen control for /data/local/bl.sh
 * (GT-S5570I, CyanogenMod 11). Runs the script as root via su.
 */
public class MainActivity extends Activity {

    private static final String SCRIPT = "/data/local/bl.sh";
    private static final String PSY = "/sys/class/power_supply/max8986-battery/";

    private static final int GREEN = 0xFF2E7D32, GREEN_DARK = 0xFF1B5E20;
    private static final int ORANGE = 0xFFEF6C00, ORANGE_DARK = 0xFFBF360C;
    private static final int BLUE = 0xFF1565C0, BLUE_DARK = 0xFF0D47A1;
    private static final int RED = 0xFFC62828, GREY = 0xFF424242;

    private TextView stateView, infoView, logView;
    private Button onBtn, offBtn, refreshBtn;

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    private GradientDrawable shape(int color) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(dp(12));
        return g;
    }

    private StateListDrawable pressable(int normal, int pressed) {
        StateListDrawable s = new StateListDrawable();
        s.addState(new int[]{android.R.attr.state_pressed}, shape(pressed));
        s.addState(new int[]{-android.R.attr.state_enabled}, shape(GREY));
        s.addState(new int[]{}, shape(normal));
        return s;
    }

    private LinearLayout.LayoutParams block(int topMargin) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(topMargin);
        return lp;
    }

    @SuppressWarnings("deprecation")
    private Button makeButton(String text, int color, int pressed) {
        Button b = new Button(this);
        b.setText(text);
        b.setTextColor(Color.WHITE);
        b.setTextSize(17);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setBackgroundDrawable(pressable(color, pressed));
        b.setPadding(dp(8), dp(14), dp(8), dp(14));
        b.setLayoutParams(block(10));
        return b;
    }

    @SuppressWarnings("deprecation")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(12), dp(12), dp(12), dp(12));
        root.setBackgroundColor(0xFF121212);

        TextView title = new TextView(this);
        title.setText("Battery Limit");
        title.setTextColor(Color.WHITE);
        title.setTextSize(22);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setGravity(Gravity.CENTER);
        root.addView(title);

        stateView = new TextView(this);
        stateView.setTextColor(Color.WHITE);
        stateView.setTextSize(18);
        stateView.setTypeface(Typeface.DEFAULT_BOLD);
        stateView.setGravity(Gravity.CENTER);
        stateView.setPadding(dp(8), dp(14), dp(8), dp(14));
        stateView.setLayoutParams(block(10));
        root.addView(stateView);

        infoView = new TextView(this);
        infoView.setTextColor(0xFFE0E0E0);
        infoView.setTextSize(15);
        infoView.setGravity(Gravity.CENTER);
        infoView.setLayoutParams(block(8));
        root.addView(infoView);

        onBtn = makeButton("KEEP 40-50%", GREEN, GREEN_DARK);
        offBtn = makeButton("CHARGE TO 100%", ORANGE, ORANGE_DARK);
        refreshBtn = makeButton("REFRESH", BLUE, BLUE_DARK);
        root.addView(onBtn);
        root.addView(offBtn);
        root.addView(refreshBtn);

        logView = new TextView(this);
        logView.setTextColor(0xFF9E9E9E);
        logView.setTextSize(11);
        logView.setTypeface(Typeface.MONOSPACE);
        logView.setLayoutParams(block(12));
        root.addView(logView);

        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(0xFF121212);
        scroll.addView(root);
        setContentView(scroll);

        onBtn.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) { runRoot("on"); }
        });
        offBtn.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) { runRoot("off"); }
        });
        refreshBtn.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) { runRoot(""); }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        runRoot("");
    }

    private void setBusy(boolean busy) {
        onBtn.setEnabled(!busy);
        offBtn.setEnabled(!busy);
        refreshBtn.setEnabled(!busy);
    }

    @SuppressWarnings("deprecation")
    private void setState(String text, int color) {
        stateView.setText(text);
        stateView.setBackgroundDrawable(shape(color));
    }

    /** Runs "bl.sh <arg>" (if any) followed by "bl.sh" (status) as root. */
    private void runRoot(final String arg) {
        setBusy(true);
        setState("Working...", GREY);
        new Thread(new Runnable() {
            public void run() {
                String cmd = (arg.length() > 0 ? "sh " + SCRIPT + " " + arg + " 2>&1; " : "")
                        + "sh " + SCRIPT + " 2>&1";
                final String out = exec(cmd);
                runOnUiThread(new Runnable() {
                    public void run() {
                        show(out);
                        setBusy(false);
                    }
                });
            }
        }).start();
    }

    private String exec(String cmd) {
        StringBuilder sb = new StringBuilder();
        try {
            Process p = Runtime.getRuntime().exec(new String[]{"su", "-c", cmd});
            BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String line;
            while ((line = r.readLine()) != null) sb.append(line).append('\n');
            r.close();
            p.waitFor();
        } catch (Exception e) {
            sb.append("ERROR: ").append(e.getMessage());
        }
        return sb.toString();
    }

    private String readSys(String name) {
        try {
            BufferedReader r = new BufferedReader(new FileReader(PSY + name));
            String s = r.readLine();
            r.close();
            return s == null ? "?" : s.trim();
        } catch (Exception e) {
            return "?";
        }
    }

    private void show(String out) {
        if (out.contains("limit is OFF")) {
            setState("FULL CHARGE MODE\ncharging to 100%", ORANGE);
        } else if (out.contains("limit is ON")) {
            setState("LIMIT ON\nholding 40-50%", GREEN);
        } else {
            setState("NO ROOT / SCRIPT MISSING\ncheck su and " + SCRIPT, RED);
        }

        String temp = readSys("temp");
        try {
            temp = String.format("%.1f C", Integer.parseInt(temp) / 10.0);
        } catch (Exception ignored) { }
        infoView.setText("Battery " + readSys("capacity") + "%   |   "
                + readSys("status") + "   |   " + temp);

        logView.setText(out.trim());
    }
}
