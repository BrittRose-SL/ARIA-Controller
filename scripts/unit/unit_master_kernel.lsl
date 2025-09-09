//-- A.R.I.A. Main Module (The "Operating System" Kernel)
//-- Version 10.6 - FIXED SYNTAX ERROR & MENU OVERFLOW & ADDED DIRECT ACCESS
//-- Added centralized hover text management with persona data integration and emoji support
//-- CHANGELOG v10.6: Fixed syntax error - moved function definitions outside state block
//-- CHANGELOG v10.5: Fixed button overflow, moved Permissions and Diagnostics to main menu, added paging support

// --- USER LISTS & CHANNELS ---
list gAdministrators;
list gTrustedUsers;
integer menu_channel;
integer gStationLinkChannel = -18795462;

// --- LINKED MESSAGE CODES ---
integer SET_SPEECH_MODE = 100;
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer UPDATE_UNIT_INFO = 103;
integer UPDATE_PERSONA_STATUS = 104;
integer UPDATE_USER_LISTS = 105;
integer UPDATE_WEARER_ADMIN_MODE = 106;
integer UPDATE_HOVER_DATA = 107;      
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- UNIT & USER VARIABLES ---
key gPrimaryAdmin;
key wearer;
string gUnitName = "A.R.I.A.";

// --- CORE SYSTEM STATES ---
string gHomeLandmark = "http://maps.secondlife.com/secondlife/Hippo%20Hollow/128/128/2";
integer gPowerState = TRUE;
integer gIsSecure = FALSE;
key gPendingSyncProgrammer;
key gSyncedAdminHudKey;
key gSyncedWearerHudKey;
string gCurrentPersona = "Default";
integer gWearerAdminMode = TRUE;
string gInstallDate = "";
integer gInstallTimestamp = 0;

// --- BATTERY & POWER SYSTEM ---
float gBatteryLevel = 100.0;
float gBatteryDrainRate = 0.1;
float gBatteryChargeRate = 1.0;
integer gIsCharging = FALSE;

// --- MODULE MANAGEMENT ---
list gRegisteredModules;
list gActiveModules;
integer gCurrentModulePage = 0; // For paging through modules
integer gModulesPerPage = 7; // Max modules per page (leaving room for nav buttons)

// --- HOVER TEXT MANAGEMENT ---
string gPersonaName = "Default";
string gPersonaTone = "standard";
integer gArousalLevel = 0;
integer gStimulationLevel = 0;
integer gPainLevel = 0;
integer gStressLevel = 0;

// --- MENU DIALOGS & VARIABLES ---
string gMainMenuDialog;
integer gDialogHandle;
integer gTextBoxHandle;
list base_SubMenu_Modules_Buttons = ["SPEECH MODE", "Close", "-Main-"];

// --- MENU STATES ---
integer MENU_STATE_NONE = 0;
integer MENU_STATE_SET_HOME = 1;
integer gMenuState = 0;

// --- PERMISSION LEVELS ---
integer ACCESS_ADMIN = 4;
integer ACCESS_TRUSTED = 3;
integer ACCESS_WEARER = 2;
integer ACCESS_PUBLIC = 1;

// --- HELPER FUNCTIONS ---
updateHoverText() {
    string status = "🤖 A.R.I.A. " + gPersonaName;
    
    // Battery indicator with emoji
    if (gBatteryLevel >= 75.0) {
        status += " 🔋";
    } else if (gBatteryLevel >= 50.0) {
        status += " 🔄";
    } else if (gBatteryLevel >= 25.0) {
        status += " ⚡";
    } else {
        status += " 🪫";
    }
    
    // Power state indicator
    if (!gPowerState) {
        status += " 💤";
    } else if (gIsCharging) {
        status += " ⚡";
    }
    
    // Security status
    if (gIsSecure) {
        status += " 🔒";
    }
    
    status += "\nBattery: " + (string)((integer)gBatteryLevel) + "%";
    
    // Persona tone indicator
    if (gPersonaTone != "standard") {
        status += " | Tone: " + gPersonaTone;
    }
    
    // Add indicators for arousal/stimulation levels if applicable
    if (gArousalLevel > 0 || gStimulationLevel > 0) {
        status += " | A:" + (string)gArousalLevel + " S:" + (string)gStimulationLevel;
    }
    
    vector textColor = <0.8, 0.9, 1.0>; // Light blue default
    
    if (!gPowerState) {
        textColor = <0.5, 0.5, 0.5>; // Gray when offline
    } else if (gBatteryLevel <= 15.0) {
        textColor = <1.0, 0.3, 0.3>; // Red when low battery
    } else if (gIsCharging) {
        textColor = <0.3, 1.0, 0.3>; // Green when charging
    }
    
    llSetText(status, textColor, 1.0);
    
    // Send hover data to modules
    string hoverData = gPersonaName + "|" + gPersonaTone + "|" + (string)gArousalLevel + "|" + (string)gStimulationLevel + "|" + (string)gPainLevel + "|" + (string)gStressLevel;
    llMessageLinked(LINK_SET, UPDATE_HOVER_DATA, hoverData, NULL_KEY);
}

