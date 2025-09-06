//-- A.R.I.A. Station Charging System
//-- Version 1.0 - BATTERY CHARGING & POWER MANAGEMENT
//-- Handles battery charging and power control for synced A.R.I.A. units

// --- COMMUNICATION CHANNELS ---
integer gUnitLinkChannel = -18795462; // Communication with A.R.I.A. units
integer gMenuChannel;

// --- LINKED MESSAGE CODES ---
integer STATION_MODULE_REGISTER = 500;
integer STATION_OPEN_MENU = 501;
integer STATION_UPDATE_DATA = 502;
integer STATION_UNIT_SYNC = 503;
integer STATION_UNIT_STATUS = 504;
integer STATION_REQUEST_DATA = 505;

// --- STATE VARIABLES ---
key gCurrentUser;
key gSyncedUnitKey;
string gSyncedUnitName = "";
float gUnitBatteryLevel = 0.0;
string gUnitStatus = "Unknown";
integer gUnitPowerState = FALSE;
integer gListenHandle;
integer gTextBoxHandle;

// --- CHARGING CONTROL ---
integer gIsCharging = FALSE;
float gChargeRate = 1.0; // Default charge rate
integer gChargingTimer = 0;
integer gAutoStopEnabled = TRUE;
float gAutoStopLevel = 95.0;

// --- HELPER FUNCTIONS ---
openChargingMenu(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No A.R.I.A. unit connected to station.");
        return;
    }
    
    string dialog = "\n[ CHARGING SYSTEM ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Battery: " + (string)((integer)gUnitBatteryLevel) + "%\n";
    dialog += "Power: " + gUnitStatus + "\n";
    dialog += "Charge Rate: " + (string)gChargeRate + "%/min\n";
    dialog += "Auto-Stop: ";
    if (gAutoStopEnabled) {
        dialog += "ON (" + (string)((integer)gAutoStopLevel) + "%)\n";
    } else {
        dialog += "OFF\n";
    }
    dialog += "Status: ";
    if (gIsCharging) {
        dialog += "CHARGING ACTIVE\n";
    } else {
        dialog += "STANDBY\n";
    }
    
    list buttons = [];
    
    // Charging control
    if (gIsCharging) {
        buttons += ["Stop Charging"];
    } else {
        buttons += ["Start Charging"];
    }
    
    // Emergency and advanced options
    buttons += ["Emergency Charge", "Set Rate", "Auto-Stop"];
    
    // Power control
    if (gUnitPowerState) {
        buttons += ["Power OFF"];
    } else {
        buttons += ["Power ON"];
    }
    
    buttons += ["Battery Info", "-Main-"];
    
    llListenRemove(gListenHandle);
    llListenRemove(gTextBoxHandle);
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

startCharging(key user, integer emergency) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    if (gIsCharging) {
        llInstantMessage(user, "Charging already active.");
        return;
    }
    
    gIsCharging = TRUE;
    gChargingTimer = llGetUnixTime();
    
    if (emergency) {
        gChargeRate = 5.0; // Emergency fast charge
        llInstantMessage(user, "EMERGENCY CHARGING activated at " + (string)gChargeRate + "%/min!");
        llSay(0, "EMERGENCY CHARGE: " + gSyncedUnitName + " charging at maximum rate!");
    } else {
        llInstantMessage(user, "Charging started at " + (string)gChargeRate + "%/min");
        llSay(0, "CHARGING: " + gSyncedUnitName + " connected to power");
    }
    
    // Send charge start command to unit
    string command = "CHARGE_START|" + (string)gSyncedUnitKey + "|" + (string)gChargeRate;
    llRegionSay(gUnitLinkChannel, command);
    
    // Start monitoring timer
    llSetTimerEvent(30.0);
}

