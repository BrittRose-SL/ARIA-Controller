//-- A.R.I.A. Main Module (The "Operating System" Kernel)
//-- Version 12.1 - OPENCOLLAR AUTH INTEGRATION
//-- September 12, 2025 - Refactored to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v12.1:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//-- CHANGES v12.0: 
//--   - Removed synchronous getAccessLevel() function
//--   - Implemented asynchronous AUTH_REQUEST/AUTH_REPLY protocol
//--   - Added pending auth request management
//--   - Removed old permission variables and broadcasts
//--   - Streamlined touch_start and menu system
//--   - All permission checks now asynchronous

// --- COMMUNICATION CHANNELS ---
integer gStationLinkChannel = -18795462;    // Programming station communication
integer gOwnerHudChannel = -18795463;       // Owner HUD communication
integer gWearerHudChannel = -18795464;      // Wearer HUD communication
integer menu_channel;

// --- LINKED MESSAGE CODES ---
integer SET_SPEECH_MODE = 100;
integer UPDATE_BATTERY = 101;
integer UPDATE_UNIT_INFO = 103;
integer UPDATE_PERSONA_STATUS = 104;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- NEW AUTH SYSTEM CODES ---
integer AUTH_REQUEST = 600;
integer AUTH_REPLY = 601;

// --- AUTH LEVEL CONSTANTS (matching permission module) ---
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_BLOCKED = 598;
integer CMD_NOACCESS = 599;

// --- CORE SYSTEM STATES ---
key g_kWearer;
string gUnitName = "A.R.I.A.";
string gHomeLandmark = "http://maps.secondlife.com/secondlife/Hippo%20Hollow/128/128/2";
integer gPowerState = TRUE;
integer gIsSecure = FALSE;
key gPendingSyncProgrammer;
key gSyncedOwnerHudKey;
key gSyncedWearerHudKey;
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

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, timestamp, ...]
integer gNextRequestId = 1;
integer gAuthTimeoutSeconds = 30;

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
    
    year += (days_since_epoch / 365);
    month += ((days_since_epoch % 365) / 30);
    day += ((days_since_epoch % 365) % 30);
    
    if (month > 12) {
        year += (month - 1) / 12;
        month = ((month - 1) % 12) + 1;
    }
    
    return (string)day + " " + llList2String(months, month - 1) + " " + (string)year;
}

// Clean up expired auth requests
cleanupAuthRequests() {
    integer currentTime = llGetUnixTime();
    integer i = 0;
    
    while (i < llGetListLength(gPendingAuthRequests)) {
        integer requestTime = llList2Integer(gPendingAuthRequests, i + 3);
        if (currentTime - requestTime > gAuthTimeoutSeconds) {
            // Remove expired request
            gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, i, i + 3);
        } else {
            i += 4; // Move to next request
        }
    }
}

// Build paginated main menu (now called after auth check)
buildMainMenu(key user, integer page) {
    gCurrentMenuUser = user;
    gCurrentMenuPage = page;
    gMenuState = MENU_STATE_MAIN_MENU;
    
    // We can build menu immediately since auth was already checked
    gMainMenuDialog = "\n[ A.R.I.A. MAIN MENU ]\n";
    gMainMenuDialog += "Unit: " + gUnitName + "\n";
    gMainMenuDialog += "Persona: " + gCurrentPersona + "\n";
    gMainMenuDialog += "Power: " + (string)((integer)gBatteryLevel) + "%";
    
    // Build basic menu options - auth levels will be checked on selection
    gCurrentMenuButtons = ["MODULES", "HOME", "SOS"];
    
    // Add advanced options
    gCurrentMenuButtons += ["Set Home"];
    
    if (gIsSecure) {
        gCurrentMenuButtons += ["[UNLOCK]"];
    } else {
        gCurrentMenuButtons += ["[SECURE]"];
    }
    
    gCurrentMenuButtons += ["POWER OFF"];
    
    // Simple pagination (max 9 buttons per page)
    integer totalButtons = llGetListLength(gCurrentMenuButtons);
    integer maxButtonsPerPage = 9;
    integer totalPages = (totalButtons + maxButtonsPerPage - 1) / maxButtonsPerPage;
    
    if (page >= totalPages) page = totalPages - 1;
    if (page < 0) page = 0;
    gCurrentMenuPage = page;
    
    integer startIndex = page * maxButtonsPerPage;
    integer endIndex = startIndex + maxButtonsPerPage - 1;
    if (endIndex >= totalButtons) endIndex = totalButtons - 1;
    
    list pageButtons = [];
    integer i;
    for (i = startIndex; i <= endIndex && i < totalButtons; i++) {
        pageButtons += [llList2String(gCurrentMenuButtons, i)];
    }
    
    // Add navigation if needed
    if (totalPages > 1) {
        gMainMenuDialog += "\n\nPage " + (string)(page + 1) + " of " + (string)totalPages;
        if (page > 0) pageButtons += ["< BACK"];
        if (page < totalPages - 1) pageButtons += ["NEXT >"];
    }
    
    pageButtons += ["CLOSE"];
    
    open_menu(user, gMainMenuDialog, pageButtons);
}