saveInstallData() {
    // Save install timestamp for persistence
    llOwnerSay("@setenv_install_timestamp:" + (string)gInstallTimestamp + "=force");
}

string convertTimestampToDate(integer timestamp) {
    if (timestamp <= 0) return "Unknown";
    
    list months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    string dateStr = llGetDate();
    
    return dateStr;
}

integer getAccessLevel(key id) {
    if (llListFindList(gAdministrators, [id]) != -1) return ACCESS_ADMIN;
    if (llListFindList(gTrustedUsers, [id]) != -1) return ACCESS_TRUSTED;
    
    if (id == wearer) {
        if (gWearerAdminMode) {
            return ACCESS_ADMIN;
        } else {
            return ACCESS_WEARER;
        }
    }
    
    return ACCESS_PUBLIC;
}

open_menu(key id, string str, list btns) {
    llListenRemove(gDialogHandle);
    gDialogHandle = llListen(menu_channel, "", id, "");
    llDialog(id, str, btns, menu_channel);
    llSetTimerEvent(30.0);
}

open_textbox(key id, string prompt) {
    llListenRemove(gTextBoxHandle);
    gTextBoxHandle = llListen(menu_channel, "", id, "");
    llTextBox(id, prompt, menu_channel);
    llSetTimerEvent(60.0);
}

broadcastConfig() {
    string admin_csv = llList2CSV(gAdministrators);
    string trusted_csv = llList2CSV(gTrustedUsers);
    string config_string = admin_csv + "|" + trusted_csv;
    llMessageLinked(LINK_SET, UPDATE_CONFIG, config_string, NULL_KEY);
    llMessageLinked(LINK_SET, UPDATE_UNIT_INFO, gUnitName, NULL_KEY);
    llMessageLinked(LINK_SET, UPDATE_WEARER_ADMIN_MODE, (string)gWearerAdminMode, NULL_KEY);
}

openModulesMenu(key user, integer page) {
    integer access = getAccessLevel(user);
    if (access < ACCESS_TRUSTED) {
        llInstantMessage(user, "Access denied. Trusted user or Administrator permissions required.");
        return;
    }
    
    // Filter out PERMISSIONS and DIAGNOSTICS from module list (they're in main menu now)
    list filteredModules = [];
    integer i;
    for (i = 0; i < llGetListLength(gActiveModules); i++) {
        string moduleName = llList2String(gActiveModules, i);
        if (moduleName != "Permissions" && moduleName != "Diagnostics") {
            filteredModules += [moduleName];
        }
    }
    
    gCurrentModulePage = page;
    integer totalModules = llGetListLength(filteredModules);
    integer startIndex = page * gModulesPerPage;
    integer endIndex = startIndex + gModulesPerPage - 1;
    if (endIndex >= totalModules) endIndex = totalModules - 1;
    
    string dialog = "\n[ OTHER MODULES ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Unit: " + gUnitName + "\n";
    dialog += "Page " + (string)(page + 1) + " of " + (string)(((totalModules - 1) / gModulesPerPage) + 1) + "\n";
    dialog += "Showing " + (string)(startIndex + 1) + "-" + (string)(endIndex + 1) + " of " + (string)totalModules + " modules\n\n";
    dialog += "Select module:";
    
    list buttons = [];
    
    // Add modules for current page
    for (i = startIndex; i <= endIndex && i < totalModules; i++) {
        string moduleName = llList2String(filteredModules, i);
        // Truncate long module names for buttons
        if (llStringLength(moduleName) > 12) {
            moduleName = llGetSubString(moduleName, 0, 11);
        }
        buttons += [moduleName];
    }
    
    // Add SPEECH MODE if we have room
    if (llGetListLength(buttons) < gModulesPerPage) {
        buttons += ["SPEECH MODE"];
    }
    
    // Add navigation buttons
    if (page > 0) {
        buttons += ["<< Prev"];
    }
    if (endIndex < totalModules - 1) {
        buttons += ["Next >>"];
    }
    
    buttons += ["Close", "-Main-"]; // Return to main menu
    
    open_menu(user, dialog, buttons);
}

