//-- A.R.I.A. Main Module (The "Operating System" Kernel)
//-- Version 10.3 - WEARER ADMIN MODE + DATA PERSISTENCE + ACCURATE DATES
//-- Added support for configurable wearer admin privileges, persistent install data, and accurate date conversion

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
string convertTimestampToDate(integer timestamp) {
    if (timestamp < 1) return "";
    
    integer daysSinceEpoch = timestamp / 86400;
    integer year = 1970;
    integer remainingDays = daysSinceEpoch;
    
    while (remainingDays >= 365) {
        integer daysInYear = 365;
        if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
            daysInYear = 366;
        }
        
        if (remainingDays >= daysInYear) {
            remainingDays -= daysInYear;
            year++;
        } else {
            jump done;
        }
    }
    @done;
    
    list monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    
    if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
        monthDays = llListReplaceList(monthDays, [29], 1, 1);
    }
    
    integer month = 1;
    while (remainingDays >= llList2Integer(monthDays, month - 1) && month <= 12) {
        remainingDays -= llList2Integer(monthDays, month - 1);
        month++;
    }
    
    integer day = remainingDays + 1;
    
    string yearStr = (string)year;
    string monthStr = (string)month;
    string dayStr = (string)day;
    
    if (month < 10) monthStr = "0" + monthStr;
    if (day < 10) dayStr = "0" + dayStr;
    
    return yearStr + "-" + monthStr + "-" + dayStr;
}

saveInstallData() {
    if (gInstallTimestamp > 0) {
        string currentDesc = llGetObjectDesc();
        string installData = "INSTALL:" + gInstallDate + ":" + (string)gInstallTimestamp;
        
        if (llSubStringIndex(currentDesc, "INSTALL:") != -1) {
            list descParts = llParseString2List(currentDesc, ["|"], []);
            integer i;
            list newDescParts = [];
            for (i = 0; i < llGetListLength(descParts); i++) {
                string part = llList2String(descParts, i);
                if (llSubStringIndex(part, "INSTALL:") == -1) {
                    newDescParts += [part];
                }
            }
            newDescParts += [installData];
            string newDesc = llDumpList2String(newDescParts, "|");
            llSetObjectDesc(newDesc);
        } else {
            if (currentDesc == "") {
                llSetObjectDesc(installData);
            } else {
                llSetObjectDesc(currentDesc + "|" + installData);
            }
        }
    }
}

