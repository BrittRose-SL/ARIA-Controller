//-- A.R.I.A. Station Module Manager
//-- Version 1.0 - MODULE ACTIVATION/DEACTIVATION
//-- Handles remote module management for synced A.R.I.A. units

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
list gUnitModules = [];
list gUnitActiveModules = [];
integer gListenHandle;

// --- HELPER FUNCTIONS ---
openModuleMenu(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No A.R.I.A. unit connected to station.");
        return;
    }
    
    if (llGetListLength(gUnitModules) == 0) {
        llInstantMessage(user, "No module data available. Requesting update...");
        llRegionSay(gUnitLinkChannel, "REQUEST_MODULE_LIST|" + (string)user);
        return;
    }
    
    string dialog = "\n[ MODULE MANAGER ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Registered: " + (string)llGetListLength(gUnitModules) + "\n";
    dialog += "Active: " + (string)llGetListLength(gUnitActiveModules) + "\n\n";
    dialog += "Click module to toggle state:";
    
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(gUnitModules) && i < 9; i++) {
        string moduleName = llList2String(gUnitModules, i);
        string status = "OFF";
        if (llListFindList(gUnitActiveModules, [moduleName]) != -1) {
            status = "ON";
        }
        
        // Create button text (truncate long names)
        string buttonText = moduleName;
        if (llStringLength(buttonText) > 8) {
            buttonText = llGetSubString(buttonText, 0, 7);
        }
        buttonText += ":" + status;
        buttons += [buttonText];
    }
    
    // Add control buttons
    buttons += ["Refresh", "Status", "-Main-"];
    
    llListenRemove(gListenHandle);
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

toggleModule(string moduleButton, key user) {
    // Parse module name from button (format: "ModuleName:ON/OFF")
    list parts = llParseString2List(moduleButton, [":"], []);
    if (llGetListLength(parts) != 2) {
        llInstantMessage(user, "Invalid module selection.");
        return;
    }
    
    string shortName = llList2String(parts, 0);
    string currentStatus = llList2String(parts, 1);
    
    // Find full module name from registered list
    string fullModuleName = "";
    integer i;
    for (i = 0; i < llGetListLength(gUnitModules); i++) {
        string regModule = llList2String(gUnitModules, i);
        if (llSubStringIndex(regModule, shortName) == 0) {
            fullModuleName = regModule;
            jump found_module;
        }
    }
    @found_module;
    
    if (fullModuleName == "") {
        llInstantMessage(user, "Module not found: " + shortName);
        return;
    }
    
    // Determine action
    string action = "activate";
    if (currentStatus == "ON") {
        action = "deactivate";
    }
    
    // Send toggle command to unit
    string command = "TOGGLE_MODULE|" + fullModuleName + "|" + action + "|" + (string)user;
    llRegionSay(gUnitLinkChannel, command);
    
    string actionMsg = "Activating";
    if (action == "deactivate") {
        actionMsg = "Deactivating";
    }
    
    llInstantMessage(user, actionMsg + " module: " + fullModuleName);
    llSay(0, actionMsg + " " + fullModuleName + " on " + gSyncedUnitName);
    
    // Request updated module list
    llSleep(1.0);
    llRegionSay(gUnitLinkChannel, "REQUEST_MODULE_LIST|" + (string)user);
}

showModuleStatus(key user) {
    if (llGetListLength(gUnitModules) == 0) {
        llInstantMessage(user, "No module data available.");
        return;
    }
    
    string report = "MODULE STATUS REPORT\n";
    report += "Unit: " + gSyncedUnitName + "\n";
    report += "═══════════════════════\n";
    
    integer i;
    for (i = 0; i < llGetListLength(gUnitModules); i++) {
        string moduleName = llList2String(gUnitModules, i);
        string status = "INACTIVE";
        if (llListFindList(gUnitActiveModules, [moduleName]) != -1) {
            status = "ACTIVE";
        }
        report += "• " + moduleName + ": " + status + "\n";
    }
    
    report += "═══════════════════════\n";
    report += "Total: " + (string)llGetListLength(gUnitModules) + " modules\n";
    report += "Active: " + (string)llGetListLength(gUnitActiveModules) + " modules";
    
    llInstantMessage(user, report);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Register with main station
        llMessageLinked(LINK_ROOT, STATION_MODULE_REGISTER, "Module Manager", NULL_KEY);
        
        // Listen for unit responses
        llListen(gUnitLinkChannel, "", NULL_KEY, "");
        
        llOwnerSay("Station Module Manager v1.0 initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == STATION_OPEN_MENU) {
            // Parse: userkey|modulename
            list parts = llParseString2List(msg, ["|"], []);
            key user = (key)llList2String(parts, 0);
            string moduleName = llList2String(parts, 1);
            
            if (moduleName == "Module Manager" || moduleName == "Module" || moduleName == "Modules") {
                gCurrentUser = user;
                openModuleMenu(user);
            }
        }
        else if (num == STATION_UNIT_SYNC) {
            list parts = llParseString2List(msg, ["|"], []);
            string syncCommand = llList2String(parts, 0);
            
            if (syncCommand == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                llOwnerSay("Module Manager synced with: " + gSyncedUnitName);
            }
            else if (syncCommand == "DISCONNECT") {
                gSyncedUnitKey = NULL_KEY;
                gSyncedUnitName = "";
                gUnitModules = [];
                gUnitActiveModules = [];
                llOwnerSay("Module Manager disconnected from unit.");
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
                }
            }
        }
        else if (num == STATION_UNIT_STATUS) {
            // Parse unit status data
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gSyncedUnitKey = (key)llList2String(parts, 0);
                gSyncedUnitName = llList2String(parts, 1);
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle unit responses
        if (chan == gUnitLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "MODULE_LIST_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    gUnitModules = llCSV2List(llList2String(parts, 1));
                    gUnitActiveModules = llCSV2List(llList2String(parts, 2));
                    llOwnerSay("Module data updated from unit.");
                }
                return;
            }
            else if (command == "MODULE_TOGGLE_RESPONSE") {
                if (llGetListLength(parts) >= 4) {
                    string moduleName = llList2String(parts, 1);
                    string action = llList2String(parts, 2);
                    string result = llList2String(parts, 3);
                    
                    if (result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "Module " + moduleName + " " + action + "d successfully.");
                    } else {
                        llInstantMessage(gCurrentUser, "Failed to " + action + " module " + moduleName + ": " + result);
                    }
                }
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
            else if (msg == "Refresh") {
                llInstantMessage(id, "Refreshing module data...");
                llRegionSay(gUnitLinkChannel, "REQUEST_MODULE_LIST|" + (string)id);
                llSleep(1.0);
                openModuleMenu(id);
            }
            else if (msg == "Status") {
                showModuleStatus(id);
                openModuleMenu(id);
            }
            else if (llSubStringIndex(msg, ":") != -1) {
                // Module toggle button
                toggleModule(msg, id);
                llSleep(2.0); // Give time for toggle to complete
                openModuleMenu(id);
            }
            else {
                llInstantMessage(id, "Unknown command: " + msg);
                openModuleMenu(id);
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
