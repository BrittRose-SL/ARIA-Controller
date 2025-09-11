//-- A.R.I.A. Mobility RLV Module (Add-on)
//-- Version 2.1 - FIXED PERMISSIONS + MOVEMENT RESTRICTIONS + ENHANCED FEEDBACK
//-- CHANGELOG v2.1: Integrated proper permissions system with master kernel synchronization
//-- CHANGELOG v2.0: Fixed RLV commands, improved permission handling, enhanced user feedback

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;

// --- PERMISSION VARIABLES ---
list gAdministrators;
list gTrustedUsers;
key wearer;
integer gWearerAdminMode = TRUE;
integer gConfigReceived = FALSE;

// --- PERMISSION LEVELS ---
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
integer gIsGrounded = FALSE;      // No flying
integer gIsFrozen = FALSE;        // No movement at all
integer gIsTPBlocked = FALSE;     // No teleporting
integer gIsJumpBlocked = FALSE;   // No jumping
integer gIsSitBlocked = FALSE;    // No sitting
integer gIsRunBlocked = FALSE;    // Walking only

// --- TELEPORT PERMISSION MANAGEMENT ---
list gTPWhitelist = [];
list gTPBlacklist = [];

// --- RESTRICTION TRACKING ---
integer gRestrictionsActive = FALSE;
string gLastActionBy = "";

// --- PERMISSION FUNCTIONS ---
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

integer checkModuleAccess(key user, integer requiredLevel, string moduleName) {
    integer access = getAccessLevel(user);
    
    if (access < requiredLevel) {
        string levelName = "Public";
        if (requiredLevel == ACCESS_WEARER) levelName = "Wearer";
        else if (requiredLevel == ACCESS_TRUSTED) levelName = "Trusted User";
        else if (requiredLevel == ACCESS_ADMIN) levelName = "Administrator";
        
        llInstantMessage(user, "Access denied. " + levelName + " permissions required for " + moduleName + ".");
        return FALSE;
    }
    
    if (!gConfigReceived) {
        llInstantMessage(user, "Module permissions not synchronized. Please try again in a moment.");
        return FALSE;
    }
    
    return TRUE;
}

// --- RLV RESTRICTION FUNCTIONS ---
applyRestrictions() {
    if (!gPowerState) {
        // When powered off, clear all restrictions
        llOwnerSay("@clear");
        return;
    }
    
    string cmd = "@";
    
    // Apply current manual settings
    if (gIsGrounded) {
        cmd += "fly=n,";
    } else {
        cmd += "fly=y,";
    }
    
    if (gIsFrozen) {
        cmd += "forwards=n,back=n,left=n,right=n,up=n,down=n,";
    } else {
        cmd += "forwards=y,back=y,left=y,right=y,up=y,down=y,";
    }
    
    if (gIsTPBlocked) {
        cmd += "tploc=n,tplm=n,tplocal=n,tpto=n,";
    } else {
        cmd += "tploc=y,tplm=y,tplocal=y,tpto=y,";
    }
    
    if (gIsJumpBlocked) {
        cmd += "jump=n,";
    } else {
        cmd += "jump=y,";
    }
    
    if (gIsSitBlocked) {
        cmd += "sit=n,";
    } else {
        cmd += "sit=y,";
    }
    
    if (gIsRunBlocked) {
        cmd += "alwaysrun=n,";
    } else {
        cmd += "alwaysrun=y,";
    }
    
    // Low battery automatic restrictions override manual settings
    if (gBatteryLevel <= 15.0) {
        cmd += "fly=n,jump=n,alwaysrun=n,";
    }
    if (gBatteryLevel <= 10.0) {
        cmd += "tploc=n,tplm=n,tplocal=n,tpto=n,";
    }
    if (gBatteryLevel <= 5.0) {
        cmd += "forwards=n,back=n,left=n,right=n,up=n,down=n,sit=n,";
    }
    
    // Apply teleport whitelist/blacklist
    integer i;
    for (i = 0; i < llGetListLength(gTPWhitelist); i++) {
        cmd += "tprequest:" + (string)llList2String(gTPWhitelist, i) + "=rem,";
    }
    for (i = 0; i < llGetListLength(gTPBlacklist); i++) {
        cmd += "tprequest:" + (string)llList2String(gTPBlacklist, i) + "=add,";
    }
    
    // Apply all restrictions at once
    llOwnerSay(cmd);
    
    // Update restriction status
    gRestrictionsActive = (gIsGrounded || gIsFrozen || gIsTPBlocked || gIsJumpBlocked || gIsSitBlocked || gIsRunBlocked);
}