loadInstallData() {
    string desc = llGetObjectDesc();
    if (llSubStringIndex(desc, "INSTALL:") != -1) {
        list descParts = llParseString2List(desc, ["|"], []);
        integer i;
        integer found = FALSE;
        for (i = 0; i < llGetListLength(descParts) && !found; i++) {
            string part = llList2String(descParts, i);
            if (llSubStringIndex(part, "INSTALL:") == 0) {
                list installParts = llParseString2List(part, [":"], []);
                if (llGetListLength(installParts) >= 3) {
                    gInstallDate = llList2String(installParts, 1);
                    gInstallTimestamp = (integer)llList2String(installParts, 2);
                    integer ageInDays = (llGetUnixTime() - gInstallTimestamp) / 86400;
                    llOwnerSay("Install data loaded: " + gInstallDate + " (Age: " + (string)ageInDays + " days)");
                }
                found = TRUE;
            }
        }
    }
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
    else if (command == "MODULES" && access >= ACCESS_TRUSTED) {
        dialog = "\n[ MODULES ]\nSelect a module to configure.";
        dynamicModuleButtons = base_SubMenu_Modules_Buttons;
        
        moduleCount = llGetListLength(gActiveModules);
        for (i = 0; i < moduleCount; i++) {
            moduleName = llList2String(gActiveModules, i);
            dynamicModuleButtons = [moduleName] + dynamicModuleButtons;
        }
        open_menu(user, dialog, dynamicModuleButtons);
    } 
    else if (llListFindList(gActiveModules, [command]) != -1 || command == "Persona" || command == "SPEECH MODE" || command == "Permissions") {
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
        
        string desc = llGetObjectDesc();
        if (desc != "" && (key)desc != NULL_KEY) {
            gAdministrators = [(key)desc];
        } else {
            gAdministrators = [gPrimaryAdmin];
        }
        
        menu_channel = (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
        gRegisteredModules = [];
        gActiveModules = [];
        
        llSetTimerEvent(60.0);
        llListen(gStationLinkChannel, "", NULL_KEY, "");
        
        loadInstallData();
        
        string modeStatus = "ENABLED";
        if (!gWearerAdminMode) modeStatus = "DISABLED";
        llOwnerSay("A.R.I.A. Main Module v10.3 initialized. Wearer Admin Mode: " + modeStatus);
        broadcastConfig();
    }

    dataserver(key requested, string data) {
        // No longer needed - removed notecard functionality
    }

    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        integer access;
        list buttons;
        
        if (gPendingSyncProgrammer == toucher && getAccessLevel(toucher) >= ACCESS_ADMIN) {
            llRegionSay(gStationLinkChannel, "SYNC_SUCCESS|" + (string)llGetKey() + "|" + gUnitName);
            gPendingSyncProgrammer = NULL_KEY;
            llSetTimerEvent(60.0);
            llInstantMessage(toucher, "Sync with Programming Station successful.");
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
            buttons = ["MODULES", "HOME", "Set Home", "SOS"];
            if (gIsSecure) {
                buttons += ["[UNLOCK]"];
            } else {
                buttons += ["[SECURE]"];
            }
            buttons += ["POWER OFF"];
        } else if (access >= ACCESS_TRUSTED) {
            buttons = ["MODULES", "HOME", "SOS"];
        } else {
            buttons = ["HOME", "SOS"];
        }
        
        open_menu(toucher, gMainMenuDialog, buttons);
    }

    link_message(integer s, integer n, string m, key id) {
        if (n == MODULE_REGISTER) {
            if (llListFindList(gRegisteredModules, [m]) == -1) {
                gRegisteredModules += [m];
                gActiveModules += [m];
                llOwnerSay("Module registered: " + m);
            }
        } else if (n == UPDATE_PERSONA_STATUS) {
            gCurrentPersona = m;
        }
        else if (n == UPDATE_USER_LISTS) {
            list parts = llParseString2List(m, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string admin_csv = llList2String(parts, 0);
                string trusted_csv = llList2String(parts, 1);
                if (admin_csv != "") gAdministrators = llCSV2List(admin_csv);
                if (trusted_csv != "") gTrustedUsers = llCSV2List(trusted_csv);
                broadcastConfig();
            }
        }
        else if (n == UPDATE_WEARER_ADMIN_MODE) {
            gWearerAdminMode = (integer)m;
            string modeStatus = "DISABLED";
            if (gWearerAdminMode) modeStatus = "ENABLED";
            llOwnerSay("Wearer Admin Mode " + modeStatus + " by administrator.");
            
            if (!gWearerAdminMode) {
                llInstantMessage(wearer, "// Administrator privileges have been revoked. Access limited to basic functions. //");
            } else if (gWearerAdminMode) {
                llInstantMessage(wearer, "// Administrator privileges have been restored. //");
            }
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
            } else if (command == "HUD_SYNC_REQUEST") {
                gSyncedAdminHudKey = id;
                llRegionSay(gStationLinkChannel, "HUD_SYNC_SUCCESS|" + (string)llGetKey() + "|" + (string)llList2String(parts, 1));
            } else if (command == "WEARER_HUD_SYNC_REQUEST" && (key)llList2String(parts, 1) == wearer) {
                gSyncedWearerHudKey = id;
                llRegionSay(gStationLinkChannel, "HUD_SYNC_SUCCESS|" + (string)llGetKey() + "|" + (string)llList2String(parts, 1));
            } else if (command == "CHARGE_START" && (key)llList2String(parts, 1) == llGetKey()) {
                gIsCharging = TRUE;
            } else if (command == "CHARGE_STOP" && (key)llList2String(parts, 1) == llGetKey()) {
                gIsCharging = FALSE;
            } else if (command == "REMOTE_COMMAND") {
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
                    llInstantMessage(id, "Invalid SLURL format. Please enter a valid Second Life map URL starting with:\nhttp://maps.secondlife.com/");
                }
                
                gMenuState = MENU_STATE_NONE;
            } else {
                handleMenuCommand(id, msg);
            }
            return;
        }

        if (chan == 0 && id == llGetOwner()) {
            if (llGetSubString(msg, 0, 7) == "@version") { 
                llInstantMessage(gPrimaryAdmin, "RLV Version Report: " + llGetSubString(msg, 9, -1)); 
            }
            else if (llGetSubString(msg, 0, 11) == "@attachlist") { 
                llInstantMessage(gPrimaryAdmin, "Attachment List Report: " + llGetSubString(msg, 13, -1)); 
            }
        }
    }

    timer() {
        if (gPendingSyncProgrammer != NULL_KEY) {
            llInstantMessage(gPendingSyncProgrammer, "Sync request for " + gUnitName + " has timed out.");
            gPendingSyncProgrammer = NULL_KEY;
            llSetTimerEvent(60.0);
            return;
        }
        
        llListenRemove(gDialogHandle);
        llListenRemove(gTextBoxHandle);
        gMenuState = MENU_STATE_NONE;
        
        if (!gPowerState) return;
        
        if (gIsCharging && gBatteryLevel < 100.0) { 
            gBatteryLevel += gBatteryChargeRate; 
            if (gBatteryLevel > 100.0) gBatteryLevel = 100.0; 
        }
        else if (!gIsCharging && gBatteryLevel > 0.0) { 
            gBatteryLevel -= gBatteryDrainRate; 
        }
        
        if (gBatteryLevel <= 0.0 && gPowerState) { 
            gBatteryLevel = 0.0; 
            gPowerState = FALSE; 
            llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "OFF", NULL_KEY); 
            llSay(0, "CRITICAL POWER FAILURE. SYSTEM OFFLINE."); 
        }
        if (gBatteryLevel > 0.0 && !gPowerState) { 
            gPowerState = TRUE; 
            llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "ON", NULL_KEY); 
            llSay(0, "Minimum power level reached. Systems rebooting."); 
            broadcastConfig(); 
        }
        
        string status_string = "STATUS_BROADCAST|" + gUnitName + "|" + (string)gBatteryLevel + "|" + gCurrentPersona + "|";
        if (gPowerState) {
            status_string += "Online";
        } else {
            status_string += "Offline";
        }
        
        if (gSyncedAdminHudKey != NULL_KEY) { 
            llRegionSayTo(gSyncedAdminHudKey, gStationLinkChannel, status_string); 
        }
        if (gSyncedWearerHudKey != NULL_KEY) { 
            llRegionSayTo(gSyncedWearerHudKey, gStationLinkChannel, status_string); 
        }
        
        llMessageLinked(LINK_SET, UPDATE_BATTERY, (string)gBatteryLevel, NULL_KEY);
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
