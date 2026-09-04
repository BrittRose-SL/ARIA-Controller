//-- A.R.I.A. Wardrobe RLV Module (Add-on)
//-- Version 3.1 - OPENCOLLAR AUTH INTEGRATION
//-- September 12, 2025 - Refactored to use AUTH_REQUEST/AUTH_REPLY system
//-- CHANGES v3.1:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//-- CHANGES v3.0:
//--   - Removed synchronous getAccessLevel() and checkModuleAccess() functions
//--   - Implemented asynchronous AUTH_REQUEST/AUTH_REPLY protocol
//--   - Added pending auth request management for wardrobe operations
//--   - Removed old permission variables and UPDATE_CONFIG handling
//--   - All menu functions now use async auth checks
//--   - Enhanced wardrobe control security with granular RLV operations

// --- CONFIGURATION ---
string gRlvRootFolder = "#RLV/~A.R.I.A.";

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- AUTH SYSTEM CODES ---
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

// --- STATE VARIABLES ---
key g_kWearer;
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
integer gPowerState = TRUE;

// --- MODULE STATE ---
list gDefinedFolders = ["BODY", "SKIN", "OUTFIT", "LEGS", "ARMS", "ACCESSORIES", "MISC"];
list gAttachedFolders;
integer gIsLocked = FALSE;
integer gDetachBlocked = FALSE;
integer gAttachBlocked = FALSE;

// --- FOLDER STATUS TRACKING ---
list gFolderStatus; // Parallel list to gDefinedFolders for ON/OFF status

// --- ASYNCHRONOUS AUTH SYSTEM ---
list gPendingAuthRequests;  // Format: [requestId, userKey, action, timestamp, ...]
integer gNextRequestId = 1;
integer gAuthTimeoutSeconds = 30;

// --- MENU VARIABLES ---
key gCurrentMenuUser;
string gCurrentMenuContext = ""; // Track which menu context we're in

// --- AUTH MANAGEMENT FUNCTIONS ---

