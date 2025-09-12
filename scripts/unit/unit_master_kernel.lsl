//-- A.R.I.A. Main Module (The "Operating System" Kernel)
//-- Version 11.0 - SIMPLIFIED PERMISSIONS SYSTEM - FIXED FUNCTION ORDER
//-- September 11, 2025 - Complete rewrite with simplified access control
//-- CHANGES v11.0: Simplified permissions hierarchy, removed hovertext,
//                   added Owner_HUD and Wearer_HUD communication channels
//-- FIX: All functions properly ordered to resolve LSL scope issues

// --- COMMUNICATION CHANNELS ---
integer gStationLinkChannel = -18795462;    // Programming station communication
integer gOwnerHudChannel = -18795463;       // NEW: Owner HUD communication
integer gWearerHudChannel = -18795464;      // NEW: Wearer HUD communication
integer menu_channel;

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

// --- USER MANAGEMENT SIMPLIFIED ---
key gPrimaryAdmin;          // Primary Admin - full control
list gAdministrators;       // Regular Admins - full access except permissions
list gTrustedUsers;         // Trusted - limited access
key wearer;                 // Wearer - conditional access
integer gWearerAccess = TRUE; // TRUE = wearer has access, FALSE = wearer blocked

// --- CORE SYSTEM STATES ---
string gUnitName = "A.R.I.A.";
string gHomeLandmark = "http://maps.secondlife.com/secondlife/Hippo%20Hollow/128/128/2";
integer gPowerState = TRUE;
integer gIsSecure = FALSE;
key gPendingSyncProgrammer;
key gSyncedOwnerHudKey;     // NEW: Synced Owner HUD
key gSyncedWearerHudKey;    // NEW: Synced Wearer HUD
string gCurrentPersona = "Default";
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

// --- MENU STATES ---
integer MENU_STATE_NONE = 0;
integer MENU_STATE_SET_HOME = 1;
integer MENU_STATE_MAIN_MENU = 2;
integer MENU_STATE_MODULES_MENU = 3;
integer gMenuState = 0;

// --- MENU PAGINATION ---
integer gCurrentMenuPage = 0;
key gCurrentMenuUser;
list gCurrentMenuButtons;

// --- SIMPLIFIED ACCESS LEVELS ---
integer ACCESS_PRIMARY_ADMIN = 5;  // Primary Admin - everything
integer ACCESS_ADMIN = 4;          // Regular Admin - everything except permissions
integer ACCESS_TRUSTED = 3;        // Trusted - modules only
integer ACCESS_WEARER = 2;         // Wearer - basic functions (if enabled)
integer ACCESS_DENIED = 1;         // No access

// --- SIMPLIFIED ACCESS CONTROL ---
integer getAccessLevel(key id) {
    // Primary Admin gets highest access
    if (id == gPrimaryAdmin) {
        return ACCESS_PRIMARY_ADMIN;
    }
    
    // Regular Admins get full access (except permissions module)
    if (llListFindList(gAdministrators, [id]) != -1) {
        return ACCESS_ADMIN;
    }
    
    // Trusted users get limited access
    if (llListFindList(gTrustedUsers, [id]) != -1) {
        return ACCESS_TRUSTED;
    }
    
    // Wearer gets conditional access
    if (id == wearer) {
        if (gWearerAccess) {
            return ACCESS_WEARER;
        } else {
            return ACCESS_DENIED;
        }
    }
    
    // Everyone else denied
    return ACCESS_DENIED;
}

// Check if someone can access permissions module (most restricted)
integer canAccessPermissions(key id) {
    integer access = getAccessLevel(id);
    // Only Primary Admin, Admins, and Wearer can access permissions
    return (access >= ACCESS_ADMIN || (id == wearer && gWearerAccess));
}

// --- HELPER FUNCTIONS ---
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

// Broadcast configuration to all modules
broadcastConfig() {
    string admin_csv = llList2CSV(gAdministrators);
    string trusted_csv = llList2CSV(gTrustedUsers);
    string config_string = admin_csv + "|" + trusted_csv + "|" + (string)gWearerAccess;
    llMessageLinked(LINK_SET, UPDATE_CONFIG, config_string, NULL_KEY);
    llMessageLinked(LINK_SET, UPDATE_UNIT_INFO, gUnitName, NULL_KEY);
}

