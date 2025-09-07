//-- A.R.I.A. Station Diagnostics Module
//-- Version 1.0 - STATUS REPORTS & SYSTEM DIAGNOSTICS
//-- Handles comprehensive status reporting and system diagnostics for synced A.R.I.A. units

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
string gUnitPersona = "Unknown";
string gUnitStatus = "Unknown";
integer gUnitPowerState = FALSE;
list gUnitModules = [];
list gUnitActiveModules = [];
list gUnitAdministrators = [];
list gUnitTrustedUsers = [];
integer gWearerAdminMode = TRUE;
integer gListenHandle;

// --- DIAGNOSTIC DATA ---
string gLastSync = "";
integer gSyncTime = 0;
integer gDataRequests = 0;
integer gSuccessfulRequests = 0;

// --- HELPER FUNCTIONS ---
openDiagnosticsMenu(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No A.R.I.A. unit connected to station.");
        return;
    }
    
    string dialog = "\n[ DIAGNOSTICS & STATUS ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Connected: " + gLastSync + "\n";
    dialog += "Status: " + gUnitStatus + "\n";
    dialog += "Battery: " + (string)((integer)gUnitBatteryLevel) + "%\n\n";
    dialog += "Select diagnostic option:";
    
    list buttons = ["Full Report", "Quick Status", "Module Report"];
    buttons += ["Permission Report", "System Test", "RLV Query"];
    buttons += ["Refresh Data", "Export Log", "-Main-"];
    
    llListenRemove(gListenHandle);
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

generateFullReport(key user) {
    string report = "═══ A.R.I.A. UNIT DIAGNOSTIC REPORT ═══\n";
    report += "Generated: " + llGetTimestamp() + "\n";
    report += "Station: " + llGetObjectName() + "\n";
    report += "Operator: " + llKey2Name(user) + "\n\n";
    
    // Unit Information
    report += "UNIT INFORMATION\n";
    report += "─────────────────\n";
    report += "Name: " + gSyncedUnitName + "\n";
    report += "UUID: " + (string)gSyncedUnitKey + "\n";
    report += "Last Sync: " + gLastSync + "\n";
    report += "Connection Time: " + (string)((llGetUnixTime() - gSyncTime) / 60) + " minutes\n\n";
    
    // Power & Battery
    report += "POWER STATUS\n";
    report += "─────────────\n";
    report += "Power State: " + gUnitStatus + "\n";
    report += "Battery Level: " + (string)((integer)gUnitBatteryLevel) + "%\n";
    string batteryStatus = "Normal";
    if (gUnitBatteryLevel <= 25.0) batteryStatus = "Low";
    if (gUnitBatteryLevel <= 10.0) batteryStatus = "Critical";
    report += "Battery Status: " + batteryStatus + "\n";
    report += "Power Mode: ";
    if (gUnitPowerState) {
        report += "Online\n\n";
    } else {
        report += "Offline\n\n";
    }
    
    // Persona Status
    report += "PERSONA STATUS\n";
    report += "──────────────\n";
    report += "Active Persona: " + gUnitPersona + "\n";
    report += "Persona Mode: Active\n\n";
    
    // Module Status
    report += "MODULE STATUS\n";
    report += "─────────────\n";
    report += "Total Modules: " + (string)llGetListLength(gUnitModules) + "\n";
    report += "Active Modules: " + (string)llGetListLength(gUnitActiveModules) + "\n";
    report += "Inactive Modules: " + (string)(llGetListLength(gUnitModules) - llGetListLength(gUnitActiveModules)) + "\n\n";
    
    // Permission Status
    report += "PERMISSION STATUS\n";
    report += "─────────────────\n";
    report += "Administrators: " + (string)llGetListLength(gUnitAdministrators) + "\n";
    report += "Trusted Users: " + (string)llGetListLength(gUnitTrustedUsers) + "\n";
    report += "Wearer Admin: ";
    if (gWearerAdminMode) {
        report += "Enabled\n\n";
    } else {
        report += "Disabled\n\n";
    }
    
    // Communication Status
    report += "COMMUNICATION STATUS\n";
    report += "────────────────────\n";
    report += "Data Requests: " + (string)gDataRequests + "\n";
    report += "Successful: " + (string)gSuccessfulRequests + "\n";
    float successRate = 0.0;
    if (gDataRequests > 0) {
        successRate = ((float)gSuccessfulRequests / (float)gDataRequests) * 100.0;
    }
    report += "Success Rate: " + (string)((integer)successRate) + "%\n\n";
    
    report += "═══ END DIAGNOSTIC REPORT ═══";
    
    llInstantMessage(user, report);
}

