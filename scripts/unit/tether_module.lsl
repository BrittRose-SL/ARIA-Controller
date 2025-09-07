//-- A.R.I.A. Tether RLV Module (Add-on)
//-- Version 2.0 - CRITICAL FIXES & IMPROVEMENTS
//-- Fixed RLV commands, improved leash system, enhanced target management

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
integer gTextBoxHandle;
key gAdministrator;
key gWearer;
list gAdministrators;
list gTrustedUsers;
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

openControlMenu(key admin_id) {
    string dialog = "\n[ TETHER & FOLLOW PROTOCOLS ]\n";
    
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
    
    if (gBatteryLevel <= 5.0) {
        dialog += "\n⚠ Low power may affect tether stability!";
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
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    llListenRemove(gTextBoxHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openTextBox(key admin_id, string prompt) {
    llListenRemove(gTextBoxHandle);
    gTextBoxHandle = llListen(gMenuChannel, "", admin_id, "");
    llTextBox(admin_id, prompt, gMenuChannel);
    llSetTimerEvent(60.0);
}

scanNearbyAvatars(key admin_id) {
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
        gWearer = llGetOwner();
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
        
        llOwnerSay("Tether RLV module initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            
            // Disable tether if battery is critically low
            if (gBatteryLevel <= 5.0 && gTetherActive) {
                gTetherActive = FALSE;
                updateFollow();
                llInstantMessage(gWearer, "// Tether connection lost due to low power. //");
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
            if (llListFindList(gAdministrators, [user]) != -1 || 
                llListFindList(gTrustedUsers, [user]) != -1) {
                gAdministrator = user;
                openControlMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Trusted user or Administrator permissions required.");
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
                if (llDetectedKey(i) != gWearer) {
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
        integer i;
        
        if (chan != gMenuChannel) return;
        
        // Verify user still has permissions
        if (llListFindList(gAdministrators, [id]) == -1 && 
            llListFindList(gTrustedUsers, [id]) == -1) {
            llInstantMessage(id, "Access denied. Permissions may have changed.");
            return;
        }
        
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);

        if (msg == "-Main-") {
            gMenuState = MENU_STATE_NONE;
            llInstantMessage(id, "Returning to main menu.");
            return;
        }
        else if (msg == "-Cancel-") {
            gMenuState = MENU_STATE_NONE;
            openControlMenu(id);
            return;
        }

        // Handle text input
        if (gMenuState != MENU_STATE_NONE) {
            handleTextInput(id, msg);
            return;
        }

        if (llSubStringIndex(msg, "[TETHER:") != -1) {
            gTetherActive = !gTetherActive;
            if (gTetherActive) {
                if (gFollowTarget != NULL_KEY) {
                    llInstantMessage(gWearer, "// Follow protocol engaged. Target: " + llKey2Name(gFollowTarget) + " //");
                } else {
                    llInstantMessage(gWearer, "// Follow protocol engaged. No target set. //");
                }
            } else {
                llInstantMessage(gWearer, "// Follow protocol disengaged. //");
            }
        }
        else if (msg == "Set Target") {
            gMenuState = MENU_STATE_SET_TARGET;
            openTextBox(id, "\nEnter target name or UUID:\n\nYou can enter either:\n• Full avatar name\n• Avatar UUID\n\nCurrent target: " + llKey2Name(gFollowTarget));
            return;
        }
        else if (msg == "Set Distance") {
            gMenuState = MENU_STATE_SET_DISTANCE;
            openTextBox(id, "\nEnter follow distance (1.0 to 20.0 meters):\n\nCurrent distance: " + (string)gFollowDistance + "m");
            return;
        }
        else if (llSubStringIndex(msg, "[LEASH:") != -1) {
            gLeashVisible = !gLeashVisible;
            if (gLeashVisible) {
                llInstantMessage(gWearer, "// Leash visualization enabled. //");
            } else {
                llInstantMessage(gWearer, "// Leash visualization disabled. //");
                stopLeashEffect();
            }
        }
        else if (llSubStringIndex(msg, "[AUTO:") != -1) {
            gAutoFollow = !gAutoFollow;
            if (gAutoFollow) {
                llInstantMessage(gWearer, "// Auto-follow mode enabled. //");
            } else {
                llInstantMessage(gWearer, "// Auto-follow mode disabled. //");
            }
        }
        else if (msg == "Follow Self") {
            gFollowTarget = id;
            llInstantMessage(gWearer, "// Follow target set to: " + llKey2Name(id) + " //");
        }
        else if (msg == "RELEASE") {
            gTetherActive = FALSE;
            gFollowTarget = NULL_KEY;
            gLeashVisible = FALSE;
            gAutoFollow = FALSE;
            llInstantMessage(gWearer, "// All follow protocols released. //");
        }
        else if (msg == "Nearby") {
            scanNearbyAvatars(id);
            return;
        }
        else {
            // Check if it's a name from the nearby avatars list
            llSensor(msg, NULL_KEY, AGENT, 20.0, PI);
            return;
        }
        
        // Update follow state and reopen menu
        updateFollow();
        llInstantMessage(id, "Tether protocols updated.");
        openControlMenu(id);
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);
        gMenuState = MENU_STATE_NONE;
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