// Build paginated main menu
buildMainMenu(key user, integer page) {
    gCurrentMenuUser = user;
    gCurrentMenuPage = page;
    gMenuState = MENU_STATE_MAIN_MENU;
    
    integer access = getAccessLevel(user);
    
    if (access < ACCESS_WEARER) {
        llInstantMessage(user, "Access denied. Insufficient permissions.");
        return;
    }
    
    // Build dialog header
    gMainMenuDialog = "\n[ A.R.I.A. MAIN MENU ]\n";
    gMainMenuDialog += "Unit: " + gUnitName + "\n";
    gMainMenuDialog += "Access: ";
    
    if (access == ACCESS_PRIMARY_ADMIN) {
        gMainMenuDialog += "PRIMARY ADMIN\n";
    } else if (access == ACCESS_ADMIN) {
        gMainMenuDialog += "ADMINISTRATOR\n";
    } else if (access == ACCESS_TRUSTED) {
        gMainMenuDialog += "TRUSTED\n";
    } else {
        gMainMenuDialog += "WEARER\n";
    }
    
    // Show admin info
    string adminText = llKey2Name(gPrimaryAdmin);
    if (adminText == "") adminText = "Unknown User";
    gMainMenuDialog += "Admin: " + adminText + "\n";
    gMainMenuDialog += "Power: " + (string)((integer)gBatteryLevel) + "%";
    
    // Build all available buttons based on access level
    gCurrentMenuButtons = [];
    
    if (access >= ACCESS_ADMIN) {
        gCurrentMenuButtons += ["MODULES", "HOME", "Set Home", "SOS"];
        if (gIsSecure) {
            gCurrentMenuButtons += ["[UNLOCK]"];
        } else {
            gCurrentMenuButtons += ["[SECURE]"];
        }
        gCurrentMenuButtons += ["POWER OFF"];
    } else if (access >= ACCESS_TRUSTED) {
        gCurrentMenuButtons += ["MODULES", "HOME", "SOS"];
    } else {
        gCurrentMenuButtons += ["HOME", "SOS"];
    }
    
    // Calculate pagination
    integer totalButtons = llGetListLength(gCurrentMenuButtons);
    integer maxButtonsPerPage = 9; // Leave room for navigation
    integer totalPages = (totalButtons + maxButtonsPerPage - 1) / maxButtonsPerPage; // Ceiling division
    
    if (page >= totalPages) page = totalPages - 1;
    if (page < 0) page = 0;
    gCurrentMenuPage = page;
    
    // Get buttons for current page
    integer startIndex = page * maxButtonsPerPage;
    integer endIndex = startIndex + maxButtonsPerPage - 1;
    if (endIndex >= totalButtons) endIndex = totalButtons - 1;
    
    list pageButtons = [];
    integer i;
    for (i = startIndex; i <= endIndex && i < totalButtons; i++) {
        pageButtons += [llList2String(gCurrentMenuButtons, i)];
    }
    
    // Add navigation buttons
    if (totalPages > 1) {
        gMainMenuDialog += "\n\nPage " + (string)(page + 1) + " of " + (string)totalPages;
        
        if (page > 0) {
            pageButtons += ["< BACK"];
        }
        if (page < totalPages - 1) {
            pageButtons += ["NEXT >"];
        }
    }
    
    pageButtons += ["CLOSE"];
    
    open_menu(user, gMainMenuDialog, pageButtons);
}