generateQuickStatus(key user) {
    string report = "QUICK STATUS REPORT\n";
    report += "Unit: " + gSyncedUnitName + "\n";
    report += "═══════════════════\n";
    report += "Power: " + gUnitStatus + " (" + (string)((integer)gUnitBatteryLevel) + "%)\n";
    report += "Persona: " + gUnitPersona + "\n";
    report += "Modules: " + (string)llGetListLength(gUnitActiveModules) + "/" + (string)llGetListLength(gUnitModules) + " active\n";
    report += "Users: " + (string)llGetListLength(gUnitAdministrators) + " admins, " + (string)llGetListLength(gUnitTrustedUsers) + " trusted\n";
    report += "Connection: " + (string)((llGetUnixTime() - gSyncTime) / 60) + " min ago";
    
    llInstantMessage(user, report);
}

generateModuleReport(key user) {
    string report = "MODULE STATUS REPORT\n";
    report += "Unit: " + gSyncedUnitName + "\n";
    report += "═══════════════════════\n";
    
    if (llGetListLength(gUnitModules) == 0) {
        report += "No module data available.\nRequest data refresh from unit.";
    } else {
        report += "ACTIVE MODULES (" + (string)llGetListLength(gUnitActiveModules) + "):\n";
        integer i;
        for (i = 0; i < llGetListLength(gUnitActiveModules); i++) {
            report += "✓ " + llList2String(gUnitActiveModules, i) + "\n";
        }
        
        report += "\nINACTIVE MODULES:\n";
        for (i = 0; i < llGetListLength(gUnitModules); i++) {
            string moduleName = llList2String(gUnitModules, i);
            if (llListFindList(gUnitActiveModules, [moduleName]) == -1) {
                report += "✗ " + moduleName + "\n";
            }
        }
        
        report += "\nSUMMARY:\n";
        report += "Total: " + (string)llGetListLength(gUnitModules) + " modules\n";
        report += "Active: " + (string)llGetListLength(gUnitActiveModules) + " modules\n";
        report += "Inactive: " + (string)(llGetListLength(gUnitModules) - llGetListLength(gUnitActiveModules)) + " modules";
    }
    
    llInstantMessage(user, report);
}

generatePermissionReport(key user) {
    string report = "PERMISSION STATUS REPORT\n";
    report += "Unit: " + gSyncedUnitName + "\n";
    report += "═══════════════════════\n";
    
    report += "ADMINISTRATORS (" + (string)llGetListLength(gUnitAdministrators) + "):\n";
    integer i;
    for (i = 0; i < llGetListLength(gUnitAdministrators) && i < 8; i++) {
        key userKey = (key)llList2String(gUnitAdministrators, i);
        string userName = llKey2Name(userKey);
        if (userName == "") userName = "Unknown User";
        report += "• " + userName + "\n";
    }
    if (llGetListLength(gUnitAdministrators) > 8) {
        report += "... and " + (string)(llGetListLength(gUnitAdministrators) - 8) + " more\n";
    }
    
    report += "\nTRUSTED USERS (" + (string)llGetListLength(gUnitTrustedUsers) + "):\n";
    for (i = 0; i < llGetListLength(gUnitTrustedUsers) && i < 8; i++) {
        key userKey = (key)llList2String(gUnitTrustedUsers, i);
        string userName = llKey2Name(userKey);
        if (userName == "") userName = "Unknown User";
        report += "• " + userName + "\n";
    }
    if (llGetListLength(gUnitTrustedUsers) > 8) {
        report += "... and " + (string)(llGetListLength(gUnitTrustedUsers) - 8) + " more\n";
    }
    
    report += "\nPERMISSION SETTINGS:\n";
    report += "Wearer Admin Mode: ";
    if (gWearerAdminMode) {
        report += "ENABLED\n";
    } else {
        report += "DISABLED\n";
    }
    
    report += "Total Users: " + (string)(llGetListLength(gUnitAdministrators) + llGetListLength(gUnitTrustedUsers));
    
    llInstantMessage(user, report);
}