// Build modules menu (now called after auth check)
buildModulesMenu(key user, integer page) {
    gCurrentMenuUser = user;
    gCurrentMenuPage = page;
    gMenuState = MENU_STATE_MODULES_MENU;
    
    string dialog = "\n[ MODULES MENU ]\n";
    dialog += "Select a module to configure:\n";
    
    // Build module list
    gCurrentMenuButtons = [];
    
    // Add registered modules
    integer i;
    for (i = 0; i < llGetListLength(gActiveModules); i++) {
        gCurrentMenuButtons += [llList2String(gActiveModules, i)];
    }
    
    // Add core modules
    gCurrentMenuButtons += ["Persona", "SPEECH MODE", "Permissions"];
    
    // Simple pagination
    integer totalButtons = llGetListLength(gCurrentMenuButtons);
    integer maxButtonsPerPage = 9;
    integer totalPages = (totalButtons + maxButtonsPerPage - 1) / maxButtonsPerPage;
    
    if (page >= totalPages) page = totalPages - 1;
    if (page < 0) page = 0;
    gCurrentMenuPage = page;
    
    integer startIndex = page * maxButtonsPerPage;
    integer endIndex = startIndex + maxButtonsPerPage - 1;
    if (endIndex >= totalButtons) endIndex = totalButtons - 1;
    
    list pageButtons = [];
    for (i = startIndex; i <= endIndex && i < totalButtons; i++) {
        pageButtons += [llList2String(gCurrentMenuButtons, i)];
    }
    
    if (totalPages > 1) {
        dialog += "\nPage " + (string)(page + 1) + " of " + (string)totalPages;
        if (page > 0) pageButtons += ["< BACK"];
        if (page < totalPages - 1) pageButtons += ["NEXT >"];
    }
    
    pageButtons += ["-Main-", "CLOSE"];
    
    open_menu(user, dialog, pageButtons);
}

// Request auth for a specific action
requestAuth(key user, string action) {
    string requestId = (string)gNextRequestId;
    gNextRequestId++;
    
    // Store pending request: [requestId, userKey, action, timestamp]
    integer timestamp = llGetUnixTime();
    gPendingAuthRequests += [requestId, user, action, timestamp];
    
    // Send auth request to permission module
    llMessageLinked(LINK_SET, AUTH_REQUEST, action, user);
    
    // Start cleanup timer
    llSetTimerEvent(5.0);
}

