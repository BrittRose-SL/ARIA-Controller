//-- A.R.I.A. Wardrobe RLV Module (Add-on)
//-- Version 2.0 - CRITICAL FIXES & IMPROVEMENTS
//-- Fixed RLV commands, improved outfit management, enhanced folder handling

// --- CONFIGURATION ---
string gRlvRootFolder = "#RLV/~A.R.I.A.";

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
key gAdministrator;
key gWearer;
list gAdministrators;
list gTrustedUsers;
integer gPowerState = TRUE;

// --- MODULE STATE ---
list gDefinedFolders = ["BODY", "SKIN", "OUTFIT", "LEGS", "ARMS", "ACCESSORIES", "MISC"];
list gAttachedFolders;
integer gIsLocked = FALSE;
integer gDetachBlocked = FALSE;
integer gAttachBlocked = FALSE;

// --- FOLDER STATUS TRACKING ---
list gFolderStatus; // Parallel list to gDefinedFolders for ON/OFF status

// --- HELPER FUNCTIONS ---
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
    
    // Low battery restrictions
    if (gBatteryLevel <= 10.0) {
        cmd += "attach=n,addoutfit=n,";
    }
    if (gBatteryLevel <= 5.0) {
        cmd += "detach=n,detachall=n,";
    }
    
    llOwnerSay(cmd);
}

initializeFolderStatus() {
    gFolderStatus = [];
    integer i;
    for (i = 0; i < llGetListLength(gDefinedFolders); i++) {
        gFolderStatus += [FALSE]; // All folders start as OFF
    }
}

updateFolderStatus(string folder, integer status) {
    integer index = llListFindList(gDefinedFolders, [folder]);
    if (index != -1) {
        gFolderStatus = llListReplaceList(gFolderStatus, [status], index, index);
    }
}

integer getFolderStatus(string folder) {
    integer index = llListFindList(gDefinedFolders, [folder]);
    if (index != -1) {
        return llList2Integer(gFolderStatus, index);
    }
    return FALSE;
}

openControlMenu(key admin_id) {
    string dialog = "\n[ WARDROBE RLV PROTOCOLS ]\n";
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
        dialog += "\n⚠ Low power wardrobe restrictions active!";
    }
    
    list buttons = [
        "[" + lockStatus + "]",
        "[DETACH: " + detachStatus + "]",
        "[ATTACH: " + attachStatus + "]",
        "Folders",
        "UNEQUIP ALL",
        "Show Active",
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openFoldersMenu(key admin_id) {
    string dialog = "\n[ WARDROBE FOLDERS ]\n";
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
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

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
        
        llInstantMessage(gWearer, "// Wardrobe schematic '" + folder + "' unequipped. //");
    } else {
        // It's off, turn it on
        llOwnerSay("@attachfolder=" + fullPath + "=force");
        updateFolderStatus(folder, TRUE);
        
        // Add to attached folders list
        if (llListFindList(gAttachedFolders, [folder]) == -1) {
            gAttachedFolders += [folder];
        }
        
        llInstantMessage(gWearer, "// Wardrobe schematic '" + folder + "' equipped. //");
    }
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gWearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize with safe defaults
        gIsLocked = FALSE;
        gDetachBlocked = FALSE;
        gAttachBlocked = FALSE;
        gAttachedFolders = [];
        
        // Initialize folder status tracking
        initializeFolderStatus();
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Wardrobe RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyLock();
        
        llOwnerSay("Wardrobe RLV module initialized.");
        llOwnerSay("RLV Root Folder: " + gRlvRootFolder);
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
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
        else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gAdministrators = llCSV2List(llList2String(parts, 0));
                gTrustedUsers = llCSV2List(llList2String(parts, 1));
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
            if (llListFindList(gAdministrators, [user]) != -1 || 
                llListFindList(gTrustedUsers, [user]) != -1) {
                gAdministrator = user;
                openControlMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Trusted user or Administrator permissions required.");
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        integer i;
        string folder;
        string report;
        
        if (chan != gMenuChannel) return;
        
        // Verify user still has permissions
        if (llListFindList(gAdministrators, [id]) == -1 && 
            llListFindList(gTrustedUsers, [id]) == -1) {
            llInstantMessage(id, "Access denied. Permissions may have changed.");
            return;
        }
        
        llListenRemove(gListenHandle);

        if (msg == "-Main-") {
            llInstantMessage(id, "Returning to main menu.");
            return;
        }
        else if (msg == "-Back-") {
            openControlMenu(id);
            return;
        }

        if (llSubStringIndex(msg, "[LOCKED]") != -1 || llSubStringIndex(msg, "[UNLOCKED]") != -1) {
            gIsLocked = !gIsLocked;
            if (gIsLocked) {
                llInstantMessage(gWearer, "// Wardrobe access restricted. Manual override disabled. //");
            } else {
                llInstantMessage(gWearer, "// Wardrobe access restored. //");
            }
        }
        else if (llSubStringIndex(msg, "[DETACH:") != -1) {
            gDetachBlocked = !gDetachBlocked;
            if (gDetachBlocked) {
                llInstantMessage(gWearer, "// Detachment protocols disabled. //");
            } else {
                llInstantMessage(gWearer, "// Detachment protocols enabled. //");
            }
        }
        else if (llSubStringIndex(msg, "[ATTACH:") != -1) {
            gAttachBlocked = !gAttachBlocked;
            if (gAttachBlocked) {
                llInstantMessage(gWearer, "// Attachment protocols disabled. //");
            } else {
                llInstantMessage(gWearer, "// Attachment protocols enabled. //");
            }
        }
        else if (msg == "Folders") {
            openFoldersMenu(id);
            return;
        }
        else if (msg == "UNEQUIP ALL") {
            for (i = 0; i < llGetListLength(gAttachedFolders); i++) {
                folder = llList2String(gAttachedFolders, i);
                llOwnerSay("@detachfolder=" + gRlvRootFolder + "/" + folder + "=force");
                updateFolderStatus(folder, FALSE);
            }
            gAttachedFolders = [];
            initializeFolderStatus(); // Reset all to OFF
            llInstantMessage(gWearer, "// All wardrobe schematics unequipped. //");
        }
        else if (msg == "Show Active") {
            if (llGetListLength(gAttachedFolders) == 0) {
                report = "No folders currently attached.";
            } else {
                report = "Currently attached folders:\n";
                for (i = 0; i < llGetListLength(gAttachedFolders); i++) {
                    report += "• " + llList2String(gAttachedFolders, i) + "\n";
                }
            }
            llInstantMessage(id, report);
            openControlMenu(id);
            return;
        }
        else {
            // Check if it's a folder toggle
            for (i = 0; i < llGetListLength(gDefinedFolders); i++) {
                folder = llList2String(gDefinedFolders, i);
                if (llSubStringIndex(msg, "[" + folder + ":") != -1) {
                    toggleFolder(folder);
                    openFoldersMenu(id);
                    return;
                }
            }
        }
        
        // Apply the new restrictions
        applyLock();
        llInstantMessage(id, "Wardrobe protocols updated.");
        
        // Re-open menu to show new status
        openControlMenu(id);
    }
    
    timer() {
        llListenRemove(gListenHandle);
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
