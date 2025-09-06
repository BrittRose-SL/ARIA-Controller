//-- A.R.I.A. Programming & Configuration Station
//-- Version 3.0 - COMPLETE MANAGEMENT INTERFACE
//-- CHANGELOG: 
//--   - Added persona installation from station inventory to controller
//--   - Added permission management interface
//--   - Added battery charging functionality
//--   - Added comprehensive status reporting
//--   - Added module activation/deactivation
//--   - Fixed communication protocol to match controller modules
//--   - Added error handling and validation
//--   - Added comprehensive feature set for station management

// --- CONFIGURATION ---
integer gLinkChannel = -18795462; // Must match main_module
integer gMenuChannel = -99887; // Separate channel for station menus
float gChargeRate = 2.0; // Battery charge rate per timer cycle

// --- STATE VARIABLES ---
key gProgrammerKey;
key gSyncedUnitKey;
string gSyncedUnitName;
float gUnitBatteryLevel = 0.0;
string gUnitPersona = "Unknown";
string gUnitStatus = "Unknown";
integer gIsCharging = FALSE;

//-- Cached data from synced unit
list gRegisteredModules = [];
list gActiveModules = [];
list gAdministrators = [];
list gTrustedUsers = [];

// --- MENU & DIALOG VARIABLES ---
integer gListenHandle;
integer gTextBoxHandle;
integer gMenuState = 0; // 0=main, 1=modules, 2=personas, 3=permissions, 4=status

// --- MENU STATES ---
integer MENU_MAIN = 0;
integer MENU_MODULES = 1;
integer MENU_PERSONAS = 2;
integer MENU_PERMISSIONS = 3;
integer MENU_STATUS = 4;
integer MENU_CHARGING = 5;
integer MENU_ADD_ADMIN = 6;
integer MENU_ADD_TRUSTED = 7;

// --- HELPER FUNCTIONS ---
updateStationDisplay() {
    string display = "A.R.I.A. PROGRAMMING STATION\n";
    
    if (gSyncedUnitKey == NULL_KEY) {
        display += "Status: READY FOR SYNC\nTouch to begin programming\nThen touch target A.R.I.A. unit";
        llSetText(display, <1.0, 1.0, 0.0>, 1.0);
    } else {
        display += "Unit: " + gSyncedUnitName + "\n";
        display += "Battery: " + (string)((integer)gUnitBatteryLevel) + "%\n";
        display += "Persona: " + gUnitPersona + "\n";
        display += "Status: " + gUnitStatus;
        
        if (gIsCharging) {
            display += "\nCHARGING ACTIVE";
            llSetText(display, <0.0, 1.0, 0.0>, 1.0);
        } else {
            llSetText(display, <0.2, 0.8, 1.0>, 1.0);
        }
    }
}

open_menu(key id, string dialog, list buttons) {
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", id, "");
    llDialog(id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

request_input(key id, string prompt) {
    llListenRemove(gTextBoxHandle);
    gTextBoxHandle = llListen(gMenuChannel, "", id, "");
    llTextBox(id, prompt, gMenuChannel);
    llSetTimerEvent(60.0);
}

openMainMenu(key id) {
    gMenuState = MENU_MAIN;
    string dialog = "\n[ A.R.I.A. PROGRAMMING STATION ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Battery: " + (string)((integer)gUnitBatteryLevel) + "%\n";
    dialog += "Status: " + gUnitStatus + "\n\n";
    dialog += "Select operation:";
    
    list buttons = ["Modules", "Personas", "Permissions"];
    buttons += ["Status Report", "Charging", "Disconnect"];
    
    open_menu(id, dialog, buttons);
}

openModulesMenu(key id) {
    gMenuState = MENU_MODULES;
    string dialog = "\n[ MODULE MANAGEMENT ]\n";
    dialog += "Registered: " + (string)llGetListLength(gRegisteredModules) + "\n";
    dialog += "Active: " + (string)llGetListLength(gActiveModules) + "\n\n";
    dialog += "Click module to toggle state:";
    
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(gRegisteredModules) && i < 9; i++) {
        string moduleName = llList2String(gRegisteredModules, i);
        string status = "OFF";
        if (llListFindList(gActiveModules, [moduleName]) != -1) {
            status = "ON";
        }
        
        // Truncate long module names for buttons
        string buttonText = moduleName;
        if (llStringLength(buttonText) > 10) {
            buttonText = llGetSubString(buttonText, 0, 9);
        }
        buttons += [buttonText + ":" + status];
    }
    
    buttons += ["Refresh", "-Back-"];
    open_menu(id, dialog, buttons);
}

openPersonasMenu(key id) {
    gMenuState = MENU_PERSONAS;
    string dialog = "\n[ PERSONA MANAGEMENT ]\n";
    dialog += "Current: " + gUnitPersona + "\n\n";
    dialog += "Available personas in station:";
    
    list buttons = [];
    integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer i;
    integer found = 0;
    
    for (i = 0; i < count; i++) {
        string cardName = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llSubStringIndex(cardName, "Persona_") == 0) {
            string personaName = llGetSubString(cardName, 8, -1); // Remove "Persona_" prefix
            buttons += [personaName];
            found++;
            if (found >= 9) break; // Limit to 9 personas for dialog
        }
    }
    
    if (found == 0) {
        dialog += "\nNo persona notecards found!";
        buttons += ["No Personas"];
    }
    
    buttons += ["Scan Unit", "-Back-"];
    open_menu(id, dialog, buttons);
}

