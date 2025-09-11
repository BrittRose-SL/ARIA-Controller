//-- A.R.I.A. Vision RLV Module (Add-on)
//-- Version 2.1 - PERMISSIONS SYSTEM INTEGRATED
//-- Fixed RLV commands, improved overlay handling, enhanced permission system
//-- CHANGES v2.1: Integrated standardized permissions system from template,
//                 Added proper access control for all menu functions,
//                 Fixed initialization order and permission synchronization

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
        
        llInstantMessage(user, "Access denied. " + levelName + " permissions required for Vision RLV Module.");
        return FALSE;
    }
    
    if (!gConfigReceived) {
        llInstantMessage(user, "Module permissions not synchronized. Please try again in a moment.");
        return FALSE;
    }
    
    return TRUE;
}

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

openControlMenu(key user) {
    // Check permissions before opening menu
    if (!checkModuleAccess(user, ACCESS_TRUSTED, "Vision RLV")) {
        return;
    }
    
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ VISION RLV PROTOCOLS ]\n";
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
    dialog += "\n\nCurrent Status:\n";
    
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
    
    list buttons = [];
    
    // All trusted users can toggle basic vision settings
    if (access >= ACCESS_TRUSTED) {
        buttons += [
            "[BLINDFOLD: " + blindStatus + "]",
            "[OVERLAY: " + overlayStatus + "]", 
            "[CENSOR: " + censorStatus + "]",
            "[BLUR: " + blurStatus + "]"
        ];
    }
    
    // Admin-only functions
    if (access >= ACCESS_ADMIN) {
        buttons += [
            "FULL BLIND",
            "RESTORE ALL",
            "Overlays",
            "Name Perms"
        ];
    }
    
    buttons += ["Close", "-Main-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openOverlayMenu(key user) {
    // Check admin permissions for overlay management
    if (!checkModuleAccess(user, ACCESS_ADMIN, "Vision RLV Overlays")) {
        return;
    }
    
    string dialog = "\n[ VISUAL OVERLAYS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
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
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openNamePermissionsMenu(key user) {
    // Check admin permissions for name permission management
    if (!checkModuleAccess(user, ACCESS_ADMIN, "Vision RLV Name Permissions")) {
        return;
    }
    
    string dialog = "\n[ NAME VISIBILITY PERMISSIONS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
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
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
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
        
        llOwnerSay("Vision RLV Module v2.1 initialized successfully.");
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
                llOwnerSay("Vision RLV permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            
            // Minimum trusted user access required for Vision RLV
            if (checkModuleAccess(user, ACCESS_TRUSTED, "Vision RLV")) {
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
            gPowerState = (integer)msg;
            
            if (!gPowerState) {
                // Emergency power mode - apply heavy restrictions
                gIsBlindfolded = TRUE;
                gIsCensored = TRUE;
                gIsBlurred = TRUE;
                llInstantMessage(wearer, "// Emergency power mode: Visual systems severely limited. //");
                applyRestrictions();
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
                llInstantMessage(id, "Vision RLV menu closed.");
            }
            return;
        }
        
        if (msg == "-Back-") {
            openControlMenu(id);
            return;
        }

        // Handle menu options with permission checks
        if (llSubStringIndex(msg, "[BLINDFOLD:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsBlindfolded = !gIsBlindfolded;
                if (gIsBlindfolded) {
                    llInstantMessage(wearer, "// Visual sensors obstructed. //");
                } else {
                    llInstantMessage(wearer, "// Visual sensors nominal. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(msg, "[OVERLAY:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gHasOverlay = !gHasOverlay;
                if (gHasOverlay) {
                    if (gCurrentOverlay == "" && llGetListLength(gAvailableOverlays) > 0) {
                        // Auto-select first available overlay
                        integer i;
                        string overlayName;
                        for (i = 0; i < llGetListLength(gAvailableOverlays); i++) {
                            overlayName = llList2String(gAvailableOverlays, i);
                            if (llGetInventoryType(overlayName) == INVENTORY_TEXTURE) {
                                gCurrentOverlay = overlayName;
                                jump found_overlay;
                            }
                        }
                        @found_overlay;
                    }
                    llInstantMessage(wearer, "// Tactical overlay engaged. //");
                } else {
                    llInstantMessage(wearer, "// Tactical overlay disengaged. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(msg, "[CENSOR:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsCensored = !gIsCensored;
                if (gIsCensored) {
                    llInstantMessage(wearer, "// IFF censor active. Non-essential personnel data redacted. //");
                } else {
                    llInstantMessage(wearer, "// IFF censor disabled. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (llSubStringIndex(msg, "[BLUR:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gIsBlurred = !gIsBlurred;
                if (gIsBlurred) {
                    llInstantMessage(wearer, "// Visual processing degraded. Image clarity reduced. //");
                } else {
                    llInstantMessage(wearer, "// Visual processing restored. Image clarity normal. //");
                }
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required.");
            }
        }
        else if (msg == "FULL BLIND") {
            if (access >= ACCESS_ADMIN) {
                gIsBlindfolded = TRUE;
                gHasOverlay = FALSE;
                gIsCensored = TRUE;
                gIsBlurred = TRUE;
                gShowNamesBlocked = TRUE;
                llInstantMessage(wearer, "// Full sensory deprivation (visual) engaged. //");
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "RESTORE ALL") {
            if (access >= ACCESS_ADMIN) {
                gIsBlindfolded = FALSE;
                gHasOverlay = FALSE;
                gIsCensored = FALSE;
                gIsBlurred = FALSE;
                gShowNamesBlocked = FALSE;
                llInstantMessage(wearer, "// All visual systems restored to normal operation. //");
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "Overlays") {
            if (access >= ACCESS_ADMIN) {
                openOverlayMenu(id);
                return;
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "Name Perms") {
            if (access >= ACCESS_ADMIN) {
                openNamePermissionsMenu(id);
                return;
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "Clear Overlay") {
            if (access >= ACCESS_ADMIN) {
                gCurrentOverlay = "";
                gHasOverlay = FALSE;
                llInstantMessage(id, "Visual overlay cleared.");
                openOverlayMenu(id);
                return;
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "Clear Whitelist") {
            if (access >= ACCESS_ADMIN) {
                gNameWhitelist = [];
                llInstantMessage(id, "Name visibility whitelist cleared.");
                openNamePermissionsMenu(id);
                return;
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "Clear Blacklist") {
            if (access >= ACCESS_ADMIN) {
                gNameBlacklist = [];
                llInstantMessage(id, "Name visibility blacklist cleared.");
                openNamePermissionsMenu(id);
                return;
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "Add Admin to WL") {
            if (access >= ACCESS_ADMIN) {
                if (llListFindList(gNameWhitelist, [id]) == -1) {
                    gNameWhitelist += [id];
                    llInstantMessage(id, "You have been added to the name visibility whitelist.");
                } else {
                    llInstantMessage(id, "You are already on the name visibility whitelist.");
                }
                openNamePermissionsMenu(id);
                return;
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else if (msg == "Show Lists") {
            if (access >= ACCESS_ADMIN) {
                string report = "\nName Visibility Whitelist:\n";
                integer i;
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
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        else {
            // Check if it's an overlay selection (admin only)
            if (access >= ACCESS_ADMIN) {
                integer i;
                string overlayName;
                string buttonName;
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
            } else {
                llInstantMessage(id, "Access denied. Administrator permissions required.");
            }
        }
        
        // Apply the new restrictions after any changes
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