// Execute action based on auth level
executeAuthorizedAction(key user, integer authLevel, string action) {
    if (action == "MAIN_MENU") {
        if (authLevel <= CMD_WEARER) {
            // Check if unit is powered off first
            if (!gPowerState && authLevel <= CMD_OWNER) {
                open_menu(user, "\nUnit is OFFLINE.\nOnly Owners can power on the unit.", ["POWER ON"]);
                return;
            } else if (!gPowerState) {
                llInstantMessage(user, "Unit is offline. Contact an owner to power on.");
                return;
            }
            buildMainMenu(user, 0);
        } else {
            llInstantMessage(user, "Access denied. Insufficient permissions.");
        }
    }
    else if (action == "SYNC_CONFIRM") {
        if (authLevel <= CMD_TRUSTED) {
            llRegionSay(gStationLinkChannel, "SYNC_SUCCESS|" + (string)llGetKey() + "|" + gUnitName);
            gPendingSyncProgrammer = NULL_KEY;
            llInstantMessage(user, "Sync with Programming Station successful.");
        } else {
            llInstantMessage(user, "Access denied. Trusted access required for sync.");
        }
    }
    else if (action == "POWER_ON") {
        if (authLevel <= CMD_OWNER) {
            gPowerState = TRUE;
            llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "ON", NULL_KEY);
            llSetTimerEvent(60.0);
            llInstantMessage(user, "A.R.I.A. systems online.");
            // Now show main menu
            buildMainMenu(user, 0);
        } else {
            llInstantMessage(user, "Access denied. Owner access required to power on.");
        }
    }
    else if (action == "POWER_OFF") {
        if (authLevel <= CMD_TRUSTED) {
            if (gBatteryLevel < 5.0) {
                llInstantMessage(user, "Cannot power off. Battery level is below 5%.");
                return;
            }
            gPowerState = FALSE;
            llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "OFF", NULL_KEY);
            llSetTimerEvent(0.0);
            llInstantMessage(user, "A.R.I.A. systems shutting down.");
        } else {
            llInstantMessage(user, "Access denied. Trusted access required.");
        }
    }
    else if (action == "SECURE_UNIT") {
        if (authLevel <= CMD_TRUSTED) {
            gIsSecure = TRUE;
            if (gInstallTimestamp < 1) {
                gInstallTimestamp = llGetUnixTime();
                gInstallDate = convertTimestampToDate(gInstallTimestamp);
                saveInstallData();
                llOwnerSay("Unit installation recorded: " + gInstallDate);
            }
            llOwnerSay("@detach=n");
            llInstantMessage(user, "Unit attachment lock: SECURED.");
            llInstantMessage(g_kWearer, "// Attachment lock engaged. //");
            buildMainMenu(user, gCurrentMenuPage); // Refresh menu
        } else {
            llInstantMessage(user, "Access denied. Trusted access required.");
        }
    }
    else if (action == "UNLOCK_UNIT") {
        if (authLevel <= CMD_TRUSTED) {
            gIsSecure = FALSE;
            llOwnerSay("@detach=y");
            llInstantMessage(user, "Unit attachment lock: UNLOCKED.");
            llInstantMessage(g_kWearer, "// Attachment lock disengaged. //");
            buildMainMenu(user, gCurrentMenuPage); // Refresh menu
        } else {
            llInstantMessage(user, "Access denied. Trusted access required.");
        }
    }
    else if (action == "SOS") {
        if (authLevel <= CMD_WEARER) {
            // Find any owner to notify
            llOwnerSay("SOS signal activated by " + llKey2Name(user) + "!");
            llInstantMessage(user, "SOS signal sent.");
        } else {
            llInstantMessage(user, "Access denied.");
        }
    }
    else if (action == "HOME") {
        if (authLevel <= CMD_WEARER) {
            llOwnerSay("@tplm:" + gHomeLandmark + "=force");
            llInstantMessage(user, "Teleporting to home location...");
        } else {
            llInstantMessage(user, "Access denied.");
        }
    }
    else if (action == "SET_HOME") {
        if (authLevel <= CMD_TRUSTED) {
            gMenuState = MENU_STATE_SET_HOME;
            open_textbox(user, "\nEnter the new home SLURL:\n\nExample:\nhttp://maps.secondlife.com/secondlife/Region%20Name/128/128/22\n\nCurrent home:\n" + gHomeLandmark);
        } else {
            llInstantMessage(user, "Access denied. Trusted access required.");
        }
    }
    else if (action == "MODULES_MENU") {
        if (authLevel <= CMD_TRUSTED) {
            buildModulesMenu(user, 0);
        } else {
            llInstantMessage(user, "Access denied. Trusted access required for modules.");
        }
    }
}