stopCharging(key user) {
    if (!gIsCharging) {
        llInstantMessage(user, "Charging not active.");
        return;
    }
    
    gIsCharging = FALSE;
    integer chargeDuration = llGetUnixTime() - gChargingTimer;
    float chargeAdded = (chargeDuration / 60.0) * gChargeRate;
    
    llInstantMessage(user, "Charging stopped. Duration: " + (string)(chargeDuration / 60) + " minutes");
    llSay(0, "CHARGING COMPLETE: " + gSyncedUnitName + " disconnected from power");
    
    // Send charge stop command to unit
    string command = "CHARGE_STOP|" + (string)gSyncedUnitKey;
    llRegionSay(gUnitLinkChannel, command);
    
    // Reset emergency charge rate if it was used
    if (gChargeRate > 3.0) {
        gChargeRate = 1.0;
        llInstantMessage(user, "Charge rate reset to normal (" + (string)gChargeRate + "%/min)");
    }
}

setChargeRate(key user, float newRate) {
    if (newRate < 0.1 || newRate > 10.0) {
        llInstantMessage(user, "Invalid charge rate. Must be between 0.1 and 10.0 %/min");
        return;
    }
    
    gChargeRate = newRate;
    llInstantMessage(user, "Charge rate set to " + (string)newRate + "%/min");
    
    // If currently charging, update the rate
    if (gIsCharging) {
        string command = "CHARGE_RATE|" + (string)gSyncedUnitKey + "|" + (string)gChargeRate;
        llRegionSay(gUnitLinkChannel, command);
        llInstantMessage(user, "Updated active charging rate.");
    }
}

toggleAutoStop(key user) {
    gAutoStopEnabled = !gAutoStopEnabled;
    
    if (gAutoStopEnabled) {
        llInstantMessage(user, "Auto-stop enabled. Will stop charging at " + (string)((integer)gAutoStopLevel) + "%");
    } else {
        llInstantMessage(user, "Auto-stop disabled. Manual charging control only.");
    }
}

showBatteryInfo(key user) {
    string report = "BATTERY STATUS REPORT\n";
    report += "Unit: " + gSyncedUnitName + "\n";
    report += "═══════════════════════\n";
    report += "Current Level: " + (string)((integer)gUnitBatteryLevel) + "%\n";
    report += "Power Status: " + gUnitStatus + "\n";
    report += "Charging: ";
    if (gIsCharging) {
        report += "ACTIVE (" + (string)gChargeRate + "%/min)\n";
        integer duration = llGetUnixTime() - gChargingTimer;
        report += "Duration: " + (string)(duration / 60) + " minutes\n";
        
        // Estimate time to full
        if (gUnitBatteryLevel < 100.0 && gChargeRate > 0.0) {
            float remaining = 100.0 - gUnitBatteryLevel;
            integer timeToFull = (integer)(remaining / gChargeRate);
            report += "Est. Time to Full: " + (string)timeToFull + " minutes\n";
        }
    } else {
        report += "INACTIVE\n";
    }
    
    report += "═══════════════════════\n";
    report += "Station Settings:\n";
    report += "• Charge Rate: " + (string)gChargeRate + "%/min\n";
    report += "• Auto-Stop: ";
    if (gAutoStopEnabled) {
        report += "ON (" + (string)((integer)gAutoStopLevel) + "%)\n";
    } else {
        report += "OFF\n";
    }
    
    llInstantMessage(user, report);
}