runSystemTest(key user) {
    llInstantMessage(user, "Running system test on " + gSyncedUnitName + "...");
    llSay(0, "SYSTEM TEST: Testing all communication channels with " + gSyncedUnitName);
    
    // Test basic communication
    gDataRequests++;
    llRegionSay(gUnitLinkChannel, "SYSTEM_TEST|PING|" + (string)user);
    
    // Test data requests
    llRegionSay(gUnitLinkChannel, "REQUEST_FULL_STATUS|" + (string)user);
    llRegionSay(gUnitLinkChannel, "REQUEST_MODULE_LIST|" + (string)user);
    llRegionSay(gUnitLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)user);
    
    llInstantMessage(user, "System test initiated. Results will be reported shortly.");
}

runRLVQuery(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    llInstantMessage(user, "Querying RLV status from " + gSyncedUnitName + "...");
    llSay(0, "RLV DIAGNOSTIC: Requesting viewer information from " + gSyncedUnitName);
    
    // Send RLV diagnostic commands
    llRegionSay(gUnitLinkChannel, "RLV_QUERY|VERSION|" + (string)user);
    llRegionSay(gUnitLinkChannel, "RLV_QUERY|ATTACHMENTS|" + (string)user);
    llRegionSay(gUnitLinkChannel, "RLV_QUERY|RESTRICTIONS|" + (string)user);
}

refreshAllData(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No unit connected.");
        return;
    }
    
    llInstantMessage(user, "Refreshing all data from " + gSyncedUnitName + "...");
    
    gDataRequests += 4;
    llRegionSay(gUnitLinkChannel, "REQUEST_FULL_STATUS|" + (string)user);
    llRegionSay(gUnitLinkChannel, "REQUEST_MODULE_LIST|" + (string)user);
    llRegionSay(gUnitLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)user);
    llRegionSay(gUnitLinkChannel, "REQUEST_PERSONA_LIST|" + (string)user);
    
    llSay(0, "DATA REFRESH: Updating all cached information from " + gSyncedUnitName);
}

