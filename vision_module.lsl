//-- A.R.I.A. Vision RLV Module (Add-on)
//-- Version 2.0 - CRITICAL FIXES & IMPROVEMENTS
//-- Fixed RLV commands, improved overlay handling, enhanced permission system

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
integer gIsBlindfolded = FALSE;
integer gHasOverlay = FALSE;
integer gIsCensored = FALSE;
integer gIsBlurred = FALSE;
integer gShowNamesBlocked = FALSE;

// --- OVERLAY MANAGEMENT ---
string gCurrentOverlay = "";
list gAvailableOverlays = [
    "aria_hud_overlay",
    "aria_tactical_overlay", 
    "aria_night_vision",
    "aria_glitch_overlay",
    "aria_static_overlay"
];

// --- PERMISSION MANAGEMENT ---
list gNameWhitelist;
list gNameBlacklist;

// --- HELPER FUNCTIONS ---
applyRestrictions() {
    string cmd = "@";
    
    // Apply blindfold (reduces draw distance dramatically)
    if (gIsBlindfolded) {
        cmd += "camdrawmin=0.1,camdrawmax=0.5,";
    } else {
        cmd += "camdrawmin=0.0,camdrawmax=512.0,";
    }
    
    // Apply visual blur
    if (gIsBlurred) {
        cmd += "camblur=1.0,";
    } else {
        cmd += "camblur=0.0,";
    }
    
    // Handle overlay display
    if (gHasOverlay && gCurrentOverlay != "") {
        // Check if overlay texture exists in inventory
        if (llGetInventoryType(gCurrentOverlay) == INVENTORY_TEXTURE) {
            cmd += "overlay=" + (string)llGetInventoryKey(gCurrentOverlay) + ",";
        }
    } else {
        cmd += "overlay=clear,";
    }
    
    // Handle name censoring
    if (gIsCensored || gShowNamesBlocked) {
        cmd += "shownames=n,";
    } else {
        cmd += "shownames=y,";
    }
    
    // Low battery automatic restrictions override manual settings
    if (gBatteryLevel <= 15.0) {
        cmd += "shownames=n,";
    }
    if (gBatteryLevel <= 10.0) {
        // Apply glitch overlay if available
        if (llGetInventoryType("aria_glitch_overlay") == INVENTORY_TEXTURE) {
            cmd += "overlay=" + (string)llGetInventoryKey("aria_glitch_overlay") + ",";
        }
    }
    if (gBatteryLevel <= 5.0) {
        cmd += "camdrawmin=0.1,camdrawmax=1.0,camblur=1.0,";
    }
    
    // Apply whitelist/blacklist for name visibility
    integer i;
    for (i = 0; i < llGetListLength(gNameWhitelist); i++) {
        cmd += "showname:" + (string)llList2String(gNameWhitelist, i) + "=rem,";
    }
    for (i = 0; i < llGetListLength(gNameBlacklist); i++) {
        cmd += "showname:" + (string)llList2String(gNameBlacklist, i) + "=add,";
    }
    
    // Apply all restrictions at once
    llOwnerSay(cmd);
}

