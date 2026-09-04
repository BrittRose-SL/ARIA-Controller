//-- A.R.I.A. Programming Station Main Kernel
//-- Version 1.1 - MODULAR STATION ARCHITECTURE
//-- The main hub for all station modules, handles unit sync and core functionality
//-- CHANGES v1.1:
//--   - Added target unit keys to permission requests

// --- COMMUNICATION CHANNELS ---
integer gUnitLinkChannel = -18795462; // Communication with A.R.I.A. units
integer gStationMenuChannel; // Station menu dialogs

// --- LINKED MESSAGE CODES ---
integer STATION_MODULE_REGISTER = 500;
integer STATION_OPEN_MENU = 501;
integer STATION_UPDATE_DATA = 502;
integer STATION_UNIT_SYNC = 503;
integer STATION_UNIT_STATUS = 504;
integer STATION_REQUEST_DATA = 505;

// --- CORE STATE VARIABLES ---
key gProgrammerKey;
key gSyncedUnitKey;
string gSyncedUnitName = "";
float gUnitBatteryLevel = 0.0;
string gUnitPersona = "Unknown";
string gUnitStatus = "Offline";
integer gUnitPowerState = FALSE;

// --- MODULE MANAGEMENT ---
list gRegisteredModules = [];
list gActiveModules = [];

// --- UNIT DATA CACHE ---
list gUnitModules = [];
list gUnitActiveModules = [];
list gUnitAdministrators = [];
list gUnitTrustedUsers = [];
integer gWearerAdminMode = TRUE;

// --- MENU & DIALOG VARIABLES ---
integer gListenHandle;
integer gMainMenuOpen = FALSE;

// --- HELPER FUNCTIONS ---
updateStationDisplay() {
    string display = "A.R.I.A. PROGRAMMING STATION v1.0\n";
    display += "═══════════════════════════════\n";
    
    if (gSyncedUnitKey == NULL_KEY) {
        display += "STATUS: READY FOR SYNC\n";
        display += "Touch to begin programming\n";
        display += "Then touch target A.R.I.A. unit";
        llSetText(display, <1.0, 1.0, 0.0>, 1.0);
    } else {
        display += "UNIT: " + gSyncedUnitName + "\n";
        display += "BATTERY: " + (string)((integer)gUnitBatteryLevel) + "%\n";
        display += "PERSONA: " + gUnitPersona + "\n";
        display += "STATUS: " + gUnitStatus + "\n";
        display += "MODULES: " + (string)llGetListLength(gRegisteredModules) + " loaded";
        
        vector color = <0.2, 0.8, 1.0>; // Blue for normal operation
        if (gUnitStatus == "Charging") {
            color = <0.0, 1.0, 0.0>; // Green for charging
        } else if (gUnitBatteryLevel <= 25.0) {
            color = <1.0, 0.5, 0.0>; // Orange for low battery
        } else if (gUnitStatus == "Offline") {
            color = <1.0, 0.0, 0.0>; // Red for offline
        }
        
        llSetText(display, color, 1.0);
    }
}

broadcastUnitData() {
    // Send unit data to all registered modules
    string unitData = (string)gSyncedUnitKey + "|" + gSyncedUnitName + "|" + (string)gUnitBatteryLevel + "|";
    unitData += gUnitPersona + "|" + gUnitStatus + "|" + (string)gUnitPowerState;
    llMessageLinked(LINK_SET, STATION_UNIT_STATUS, unitData, NULL_KEY);
    
    // Send cached module data
    if (llGetListLength(gUnitModules) > 0) {
        string moduleData = llList2CSV(gUnitModules) + "|" + llList2CSV(gUnitActiveModules);
        llMessageLinked(LINK_SET, STATION_UPDATE_DATA, "MODULES|" + moduleData, NULL_KEY);
    }
    
    // Send cached permission data
    if (llGetListLength(gUnitAdministrators) > 0) {
        string permData = llList2CSV(gUnitAdministrators) + "|" + llList2CSV(gUnitTrustedUsers) + "|" + (string)gWearerAdminMode;
        llMessageLinked(LINK_SET, STATION_UPDATE_DATA, "PERMISSIONS|" + permData, NULL_KEY);
    }
}

