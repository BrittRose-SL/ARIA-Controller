//-- A.R.I.A. Wardrobe RLV Module (Add-on)
//-- Version 2.1 - PERMISSIONS SYSTEM INTEGRATED
//-- Fixed RLV commands, improved outfit management, enhanced folder handling
//-- CHANGES v2.1: Integrated standardized permissions system from template,
//                 Added proper access control for all menu functions,
//                 Fixed initialization order and permission synchronization

// --- CONFIGURATION ---
string gRlvRootFolder = "#RLV/~A.R.I.A.";

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- PERMISSION VARIABLES (REQUIRED) ---
list gAdministrators;
list gTrustedUsers;
key wearer;
integer gWearerAdminMode = TRUE;
integer gConfigReceived = FALSE;

// --- PERMISSION LEVELS (REQUIRED) ---
integer ACCESS_ADMIN = 4;
integer ACCESS_TRUSTED = 3;
integer ACCESS_WEARER = 2;
integer ACCESS_PUBLIC = 1;

// --- STATE VARIABLES ---
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

// --- PERMISSION FUNCTIONS (REQUIRED) ---

// This function MUST be included in every module
integer getAccessLevel(key id) {
    // Check administrator list first
    if (llListFindList(gAdministrators, [id]) != -1) return ACCESS_ADMIN;
    
    // Check trusted users list
    if (llListFindList(gTrustedUsers, [id]) != -1) return ACCESS_TRUSTED;
    
    // Check if it's the wearer
    if (id == wearer) {
        // Wearer access depends on wearer admin mode
        if (gWearerAdminMode) {
            return ACCESS_ADMIN;
        } else {
            return ACCESS_WEARER;
        }
    }
    
    // Everyone else gets public access
    return ACCESS_PUBLIC;
}

// This function should be called at the start of any menu function
integer checkModuleAccess(key user, integer requiredLevel, string moduleName) {
    integer access = getAccessLevel(user);
    
    if (access < requiredLevel) {
        string levelName = "Public";
        if (requiredLevel == ACCESS_WEARER) levelName = "Wearer";
        else if (requiredLevel == ACCESS_TRUSTED) levelName = "Trusted User";
        else if (requiredLevel == ACCESS_ADMIN) levelName = "Administrator";
        
        llInstantMessage(user, "Access denied. " + levelName + " permissions required for Wardrobe RLV Module.");
        return FALSE;
    }
    
    if (!gConfigReceived) {
        llInstantMessage(user, "Module permissions not synchronized. Please try again in a moment.");
        return FALSE;
    }
    
    return TRUE;
}

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

