package com.kushal.wakeupcall;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import android.content.Intent;
import android.os.Bundle;

@CapacitorPlugin(name = "NotificationHandler")
public class NotificationHandlerPlugin extends Plugin {
    @PluginMethod
    public void handleAction(PluginCall call) {
        String actionId = call.getString("actionId");
        JSObject extra = call.getObject("extra");
        String wakeupTime = extra != null ? extra.getString("wakeupTime") : null;

        if ("accept".equals(actionId) || "decline".equals(actionId)) {
            Intent intent = new Intent("com.kushal.wakeupcall.FULL_SCREEN_CALL");
            intent.setClass(getContext(), CallActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            if (wakeupTime != null) {
                intent.putExtra("wakeupTime", wakeupTime);
            }
            getContext().startActivity(intent);
            call.resolve();
        } else {
            call.reject("Unknown action");
        }
    }
}