// Send status updates to synced wearer HUD
sendWearerHudStatus() {
    if (gSyncedWearerHudKey == NULL_KEY) return;
    
    string primaryAdminName = "Unknown";
    if (llGetListLength(gAdministrators) > 0) {
        primaryAdminName = llKey2Name(gPrimaryAdmin);
        if (primaryAdminName == "") primaryAdminName = "Unknown Admin";
    }
    
    string statusData = "WEARER_HUD_STATUS_UPDATE|" + (string)llGetKey() + "|" +
                       (string)gBatteryLevel + "|" +
                       gPersonaName + "|" +
                       gPersonaTone + "|" +
                       primaryAdminName + "|" +
                       (string)gIsSecure + "|" +
                       (string)gPowerState + "|" +
                       (string)gWearerAdminMode + "|" +
                       gInstallDate;
    
    llRegionSay(gStationLinkChannel, statusData);
}

// Send module information to synced wearer HUD
sendWearerHudModules() {
    if (gSyncedWearerHudKey == NULL_KEY) return;
    
    string moduleData = "WEARER_HUD_MODULE_UPDATE|" + (string)llGetKey() + "|" +
                       llList2CSV(gRegisteredModules) + "|" +
                       llList2CSV(gActiveModules);
    
    llRegionSay(gStationLinkChannel, moduleData);
}