exportDiagnosticLog(key user) {
    string logData = "A.R.I.A. DIAGNOSTIC LOG\n";
    logData += "Timestamp: " + llGetTimestamp() + "\n";
    logData += "Station: " + llGetObjectName() + "\n";
    logData += "Unit: " + gSyncedUnitName + " (" + (string)gSyncedUnitKey + ")\n";
    logData += "Session Duration: " + (string)((llGetUnixTime() - gSyncTime) / 60) + " minutes\n";
    logData += "Communication Success Rate: " + (string)((integer)(((float)gSuccessfulRequests / (float)gDataRequests) * 100.0)) + "%\n";
    logData += "Last Status: " + gUnitStatus + " @ " + (string)((integer)gUnitBatteryLevel) + "%\n";
    logData += "Active Modules: " + llList2CSV(gUnitActiveModules) + "\n";
    logData += "Administrators: " + (string)llGetListLength(gUnitAdministrators) + "\n";
    logData += "Trusted Users: " + (string)llGetListLength(gUnitTrustedUsers) + "\n";
    
    llInstantMessage(user, "DIAGNOSTIC LOG EXPORT:\n" + logData);
    llOwnerSay("Diagnostic log exported for " + gSyncedUnitName);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize diagnostic data
        gLastSync = "Never";
        gSyncTime = 0;
        gDataRequests = 0;
        gSuccessfulRequests = 0;
        
        // Register with main station
        llMessageLinked(LINK_ROOT, STATION_MODULE_REGISTER, "Diagnostics", NULL_KEY);
        
        // Listen for unit responses
        llListen(gUnitLinkChannel, "", NULL_KEY, "");
        
        llOwnerSay("Station Diagnostics Module v1.0 initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == STATION_OPEN_MENU) {
            // Parse: userkey|modulename
            list parts = llParseString2List(msg, ["|"], []);
            key user = (key)llList2String(parts, 0);
            string moduleName = llList2String(parts, 1);
            
            if (moduleName == "Diagnostics" || moduleName == "Status" || moduleName == "Status Report") {
                gCurrentUser = user;
                openDiagnosticsMenu(user);
            }
        }
        else if (num == STATION_UNIT_SYNC) {
            list parts = llParseString2List(msg, ["|"], []);
            string syncCommand = llList2String(parts, 0);
            
            if (syncCommand == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                gLastSync = llGetTimestamp();
                gSyncTime = llGetUnixTime();
                llOwnerSay("Diagnostics synced with: " + gSyncedUnitName);
            }
            else if (syncCommand == "DISCONNECT") {
                gSyncedUnitKey = NULL_KEY;
                gSyncedUnitName = "";
                gLastSync = "Disconnected";
                llOwnerSay("Diagnostics disconnected from unit.");
            }
        }
        else if (num == STATION_UPDATE_DATA) {
            list parts = llParseString2List(msg, ["|"], []);
            string dataType = llList2String(parts, 0);
            
            if (dataType == "MODULES") {
                string moduleData = llList2String(parts, 1);
                list dataParts = llParseString2List(moduleData, ["|"], []);
                if (llGetListLength(dataParts) >= 2) {
                    gUnitModules = llCSV2List(llList2String(dataParts, 0));
                    gUnitActiveModules = llCSV2List(llList2String(dataParts, 1));
                    gSuccessfulRequests++;
                }
            }
            else if (dataType == "PERMISSIONS") {
                string permData = llList2String(parts, 1);
                list dataParts = llParseString2List(permData, ["|"], []);
                if (llGetListLength(dataParts) >= 3) {
                    gUnitAdministrators = llCSV2List(llList2String(dataParts, 0));
                    gUnitTrustedUsers = llCSV2List(llList2String(dataParts, 1));
                    gWearerAdminMode = (integer)llList2String(dataParts, 2);
                    gSuccessfulRequests++;
                }
            }
        }
        else if (num == STATION_UNIT_STATUS) {
            // Parse unit status data
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 6) {
                gSyncedUnitKey = (key)llList2String(parts, 0);
                gSyncedUnitName = llList2String(parts, 1);
                gUnitBatteryLevel = (float)llList2String(parts, 2);
                gUnitPersona = llList2String(parts, 3);
                gUnitStatus = llList2String(parts, 4);
                gUnitPowerState = (integer)llList2String(parts, 5);
                gSuccessfulRequests++;
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle unit responses
        if (chan == gUnitLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "SYSTEM_TEST_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string testType = llList2String(parts, 1);
                    string result = llList2String(parts, 2);
                    
                    llInstantMessage(gCurrentUser, "System Test Result - " + testType + ": " + result);
                    if (result == "SUCCESS") {
                        gSuccessfulRequests++;
                    }
                }
                return;
            }
            else if (command == "RLV_QUERY_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string queryType = llList2String(parts, 1);
                    string queryResult = llList2String(parts, 2);
                    
                    llInstantMessage(gCurrentUser, "RLV " + queryType + " Result:\n" + queryResult);
                }
                return;
            }
            else if (command == "FULL_STATUS_RESPONSE") {
                gSuccessfulRequests++;
                llInstantMessage(gCurrentUser, "Full status data received from " + gSyncedUnitName);
                return;
            }
            return;
        }
        
        // Handle menu interactions
        if (chan == gMenuChannel) {
            llListenRemove(gListenHandle);
            
            if (msg == "-Main-") {
                llInstantMessage(id, "Returning to main station menu.");
                return;
            }
            else if (msg == "Full Report") {
                generateFullReport(id);
                openDiagnosticsMenu(id);
            }
            else if (msg == "Quick Status") {
                generateQuickStatus(id);
                openDiagnosticsMenu(id);
            }
            else if (msg == "Module Report") {
                generateModuleReport(id);
                openDiagnosticsMenu(id);
            }
            else if (msg == "Permission Report") {
                generatePermissionReport(id);
                openDiagnosticsMenu(id);
            }
            else if (msg == "System Test") {
                runSystemTest(id);
                openDiagnosticsMenu(id);
            }
            else if (msg == "RLV Query") {
                runRLVQuery(id);
                openDiagnosticsMenu(id);
            }
            else if (msg == "Refresh Data") {
                refreshAllData(id);
                openDiagnosticsMenu(id);
            }
            else if (msg == "Export Log") {
                exportDiagnosticLog(id);
                openDiagnosticsMenu(id);
            }
            else {
                llInstantMessage(id, "Unknown command: " + msg);
                openDiagnosticsMenu(id);
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