// Request auth for a specific wardrobe action
requestWardrobeAuth(key user, string action) {
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

// Process auth response and execute authorized action
processWardrobeAuth(key user, integer authLevel, string action) {
    // Find and remove the pending request
    integer idx = llListFindList(gPendingAuthRequests, [user]);
    if (idx == -1) return; // Request not found
    
    string originalAction = llList2String(gPendingAuthRequests, idx + 1);
    gPendingAuthRequests = llDeleteSubList(gPendingAuthRequests, idx - 1, idx + 2);
    
    // Basic wardrobe operations require trusted access, admin functions need higher
    if (action == "WARDROBE_MENU" && authLevel <= CMD_TRUSTED) {
        executeWardrobeAction(user, action);
    }
    else if ((action == "FOLDERS_MENU" || action == "UNEQUIP_ALL" || llSubStringIndex(action, "FOLDER:") == 0) && authLevel <= CMD_TRUSTED) {
        // Admin-level operations (folder management) - require trusted for A.R.I.A.
        executeWardrobeAction(user, action);
    }
    else if (authLevel <= CMD_TRUSTED) {
        // Basic wardrobe operations for trusted users
        executeWardrobeAction(user, action);
    }
    else {
        llInstantMessage(user, "Access denied. Trusted User permissions required for Wardrobe RLV Module.");
    }
}

// Execute the requested wardrobe action after auth confirmation
executeWardrobeAction(key user, string action) {
    if (action == "WARDROBE_MENU") {
        openControlMenu(user);
    }
    else if (action == "TOGGLE_LOCK") {
        gIsLocked = !gIsLocked;
        if (gIsLocked) {
            llInstantMessage(g_kWearer, "// Wardrobe access restricted. Manual override disabled. //");
        } else {
            llInstantMessage(g_kWearer, "// Wardrobe access restored. //");
        }
        applyLock();
        llInstantMessage(user, "Wardrobe lock setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_DETACH_BLOCK") {
        gDetachBlocked = !gDetachBlocked;
        if (gDetachBlocked) {
            llInstantMessage(g_kWearer, "// Detachment protocols disabled. //");
        } else {
            llInstantMessage(g_kWearer, "// Detachment protocols enabled. //");
        }
        applyLock();
        llInstantMessage(user, "Detach block setting updated.");
        openControlMenu(user);
    }
    else if (action == "TOGGLE_ATTACH_BLOCK") {
        gAttachBlocked = !gAttachBlocked;
        if (gAttachBlocked) {
            llInstantMessage(g_kWearer, "// Attachment protocols disabled. //");
        } else {
            llInstantMessage(g_kWearer, "// Attachment protocols enabled. //");
        }
        applyLock();
        llInstantMessage(user, "Attach block setting updated.");
        openControlMenu(user);
    }
    else if (action == "SHOW_ACTIVE") {
        showActiveFolders(user);
        openControlMenu(user);
    }
    else if (action == "FOLDERS_MENU") {
        gCurrentMenuContext = "FOLDERS";
        openFoldersMenu(user);
    }
    else if (action == "UNEQUIP_ALL") {
        unequipAllFolders(user);
        openControlMenu(user);
    }
    else if (llSubStringIndex(action, "FOLDER:") == 0) {
        // Handle folder toggle: "FOLDER:foldername"
        string folderName = llGetSubString(action, 7, -1);
        toggleFolder(folderName);
        openFoldersMenu(user);
    }
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

// --- WARDROBE MODULE FUNCTIONS ---

// Apply wardrobe locks and restrictions based on module state and battery
applyLock() {
    string cmd = "@";
    
    if (gIsLocked) {
        cmd += "unsharedwear:" + gRlvRootFolder + "=add,";
        cmd += "detach=n,";
    } else {
        cmd += "unsharedwear:" + gRlvRootFolder + "=rem,";
        cmd += "detach=y,";
    }
    
    if (gDetachBlocked) {
        cmd += "detachall=n,";
    } else {
        cmd += "detachall=y,";
    }
    
    if (gAttachBlocked) {
        cmd += "attach=n,addoutfit=n,";
    } else {
        cmd += "attach=y,addoutfit=y,";
    }
    
    // Battery-based restrictions override user settings when critical
    if (gBatteryLevel <= 10.0) {
        cmd += "attach=n,addoutfit=n,";
        llInstantMessage(g_kWearer, "// LOW POWER: Attachment systems offline. //");
    }
    if (gBatteryLevel <= 5.0) {
        cmd += "detach=n,detachall=n,";
        llInstantMessage(g_kWearer, "// CRITICAL POWER: All wardrobe systems locked. //");
    }
    
    if (!gPowerState) {
        // When powered off, remove all restrictions
        cmd = "@detach=y,attach=y,addoutfit=y,detachall=y,unsharedwear:" + gRlvRootFolder + "=rem";
    }
    
    llOwnerSay(cmd);
}

// Initialize folder status tracking
initializeFolderStatus() {
    gFolderStatus = [];
    integer i;
    for (i = 0; i < llGetListLength(gDefinedFolders); i++) {
        gFolderStatus += [FALSE]; // All folders start as OFF
    }
}

// Update status of a specific folder
updateFolderStatus(string folder, integer status) {
    integer index = llListFindList(gDefinedFolders, [folder]);
    if (index != -1) {
        gFolderStatus = llListReplaceList(gFolderStatus, [status], index, index);
    }
}

// Get current status of a folder
integer getFolderStatus(string folder) {
    integer index = llListFindList(gDefinedFolders, [folder]);
    if (index != -1) {
        return llList2Integer(gFolderStatus, index);
    }
    return FALSE;
}

// Toggle a specific RLV folder on/off
toggleFolder(string folder) {
    string fullPath = gRlvRootFolder + "/" + folder;
    integer currentStatus = getFolderStatus(folder);
    
    if (currentStatus) {
        // It's on, turn it off
        llOwnerSay("@detachfolder=" + fullPath + "=force");
        updateFolderStatus(folder, FALSE);
        
        // Remove from attached folders list
        integer index = llListFindList(gAttachedFolders, [folder]);
        if (index != -1) {
            gAttachedFolders = llDeleteSubList(gAttachedFolders, index, index);
        }
        
        llInstantMessage(g_kWearer, "// Wardrobe schematic '" + folder + "' unequipped. //");
    } else {
        // It's off, turn it on
        llOwnerSay("@attachfolder=" + fullPath + "=force");
        updateFolderStatus(folder, TRUE);
        
        // Add to attached folders list
        if (llListFindList(gAttachedFolders, [folder]) == -1) {
            gAttachedFolders += [folder];
        }
        
        llInstantMessage(g_kWearer, "// Wardrobe schematic '" + folder + "' equipped. //");
    }
}

// Unequip all currently active folders
unequipAllFolders(key user) {
    integer i;
    string folder;
    
    for (i = 0; i < llGetListLength(gDefinedFolders); i++) {
        folder = llList2String(gDefinedFolders, i);
        if (getFolderStatus(folder)) {
            string fullPath = gRlvRootFolder + "/" + folder;
            llOwnerSay("@detachfolder=" + fullPath + "=force");
            updateFolderStatus(folder, FALSE);
        }
    }
    
    gAttachedFolders = [];
    llInstantMessage(g_kWearer, "// All wardrobe schematics unequipped. //");
    llInstantMessage(user, "All outfit folders unequipped.");
}

// Show list of currently active folders
showActiveFolders(key user) {
    string report;
    if (llGetListLength(gAttachedFolders) == 0) {
        report = "No folders currently attached.";
    } else {
        report = "Currently attached folders:\n";
        integer i;
        for (i = 0; i < llGetListLength(gAttachedFolders); i++) {
            report += "• " + llList2String(gAttachedFolders, i) + "\n";
        }
    }
    llInstantMessage(user, report);
}

// Build and display the main wardrobe control menu
openControlMenu(key user) {
    gCurrentMenuUser = user;
    gCurrentMenuContext = "MAIN";
    gMenuChannel = (integer)("0x" + llGetSubString((string)user, -7, -1));
    
    string dialog = "\n[ WARDROBE RLV PROTOCOLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Power: " + (string)gPowerState + "\n\n";
    dialog += "RLV Folder: " + gRlvRootFolder + "\n\n";
    dialog += "Current Status:\n";
    
    string lockStatus = "UNLOCKED";
    if (gIsLocked) lockStatus = "LOCKED";
    
    string detachStatus = "OFF";
    if (gDetachBlocked) detachStatus = "ON";
    
    string attachStatus = "OFF";
    if (gAttachBlocked) attachStatus = "ON";
    
    dialog += "• Wardrobe Lock: " + lockStatus + "\n";
    dialog += "• Block Detach: " + detachStatus + "\n";
    dialog += "• Block Attach: " + attachStatus + "\n";
    dialog += "• Active Folders: " + (string)llGetListLength(gAttachedFolders) + "\n";
    
    if (gBatteryLevel <= 10.0) {
        dialog += "\n⚠️ Low power wardrobe restrictions active!";
    }
    
    list buttons = [
        "[" + lockStatus + "]",
        "[DETACH: " + detachStatus + "]",
        "[ATTACH: " + attachStatus + "]",
        "Show Active",
        "Folders",
        "UNEQUIP ALL",
        "Close"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Build and display the folders management menu
openFoldersMenu(key user) {
    string dialog = "\n[ WARDROBE FOLDERS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Toggle outfit folders on/off:\n\n";
    
    list buttons = [];
    integer i;
    string folder;
    string status;
    
    for (i = 0; i < llGetListLength(gDefinedFolders); i++) {
        folder = llList2String(gDefinedFolders, i);
        if (getFolderStatus(folder)) {
            status = "ON";
        } else {
            status = "OFF";
        }
        dialog += "• " + folder + ": " + status + "\n";
        buttons += ["[" + folder + ": " + status + "]"];
    }
    
    if (llGetListLength(buttons) > 9) {
        // Split into multiple menus if too many folders
        buttons = llList2List(buttons, 0, 8);
        buttons += ["More..."];
    }
    
    buttons += ["-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        g_kWearer = llGetOwner();
        gPendingAuthRequests = [];
        
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize with safe defaults
        gIsLocked = FALSE;
        gDetachBlocked = FALSE;
        gAttachBlocked = FALSE;
        gAttachedFolders = [];
        
        // Initialize folder status tracking
        initializeFolderStatus();
        
        // Register with main module
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Wardrobe RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyLock();
        
        llOwnerSay("Wardrobe RLV Module v3.0 initialized with OpenCollar auth system.");
        llOwnerSay("RLV Root Folder: " + gRlvRootFolder);
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == AUTH_REPLY) {
            // Parse auth reply: "AuthReply|userKey|authLevel"
            list parts = llParseString2List(msg, ["|"], []);
            if (llList2String(parts, 0) == "AuthReply") {
                key user = (key)llList2String(parts, 1);
                integer authLevel = (integer)llList2String(parts, 2);
                string originalAction = (string)id; // The action from AUTH_REQUEST
                
                processWardrobeAuth(user, authLevel, originalAction);
            }
        }
        else if (num == UPDATE_BATTERY) {
            float oldBattery = gBatteryLevel;
            gBatteryLevel = (float)msg;
            
            // Only reapply restrictions if battery level crossed a threshold
            if ((oldBattery > 10.0 && gBatteryLevel <= 10.0) ||
                (oldBattery > 5.0 && gBatteryLevel <= 5.0) ||
                (oldBattery <= 10.0 && gBatteryLevel > 10.0) ||
                (oldBattery <= 5.0 && gBatteryLevel > 5.0)) {
                applyLock();
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                applyLock();
            } else {
                gPowerState = FALSE;
                // When powered off, remove all restrictions
                llOwnerSay("@detach=y,attach=y,addoutfit=y,detachall=y,unsharedwear:" + gRlvRootFolder + "=rem");
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            // Request auth for wardrobe menu access
            requestWardrobeAuth(user, "WARDROBE_MENU");
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        
        if (msg == "Close") {
            llInstantMessage(id, "Wardrobe RLV module menu closed.");
            return;
        }
        
        if (msg == "-Back-") {
            if (gCurrentMenuContext == "FOLDERS") {
                requestWardrobeAuth(id, "WARDROBE_MENU");
            }
            return;
        }

        // Handle menu actions based on context
        if (gCurrentMenuContext == "MAIN") {
            // Main menu actions
            if (llSubStringIndex(msg, "[LOCKED]") != -1 || llSubStringIndex(msg, "[UNLOCKED]") != -1) {
                requestWardrobeAuth(id, "TOGGLE_LOCK");
            }
            else if (llSubStringIndex(msg, "[DETACH:") != -1) {
                requestWardrobeAuth(id, "TOGGLE_DETACH_BLOCK");
            }
            else if (llSubStringIndex(msg, "[ATTACH:") != -1) {
                requestWardrobeAuth(id, "TOGGLE_ATTACH_BLOCK");
            }
            else if (msg == "Show Active") {
                requestWardrobeAuth(id, "SHOW_ACTIVE");
            }
            else if (msg == "Folders") {
                requestWardrobeAuth(id, "FOLDERS_MENU");
            }
            else if (msg == "UNEQUIP ALL") {
                requestWardrobeAuth(id, "UNEQUIP_ALL");
            }
        }
        else if (gCurrentMenuContext == "FOLDERS") {
            // Folder menu actions
            integer i;
            string folder;
            for (i = 0; i < llGetListLength(gDefinedFolders); i++) {
                folder = llList2String(gDefinedFolders, i);
                if (llSubStringIndex(msg, "[" + folder + ":") != -1) {
                    requestWardrobeAuth(id, "FOLDER:" + folder);
                    return;
                }
            }
        }
    }

    timer() {
        // Clean up expired auth requests
        cleanupAuthRequests();
        
        // Continue timer for next cleanup
        llSetTimerEvent(60.0);
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