openPermissionsMenu(key id) {
    gMenuState = MENU_PERMISSIONS;
    string dialog = "\n[ PERMISSION MANAGEMENT ]\n";
    dialog += "Administrators: " + (string)llGetListLength(gAdministrators) + "\n";
    dialog += "Trusted Users: " + (string)llGetListLength(gTrustedUsers) + "\n\n";
    dialog += "Select operation:";
    
    list buttons = ["Add Admin", "Add Trusted", "Remove Admin"];
    buttons += ["Remove Trusted", "Show Lists", "Sync Perms"];
    buttons += ["Wearer Mode", "-Back-"];
    
    open_menu(id, dialog, buttons);
}

openStatusMenu(key id) {
    gMenuState = MENU_STATUS;
    string dialog = "\n[ UNIT STATUS REPORT ]\n";
    dialog += "═══════════════════════\n";
    dialog += "Unit Name: " + gSyncedUnitName + "\n";
    dialog += "Battery Level: " + (string)((integer)gUnitBatteryLevel) + "%\n";
    dialog += "Current Persona: " + gUnitPersona + "\n";
    dialog += "Power Status: " + gUnitStatus + "\n";
    dialog += "Registered Modules: " + (string)llGetListLength(gRegisteredModules) + "\n";
    dialog += "Active Modules: " + (string)llGetListLength(gActiveModules) + "\n";
    dialog += "Administrators: " + (string)llGetListLength(gAdministrators) + "\n";
    dialog += "Trusted Users: " + (string)llGetListLength(gTrustedUsers) + "\n";
    
    list buttons = ["Refresh", "Module List", "User Lists"];
    buttons += ["Power ON", "Power OFF", "-Back-"];
    
    open_menu(id, dialog, buttons);
}

openChargingMenu(key id) {
    gMenuState = MENU_CHARGING;
    string dialog = "\n[ CHARGING STATION ]\n";
    dialog += "Unit Battery: " + (string)((integer)gUnitBatteryLevel) + "%\n";
    dialog += "Charge Rate: " + (string)gChargeRate + "%/min\n";
    dialog += "Status: ";
    
    if (gIsCharging) {
        dialog += "CHARGING ACTIVE";
    } else {
        dialog += "STANDBY";
    }
    
    list buttons = [];
    if (gIsCharging) {
        buttons += ["Stop Charging"];
    } else {
        buttons += ["Start Charging"];
    }
    
    buttons += ["Emergency Charge", "Set Rate", "-Back-"];
    open_menu(id, dialog, buttons);
}

installPersona(string personaName, key user) {
    string notecardName = "Persona_" + personaName;
    
    if (llGetInventoryType(notecardName) != INVENTORY_NOTECARD) {
        llInstantMessage(user, "ERROR: Persona notecard '" + notecardName + "' not found in station inventory.");
        return;
    }
    
    // Send persona installation command to unit
    string command = "INSTALL_PERSONA|" + personaName + "|" + (string)user;
    llRegionSay(gLinkChannel, command);
    
    // Give the notecard to the unit
    llGiveInventory(gSyncedUnitKey, notecardName);
    
    llInstantMessage(user, "Installing persona '" + personaName + "' to " + gSyncedUnitName + "...");
    llSay(0, "Transferring persona data: " + personaName);
}