integer countActiveRestrictions() {
    integer count = 0;
    if (gIsGrounded) count++;
    if (gIsFrozen) count++;
    if (gIsTPBlocked) count++;
    if (gIsJumpBlocked) count++;
    if (gIsSitBlocked) count++;
    if (gIsRunBlocked) count++;
    return count;
}

// --- MENU FUNCTIONS ---
openControlMenu(key user) {
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ MOBILITY RLV PROTOCOLS ]\n";
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
        dialog += "SYNCHRONIZED\n";
    } else {
        dialog += "WAITING\n";
    }
    
    dialog += "Battery Level: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Active Restrictions: " + (string)countActiveRestrictions() + "/6\n";
    
    if (gLastActionBy != "") {
        dialog += "Last Modified By: " + llKey2Name(gLastActionBy) + "\n";
    }
    
    dialog += "\nCurrent Status:\n";
    
    string groundStatus = "OFF";
    if (gIsGrounded) groundStatus = "ON";
    
    string freezeStatus = "OFF";
    if (gIsFrozen) freezeStatus = "ON";
    
    string tpStatus = "OFF";
    if (gIsTPBlocked) tpStatus = "ON";
    
    string jumpStatus = "OFF";
    if (gIsJumpBlocked) jumpStatus = "ON";
    
    string sitStatus = "OFF";
    if (gIsSitBlocked) sitStatus = "ON";
    
    string runStatus = "OFF";
    if (gIsRunBlocked) runStatus = "ON";
    
    dialog += "• Ground (No Fly): " + groundStatus + "\n";
    dialog += "• Freeze (No Move): " + freezeStatus + "\n";
    dialog += "• Block TP: " + tpStatus + "\n";
    dialog += "• Block Jump: " + jumpStatus + "\n";
    dialog += "• Block Sit: " + sitStatus + "\n";
    dialog += "• Block Run: " + runStatus;
    
    if (gBatteryLevel <= 15.0) {
        dialog += "\n\n⚠ Low power mobility restrictions active!";
    }
    
    list buttons = [];
    
    // Basic controls available to trusted users and above
    if (access >= ACCESS_TRUSTED) {
        buttons += ["[GROUND: " + groundStatus + "]"];
        buttons += ["[FREEZE: " + freezeStatus + "]"];
        buttons += ["[BLOCK TP: " + tpStatus + "]"];
        buttons += ["[BLOCK JUMP: " + jumpStatus + "]"];
        buttons += ["[BLOCK SIT: " + sitStatus + "]"];
        buttons += ["[BLOCK RUN: " + runStatus + "]"];
    }
    
    // Advanced controls for administrators
    if (access >= ACCESS_ADMIN) {
        if (gRestrictionsActive) {
            buttons += ["RELEASE ALL"];
        }
        buttons += ["FULL LOCK"];
        buttons += ["TP Perms"];
    }
    
    buttons += ["Refresh", "Close", "-Main-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openPermissionsMenu(key user) {
    integer access = getAccessLevel(user);
    
    if (access < ACCESS_ADMIN) {
        llInstantMessage(user, "Access denied. Administrator permissions required for teleport permissions management.");
        openControlMenu(user);
        return;
    }
    
    string dialog = "\n[ TELEPORT PERMISSIONS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Manage who can send teleport requests to the unit.\n\n";
    dialog += "Whitelist (" + (string)llGetListLength(gTPWhitelist) + " users)\n";
    dialog += "Blacklist (" + (string)llGetListLength(gTPBlacklist) + " users)\n\n";
    dialog += "Note: Use main Permissions module\nto manage general user access lists.\n\n";
    dialog += "Whitelist = Allow ONLY these users\n";
    dialog += "Blacklist = Deny these users";
    
    list buttons = [
        "Clear Whitelist",
        "Clear Blacklist", 
        "Add Admin to WL",
        "Show Lists",
        "Help",
        "<-- Back",
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        wearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        gConfigReceived = FALSE;
        
        // Initialize with owner as admin (backup measure)
        gAdministrators = [wearer];
        gTrustedUsers = [];
        
        // Initialize with safe defaults
        gIsGrounded = FALSE;
        gIsFrozen = FALSE;
        gIsTPBlocked = FALSE;
        gIsJumpBlocked = FALSE;
        gIsSitBlocked = FALSE;
        gIsRunBlocked = FALSE;
        gRestrictionsActive = FALSE;
        gLastActionBy = "";
        
        // Initialize permission lists
        gTPWhitelist = [];
        gTPBlacklist = [];
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Mobility RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Mobility RLV module v2.1 initialized successfully.");
        llOwnerSay("CHANGELOG v2.1: Integrated proper permissions system");
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
                llOwnerSay("Mobility RLV permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
                
                // Reset whitelist with current administrators for safety
                gTPWhitelist = gAdministrators;
                applyRestrictions();
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (checkModuleAccess(user, ACCESS_TRUSTED, "Mobility RLV")) {
                openControlMenu(user);
            }
        }
        else if (num == UPDATE_BATTERY) {
            float oldBattery = gBatteryLevel;
            gBatteryLevel = (float)msg;
            
            // Only reapply restrictions if battery level crossed a threshold
            if ((oldBattery > 15.0 && gBatteryLevel <= 15.0) ||
                (oldBattery > 10.0 && gBatteryLevel <= 10.0) ||
                (oldBattery > 5.0 && gBatteryLevel <= 5.0) ||
                (oldBattery <= 15.0 && gBatteryLevel > 15.0) ||
                (oldBattery <= 10.0 && gBatteryLevel > 10.0) ||
                (oldBattery <= 5.0 && gBatteryLevel > 5.0)) {
                applyRestrictions();
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                applyRestrictions();
                llInstantMessage(wearer, "// Mobility control systems online //");
            } else {
                gPowerState = FALSE;
                // When powered off, clear all restrictions
                llOwnerSay("@clear");
                llInstantMessage(wearer, "// Mobility control systems offline - all restrictions cleared //");
            }
        }
    }

    listen(integer chan, string name, key id, string message) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        
        integer access = getAccessLevel(id);
        
        if (message == "-Main-" || message == "Close") {
            if (message == "Close") {
                llInstantMessage(id, "Mobility RLV menu closed.");
            }
            return;
        }
        
        if (message == "Refresh") {
            llInstantMessage(id, "Refreshing mobility data...");
            openControlMenu(id);
            return;
        }
        
        if (message == "<-- Back") {
            openControlMenu(id);
            return;
        }
        
        // Track who made changes
        gLastActionBy = id;
        
        // Handle menu options with permission checks
        if (llSubStringIndex(message, "[GROUND:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsGrounded = !gIsGrounded;
                if (gIsGrounded) {
                    llInstantMessage(wearer, "// Flight inhibitors engaged. //");
                } else {
                    llInstantMessage(wearer, "// Flight inhibitors disengaged. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[FREEZE:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsFrozen = !gIsFrozen;
                if (gIsFrozen) {
                    llInstantMessage(wearer, "// Locomotion system halted. //");
                } else {
                    llInstantMessage(wearer, "// Locomotion system nominal. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[BLOCK TP:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsTPBlocked = !gIsTPBlocked;
                if (gIsTPBlocked) {
                    llInstantMessage(wearer, "// Teleportation beacon disabled. //");
                } else {
                    llInstantMessage(wearer, "// Teleportation beacon enabled. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[BLOCK JUMP:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsJumpBlocked = !gIsJumpBlocked;
                if (gIsJumpBlocked) {
                    llInstantMessage(wearer, "// Jump functionality disabled. //");
                } else {
                    llInstantMessage(wearer, "// Jump functionality enabled. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[BLOCK SIT:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsSitBlocked = !gIsSitBlocked;
                if (gIsSitBlocked) {
                    llInstantMessage(wearer, "// Sitting functionality disabled. //");
                } else {
                    llInstantMessage(wearer, "// Sitting functionality enabled. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(message, "[BLOCK RUN:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsRunBlocked = !gIsRunBlocked;
                if (gIsRunBlocked) {
                    llInstantMessage(wearer, "// Running functionality disabled. Walking only. //");
                } else {
                    llInstantMessage(wearer, "// Running functionality enabled. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (message == "FULL LOCK") {
            if (access >= ACCESS_ADMIN) {
                gIsGrounded = TRUE;
                gIsFrozen = TRUE;
                gIsTPBlocked = TRUE;
                gIsJumpBlocked = TRUE;
                gIsSitBlocked = TRUE;
                gIsRunBlocked = TRUE;
                llInstantMessage(wearer, "// All mobility systems locked down. Movement prohibited. //");
                llInstantMessage(id, "Full mobility lockdown applied.");
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (message == "RELEASE ALL") {
            if (access >= ACCESS_ADMIN) {
                gIsGrounded = FALSE;
                gIsFrozen = FALSE;
                gIsTPBlocked = FALSE;
                gIsJumpBlocked = FALSE;
                gIsSitBlocked = FALSE;
                gIsRunBlocked = FALSE;
                llInstantMessage(wearer, "// All mobility protocols have been released. //");
                llInstantMessage(id, "All mobility restrictions released.");
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (message == "TP Perms") {
            openPermissionsMenu(id);
            return;
        }
        else if (message == "Clear Whitelist") {
            if (access >= ACCESS_ADMIN) {
                gTPWhitelist = [];
                llInstantMessage(id, "Teleport whitelist cleared.");
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
            openPermissionsMenu(id);
            return;
        }
        else if (message == "Clear Blacklist") {
            if (access >= ACCESS_ADMIN) {
                gTPBlacklist = [];
                llInstantMessage(id, "Teleport blacklist cleared.");
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
            openPermissionsMenu(id);
            return;
        }
        else if (message == "Add Admin to WL") {
            if (access >= ACCESS_ADMIN) {
                if (llListFindList(gTPWhitelist, [id]) == -1) {
                    gTPWhitelist += [id];
                    llInstantMessage(id, "You have been added to the teleport whitelist.");
                } else {
                    llInstantMessage(id, "You are already on the teleport whitelist.");
                }
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
            openPermissionsMenu(id);
            return;
        }
        else if (message == "Show Lists") {
            if (access >= ACCESS_ADMIN) {
                string report = "\nTeleport Whitelist:\n";
                if (llGetListLength(gTPWhitelist) == 0) {
                    report += "  (empty)\n";
                } else {
                    integer i;
                    for (i = 0; i < llGetListLength(gTPWhitelist) && i < 5; i++) {
                        string userName = llKey2Name((key)llList2String(gTPWhitelist, i));
                        if (userName == "") userName = "Unknown User";
                        report += "  " + userName + "\n";
                    }
                    if (llGetListLength(gTPWhitelist) > 5) {
                        report += "  ... and " + (string)(llGetListLength(gTPWhitelist) - 5) + " more\n";
                    }
                }
                
                report += "\nTeleport Blacklist:\n";
                if (llGetListLength(gTPBlacklist) == 0) {
                    report += "  (empty)";
                } else {
                    integer i;
                    for (i = 0; i < llGetListLength(gTPBlacklist) && i < 5; i++) {
                        string userName = llKey2Name((key)llList2String(gTPBlacklist, i));
                        if (userName == "") userName = "Unknown User";
                        report += "  " + userName + "\n";
                    }
                    if (llGetListLength(gTPBlacklist) > 5) {
                        report += "  ... and " + (string)(llGetListLength(gTPBlacklist) - 5) + " more";
                    }
                }
                
                llInstantMessage(id, report);
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
            openPermissionsMenu(id);
            return;
        }
        else if (message == "Help") {
            if (access >= ACCESS_ADMIN) {
                string helpText = "TELEPORT PERMISSIONS HELP:\n\n";
                helpText += "WHITELIST: When not empty, ONLY users on this list can send teleport requests.\n\n";
                helpText += "BLACKLIST: Users on this list are always blocked from sending teleport requests.\n\n";
                helpText += "PRIORITY: Blacklist overrides whitelist.\n\n";
                helpText += "TIP: Use the main Permissions module to add users to admin/trusted lists first.";
                llInstantMessage(id, helpText);
            }
            openPermissionsMenu(id);
            return;
        }
        else {
            llInstantMessage(id, "Unknown command: " + message);
        }
        
        // Apply the new restrictions and reopen menu
        applyRestrictions();
        llInstantMessage(id, "Mobility protocols updated.");
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
