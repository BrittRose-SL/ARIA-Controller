//-- A.R.I.A. Tether RLV Module (Add-on)
//-- Version 2.1 - FIXED PERMISSIONS SYSTEM + RLV TETHER CONTROL
//-- CHANGELOG v2.1:
//-- - Added new standardized permissions system from template
//-- - Fixed permission validation in all menu functions
//-- - Added proper config synchronization with master kernel
//-- - Improved access level checking for trusted users
//-- - Added permission status display in menus
//-- - RLV tether controls require trusted user access minimum

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
integer gTextBoxHandle;
key gAdministrator;
integer gPowerState = TRUE;

// --- MODULE STATE ---
integer gTetherActive = FALSE;
key gFollowTarget = NULL_KEY;
float gFollowDistance = 2.0;
integer gLeashVisible = FALSE;
integer gAutoFollow = FALSE;

// --- LEASH EFFECT VARIABLES ---
integer gParticleHandle = 0;

// --- MENU STATES ---
integer MENU_STATE_NONE = 0;
integer MENU_STATE_SET_TARGET = 1;
integer MENU_STATE_SET_DISTANCE = 2;
integer gMenuState = 0;

// --- PERMISSION FUNCTIONS (REQUIRED) ---

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

// --- HELPER FUNCTIONS ---

updateFollow() {
    if (gTetherActive && gFollowTarget != NULL_KEY) {
        // Apply RLV follow command
        llOwnerSay("@follow:" + (string)gFollowTarget + "=" + (string)gFollowDistance);
        
        if (gLeashVisible) {
            startLeashEffect();
        }
    } else {
        // Clear follow command
        llOwnerSay("@follow=clear");
        stopLeashEffect();
    }
}

startLeashEffect() {
    if (gFollowTarget != NULL_KEY) {
        llParticleSystem([
            PSYS_PART_FLAGS, 
            PSYS_PART_EMISSIVE_MASK | 
            PSYS_PART_INTERP_COLOR_MASK | 
            PSYS_PART_INTERP_SCALE_MASK | 
            PSYS_PART_TARGET_POS_MASK,
            
            PSYS_PART_START_COLOR, <0.1, 0.5, 1.0>,
            PSYS_PART_END_COLOR, <0.8, 0.1, 1.0>,
            PSYS_PART_START_SCALE, <0.05, 0.05, 0>,
            PSYS_PART_END_SCALE, <0.02, 0.02, 0>,
            PSYS_PART_START_ALPHA, 0.8,
            PSYS_PART_END_ALPHA, 0.2,
            
            PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
            PSYS_SRC_BURST_RATE, 0.05,
            PSYS_SRC_BURST_PART_COUNT, 2,
            PSYS_SRC_BURST_RADIUS, 0.0,
            PSYS_SRC_BURST_SPEED_MIN, 0.1,
            PSYS_SRC_BURST_SPEED_MAX, 0.2,
            PSYS_PART_MAX_AGE, 3.0,
            PSYS_SRC_TARGET_KEY, gFollowTarget
        ]);
        gParticleHandle = 1;
    }
}

stopLeashEffect() {
    if (gParticleHandle) {
        llParticleSystem([]);
        gParticleHandle = 0;
    }
}