toggleModule(string moduleButton, key user) {
    // Parse module name from button (format: "ModuleName:ON/OFF")
    list parts = llParseString2List(moduleButton, [":"], []);
    if (llGetListLength(parts) != 2) return;
    
    string moduleName = llList2String(parts, 0);
    string currentStatus = llList2String(parts, 1);
    
    // Find full module name from registered list
    string fullModuleName = "";
    integer i;
    for (i = 0; i < llGetListLength(gRegisteredModules); i++) {
        string regModule = llList2String(gRegisteredModules, i);
        if (llSubStringIndex(regModule, moduleName) == 0) {
            fullModuleName = regModule;
            break;
        }
    }
    
    if (fullModuleName == "") {
        llInstantMessage(user, "Module not found: " + moduleName);
        return;
    }
    
    string action = "activate";
    if (currentStatus == "ON") action = "deactivate";
    
    string command = "TOGGLE_MODULE|" + fullModuleName + "|" + action + "|" + (string)user;
    llRegionSay(gLinkChannel, command);
    
    llInstantMessage(user, "Toggling module: " + fullModuleName);
}

// --- MAIN LOGIC ---
default {
    state_entry() {
        llListen(gLinkChannel, "", NULL_KEY, "");
        updateStationDisplay();
        llSetTimerEvent(10.0); // Regular status updates
        llOwnerSay("A.R.I.A. Programming Station v3.0 initialized.");
    }

    touch_start(integer num) {
        key toucher = llDetectedKey(0);
        gProgrammerKey = toucher;
        
        if (gSyncedUnitKey == NULL_KEY) {
            llInstantMessage(toucher, "Initiating sync protocol...");
            llSay(0, "Broadcasting sync request...");
            updateStationDisplay();
            llRegionSay(gLinkChannel, "SYNC_REQUEST|" + (string)toucher);
            llSetTimerEvent(30.0); // Timeout for sync
        } else {
            openMainMenu(toucher);
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle responses from A.R.I.A. unit
        if (chan == gLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                updateStationDisplay();
                llInstantMessage(gProgrammerKey, "Sync successful with " + gSyncedUnitName);
                llSay(0, "Unit synchronized: " + gSyncedUnitName);
                
                // Request initial status
                llRegionSay(gLinkChannel, "REQUEST_STATUS|" + (string)gProgrammerKey);
                llSetTimerEvent(10.0);
                return;
            }
            else if (command == "STATUS_BROADCAST") {
                // Parse: STATUS_BROADCAST|unitname|battery|persona|status
                if (llGetListLength(parts) >= 5) {
                    gSyncedUnitName = llList2String(parts, 1);
                    gUnitBatteryLevel = (float)llList2String(parts, 2);
                    gUnitPersona = llList2String(parts, 3);
                    gUnitStatus = llList2String(parts, 4);
                    updateStationDisplay();
                }
                return;
            }
            else if (command == "MODULE_LIST_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    gRegisteredModules = llCSV2List(llList2String(parts, 1));
                    gActiveModules = llCSV2List(llList2String(parts, 2));
                    llInstantMessage(gProgrammerKey, "Module data updated.");
                }
                return;
            }
            else if (command == "PERMISSION_LIST_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    gAdministrators = llCSV2List(llList2String(parts, 1));
                    gTrustedUsers = llCSV2List(llList2String(parts, 2));
                    llInstantMessage(gProgrammerKey, "Permission data updated.");
                }
                return;
            }
            return;
        }
        
        // Handle menu interactions
        if (chan == gMenuChannel) {
            llListenRemove(gListenHandle);
            llListenRemove(gTextBoxHandle);
            
            if (msg == "-Back-") {
                openMainMenu(id);
                return;
            }
            
            // Main menu handlers
            if (gMenuState == MENU_MAIN) {
                if (msg == "Modules") {
                    llRegionSay(gLinkChannel, "REQUEST_MODULE_LIST|" + (string)id);
                    llSleep(0.5);
                    openModulesMenu(id);
                }
                else if (msg == "Personas") {
                    openPersonasMenu(id);
                }
                else if (msg == "Permissions") {
                    llRegionSay(gLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)id);
                    llSleep(0.5);
                    openPermissionsMenu(id);
                }
                else if (msg == "Status Report") {
                    openStatusMenu(id);
                }
                else if (msg == "Charging") {
                    openChargingMenu(id);
                }
                else if (msg == "Disconnect") {
                    if (gIsCharging) {
                        llRegionSay(gLinkChannel, "CHARGE_STOP|" + (string)gSyncedUnitKey);
                        gIsCharging = FALSE;
                    }
                    gSyncedUnitKey = NULL_KEY;
                    gSyncedUnitName = "";
                    updateStationDisplay();
                    llInstantMessage(id, "Unit disconnected.");
                }
            }
            // Module menu handlers
            else if (gMenuState == MENU_MODULES) {
                if (msg == "Refresh") {
                    llRegionSay(gLinkChannel, "REQUEST_MODULE_LIST|" + (string)id);
                    llSleep(0.5);
                    openModulesMenu(id);
                }
                else if (llSubStringIndex(msg, ":") != -1) {
                    toggleModule(msg, id);
                    llSleep(1.0);
                    llRegionSay(gLinkChannel, "REQUEST_MODULE_LIST|" + (string)id);
                    llSleep(0.5);
                    openModulesMenu(id);
                }
            }
            // Persona menu handlers
            else if (gMenuState == MENU_PERSONAS) {
                if (msg == "Scan Unit") {
                    llRegionSay(gLinkChannel, "REQUEST_PERSONA_LIST|" + (string)id);
                    llInstantMessage(id, "Scanning unit for personas...");
                    openPersonasMenu(id);
                }
                else if (msg != "No Personas") {
                    installPersona(msg, id);
                    openPersonasMenu(id);
                }
            }
            // Permissions menu handlers
            else if (gMenuState == MENU_PERMISSIONS) {
                if (msg == "Add Admin") {
                    gMenuState = MENU_ADD_ADMIN;
                    request_input(id, "Enter the name or UUID of the user to add as Administrator:");
                }
                else if (msg == "Add Trusted") {
                    gMenuState = MENU_ADD_TRUSTED;
                    request_input(id, "Enter the name or UUID of the user to add as Trusted:");
                }
                else if (msg == "Show Lists") {
                    string report = "ADMINISTRATORS:\n";
                    integer i;
                    for (i = 0; i < llGetListLength(gAdministrators); i++) {
                        report += "• " + llKey2Name((key)llList2String(gAdministrators, i)) + "\n";
                    }
                    report += "\nTRUSTED USERS:\n";
                    for (i = 0; i < llGetListLength(gTrustedUsers); i++) {
                        report += "• " + llKey2Name((key)llList2String(gTrustedUsers, i)) + "\n";
                    }
                    llInstantMessage(id, report);
                    openPermissionsMenu(id);
                }
                else if (msg == "Wearer Mode") {
                    llRegionSay(gLinkChannel, "TOGGLE_WEARER_MODE|" + (string)id);
                    llInstantMessage(id, "Toggling wearer admin mode...");
                    openPermissionsMenu(id);
                }
                else if (msg == "Sync Perms") {
                    llRegionSay(gLinkChannel, "REQUEST_PERMISSION_LIST|" + (string)id);
                    llInstantMessage(id, "Syncing permission data...");
                    openPermissionsMenu(id);
                }
            }
            // Status menu handlers
            else if (gMenuState == MENU_STATUS) {
                if (msg == "Refresh") {
                    llRegionSay(gLinkChannel, "REQUEST_STATUS|" + (string)id);
                    llInstantMessage(id, "Refreshing status data...");
                    openStatusMenu(id);
                }
                else if (msg == "Power ON") {
                    llRegionSay(gLinkChannel, "REMOTE_COMMAND|" + (string)id + "|POWER ON");
                    llInstantMessage(id, "Sending power on command...");
                    openStatusMenu(id);
                }
                else if (msg == "Power OFF") {
                    llRegionSay(gLinkChannel, "REMOTE_COMMAND|" + (string)id + "|POWER OFF");
                    llInstantMessage(id, "Sending power off command...");
                    openStatusMenu(id);
                }
                else if (msg == "Module List") {
                    string report = "REGISTERED MODULES:\n";
                    integer i;
                    for (i = 0; i < llGetListLength(gRegisteredModules); i++) {
                        string module = llList2String(gRegisteredModules, i);
                        string status = " (INACTIVE)";
                        if (llListFindList(gActiveModules, [module]) != -1) {
                            status = " (ACTIVE)";
                        }
                        report += "• " + module + status + "\n";
                    }
                    llInstantMessage(id, report);
                    openStatusMenu(id);
                }
                else if (msg == "User Lists") {
                    string report = "ADMINISTRATORS (" + (string)llGetListLength(gAdministrators) + "):\n";
                    integer i;
                    for (i = 0; i < llGetListLength(gAdministrators) && i < 5; i++) {
                        report += "• " + llKey2Name((key)llList2String(gAdministrators, i)) + "\n";
                    }
                    if (llGetListLength(gAdministrators) > 5) {
                        report += "... and " + (string)(llGetListLength(gAdministrators) - 5) + " more\n";
                    }
                    report += "\nTRUSTED USERS (" + (string)llGetListLength(gTrustedUsers) + "):\n";
                    for (i = 0; i < llGetListLength(gTrustedUsers) && i < 5; i++) {
                        report += "• " + llKey2Name((key)llList2String(gTrustedUsers, i)) + "\n";
                    }
                    if (llGetListLength(gTrustedUsers) > 5) {
                        report += "... and " + (string)(llGetListLength(gTrustedUsers) - 5) + " more";
                    }
                    llInstantMessage(id, report);
                    openStatusMenu(id);
                }
            }
            // Charging menu handlers
            else if (gMenuState == MENU_CHARGING) {
                if (msg == "Start Charging") {
                    gIsCharging = TRUE;
                    llRegionSay(gLinkChannel, "CHARGE_START|" + (string)gSyncedUnitKey);
                    llInstantMessage(id, "Charging started.");
                    updateStationDisplay();
                    openChargingMenu(id);
                }
                else if (msg == "Stop Charging") {
                    gIsCharging = FALSE;
                    llRegionSay(gLinkChannel, "CHARGE_STOP|" + (string)gSyncedUnitKey);
                    llInstantMessage(id, "Charging stopped.");
                    updateStationDisplay();
                    openChargingMenu(id);
                }
                else if (msg == "Emergency Charge") {
                    gIsCharging = TRUE;
                    gChargeRate = 5.0; // Fast charge
                    llRegionSay(gLinkChannel, "CHARGE_START|" + (string)gSyncedUnitKey);
                    llInstantMessage(id, "Emergency fast charging activated!");
                    updateStationDisplay();
                    openChargingMenu(id);
                }
                else if (msg == "Set Rate") {
                    request_input(id, "Enter new charge rate (0.1 to 10.0 percent per minute):");
                }
            }
            // Handle text input for user addition
            else if (gMenuState == MENU_ADD_ADMIN) {
                string command = "ADD_ADMINISTRATOR|" + msg + "|" + (string)id;
                llRegionSay(gLinkChannel, command);
                llInstantMessage(id, "Adding administrator: " + msg);
                gMenuState = MENU_PERMISSIONS;
                openPermissionsMenu(id);
            }
            else if (gMenuState == MENU_ADD_TRUSTED) {
                string command = "ADD_TRUSTED|" + msg + "|" + (string)id;
                llRegionSay(gLinkChannel, command);
                llInstantMessage(id, "Adding trusted user: " + msg);
                gMenuState = MENU_PERMISSIONS;
                openPermissionsMenu(id);
            }
            else {
                // Handle charge rate setting - check if this is a numeric input for charge rate
                float testRate = (float)msg;
                if (testRate > 0.0 || msg == "0") {
                    if (testRate >= 0.1 && testRate <= 10.0) {
                        gChargeRate = testRate;
                        llInstantMessage(id, "Charge rate set to " + (string)testRate + "%/min");
                    } else {
                        llInstantMessage(id, "Invalid rate. Must be between 0.1 and 10.0");
                    }
                    openChargingMenu(id);
                }
            }
        }
    }

    timer() {
        if (gSyncedUnitKey == NULL_KEY) {
            // Timeout sync request
            llSetTimerEvent(10.0);
            return;
        }
        
        // Request status update from synced unit
        llRegionSay(gLinkChannel, "REQUEST_STATUS|" + (string)gProgrammerKey);
        
        // Handle charging
        if (gIsCharging && gUnitBatteryLevel < 100.0) {
            // Charging is handled by the main module, we just track state
            updateStationDisplay();
        }
        
        llSetTimerEvent(10.0); // Regular updates every 10 seconds
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            llOwnerSay("Station inventory updated. Persona list refreshed.");
        }
    }
}