openControlMenu(key user) {
    // Check permissions before opening menu
    if (!checkModuleAccess(user, ACCESS_TRUSTED, "Wardrobe RLV")) {
        return;
    }
    
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ WARDROBE RLV PROTOCOLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Access Level: ";
    if (access >= ACCESS_ADMIN) {
        dialog += "ADMINISTRATOR\n";
    } else if (access >= ACCESS_TRUSTED) {
        dialog += "TRUSTED USER\n";
    } else {
        dialog += "WEARER\n";
    }
    
    dialog += "Config Status: ";
    if (gConfigReceived) {
        dialog += "SYNCHRONIZED";
    } else {
        dialog += "WAITING";
    }
    dialog += "\n\nRLV Folder: " + gRlvRootFolder + "\n\n";
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
    
    list buttons = [];
    
    // All trusted users can control basic wardrobe functions
    if (access >= ACCESS_TRUSTED) {
        buttons += [
            "[" + lockStatus + "]",
            "[DETACH: " + detachStatus + "]",
            "[ATTACH: " + attachStatus + "]",
            "Show Active"
        ];
    }
    
    // Admin-only functions
    if (access >= ACCESS_ADMIN) {
        buttons += [
            "Folders",
            "UNEQUIP ALL"
        ];
    }
    
    buttons += ["Close", "-Main-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openFoldersMenu(key user) {
    // Check admin permissions for folder management
    if (!checkModuleAccess(user, ACCESS_ADMIN, "Wardrobe RLV Folders")) {
        return;
    }
    
    string dialog = "\n[ WARDROBE FOLDERS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
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
        
        llInstantMessage(wearer, "// Wardrobe schematic '" + folder + "' unequipped. //");
    } else {
        // It's off, turn it on
        llOwnerSay("@attachfolder=" + fullPath + "=force");
        updateFolderStatus(folder, TRUE);
        
        // Add to attached folders list
        if (llListFindList(gAttachedFolders, [folder]) == -1) {
            gAttachedFolders += [folder];
        }
        
        llInstantMessage(wearer, "// Wardrobe schematic '" + folder + "' equipped. //");
    }
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        wearer = llGetOwner();
        gConfigReceived = FALSE;
        
        // Initialize with owner as admin (backup measure)
        gAdministrators = [wearer];
        gTrustedUsers = [];
        
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
        
        llOwnerSay("Wardrobe RLV Module v2.1 initialized successfully.");
        llOwnerSay("RLV Root Folder: " + gRlvRootFolder);
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_CONFIG) {
            // Receive configuration from master kernel
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string adminCsv = llList2String(parts, 0);
                string trustedCsv = llList2String(parts, 1);
                
                // Update local lists from master kernel
                if (adminCsv != "") {
                    gAdministrators = llCSV2List(adminCsv);
                } else {
                    gAdministrators = [wearer]; // Ensure owner is always admin
                }
                
                if (trustedCsv != "") {
                    gTrustedUsers = llCSV2List(trustedCsv);
                } else {
                    gTrustedUsers = [];
                }
                
                gConfigReceived = TRUE;
                llOwnerSay("Wardrobe RLV permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            
            // Minimum trusted user access required for Wardrobe RLV
            if (checkModuleAccess(user, ACCESS_TRUSTED, "Wardrobe RLV")) {
                openControlMenu(user);
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
            gPowerState = (integer)msg;
            
            if (!gPowerState) {
                // When powered off, remove all restrictions
                llOwnerSay("@detach=y,attach=y,addoutfit=y,detachall=y,unsharedwear:" + gRlvRootFolder + "=rem");
            } else {
                applyLock();
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        
        // Always check permissions in listen events
        integer access = getAccessLevel(id);
        
        if (msg == "-Main-" || msg == "Close") {
            if (msg == "Close") {
                llInstantMessage(id, "Wardrobe RLV menu closed.");
            }
            return;
        }
        
        if (msg == "-Back-") {
            openControlMenu(id);
            return;
        }

        // Handle menu options with permission checks
        if (llSubStringIndex(msg, "[LOCKED]") != -1 || llSubStringIndex(msg, "[UNLOCKED]") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsLocked = !gIsLocked;
                if (gIsLocked) {
                    llInstantMessage(wearer, "// Wardrobe access restricted. Manual override disabled. //");
                } else {
                    llInstantMessage(wearer, "// Wardrobe access restored. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(msg, "[DETACH:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gDetachBlocked = !gDetachBlocked;
                if (gDetachBlocked) {
                    llInstantMessage(wearer, "// Detachment protocols disabled. //");
                } else {
                    llInstantMessage(wearer, "// Detachment protocols enabled. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(msg, "[ATTACH:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gAttachBlocked = !gAttachBlocked;
                if (gAttachBlocked) {
                    llInstantMessage(wearer, "// Attachment protocols disabled. //");
                } else {
                    llInstantMessage(wearer, "// Attachment protocols enabled. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (msg == "Folders") {
            if (access >= ACCESS_ADMIN) {
                openFoldersMenu(id);
                return;
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "UNEQUIP ALL") {
            if (access >= ACCESS_ADMIN) {
                integer i;
                string folder;
                for (i = 0; i < llGetListLength(gAttachedFolders); i++) {
                    folder = llList2String(gAttachedFolders, i);
                    llOwnerSay("@detachfolder=" + gRlvRootFolder + "/" + folder + "=force");
                    updateFolderStatus(folder, FALSE);
                }
                gAttachedFolders = [];
                initializeFolderStatus(); // Reset all to OFF
                llInstantMessage(wearer, "// All wardrobe schematics unequipped. //");
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "Show Active") {
            if (access >= ACCESS_TRUSTED) {
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
                llInstantMessage(id, report);
                openControlMenu(id);
                return;
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else {
            // Check if it's a folder toggle (admin only)
            if (access >= ACCESS_ADMIN) {
                integer i;
                string folder;
                for (i = 0; i < llGetListLength(gDefinedFolders); i++) {
                    folder = llList2String(gDefinedFolders, i);
                    if (llSubStringIndex(msg, "[" + folder + ":") != -1) {
                        toggleFolder(folder);
                        openFoldersMenu(id);
                        return;
                    }
                }
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        
        // Apply the new restrictions after any changes
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