// Build paginated modules menu
buildModulesMenu(key user, integer page) {
    gCurrentMenuUser = user;
    gCurrentMenuPage = page;
    gMenuState = MENU_STATE_MODULES_MENU;
    
    integer access = getAccessLevel(user);
    
    if (access < ACCESS_TRUSTED) {
        llInstantMessage(user, "Access denied. Trusted access required for modules.");
        return;
    }
    
    string dialog = "\n[ MODULES MENU ]\n";
    dialog += "Select a module to configure:\n";
    
    // Build all available module buttons
    gCurrentMenuButtons = [];
    
    // Add active modules
    integer moduleCount = llGetListLength(gActiveModules);
    integer i;
    for (i = 0; i < moduleCount; i++) {
        string moduleName = llList2String(gActiveModules, i);
        gCurrentMenuButtons += [moduleName];
    }
    
    // Add standard modules
    gCurrentMenuButtons += ["Persona", "SPEECH MODE"];
    
    // Add permissions if user has access
    if (canAccessPermissions(user)) {
        gCurrentMenuButtons += ["Permissions"];
    }
    
    // Calculate pagination
    integer totalButtons = llGetListLength(gCurrentMenuButtons);
    integer maxButtonsPerPage = 9; // Leave room for navigation
    integer totalPages = (totalButtons + maxButtonsPerPage - 1) / maxButtonsPerPage;
    
    if (page >= totalPages) page = totalPages - 1;
    if (page < 0) page = 0;
    gCurrentMenuPage = page;
    
    // Get buttons for current page
    integer startIndex = page * maxButtonsPerPage;
    integer endIndex = startIndex + maxButtonsPerPage - 1;
    if (endIndex >= totalButtons) endIndex = totalButtons - 1;
    
    list pageButtons = [];
    for (i = startIndex; i <= endIndex && i < totalButtons; i++) {
        pageButtons += [llList2String(gCurrentMenuButtons, i)];
    }
    
    // Add navigation buttons
    if (totalPages > 1) {
        dialog += "\nPage " + (string)(page + 1) + " of " + (string)totalPages;
        
        if (page > 0) {
            pageButtons += ["< BACK"];
        }
        if (page < totalPages - 1) {
            pageButtons += ["NEXT >"];
        }
    }
    
    pageButtons += ["-Main-"];
    
    open_menu(user, dialog, pageButtons);
}

// Load installation data from object description
loadInstallData() {
    string desc = llGetObjectDesc();
    if (desc != "" && llSubStringIndex(desc, "INSTALLED:") == 0) {
        list parts = llParseString2List(desc, [":"], []);
        if (llGetListLength(parts) >= 2) {
            gInstallTimestamp = (integer)llList2String(parts, 1);
            gInstallDate = convertTimestampToDate(gInstallTimestamp);
        }
    }
}

// Save installation data to object description
saveInstallData() {
    if (gInstallTimestamp > 0) {
        llSetObjectDesc("INSTALLED:" + (string)gInstallTimestamp);
    }
}

// Convert timestamp to readable date
string convertTimestampToDate(integer timestamp) {
    if (timestamp <= 0) return "Unknown";
    
    list months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    integer days_since_epoch = timestamp / 86400;
    integer year = 1970;
    integer month = 1;
    integer day = 1;
    
    // Simple date calculation (not perfect but adequate)
    year += (days_since_epoch / 365);
    month += ((days_since_epoch % 365) / 30);
    day += ((days_since_epoch % 365) % 30);
    
    if (month > 12) {
        year += (month - 1) / 12;
        month = ((month - 1) % 12) + 1;
    }
    
    return (string)day + " " + llList2String(months, month - 1) + " " + (string)year;
}