openMainMenu(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No A.R.I.A. unit synced. Touch the station, then touch the target unit.");
        return;
    }
    
    gMainMenuOpen = TRUE;
    string dialog = "\n[ A.R.I.A. PROGRAMMING STATION ]\n";
    dialog += "═══════════════════════════════\n";
    dialog += "UNIT: " + gSyncedUnitName + "\n";
    dialog += "BATTERY: " + (string)((integer)gUnitBatteryLevel) + "%\n";
    dialog += "STATUS: " + gUnitStatus + "\n";
    dialog += "MODULES: " + (string)llGetListLength(gRegisteredModules) + " loaded\n\n";
    dialog += "Select a station module:";
    
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(gRegisteredModules) && i < 9; i++) {
        string moduleName = llList2String(gRegisteredModules, i);
        // Truncate long module names for buttons
        if (llStringLength(moduleName) > 12) {
            moduleName = llGetSubString(moduleName, 0, 11);
        }
        buttons += [moduleName];
    }
    
    // Add control buttons
    buttons += ["Refresh", "Disconnect"];
    if (llGetListLength(gRegisteredModules) > 9) {
        buttons += ["More..."];
    }
    
    llListenRemove(gListenHandle);
    gStationMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
    gListenHandle = llListen(gStationMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gStationMenuChannel);
    llSetTimerEvent(30.0);
}