openControlMenu(key user) {
    // Check permissions first
    if (!checkModuleAccess(user, ACCESS_TRUSTED, "Tether RLV")) {
        return;
    }
    
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ TETHER & FOLLOW PROTOCOLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    
    string tetherStatus = "OFF";
    if (gTetherActive) tetherStatus = "ON";
    
    string leashStatus = "OFF";
    if (gLeashVisible) leashStatus = "ON";
    
    string autoStatus = "OFF";
    if (gAutoFollow) autoStatus = "ON";
    
    string targetName = "None";
    if (gFollowTarget != NULL_KEY) {
        targetName = llKey2Name(gFollowTarget);
        if (targetName == "") targetName = "Unknown";
    }
    
    dialog += "Current Status:\n";
    dialog += "• Tether: " + tetherStatus + "\n";
    dialog += "• Target: " + targetName + "\n";
    dialog += "• Distance: " + (string)gFollowDistance + "m\n";
    dialog += "• Leash Effect: " + leashStatus + "\n";
    dialog += "• Auto Follow: " + autoStatus + "\n";
    
    dialog += "\nAccess Level: ";
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
    
    if (gBatteryLevel <= 5.0) {
        dialog += "\n\n⚠ Low power may affect tether stability!";
    }
    
    list buttons = [
        "[TETHER: " + tetherStatus + "]",
        "Set Target",
        "Set Distance",
        "[LEASH: " + leashStatus + "]",
        "[AUTO: " + autoStatus + "]",
        "Follow Self",
        "RELEASE",
        "Nearby",
        "Close"
    ];
    
    llListenRemove(gListenHandle);
    llListenRemove(gTextBoxHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openTextBox(key user, string prompt) {
    llListenRemove(gTextBoxHandle);
    gTextBoxHandle = llListen(gMenuChannel, "", user, "");
    llTextBox(user, prompt, gMenuChannel);
    llSetTimerEvent(60.0);
}

scanNearbyAvatars(key user) {
    llSensor("", NULL_KEY, AGENT, 20.0, PI);
}

handleTextInput(key user, string input) {
    if (gMenuState == MENU_STATE_SET_TARGET) {
        input = llStringTrim(input, STRING_TRIM);
        
        // Try to interpret as UUID first
        key targetKey = (key)input;
        if (targetKey != NULL_KEY) {
            gFollowTarget = targetKey;
            llInstantMessage(user, "Follow target set to: " + llKey2Name(targetKey));
        } else {
            // Try to find by name in range
            llSensor(input, NULL_KEY, AGENT, 96.0, PI);
            return; // Wait for sensor result
        }
    }
    else if (gMenuState == MENU_STATE_SET_DISTANCE) {
        float distance = (float)input;
        if (distance >= 1.0 && distance <= 20.0) {
            gFollowDistance = distance;
            llInstantMessage(user, "Follow distance set to: " + (string)distance + "m");
        } else {
            llInstantMessage(user, "Invalid distance. Please enter a value between 1.0 and 20.0 meters.");
        }
    }
    
    gMenuState = MENU_STATE_NONE;
    updateFollow();
    openControlMenu(user);
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
        gTetherActive = FALSE;
        gFollowTarget = NULL_KEY;
        gFollowDistance = 2.0;
        gLeashVisible = FALSE;
        gAutoFollow = FALSE;
        gMenuState = MENU_STATE_NONE;
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Tether RLV", NULL_KEY);
        
        // Apply initial (unrestricted) state
        updateFollow();
        
        llOwnerSay("Tether RLV module v2.1 initialized with permissions system...");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            
            // Disable tether if battery is critically low
            if (gBatteryLevel <= 5.0 && gTetherActive) {
                gTetherActive = FALSE;
                updateFollow();
                llInstantMessage(wearer, "// Tether connection lost due to low power. //");
            }
        }
        else if (num == UPDATE_CONFIG) {
            // Receive configuration from master kernel
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 2) {
                string adminCsv = llList2String(parts, 0);
                string trustedCsv = llList2String(parts, 1);
                
                // Update local lists from master kernel
                if (adminCsv != "") {
                    gAdministrators = llCSV2List(adminCsv);
                } else {
                    gAdministrators = [llGetOwner()]; // Ensure owner is always admin
                }
                
                if (trustedCsv != "") {
                    gTrustedUsers = llCSV2List(trustedCsv);
                } else {
                    gTrustedUsers = [];
                }
                
                gConfigReceived = TRUE;
                llOwnerSay("Tether RLV Module permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "ON") {
                gPowerState = TRUE;
                if (gTetherActive) {
                    updateFollow();
                }
            } else {
                gPowerState = FALSE;
                // When powered off, disable tether
                if (gTetherActive) {
                    gTetherActive = FALSE;
                    updateFollow();
                }
            }
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            
            // Check permissions using new system
            if (checkModuleAccess(user, ACCESS_TRUSTED, "Tether RLV")) {
                gAdministrator = user;
                openControlMenu(user);
            }
        }
    }

    sensor(integer num_detected) {
        if (gMenuState == MENU_STATE_SET_TARGET) {
            // Looking for a specific target by name
            if (num_detected > 0) {
                gFollowTarget = llDetectedKey(0);
                llInstantMessage(gAdministrator, "Follow target set to: " + llDetectedName(0));
                gMenuState = MENU_STATE_NONE;
                updateFollow();
                openControlMenu(gAdministrator);
            } else {
                llInstantMessage(gAdministrator, "Target not found in range.");
                openControlMenu(gAdministrator);
            }
        } else {
            // Showing nearby avatars for selection
            if (num_detected == 0) {
                llInstantMessage(gAdministrator, "No avatars found in range (20m).");
                openControlMenu(gAdministrator);
                return;
            }
            
            string dialog = "\n[ NEARBY AVATARS ]\nSelect a target to follow:\n\n";
            list buttons = [];
            integer i;
            
            for (i = 0; i < num_detected && i < 9; i++) {
                string name = llDetectedName(i);
                if (llDetectedKey(i) != wearer) {
                    dialog += "• " + name + "\n";
                    // Truncate long names for buttons
                    if (llStringLength(name) > 12) {
                        name = llGetSubString(name, 0, 11);
                    }
                    buttons += [name];
                }
            }
            
            if (llGetListLength(buttons) == 0) {
                llInstantMessage(gAdministrator, "No other avatars found in range.");
                openControlMenu(gAdministrator);
                return;
            }
            
            buttons += ["-Cancel-"];
            
            llListenRemove(gListenHandle);
            gListenHandle = llListen(gMenuChannel, "", gAdministrator, "");
            llDialog(gAdministrator, dialog, buttons, gMenuChannel);
            llSetTimerEvent(30.0);
        }
    }
    
    no_sensor() {
        if (gMenuState == MENU_STATE_SET_TARGET) {
            llInstantMessage(gAdministrator, "Target not found in range.");
        } else {
            llInstantMessage(gAdministrator, "No avatars found in range.");
        }
        openControlMenu(gAdministrator);
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);
        
        // Always check permissions in listen events
        integer access = getAccessLevel(id);
        
        if (msg == "Close") {
            llInstantMessage(id, "Tether RLV module menu closed.");
            gMenuState = MENU_STATE_NONE;
            return;
        }
        else if (msg == "-Cancel-") {
            gMenuState = MENU_STATE_NONE;
            openControlMenu(id);
            return;
        }

        // Handle text input
        if (gMenuState != MENU_STATE_NONE) {
            if (access >= ACCESS_TRUSTED) {
                handleTextInput(id, msg);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for tether controls.");
                gMenuState = MENU_STATE_NONE;
                openControlMenu(id);
            }
            return;
        }

        if (llSubStringIndex(msg, "[TETHER:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gTetherActive = !gTetherActive;
                if (gTetherActive) {
                    if (gFollowTarget != NULL_KEY) {
                        llInstantMessage(wearer, "// Follow protocol engaged. Target: " + llKey2Name(gFollowTarget) + " //");
                    } else {
                        llInstantMessage(wearer, "// Follow protocol engaged. No target set. //");
                    }
                } else {
                    llInstantMessage(wearer, "// Follow protocol disengaged. //");
                }
                updateFollow();
                llInstantMessage(id, "Tether setting updated.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for tether controls.");
            }
        }
        else if (msg == "Set Target") {
            if (access >= ACCESS_TRUSTED) {
                gMenuState = MENU_STATE_SET_TARGET;
                openTextBox(id, "\nEnter target name or UUID:\n\nYou can enter either:\n• Full avatar name\n• Avatar UUID\n\nCurrent target: " + llKey2Name(gFollowTarget));
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for target setting.");
            }
        }
        else if (msg == "Set Distance") {
            if (access >= ACCESS_TRUSTED) {
                gMenuState = MENU_STATE_SET_DISTANCE;
                openTextBox(id, "\nEnter follow distance (1.0 to 20.0 meters):\n\nCurrent distance: " + (string)gFollowDistance + "m");
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for distance setting.");
            }
        }
        else if (llSubStringIndex(msg, "[LEASH:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gLeashVisible = !gLeashVisible;
                if (gLeashVisible) {
                    llInstantMessage(wearer, "// Leash visualization enabled. //");
                } else {
                    llInstantMessage(wearer, "// Leash visualization disabled. //");
                    stopLeashEffect();
                }
                updateFollow();
                llInstantMessage(id, "Leash visualization updated.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for leash controls.");
            }
        }
        else if (llSubStringIndex(msg, "[AUTO:") != -1) {
            if (access >= ACCESS_TRUSTED) {
                gAutoFollow = !gAutoFollow;
                if (gAutoFollow) {
                    llInstantMessage(wearer, "// Auto-follow mode enabled. //");
                } else {
                    llInstantMessage(wearer, "// Auto-follow mode disabled. //");
                }
                llInstantMessage(id, "Auto-follow setting updated.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for auto-follow controls.");
            }
        }
        else if (msg == "Follow Self") {
            if (access >= ACCESS_TRUSTED) {
                gFollowTarget = id;
                llInstantMessage(wearer, "// Follow target set to: " + llKey2Name(id) + " //");
                updateFollow();
                llInstantMessage(id, "Follow target set to yourself.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for target setting.");
            }
        }
        else if (msg == "RELEASE") {
            if (access >= ACCESS_TRUSTED) {
                gTetherActive = FALSE;
                gFollowTarget = NULL_KEY;
                gLeashVisible = FALSE;
                gAutoFollow = FALSE;
                llInstantMessage(wearer, "// All follow protocols released. //");
                updateFollow();
                llInstantMessage(id, "All tether protocols released.");
                openControlMenu(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for tether release.");
            }
        }
        else if (msg == "Nearby") {
            if (access >= ACCESS_TRUSTED) {
                scanNearbyAvatars(id);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for avatar scanning.");
            }
        }
        else {
            // Check if it's a name from the nearby avatars list
            if (access >= ACCESS_TRUSTED) {
                llSensor(msg, NULL_KEY, AGENT, 20.0, PI);
            } else {
                llInstantMessage(id, "Access denied. Trusted user permissions required for tether controls.");
                openControlMenu(id);
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);
        gMenuState = MENU_STATE_NONE;
        llSetTimerEvent(0.0);
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}

//-- IMPLEMENTATION NOTES v2.1:
//-- 1. Added complete permissions system from template
//-- 2. All menu functions now check permissions before execution
//-- 3. Tether controls require trusted user access minimum for safety
//-- 4. Permissions are synchronized from master kernel via UPDATE_CONFIG
//-- 5. Access levels displayed in menus for transparency
//-- 6. Config status shows synchronization state
//-- 7. Owner automatically has admin access as backup measure
//-- 8. All RLV tether operations require trusted user permissions
//-- 9. Permission checks added to all listen event handlers
//-- 10. Proper error messages when access is denied
//-- 11. Maintains original tether functionality with enhanced security
//-- 12. Battery-based restrictions still apply automatically