// Process completed auth response
processAuthResponse(key user, integer authLevel, string originalAction) {
    // Find and remove the pending request
    integer idx = llListFindList(gPendingAuthRequests, [user]);
    if (idx == -1) return; // Request not found or already processed
    
    string action = llList2String(gPendingAuthRequests, idx + 1);
    gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, idx - 1, idx + 2); // Remove 4 elements
    
    // Process the authorized action
    executeAuthorizedAction(user, authLevel, action);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        g_kWearer = llGetOwner();
        
        menu_channel = (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
        gRegisteredModules = [];
        gActiveModules = [];
        gPendingAuthRequests = [];
        
        llSetTimerEvent(60.0);
        llListen(gStationLinkChannel, "", NULL_KEY, "");
        llListen(gOwnerHudChannel, "", NULL_KEY, "");
        llListen(gWearerHudChannel, "", NULL_KEY, "");
        
        loadInstallData();
        
        llOwnerSay("A.R.I.A. Main Module v12.0 initialized with OpenCollar auth system.");
        
        // Broadcast unit info to modules
        llMessageLinked(LINK_SET, UPDATE_UNIT_INFO, gUnitName, NULL_KEY);
    }

    touch_start(integer total_number) {
        key toucher = llDetectedKey(0);
        
        // Handle sync confirmation - check auth first
        if (gPendingSyncProgrammer == toucher) {
            requestAuth(toucher, "SYNC_CONFIRM");
            return;
        }
        
        // Request auth for main menu access
        requestAuth(toucher, "MAIN_MENU");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == AUTH_REPLY) {
            // Parse auth reply: "AuthReply|userKey|authLevel"
            list parts = llParseString2List(msg, ["|"], []);
            if (llList2String(parts, 0) == "AuthReply") {
                key user = (key)llList2String(parts, 1);
                integer authLevel = (integer)llList2String(parts, 2);
                string originalAction = (string)id; // The action parameter from AUTH_REQUEST (passed as id parameter)
                
                processAuthResponse(user, authLevel, originalAction);
            }
        }
        else if (num == MODULE_REGISTER) {
            if (llListFindList(gRegisteredModules, [msg]) == -1) {
                gRegisteredModules += [msg];
                gActiveModules += [msg];
                llOwnerSay("Module registered: " + msg);
            }
        } 
        else if (num == UPDATE_PERSONA_STATUS) {
            gCurrentPersona = msg;
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
            return;
        }
        
        // Handle HUD communication
        if (chan == gOwnerHudChannel || chan == gWearerHudChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "HUD_SYNC_REQUEST") {
                key hudKey = (key)llList2String(parts, 1);
                if (chan == gOwnerHudChannel) {
                    gSyncedOwnerHudKey = hudKey;
                    llRegionSayTo(hudKey, chan, "HUD_SYNC_SUCCESS|" + gUnitName + "|" + (string)gBatteryLevel);
                } else {
                    gSyncedWearerHudKey = hudKey;
                    llRegionSayTo(hudKey, chan, "HUD_SYNC_SUCCESS|" + gUnitName + "|" + (string)gBatteryLevel);
                }
            }
            return;
        }
        
        // Handle menu responses
        if (chan == menu_channel) {
            llSetTimerEvent(60.0);
            llListenRemove(gDialogHandle);
            llListenRemove(gTextBoxHandle);
            
            if (msg == "CLOSE") {
                gMenuState = MENU_STATE_NONE;
                return;
            }
            
            if (gMenuState == MENU_STATE_SET_HOME) {
                if (llSubStringIndex(msg, "http") == 0) {
                    gHomeLandmark = msg;
                    llInstantMessage(id, "Home location set to: " + msg);
                } else {
                    llInstantMessage(id, "Invalid SLURL format. Please use a proper http://maps.secondlife.com/ URL.");
                }
                gMenuState = MENU_STATE_NONE;
                return;
            }
            
            // Handle navigation
            if (msg == "< BACK") {
                if (gMenuState == MENU_STATE_MAIN_MENU) {
                    buildMainMenu(id, gCurrentMenuPage - 1);
                } else if (gMenuState == MENU_STATE_MODULES_MENU) {
                    buildModulesMenu(id, gCurrentMenuPage - 1);
                }
                return;
            }
            else if (msg == "NEXT >") {
                if (gMenuState == MENU_STATE_MAIN_MENU) {
                    buildMainMenu(id, gCurrentMenuPage + 1);
                } else if (gMenuState == MENU_STATE_MODULES_MENU) {
                    buildModulesMenu(id, gCurrentMenuPage + 1);
                }
                return;
            }
            else if (msg == "-Main-") {
                requestAuth(id, "MAIN_MENU");
                return;
            }
            
            // Handle command selections - all require auth checks
            if (msg == "POWER ON") {
                requestAuth(id, "POWER_ON");
            }
            else if (msg == "POWER OFF") {
                requestAuth(id, "POWER_OFF");
            }
            else if (msg == "[SECURE]") {
                requestAuth(id, "SECURE_UNIT");
            }
            else if (msg == "[UNLOCK]") {
                requestAuth(id, "UNLOCK_UNIT");
            }
            else if (msg == "SOS") {
                requestAuth(id, "SOS");
            }
            else if (msg == "HOME") {
                requestAuth(id, "HOME");
            }
            else if (msg == "Set Home") {
                requestAuth(id, "SET_HOME");
            }
            else if (msg == "MODULES") {
                requestAuth(id, "MODULES_MENU");
            }
            else if (llListFindList(gActiveModules, [msg]) != -1 || msg == "Persona" || msg == "SPEECH MODE" || msg == "Permissions") {
                // Forward to appropriate module
                llMessageLinked(LINK_SET, OPEN_MY_MENU, (string)id, NULL_KEY);
            }
        }
    }

    timer() {
        // Clean up expired auth requests
        cleanupAuthRequests();
        
        // Battery drain simulation
        if (gPowerState && !gIsCharging) {
            gBatteryLevel -= gBatteryDrainRate;
            if (gBatteryLevel < 0.0) gBatteryLevel = 0.0;
            
            if (gBatteryLevel <= 0.0 && gPowerState) {
                gPowerState = FALSE;
                llMessageLinked(LINK_SET, POWER_STATE_CHANGE, "OFF", NULL_KEY);
                llOwnerSay("⚠️ CRITICAL: Battery depleted. Unit powering down.");
                llSetTimerEvent(0.0);
                return;
            }
        } else if (gIsCharging && gBatteryLevel < 100.0) {
            gBatteryLevel += gBatteryChargeRate;
            if (gBatteryLevel > 100.0) gBatteryLevel = 100.0;
        }
        
        // Regular battery broadcast
        llMessageLinked(LINK_SET, UPDATE_BATTERY, (string)gBatteryLevel, NULL_KEY);
        
        // Continue timer
        llSetTimerEvent(60.0);
    }
}