requestUnitData() {
    if (gSyncedUnitKey == NULL_KEY) return;
    
    // Request comprehensive status from unit
    llRegionSay(gUnitLinkChannel, "REQUEST_FULL_STATUS|" + (string)gProgrammerKey);
    llRegionSay(gUnitLinkChannel, "REQUEST_MODULE_LIST|" + (string)gProgrammerKey);
    llRegionSay(gUnitLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)gSyncedUnitKey + "|" + (string)gProgrammerKey);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        // Initialize channels
        gStationMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
        
        // Initialize state
        gSyncedUnitKey = NULL_KEY;
        gRegisteredModules = [];
        gActiveModules = [];
        
        // Listen for unit communications
        llListen(gUnitLinkChannel, "", NULL_KEY, "");
        
        // Update display
        updateStationDisplay();
        
        // Start status timer
        llSetTimerEvent(15.0);
        
        llOwnerSay("A.R.I.A. Programming Station Main Kernel v1.0 initialized.");
        llOwnerSay("Station modules will register automatically.");
    }

    touch_start(integer num) {
        key toucher = llDetectedKey(0);
        gProgrammerKey = toucher;
        
        if (gSyncedUnitKey == NULL_KEY) {
            // Initiate sync process
            llInstantMessage(toucher, "Initiating sync with A.R.I.A. unit...");
            llSay(0, "Broadcasting sync request to nearby A.R.I.A. units...");
            updateStationDisplay();
            
            // Broadcast sync request
            llRegionSay(gUnitLinkChannel, "SYNC_REQUEST|" + (string)toucher);
            
            // Notify modules that sync is starting
            llMessageLinked(LINK_SET, STATION_UNIT_SYNC, "SYNC_START|" + (string)toucher, NULL_KEY);
            
            llSetTimerEvent(30.0); // Timeout for sync
        } else {
            // Open main menu
            openMainMenu(toucher);
        }
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == STATION_MODULE_REGISTER) {
            // A station module is registering itself
            if (llListFindList(gRegisteredModules, [msg]) == -1) {
                gRegisteredModules += [msg];
                gActiveModules += [msg];
                llOwnerSay("Station module registered: " + msg);
                
                // If we have a synced unit, send data to new module
                if (gSyncedUnitKey != NULL_KEY) {
                    broadcastUnitData();
                }
            }
        }
        else if (num == STATION_OPEN_MENU) {
            // A module wants to open its menu
            key user = (key)msg;
            string moduleName = llGetScriptName(); // This won't work as intended, need to pass module name
            llMessageLinked(sender, STATION_OPEN_MENU, (string)user, NULL_KEY);
        }
        else if (num == STATION_REQUEST_DATA) {
            // A module is requesting current unit data
            if (gSyncedUnitKey != NULL_KEY) {
                broadcastUnitData();
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle A.R.I.A. unit responses
        if (chan == gUnitLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                
                llInstantMessage(gProgrammerKey, "Sync successful with " + gSyncedUnitName + "!");
                llSay(0, "Unit synchronized: " + gSyncedUnitName);
                
                // Notify all modules of successful sync
                string syncData = (string)gSyncedUnitKey + "|" + gSyncedUnitName;
                llMessageLinked(LINK_SET, STATION_UNIT_SYNC, "SYNC_SUCCESS|" + syncData, NULL_KEY);
                
                // Request initial data
                requestUnitData();
                updateStationDisplay();
                
                // Open main menu automatically
                llSleep(1.0);
                openMainMenu(gProgrammerKey);
                return;
            }
            else if (command == "STATUS_BROADCAST") {
                // Parse: STATUS_BROADCAST|unitname|battery|persona|status
                if (llGetListLength(parts) >= 5) {
                    gSyncedUnitName = llList2String(parts, 1);
                    gUnitBatteryLevel = (float)llList2String(parts, 2);
                    gUnitPersona = llList2String(parts, 3);
                    gUnitStatus = llList2String(parts, 4);
                    
                    // Determine power state from status
                    if (gUnitStatus == "Online" || gUnitStatus == "Charging") {
                        gUnitPowerState = TRUE;
                    } else {
                        gUnitPowerState = FALSE;
                    }
                    
                    updateStationDisplay();
                    broadcastUnitData();
                }
                return;
            }
            else if (command == "MODULE_LIST_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    gUnitModules = llCSV2List(llList2String(parts, 1));
                    gUnitActiveModules = llCSV2List(llList2String(parts, 2));
                    
                    // Broadcast to station modules
                    string moduleData = llList2CSV(gUnitModules) + "|" + llList2CSV(gUnitActiveModules);
                    llMessageLinked(LINK_SET, STATION_UPDATE_DATA, "MODULES|" + moduleData, NULL_KEY);
                }
                return;
            }
            else if (command == "PERMISSION_LIST_RESPONSE") {
                if (llGetListLength(parts) >= 4) {
                    gUnitAdministrators = llCSV2List(llList2String(parts, 1));
                    gUnitTrustedUsers = llCSV2List(llList2String(parts, 2));
                    gWearerAdminMode = (integer)llList2String(parts, 3);
                    
                    // Broadcast to station modules
                    string permData = llList2CSV(gUnitAdministrators) + "|" + llList2CSV(gUnitTrustedUsers) + "|" + (string)gWearerAdminMode;
                    llMessageLinked(LINK_SET, STATION_UPDATE_DATA, "PERMISSIONS|" + permData, NULL_KEY);
                }
                return;
            }
            else if (command == "FULL_STATUS_RESPONSE") {
                // Handle comprehensive status response
                if (llGetListLength(parts) >= 6) {
                    gSyncedUnitName = llList2String(parts, 1);
                    gUnitBatteryLevel = (float)llList2String(parts, 2);
                    gUnitPersona = llList2String(parts, 3);
                    gUnitStatus = llList2String(parts, 4);
                    gUnitPowerState = (integer)llList2String(parts, 5);
                    
                    updateStationDisplay();
                    broadcastUnitData();
                }
                return;
            }
            return;
        }
        
        // Handle station menu interactions
        if (chan == gStationMenuChannel && gMainMenuOpen) {
            llListenRemove(gListenHandle);
            gMainMenuOpen = FALSE;
            
            if (msg == "Refresh") {
                requestUnitData();
                llInstantMessage(id, "Refreshing unit data...");
                llSleep(1.0);
                openMainMenu(id);
            }
            else if (msg == "Disconnect") {
                // Disconnect from unit and notify modules
                string oldName = gSyncedUnitName;
                gSyncedUnitKey = NULL_KEY;
                gSyncedUnitName = "";
                gUnitBatteryLevel = 0.0;
                gUnitPersona = "Unknown";
                gUnitStatus = "Offline";
                gUnitPowerState = FALSE;
                
                // Clear cached data
                gUnitModules = [];
                gUnitActiveModules = [];
                gUnitAdministrators = [];
                gUnitTrustedUsers = [];
                
                // Notify modules
                llMessageLinked(LINK_SET, STATION_UNIT_SYNC, "DISCONNECT", NULL_KEY);
                
                updateStationDisplay();
                llInstantMessage(id, "Disconnected from " + oldName);
            }
            else if (msg == "More...") {
                // Handle additional modules if more than 9
                llInstantMessage(id, "Additional modules menu not implemented yet.");
                openMainMenu(id);
            }
            else {
                // Check if it's a registered module
                string selectedModule = msg;
                
                // Find full module name
                integer i;
                for (i = 0; i < llGetListLength(gRegisteredModules); i++) {
                    string moduleName = llList2String(gRegisteredModules, i);
                    if (llSubStringIndex(moduleName, selectedModule) == 0) {
                        // Found the module, tell it to open its menu
                        llMessageLinked(LINK_SET, STATION_OPEN_MENU, (string)id + "|" + moduleName, NULL_KEY);
                        return;
                    }
                }
                
                llInstantMessage(id, "Module not found: " + selectedModule);
                openMainMenu(id);
            }
        }
    }

    timer() {
        llListenRemove(gListenHandle);
        gMainMenuOpen = FALSE;
        
        // Request regular status updates from synced unit
        if (gSyncedUnitKey != NULL_KEY) {
            requestUnitData();
            llSetTimerEvent(15.0); // Check every 15 seconds
        } else {
            llSetTimerEvent(30.0); // Less frequent when not synced
        }
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            llOwnerSay("Station inventory changed. Modules may need to refresh.");
            // Notify modules of inventory change
            llMessageLinked(LINK_SET, STATION_UPDATE_DATA, "INVENTORY_CHANGED", NULL_KEY);
        }
        if (change & CHANGED_LINK) {
            llOwnerSay("Station link set changed. Rescanning modules...");
            // Reset module list and let them re-register
            gRegisteredModules = [];
            gActiveModules = [];
        }
    }
}