checkAutoStop() {
    if (gAutoStopEnabled && gIsCharging && gUnitBatteryLevel >= gAutoStopLevel) {
        llInstantMessage(gCurrentUser, "Auto-stop triggered at " + (string)((integer)gUnitBatteryLevel) + "%");
        stopCharging(gCurrentUser);
    }
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Register with main station
        llMessageLinked(LINK_ROOT, STATION_MODULE_REGISTER, "Charging System", NULL_KEY);
        
        // Listen for unit responses
        llListen(gUnitLinkChannel, "", NULL_KEY, "");
        
        llOwnerSay("Station Charging System v1.0 initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == STATION_OPEN_MENU) {
            // Parse: userkey|modulename
            list parts = llParseString2List(msg, ["|"], []);
            key user = (key)llList2String(parts, 0);
            string moduleName = llList2String(parts, 1);
            
            if (moduleName == "Charging System" || moduleName == "Charging" || moduleName == "Battery") {
                gCurrentUser = user;
                openChargingMenu(user);
            }
        }
        else if (num == STATION_UNIT_SYNC) {
            list parts = llParseString2List(msg, ["|"], []);
            string syncCommand = llList2String(parts, 0);
            
            if (syncCommand == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                llOwnerSay("Charging System synced with: " + gSyncedUnitName);
            }
            else if (syncCommand == "DISCONNECT") {
                // Stop charging if active
                if (gIsCharging) {
                    gIsCharging = FALSE;
                    llOwnerSay("Charging stopped - unit disconnected.");
                }
                
                gSyncedUnitKey = NULL_KEY;
                gSyncedUnitName = "";
                gUnitBatteryLevel = 0.0;
                gUnitStatus = "Unknown";
                gUnitPowerState = FALSE;
                llOwnerSay("Charging System disconnected from unit.");
            }
        }
        else if (num == STATION_UNIT_STATUS) {
            // Parse unit status data
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 6) {
                gSyncedUnitKey = (key)llList2String(parts, 0);
                gSyncedUnitName = llList2String(parts, 1);
                gUnitBatteryLevel = (float)llList2String(parts, 2);
                // parts[3] is persona
                gUnitStatus = llList2String(parts, 4);
                gUnitPowerState = (integer)llList2String(parts, 5);
                
                // Check auto-stop
                checkAutoStop();
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle unit responses
        if (chan == gUnitLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "CHARGE_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string action = llList2String(parts, 1);
                    string result = llList2String(parts, 2);
                    
                    if (action == "START" && result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "Unit confirmed charging started.");
                    } else if (action == "STOP" && result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "Unit confirmed charging stopped.");
                    } else {
                        llInstantMessage(gCurrentUser, "Charge command failed: " + result);
                    }
                }
                return;
            }
            else if (command == "POWER_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string action = llList2String(parts, 1);
                    string result = llList2String(parts, 2);
                    
                    if (result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "Power " + action + " successful.");
                        if (action == "ON") {
                            gUnitPowerState = TRUE;
                        } else {
                            gUnitPowerState = FALSE;
                        }
                    } else {
                        llInstantMessage(gCurrentUser, "Power command failed: " + result);
                    }
                }
                return;
            }
            return;
        }
        
        // Handle menu interactions
        if (chan == gMenuChannel) {
            llListenRemove(gListenHandle);
            llListenRemove(gTextBoxHandle);
            
            if (msg == "-Main-") {
                llInstantMessage(id, "Returning to main station menu.");
                return;
            }
            else if (msg == "Start Charging") {
                startCharging(id, FALSE);
                openChargingMenu(id);
            }
            else if (msg == "Stop Charging") {
                stopCharging(id);
                openChargingMenu(id);
            }
            else if (msg == "Emergency Charge") {
                startCharging(id, TRUE);
                openChargingMenu(id);
            }
            else if (msg == "Set Rate") {
                gTextBoxHandle = llListen(gMenuChannel, "", id, "");
                llTextBox(id, "Enter new charge rate (0.1 to 10.0 %/min):\nCurrent: " + (string)gChargeRate, gMenuChannel);
                llSetTimerEvent(60.0);
                return; // Don't reopen menu yet
            }
            else if (msg == "Auto-Stop") {
                toggleAutoStop(id);
                openChargingMenu(id);
            }
            else if (msg == "Power ON") {
                llRegionSay(gUnitLinkChannel, "REMOTE_COMMAND|" + (string)id + "|POWER ON");
                llInstantMessage(id, "Sending power on command...");
                openChargingMenu(id);
            }
            else if (msg == "Power OFF") {
                llRegionSay(gUnitLinkChannel, "REMOTE_COMMAND|" + (string)id + "|POWER OFF");
                llInstantMessage(id, "Sending power off command...");
                openChargingMenu(id);
            }
            else if (msg == "Battery Info") {
                showBatteryInfo(id);
                openChargingMenu(id);
            }
            else {
                // Handle charge rate input
                float testRate = (float)msg;
                if (testRate > 0.0 || msg == "0") {
                    setChargeRate(id, testRate);
                } else {
                    llInstantMessage(id, "Invalid input. Please enter a number between 0.1 and 10.0");
                }
                openChargingMenu(id);
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);
        
        // If charging, check for auto-stop
        if (gIsCharging) {
            checkAutoStop();
            llSetTimerEvent(30.0); // Continue monitoring while charging
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