// Handle menu commands
handleMenuCommand(key user, string command) {
    integer access = getAccessLevel(user);
    
    // Handle navigation commands
    if (command == "< BACK") {
        if (gMenuState == MENU_STATE_MAIN_MENU) {
            buildMainMenu(user, gCurrentMenuPage - 1);
        } else if (gMenuState == MENU_STATE_MODULES_MENU) {
            buildModulesMenu(user, gCurrentMenuPage - 1);
        }
        return;
    }
    else if (command == "NEXT >") {
        if (gMenuState == MENU_STATE_MAIN_MENU) {
            buildMainMenu(user, gCurrentMenuPage + 1);
        } else if (gMenuState == MENU_STATE_MODULES_MENU) {
            buildModulesMenu(user, gCurrentMenuPage + 1);
        }
        return;
    }
    else if (command == "-Main-") {
        buildMainMenu(user, 0);
        return;
    }
    else if (command == "CLOSE") {
        gMenuState = MENU_STATE_NONE;
        llInstantMessage(user, "Menu closed.");
        return;
    }
    
    // Handle functional commands
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
        buildModulesMenu(user, 0);
        return;
    } 
    else if (llListFindList(gActiveModules, [command]) != -1 || command == "Persona" || command == "SPEECH MODE") {
        llMessageLinked(LINK_SET, OPEN_MY_MENU, (string)user, NULL_KEY);
    }
    else if (command == "Permissions") {
        if (canAccessPermissions(user)) {
            llMessageLinked(LINK_SET, OPEN_MY_MENU, (string)user, NULL_KEY);
        } else {
            llInstantMessage(user, "Access denied. Insufficient permissions for Permission module.");
        }
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
        
        // Initialize admin list with Primary Admin
        gAdministrators = [gPrimaryAdmin];
        
        menu_channel = (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
        gRegisteredModules = [];
        gActiveModules = [];
        
        llSetTimerEvent(60.0);
        llListen(gStationLinkChannel, "", NULL_KEY, "");
        llListen(gOwnerHudChannel, "", NULL_KEY, "");      // NEW: Owner HUD listener
        llListen(gWearerHudChannel, "", NULL_KEY, "");     // NEW: Wearer HUD listener
        
        loadInstallData();
        
        string accessStatus = "ENABLED";
        if (!gWearerAccess) accessStatus = "DISABLED";
        llOwnerSay("A.R.I.A. Main Module v11.0 initialized. Wearer Access: " + accessStatus);
        broadcastConfig();
    }

    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        
        // Handle sync confirmation
        if (gPendingSyncProgrammer == toucher && getAccessLevel(toucher) >= ACCESS_ADMIN) {
            llRegionSay(gStationLinkChannel, "SYNC_SUCCESS|" + (string)llGetKey() + "|" + gUnitName);
            gPendingSyncProgrammer = NULL_KEY;
            llSetTimerEvent(60.0);
            llInstantMessage(toucher, "Sync with Programming Station successful.");
            return;
        }
        
        // Check if unit is powered off
        if (!gPowerState && getAccessLevel(toucher) >= ACCESS_ADMIN) {
            open_menu(toucher, "\nUnit is OFFLINE.\nOnly Administrators can power on the unit.", ["POWER ON"]);
            return;
        }
        
        // Check access and build appropriate menu
        integer access = getAccessLevel(toucher);
        
        if (access < ACCESS_WEARER) {
            llInstantMessage(toucher, "Access denied. Insufficient permissions.");
            return;
        }
        
        // Open paginated main menu
        buildMainMenu(toucher, 0);
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == MODULE_REGISTER) {
            if (llListFindList(gRegisteredModules, [msg]) == -1) {
                gRegisteredModules += [msg];
                gActiveModules += [msg];
                llOwnerSay("Module registered: " + msg);
            }
        } 
        else if (num == UPDATE_PERSONA_STATUS) {
            gCurrentPersona = msg;
        }
        else if (num == UPDATE_USER_LISTS) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 3) {
                string admin_csv = llList2String(parts, 0);
                string trusted_csv = llList2String(parts, 1);
                gWearerAccess = (integer)llList2String(parts, 2);
                
                if (admin_csv != "") gAdministrators = llCSV2List(admin_csv);
                if (trusted_csv != "") gTrustedUsers = llCSV2List(trusted_csv);
                
                // Ensure Primary Admin is always in admin list
                if (llListFindList(gAdministrators, [gPrimaryAdmin]) == -1) {
                    gAdministrators = [gPrimaryAdmin] + gAdministrators;
                }
                
                broadcastConfig();
            }
        }
        else if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            
            // Send battery updates to HUDs
            if (gSyncedOwnerHudKey != NULL_KEY) {
                llRegionSayTo(gSyncedOwnerHudKey, gOwnerHudChannel, "BATTERY_UPDATE|" + (string)gBatteryLevel);
            }
            if (gSyncedWearerHudKey != NULL_KEY) {
                llRegionSayTo(gSyncedWearerHudKey, gWearerHudChannel, "BATTERY_UPDATE|" + (string)gBatteryLevel);
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle programming station communication
        if (chan == gStationLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "SYNC_REQUEST") {
                gPendingSyncProgrammer = (key)llList2String(parts, 1);
                llSetTimerEvent(30.0);
                llInstantMessage(gPendingSyncProgrammer, "SYNC REQUESTED: Please touch the " + gUnitName + " unit to confirm the link.");
            } 
            else if (command == "OWNER_HUD_SYNC_REQUEST") {
                gSyncedOwnerHudKey = id;
                llRegionSay(gStationLinkChannel, "HUD_SYNC_SUCCESS|" + (string)llGetKey() + "|" + (string)llList2String(parts, 1));
                llOwnerSay("Owner HUD synced: " + llKey2Name((key)llList2String(parts, 1)));
            } 
            else if (command == "WEARER_HUD_SYNC_REQUEST" && (key)llList2String(parts, 1) == wearer) {
                gSyncedWearerHudKey = id;
                llRegionSay(gStationLinkChannel, "HUD_SYNC_SUCCESS|" + (string)llGetKey() + "|" + (string)llList2String(parts, 1));
                llOwnerSay("Wearer HUD synced: " + llKey2Name(wearer));
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
        
        // NEW: Handle Owner HUD communication
        if (chan == gOwnerHudChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "OWNER_HUD_COMMAND") {
                key sender = (key)llList2String(parts, 1);
                string hudCommand = llList2String(parts, 2);
                
                // Only process if sender has admin access
                if (getAccessLevel(sender) >= ACCESS_ADMIN) {
                    handleMenuCommand(sender, hudCommand);
                }
            }
            else if (command == "REQUEST_STATUS") {
                // Send status to Owner HUD
                string statusData = "STATUS_RESPONSE|" + gUnitName + "|" + (string)gBatteryLevel + "|" + 
                                  gCurrentPersona + "|" + (string)gPowerState + "|" + (string)gIsSecure;
                llRegionSayTo(id, gOwnerHudChannel, statusData);
            }
            return;
        }
        
        // NEW: Handle Wearer HUD communication  
        if (chan == gWearerHudChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "WEARER_HUD_COMMAND") {
                key sender = (key)llList2String(parts, 1);
                string hudCommand = llList2String(parts, 2);
                
                // Only process if sender is wearer and has access
                if (sender == wearer && getAccessLevel(sender) >= ACCESS_WEARER) {
                    handleMenuCommand(sender, hudCommand);
                }
            }
            else if (command == "REQUEST_STATUS" && (key)llList2String(parts, 1) == wearer) {
                // Send status to Wearer HUD
                string statusData = "STATUS_RESPONSE|" + gUnitName + "|" + (string)gBatteryLevel + "|" + 
                                  gCurrentPersona + "|" + (string)gPowerState + "|" + (string)gWearerAccess;
                llRegionSayTo(id, gWearerHudChannel, statusData);
            }
            return;
        }
        
        // Handle menu responses
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
                    llInstantMessage(id, "Invalid SLURL format. Please use a valid Second Life location URL.");
                }
                
                gMenuState = MENU_STATE_NONE;
                return;
            }
            
            handleMenuCommand(id, msg);
        }
    }

    timer() {
        if (gPendingSyncProgrammer != NULL_KEY) {
            gPendingSyncProgrammer = NULL_KEY;
            return;
        }
        
        if (gPowerState && !gIsCharging) {
            gBatteryLevel -= gBatteryDrainRate;
            if (gBatteryLevel < 0.0) gBatteryLevel = 0.0;
            
            if (gBatteryLevel <= 5.0) {
                gPowerState = FALSE;
                llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "OFF", NULL_KEY);
                llOwnerSay("// CRITICAL: Battery depleted. Systems shutting down. //");
                llSetTimerEvent(0.0);
                return;
            }
        } else if (gIsCharging && gBatteryLevel < 100.0) {
            gBatteryLevel += gBatteryChargeRate;
            if (gBatteryLevel > 100.0) gBatteryLevel = 100.0;
        }
        
        // Broadcast battery updates
        llMessageLinked(LINK_SET, UPDATE_BATTERY, (string)gBatteryLevel, NULL_KEY);
        
        // Send periodic status to synced HUDs
        if (gSyncedOwnerHudKey != NULL_KEY) {
            string statusData = "STATUS_BROADCAST|" + gUnitName + "|" + (string)gBatteryLevel + "|" + 
                              gCurrentPersona + "|" + (string)gPowerState;
            llRegionSayTo(gSyncedOwnerHudKey, gOwnerHudChannel, statusData);
        }
        
        if (gSyncedWearerHudKey != NULL_KEY) {
            string statusData = "STATUS_BROADCAST|" + gUnitName + "|" + (string)gBatteryLevel + "|" + 
                              gCurrentPersona + "|" + (string)gWearerAccess;
            llRegionSayTo(gSyncedWearerHudKey, gWearerHudChannel, statusData);
        }
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