openControlMenu(key admin_id) {
    string dialog = "\n[ VISION RLV PROTOCOLS ]\n";
    dialog += "Current Status:\n";
    
    string blindStatus = "OFF";
    if (gIsBlindfolded) blindStatus = "ON";
    
    string overlayStatus = "OFF";
    if (gHasOverlay) overlayStatus = "ON";
    
    string censorStatus = "OFF";
    if (gIsCensored) censorStatus = "ON";
    
    string blurStatus = "OFF";
    if (gIsBlurred) blurStatus = "ON";
    
    dialog += "• Blindfold: " + blindStatus + "\n";
    dialog += "• Overlay: " + overlayStatus;
    if (gHasOverlay && gCurrentOverlay != "") {
        dialog += " (" + gCurrentOverlay + ")";
    }
    dialog += "\n• Name Censor: " + censorStatus + "\n";
    dialog += "• Blur Vision: " + blurStatus + "\n";
    
    if (gBatteryLevel <= 15.0) {
        dialog += "\n⚠ Low power vision restrictions active!";
    }
    
    list buttons = [
        "[BLINDFOLD: " + blindStatus + "]",
        "[OVERLAY: " + overlayStatus + "]", 
        "[CENSOR: " + censorStatus + "]",
        "[BLUR: " + blurStatus + "]",
        "FULL BLIND",
        "RESTORE ALL",
        "Overlays",
        "Name Perms",
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openOverlayMenu(key admin_id) {
    string dialog = "\n[ VISUAL OVERLAYS ]\n";
    dialog += "Current: ";
    if (gCurrentOverlay == "") {
        dialog += "None";
    } else {
        dialog += gCurrentOverlay;
    }
    dialog += "\n\nAvailable overlays:\n";
    
    integer found = 0;
    integer i;
    string overlayName;
    
    for (i = 0; i < llGetListLength(gAvailableOverlays); i++) {
        overlayName = llList2String(gAvailableOverlays, i);
        if (llGetInventoryType(overlayName) == INVENTORY_TEXTURE) {
            dialog += "• " + overlayName + " ✓\n";
            found++;
        } else {
            dialog += "• " + overlayName + " ✗\n";
        }
    }
    
    if (found == 0) {
        dialog += "\nNo overlay textures found in inventory.";
    }
    
    list buttons = [];
    string buttonName;
    
    for (i = 0; i < llGetListLength(gAvailableOverlays) && i < 8; i++) {
        overlayName = llList2String(gAvailableOverlays, i);
        if (llGetInventoryType(overlayName) == INVENTORY_TEXTURE) {
            buttonName = overlayName;
            if (llStringLength(buttonName) > 12) {
                buttonName = llGetSubString(buttonName, 0, 11);
            }
            buttons += [buttonName];
        }
    }
    
    buttons += ["Clear Overlay", "-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openNamePermissionsMenu(key admin_id) {
    string dialog = "\n[ NAME VISIBILITY PERMISSIONS ]\n";
    dialog += "Whitelist (" + (string)llGetListLength(gNameWhitelist) + " users)\n";
    dialog += "Blacklist (" + (string)llGetListLength(gNameBlacklist) + " users)\n\n";
    dialog += "Note: Use main Permissions module\nto manage detailed user lists.";
    
    list buttons = [
        "Clear Whitelist",
        "Clear Blacklist", 
        "Add Admin to WL",
        "Show Lists",
        "-Back-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gWearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize with safe defaults
        gIsBlindfolded = FALSE;
        gHasOverlay = FALSE;
        gIsCensored = FALSE;
        gIsBlurred = FALSE;
        gShowNamesBlocked = FALSE;
        gCurrentOverlay = "";
        
        // Initialize permission lists
        gNameWhitelist = [];
        gNameBlacklist = [];
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Vision RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        applyRestrictions();
        
        llOwnerSay("Vision RLV module initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
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
        else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                gAdministrators = llCSV2List(llList2String(parts, 0));
                gTrustedUsers = llCSV2List(llList2String(parts, 1));
                
                // Reset whitelist with current administrators
                gNameWhitelist = gAdministrators;
                applyRestrictions();
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                applyRestrictions();
            } else {
                gPowerState = FALSE;
                // When powered off, remove all restrictions
                llOwnerSay("@camdrawmin=0.0,camdrawmax=512.0,camblur=0.0,overlay=clear,shownames=y");
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
        string overlayName;
        string buttonName;
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

        if (llSubStringIndex(msg, "[BLINDFOLD:") != -1) {
            gIsBlindfolded = !gIsBlindfolded;
            if (gIsBlindfolded) {
                llInstantMessage(gWearer, "// Visual sensors obstructed. //");
            } else {
                llInstantMessage(gWearer, "// Visual sensors nominal. //");
            }
        }
        else if (llSubStringIndex(msg, "[OVERLAY:") != -1) {
            gHasOverlay = !gHasOverlay;
            if (gHasOverlay) {
                if (gCurrentOverlay == "" && llGetListLength(gAvailableOverlays) > 0) {
                    // Auto-select first available overlay
                    for (i = 0; i < llGetListLength(gAvailableOverlays); i++) {
                        overlayName = llList2String(gAvailableOverlays, i);
                        if (llGetInventoryType(overlayName) == INVENTORY_TEXTURE) {
                            gCurrentOverlay = overlayName;
                            jump found_overlay;
                        }
                    }
                    @found_overlay;
                }
                llInstantMessage(gWearer, "// Tactical overlay engaged. //");
            } else {
                llInstantMessage(gWearer, "// Tactical overlay disengaged. //");
            }
        }
        else if (llSubStringIndex(msg, "[CENSOR:") != -1) {
            gIsCensored = !gIsCensored;
            if (gIsCensored) {
                llInstantMessage(gWearer, "// IFF censor active. Non-essential personnel data redacted. //");
            } else {
                llInstantMessage(gWearer, "// IFF censor disabled. //");
            }
        }
        else if (llSubStringIndex(msg, "[BLUR:") != -1) {
            gIsBlurred = !gIsBlurred;
            if (gIsBlurred) {
                llInstantMessage(gWearer, "// Visual processing degraded. Image clarity reduced. //");
            } else {
                llInstantMessage(gWearer, "// Visual processing restored. Image clarity normal. //");
            }
        }
        else if (msg == "FULL BLIND") {
            gIsBlindfolded = TRUE;
            gHasOverlay = FALSE;
            gIsCensored = TRUE;
            gIsBlurred = TRUE;
            gShowNamesBlocked = TRUE;
            llInstantMessage(gWearer, "// Full sensory deprivation (visual) engaged. //");
        }
        else if (msg == "RESTORE ALL") {
            gIsBlindfolded = FALSE;
            gHasOverlay = FALSE;
            gIsCensored = FALSE;
            gIsBlurred = FALSE;
            gShowNamesBlocked = FALSE;
            llInstantMessage(gWearer, "// All visual systems restored to normal operation. //");
        }
        else if (msg == "Overlays") {
            openOverlayMenu(id);
            return;
        }
        else if (msg == "Name Perms") {
            openNamePermissionsMenu(id);
            return;
        }
        else if (msg == "Clear Overlay") {
            gCurrentOverlay = "";
            gHasOverlay = FALSE;
            llInstantMessage(id, "Visual overlay cleared.");
            openOverlayMenu(id);
            return;
        }
        else if (msg == "Clear Whitelist") {
            gNameWhitelist = [];
            llInstantMessage(id, "Name visibility whitelist cleared.");
            openNamePermissionsMenu(id);
            return;
        }
        else if (msg == "Clear Blacklist") {
            gNameBlacklist = [];
            llInstantMessage(id, "Name visibility blacklist cleared.");
            openNamePermissionsMenu(id);
            return;
        }
        else if (msg == "Add Admin to WL") {
            if (llListFindList(gNameWhitelist, [id]) == -1) {
                gNameWhitelist += [id];
                llInstantMessage(id, "You have been added to the name visibility whitelist.");
            } else {
                llInstantMessage(id, "You are already on the name visibility whitelist.");
            }
            openNamePermissionsMenu(id);
            return;
        }
        else if (msg == "Show Lists") {
            report = "\nName Visibility Whitelist:\n";
            if (llGetListLength(gNameWhitelist) == 0) {
                report += "  (empty)\n";
            } else {
                for (i = 0; i < llGetListLength(gNameWhitelist) && i < 5; i++) {
                    report += "  " + llKey2Name((key)llList2String(gNameWhitelist, i)) + "\n";
                }
                if (llGetListLength(gNameWhitelist) > 5) {
                    report += "  ... and " + (string)(llGetListLength(gNameWhitelist) - 5) + " more\n";
                }
            }
            
            report += "\nName Visibility Blacklist:\n";
            if (llGetListLength(gNameBlacklist) == 0) {
                report += "  (empty)";
            } else {
                for (i = 0; i < llGetListLength(gNameBlacklist) && i < 5; i++) {
                    report += "  " + llKey2Name((key)llList2String(gNameBlacklist, i)) + "\n";
                }
                if (llGetListLength(gNameBlacklist) > 5) {
                    report += "  ... and " + (string)(llGetListLength(gNameBlacklist) - 5) + " more";
                }
            }
            
            llInstantMessage(id, report);
            openNamePermissionsMenu(id);
            return;
        }
        else {
            // Check if it's an overlay selection
            for (i = 0; i < llGetListLength(gAvailableOverlays); i++) {
                overlayName = llList2String(gAvailableOverlays, i);
                buttonName = overlayName;
                if (llStringLength(buttonName) > 12) {
                    buttonName = llGetSubString(buttonName, 0, 11);
                }
                
                if (msg == buttonName && llGetInventoryType(overlayName) == INVENTORY_TEXTURE) {
                    gCurrentOverlay = overlayName;
                    gHasOverlay = TRUE;
                    llInstantMessage(id, "Overlay set to: " + overlayName);
                    openOverlayMenu(id);
                    return;
                }
            }
        }
        
        // Apply the new restrictions
        applyRestrictions();
        llInstantMessage(id, "Vision protocols updated.");
        
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