handleMenuCommand(key user, string command) {
    integer access = getAccessLevel(user);
    integer i;
    integer moduleCount;
    string dialog;
    list dynamicModuleButtons;
    string moduleName;
    list buttons;
    
    if (command == "POWER ON" && access >= ACCESS_ADMIN) {
        gPowerState = TRUE;
        llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "ON", NULL_KEY);
        llSetTimerEvent(60.0);
        updateHoverText();
        llInstantMessage(user, "A.R.I.A. systems online.");
    } 
    else if (command == "POWER OFF" && access >= ACCESS_ADMIN) {
        if (gBatteryLevel < 5.0) { 
            llInstantMessage(user, "Cannot power off. Battery level is below 5%."); 
            return; 
        }
        gPowerState = FALSE;
        llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "OFF", NULL_KEY);
        llSetTimerEvent(0.0);
        updateHoverText();
        llInstantMessage(user, "A.R.I.A. systems shutting down.");
    } 
    else if (command == "SOS" && access >= ACCESS_WEARER) { 
        llInstantMessage(gPrimaryAdmin, "SOS signal received from " + gUnitName + "!");
        llInstantMessage(wearer, "SOS signal sent to Primary Administrator.");
    } 
    else if (command == "HOME" && access >= ACCESS_WEARER) {
        llOwnerSay("@tplm:" + gHomeLandmark + "=force");
        llInstantMessage(user, "Teleporting to home location...");
    }
    else if (command == "Set Home" && access >= ACCESS_ADMIN) {
        gMenuState = MENU_STATE_SET_HOME;
        open_textbox(user, "\nEnter the new home SLURL:\n\nExample:\nhttp://maps.secondlife.com/secondlife/Region%20Name/128/128/22\n\nCurrent home:\n" + gHomeLandmark);
    }
    else if (command == "[SECURE]" && access >= ACCESS_ADMIN) {
        gIsSecure = TRUE;
        
        if (gInstallTimestamp < 1) {
            gInstallTimestamp = llGetUnixTime();
            gInstallDate = convertTimestampToDate(gInstallTimestamp);
            saveInstallData();
            llOwnerSay("Unit installation recorded: " + gInstallDate);
        }
        
        llOwnerSay("@detach=n");
        llInstantMessage(user, "Unit attachment lock: SECURED.");
        llInstantMessage(wearer, "// Attachment lock engaged. //");
    } 
    else if (command == "[UNLOCK]" && access >= ACCESS_ADMIN) {
        gIsSecure = FALSE;
        llOwnerSay("@detach=y");
        llInstantMessage(user, "Unit attachment lock: UNLOCKED.");
        llInstantMessage(wearer, "// Attachment lock disengaged. //");
    } 
    else if (command == "PERMISSIONS" && access >= ACCESS_ADMIN) {
        // Direct access to permissions module
        llMessageLinked(LINK_SET, OPEN_MY_MENU, (string)user, NULL_KEY);
        // Find and tell permissions module specifically
        integer permIndex = llListFindList(gActiveModules, ["Permissions"]);
        if (permIndex != -1) {
            llMessageLinked(LINK_SET, OPEN_MY_MENU, (string)user, NULL_KEY);
        } else {
            llInstantMessage(user, "Permissions module not found or inactive.");
        }
    }
    else if (command == "DIAGNOSTICS" && access >= ACCESS_TRUSTED) {
        // Direct access to diagnostics module
        integer diagIndex = llListFindList(gActiveModules, ["Diagnostics"]);
        if (diagIndex != -1) {
            llMessageLinked(LINK_SET, OPEN_MY_MENU, (string)user, NULL_KEY);
        } else {
            llInstantMessage(user, "Diagnostics module not found or inactive.");
        }
    }
    else if (command == "MODULES" && access >= ACCESS_TRUSTED) {
        // Open modules menu with paging
        openModulesMenu(user, 0);
    } 
    else if (command == "<< Prev") {
        if (gCurrentModulePage > 0) {
            openModulesMenu(user, gCurrentModulePage - 1);
        }
    }
    else if (command == "Next >>") {
        openModulesMenu(user, gCurrentModulePage + 1);
    }
    else if (command == "-Main-") {
        // Return to main menu - handled by touch event
        return;
    }
    else if (command == "Close") {
        llInstantMessage(user, "Menu closed.");
        return;
    }
    else if (llListFindList(gActiveModules, [command]) != -1 || command == "Persona" || command == "SPEECH MODE") {
        llMessageLinked(LINK_SET, OPEN_MY_MENU, (string)user, NULL_KEY);
    }
    else if (access < ACCESS_WEARER) {
        llInstantMessage(user, "Access denied. Insufficient permissions.");
    }
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        wearer = llGetOwner();
        gPrimaryAdmin = llGetOwner();
        menu_channel = -1000 - (integer)("0x" + llGetSubString((string)wearer, -7, -1));
        
        gInstallTimestamp = 0;
        gInstallDate = "";
        gCurrentModulePage = 0;
        
        llSetTimerEvent(60.0);
        updateHoverText();
        broadcastConfig();
        
        llOwnerSay("A.R.I.A. Unit Master Kernel v10.6 initialized.");
        llOwnerSay("CHANGELOG v10.6: Fixed syntax error - moved function definitions outside state block");
    }

    touch_start(integer num) {
        key toucher = llDetectedKey(0);
        integer access = getAccessLevel(toucher);
        list buttons;
        
        if (gPendingSyncProgrammer != NULL_KEY && toucher == wearer) {
            llRegionSay(gStationLinkChannel, "SYNC_SUCCESS|" + (string)llGetKey() + "|" + gUnitName);
            llInstantMessage(gPendingSyncProgrammer, "Sync with " + gUnitName + " confirmed!");
            llInstantMessage(wearer, "Programming station sync confirmed.");
            gPendingSyncProgrammer = NULL_KEY;
            return;
        }
        
        if (!gPowerState && getAccessLevel(toucher) >= ACCESS_ADMIN) {
            open_menu(toucher, "\nUnit is OFFLINE.", ["POWER ON"]);
            return;
        }
        if (!gPowerState) return;

        access = getAccessLevel(toucher);
        if (access < ACCESS_WEARER) return;

        gMainMenuDialog = "\nUnit Name: " + gUnitName + "\n";
        
        if (gInstallTimestamp > 0) {
            gMainMenuDialog += "Install Date: " + gInstallDate + "\n";
        } else {
            gMainMenuDialog += "Install Date: \n";
        }
        
        // Enhanced age calculation with more precision
        string ageText = "0 days";
        if (gInstallTimestamp > 0) {
            integer currentTime = llGetUnixTime();
            integer ageSeconds = currentTime - gInstallTimestamp;
            integer ageDays = ageSeconds / 86400;
            integer ageHours = (ageSeconds % 86400) / 3600;
            integer ageMinutes = (ageSeconds % 3600) / 60;
            
            if (ageDays > 0) {
                ageText = (string)ageDays + " day";
                if (ageDays != 1) ageText += "s";
                
                if (ageHours > 0 && ageDays < 7) {
                    ageText += ", " + (string)ageHours + " hour";
                    if (ageHours != 1) ageText += "s";
                }
            } else if (ageHours > 0) {
                ageText = (string)ageHours + " hour";
                if (ageHours != 1) ageText += "s";
                
                if (ageMinutes > 0) {
                    ageText += ", " + (string)ageMinutes + " minute";
                    if (ageMinutes != 1) ageText += "s";
                }
            } else if (ageMinutes > 0) {
                ageText = (string)ageMinutes + " minute";
                if (ageMinutes != 1) ageText += "s";
            } else {
                ageText = "Less than 1 minute";
            }
        }
        gMainMenuDialog += "Unit Age: " + ageText + "\n";
        
        // Enhanced admin display logic inline
        string adminText = "";
        integer adminCount = llGetListLength(gAdministrators);
        
        if (adminCount == 0) {
            adminText = "Unknown";
        } else if (adminCount == 1) {
            string adminName = llKey2Name(llList2Key(gAdministrators, 0));
            if (adminName == "") adminName = "Unknown User";
            
            if (llList2Key(gAdministrators, 0) == gPrimaryAdmin) {
                adminText = adminName + " (Primary)";
            } else {
                adminText = adminName;
            }
        } else {
            string primaryName = llKey2Name(gPrimaryAdmin);
            if (primaryName == "") primaryName = "Unknown User";
            
            integer otherAdmins = adminCount - 1;
            adminText = primaryName + " (Primary)";
            if (otherAdmins == 1) {
                adminText += " +1 other";
            } else {
                adminText += " +" + (string)otherAdmins + " others";
            }
        }
        
        gMainMenuDialog += "Admin: " + adminText + "\n";
        
        gMainMenuDialog += "Power: " + (string)((integer)gBatteryLevel) + "%";
        
        if (toucher == wearer) {
            if (gWearerAdminMode) {
                gMainMenuDialog += "\nWearer Mode: ADMIN";
            } else {
                gMainMenuDialog += "\nWearer Mode: LIMITED";
            }
        }
        
        if (access >= ACCESS_ADMIN) {
            buttons = ["PERMISSIONS", "DIAGNOSTICS", "MODULES", "HOME", "Set Home", "SOS"];
            if (gIsSecure) {
                buttons += ["[UNLOCK]"];
            } else {
                buttons += ["[SECURE]"];
            }
            buttons += ["POWER OFF"];
        } else if (access >= ACCESS_TRUSTED) {
            buttons = ["DIAGNOSTICS", "MODULES", "HOME", "SOS"];
        } else {
            buttons = ["HOME", "SOS"];
        }
        
        open_menu(toucher, gMainMenuDialog, buttons);
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == MODULE_REGISTER) {
            if (llListFindList(gRegisteredModules, [msg]) == -1) {
                gRegisteredModules += [msg];
                gActiveModules += [msg];
                llOwnerSay("Module registered: " + msg);
            }
        } 
        else if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            updateHoverText();
        } 
        else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gAdministrators = llCSV2List(llList2String(parts, 0));
                gTrustedUsers = llCSV2List(llList2String(parts, 1));
            }
        } 
        else if (num == UPDATE_UNIT_INFO) {
            gUnitName = msg;
            updateHoverText();
        } 
        else if (num == UPDATE_PERSONA_STATUS) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gPersonaName = llList2String(parts, 0);
                gPersonaTone = llList2String(parts, 1);
                updateHoverText();
            }
        } 
        else if (num == UPDATE_USER_LISTS) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gAdministrators = llCSV2List(llList2String(parts, 0));
                gTrustedUsers = llCSV2List(llList2String(parts, 1));
                broadcastConfig();
            }
        } 
        else if (num == UPDATE_WEARER_ADMIN_MODE) {
            gWearerAdminMode = (integer)msg;
            llOwnerSay("Wearer admin mode: " + (string)gWearerAdminMode);
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan == gStationLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "SYNC_REQUEST") {
                gPendingSyncProgrammer = (key)llList2String(parts, 1);
                llSetTimerEvent(30.0);
                llInstantMessage(gPendingSyncProgrammer, "SYNC REQUESTED: Please touch the " + gUnitName + " unit to confirm the link.");
            } 
            else if (command == "HUD_SYNC_REQUEST") {
                gSyncedAdminHudKey = id;
                llRegionSay(gStationLinkChannel, "HUD_SYNC_SUCCESS|" + (string)llGetKey() + "|" + (string)llList2String(parts, 1));
            } 
            else if (command == "WEARER_HUD_SYNC_REQUEST" && (key)llList2String(parts, 1) == wearer) {
                gSyncedWearerHudKey = id;
                llRegionSay(gStationLinkChannel, "HUD_SYNC_SUCCESS|" + (string)llGetKey() + "|" + (string)llList2String(parts, 1));
                llOwnerSay("Wearer HUD connected: " + llKey2Name(id));
            } 
            else if (command == "WEARER_HUD_STATUS_REQUEST" && (key)llList2String(parts, 1) == llGetKey() && (key)llList2String(parts, 2) == wearer) {
                // Send comprehensive status to wearer HUD
                sendWearerHudStatus();
            }
            else if (command == "WEARER_HUD_FULL_SYNC" && (key)llList2String(parts, 1) == llGetKey() && (key)llList2String(parts, 2) == wearer) {
                // Send full sync data to wearer HUD
                sendWearerHudStatus();
                sendWearerHudModules();
            }
            else if (command == "CHARGE_START" && (key)llList2String(parts, 1) == llGetKey()) {
                gIsCharging = TRUE;
            } 
            else if (command == "CHARGE_STOP" && (key)llList2String(parts, 1) == llGetKey()) {
                gIsCharging = FALSE;
            } 
            else if (command == "REMOTE_COMMAND") {
                handleMenuCommand((key)llList2String(parts, 1), llList2String(parts, 2));
            }
            return;
        }
        
        if (chan == menu_channel) {
            llListenRemove(gDialogHandle);
            llListenRemove(gTextBoxHandle);
            
            if (gMenuState == MENU_STATE_SET_HOME) {
                string input = llStringTrim(msg, STRING_TRIM);
                
                if (llSubStringIndex(input, "http://maps.secondlife.com/") == 0 || 
                    llSubStringIndex(input, "https://maps.secondlife.com/") == 0) {
                    
                    gHomeLandmark = input;
                    llInstantMessage(id, "Home landmark updated successfully to:\n" + gHomeLandmark);
                    llOwnerSay("Home landmark changed by " + llKey2Name(id) + " to: " + gHomeLandmark);
                } else {
                    llInstantMessage(id, "Invalid SLURL format. Please use the format:\nhttp://maps.secondlife.com/secondlife/Region%20Name/128/128/22");
                }
                
                gMenuState = MENU_STATE_NONE;
                return;
            }
            
            handleMenuCommand(id, msg);
        }
    }

    timer() {
        if (gPendingSyncProgrammer != NULL_KEY) {
            llInstantMessage(gPendingSyncProgrammer, "Sync request timed out.");
            gPendingSyncProgrammer = NULL_KEY;
        }
        
        if (gPowerState) {
            // Battery management
            if (gIsCharging) {
                gBatteryLevel += gBatteryChargeRate;
                if (gBatteryLevel > 100.0) gBatteryLevel = 100.0;
            } else {
                gBatteryLevel -= gBatteryDrainRate;
                if (gBatteryLevel < 0.0) gBatteryLevel = 0.0;
            }
            
            // Low battery warning
            if (gBatteryLevel <= 10.0 && gBatteryLevel > 9.0) {
                llInstantMessage(wearer, "// WARNING: Battery level critical (" + (string)((integer)gBatteryLevel) + "%) //");
                llInstantMessage(gPrimaryAdmin, "Unit " + gUnitName + " battery critical: " + (string)((integer)gBatteryLevel) + "%");
            }
            
            // Auto-shutdown on critical battery
            if (gBatteryLevel <= 1.0) {
                gPowerState = FALSE;
                llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "OFF", NULL_KEY);
                llInstantMessage(wearer, "// UNIT SHUTDOWN: Battery depleted //");
                llInstantMessage(gPrimaryAdmin, "Unit " + gUnitName + " auto-shutdown due to battery depletion.");
                llSetTimerEvent(0.0);
            }
            
            updateHoverText();
            llMessageLinked(LINK_SET, UPDATE_BATTERY, (string)gBatteryLevel, NULL_KEY);
            
            // Send status updates to synced wearer HUD
            if (gSyncedWearerHudKey != NULL_KEY) {
                sendWearerHudStatus();
            }
        }
        
        if (gPowerState) {
            llSetTimerEvent(60.0);
        }
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
        if (change & CHANGED_LINK) {
            llOwnerSay("Link set changed. Modules may need to re-register.");
            // Reset module lists and let them re-register
            gRegisteredModules = [];
            gActiveModules = [];
        }
    }
}
