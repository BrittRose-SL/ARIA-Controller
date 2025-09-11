//-- A.R.I.A. Sensory Module (Add-on)
//-- Version 1.2 - FIXED PERMISSIONS SYSTEM + ADULT DEVICE INTEGRATION
//-- CHANGELOG v1.2:
//-- - Added new standardized permissions system from template
//-- - Fixed permission validation in all menu functions
//-- - Added proper config synchronization with master kernel
//-- - Improved access level checking for trusted users
//-- - Added permission status display in menus
//-- - Adult features require administrator access for safety

// --- CONFIGURATION ---
integer LOVENSE_CHANNEL = 1337; // Standard Lovense communication channel
integer RLV_RELAY_CHANNEL = -1812221819; // Standard RLV Relay channel
integer INM_CHANNEL = -2017; // It's Not Mine system channel
integer XCITE_CHANNEL = 5; // Xcite! system channel
integer SENSATIONS_CHANNEL = -58904; // Sensations system channel
integer RLVR_CHANNEL = -1812221819; // RLVr relay channel
integer AVS_CHANNEL = -9119; // AVsitter adult system channel
float PAIN_EFFECT_DURATION = 30.0; // Duration for pain effects in seconds

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
key gAdministrator;
integer gPowerState = TRUE;

//-- Module State
integer gSensoryActive = TRUE;
integer gEroticMode = FALSE;
integer gPainActive = FALSE;
integer gPainTimer = 0;
string gCurrentAnimation = "";
list gConnectedDevices; // Track connected devices
list gConnectedINM; // Track INM genitals
list gConnectedXcite; // Track Xcite devices
list gConnectedSensations; // Track Sensations devices

//-- Device Integration States
integer gINMActive = FALSE;
integer gXciteActive = FALSE;
integer gSensationsActive = FALSE;
integer gGenitalStimulation = 0; // 0-100 intensity

//-- Pain Effect States
integer gShockActive = FALSE;
integer gPokeActive = FALSE;
integer gTempRestrictions = FALSE;

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

// --- SENSORY EXPERIENCE LISTS ---

list gEroticEmotes = [
    "shivers with pleasure as sensors detect arousal stimulation",
    "breathing becomes shallow as pleasure protocols engage",
    "systems register intense pleasure feedback",
    "pleasure sensors overloading... processing sensory data",
    "emits soft synthetic moans as stimulation increases"
];

list gPainEmotes = [
    "jerks suddenly as pain receptors fire",
    "systems register damage simulation protocols",
    "pain threshold exceeded... initiating protective responses",
    "synthetic nervous system overloaded with pain signals",
    "emergency protocols engaged due to simulated trauma"
];

list gShockEmotes = [
    "convulses as electrical discharge courses through synthetic neural pathways",
    "warning: electrical surge detected in primary systems",
    "body spasms uncontrollably from shock stimulus",
    "emergency shutdown prevented... shock protocols active"
];

list gPokeEmotes = [
    "gasps as sharp objects penetrate synthetic skin barriers",
    "damage sensors detect multiple puncture points",
    "protective plating compromised... pain receptors active",
    "spike stimulus registered across multiple contact points"
];

list gEroticAnimations = ["pleasure_1", "pleasure_2", "arousal_1", "stimulation_1"];
list gPainAnimations = ["pain_1", "shock_1", "damage_1", "writhe_1"];

// --- HELPER FUNCTIONS ---

sendEmote(string emote, integer chatType) {
    string fullEmote = "/me " + emote;
    
    if (chatType == 0) { // Local chat
        llSay(0, fullEmote);
    } else if (chatType == 1) { // Owner only
        llInstantMessage(llGetOwner(), fullEmote);
    } else if (chatType == 2) { // Wearer only  
        llInstantMessage(wearer, "// " + emote + " //");
    }
}

playRandomAnimation(list animList) {
    if (llGetListLength(animList) > 0) {
        string anim = llList2String(animList, (integer)llFrand(llGetListLength(animList)));
        if (llGetInventoryType(anim) == INVENTORY_ANIMATION) {
            if (gCurrentAnimation != "") llStopAnimation(gCurrentAnimation);
            llStartAnimation(anim);
            gCurrentAnimation = anim;
        }
    }
}

stopCurrentAnimation() {
    if (gCurrentAnimation != "") {
        llStopAnimation(gCurrentAnimation);
        gCurrentAnimation = "";
    }
}

applyPainRestrictions() {
    // Apply temporary movement and interaction restrictions during pain
    llOwnerSay("@forwards=n,back=n,left=n,right=n,touch=n");
    gTempRestrictions = TRUE;
    llSetTimerEvent(PAIN_EFFECT_DURATION);
}

clearPainRestrictions() {
    // Clear temporary restrictions
    llOwnerSay("@forwards=y,back=y,left=y,right=y,touch=y");
    gTempRestrictions = FALSE;
    gShockActive = FALSE;
    gPokeActive = FALSE;
    stopCurrentAnimation();
}

broadcastToLovense(string command, integer intensity) {
    // Send command to Lovense devices on standard channel
    string lovenseCmd = "LVS:" + command + ":" + (string)intensity;
    llSay(LOVENSE_CHANNEL, lovenseCmd);
    llWhisper(LOVENSE_CHANNEL, lovenseCmd);
}

sendToINM(string command, integer intensity) {
    // It's Not Mine system commands
    string inmCmd = command + "|" + (string)intensity + "|" + (string)wearer;
    llSay(INM_CHANNEL, inmCmd);
    llWhisper(INM_CHANNEL, inmCmd);
    
    // Also try direct genital commands
    llSay(INM_CHANNEL, "STIM|" + (string)intensity);
    llSay(INM_CHANNEL, "ORGASM|" + (string)intensity);
}

sendToXcite(string command, integer intensity) {
    // Xcite! system commands
    string xciteCmd = (string)wearer + ":" + command + ":" + (string)intensity;
    llSay(XCITE_CHANNEL, xciteCmd);
    
    // Alternative Xcite format
    llSay(XCITE_CHANNEL, command + " " + (string)intensity);
}

sendToSensations(string command, integer intensity) {
    // Sensations system commands
    string sensCmd = "SENS:" + command + ":" + (string)intensity + ":" + (string)wearer;
    llSay(SENSATIONS_CHANNEL, sensCmd);
    llWhisper(SENSATIONS_CHANNEL, sensCmd);
}

broadcastToAllDevices(string command, integer intensity) {
    // Send to all connected adult systems
    broadcastToLovense(command, intensity);
    sendToINM(command, intensity);
    sendToXcite(command, intensity);
    sendToSensations(command, intensity);
}

sendToRLVRelay(string command, key target) {
    // Send command to RLV Relay for furniture/device interaction
    string relayCmd = command + "," + (string)target + ",!x-channel-redirect";
    llSay(RLV_RELAY_CHANNEL, relayCmd);
}

// --- MENU FUNCTIONS ---

openMainMenu(key user) {
    // Check permissions first
    if (!checkModuleAccess(user, ACCESS_ADMIN, "Sensory Module")) {
        return;
    }
    
    integer access = getAccessLevel(user);
    
    string dialog = "\n[ SENSORY EXPERIENCE PROTOCOLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Status: ";
    if (gSensoryActive) dialog += "ACTIVE";
    else dialog += "INACTIVE";
    
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
    dialog += "\n\n⚠️ ADULT CONTENT - ADMIN ONLY ⚠️";
    
    list buttons = ["EROTIC", "PAIN", "Stop All"];
    if (gSensoryActive) buttons += ["[DISABLE]"];
    else buttons += ["[ENABLE]"];
    buttons += ["Devices", "Close"];

    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openEroticMenu(key user) {
    // Check permissions
    if (!checkModuleAccess(user, ACCESS_ADMIN, "Erotic Sensory")) {
        return;
    }
    
    string dialog = "\n[ EROTIC SENSORY PROTOCOLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Connected: Lovense(" + (string)llGetListLength(gConnectedDevices) + ") ";
    dialog += "INM(" + (string)llGetListLength(gConnectedINM) + ") ";
    dialog += "Xcite(" + (string)llGetListLength(gConnectedXcite) + ")\n\n";
    dialog += "⚠️ EXPLICIT ADULT CONTENT ⚠️";
    
    list buttons = ["Stimulate", "Climax", "Tease", "Edge", "Penetrate", "Oral"];
    buttons += ["Low Buzz", "Med Buzz", "High Buzz", "All Devices", "INM Only", "Xcite Only"];
    buttons += ["Stop Erotic", "-Back-"];

    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openPainMenu(key user) {
    // Check permissions
    if (!checkModuleAccess(user, ACCESS_ADMIN, "Pain Sensory")) {
        return;
    }
    
    string dialog = "\n[ PAIN SENSORY PROTOCOLS ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Simulate damage and pain responses\n\n";
    dialog += "⚠️ INTENSE EXPERIENCES - ADMIN ONLY ⚠️";
    
    list buttons = ["Shock", "Poke/Spike", "Burn", "Impact", "Torture", "Agony"];
    buttons += ["Stop Pain", "-Back-"];

    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openDevicesMenu(key user) {
    // Check permissions
    if (!checkModuleAccess(user, ACCESS_ADMIN, "Device Management")) {
        return;
    }
    
    string dialog = "\n[ CONNECTED ADULT DEVICES ]\n";
    dialog += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    dialog += "Lovense: " + (string)llGetListLength(gConnectedDevices) + " devices\n";
    dialog += "INM Genitals: " + (string)llGetListLength(gConnectedINM) + " detected\n";
    dialog += "Xcite: " + (string)llGetListLength(gConnectedXcite) + " devices\n";
    dialog += "Sensations: " + (string)llGetListLength(gConnectedSensations) + " devices";
    
    list buttons = ["Scan All", "Test Lovense", "Test INM", "Test Xcite", "Test Sens"];
    buttons += ["Connect All", "Sync Devices", "-Back-"];

    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- COMMAND PROCESSORS ---

processEroticCommand(string command, key user) {
    if (!gSensoryActive) {
        llInstantMessage(user, "Sensory protocols are disabled.");
        return;
    }
    
    // Additional permission check for safety
    if (getAccessLevel(user) < ACCESS_ADMIN) {
        llInstantMessage(user, "Access denied. Administrator permissions required for adult content.");
        return;
    }
    
    gEroticMode = TRUE;
    
    if (command == "Stimulate") {
        broadcastToAllDevices("STIMULATE", 50);
        sendEmote(llList2String(gEroticEmotes, (integer)llFrand(llGetListLength(gEroticEmotes))), 0);
        playRandomAnimation(gEroticAnimations);
        llInstantMessage(wearer, "// PLEASURE PROTOCOLS ACTIVE //");
    }
    else if (command == "Climax") {
        broadcastToAllDevices("CLIMAX", 100);
        sendEmote("systems overloading with intense pleasure feedback", 0);
        playRandomAnimation(gEroticAnimations);
        llInstantMessage(wearer, "// CLIMAX SEQUENCE INITIATED //");
    }
    else if (command == "Tease") {
        broadcastToAllDevices("TEASE", 30);
        sendEmote("sensors detect teasing stimulation patterns", 0);
        llInstantMessage(wearer, "// TEASE PROTOCOLS ACTIVE //");
    }
    else if (command == "Edge") {
        broadcastToAllDevices("EDGE", 80);
        sendEmote("pleasure systems approaching critical threshold", 0);
        llInstantMessage(wearer, "// EDGE PROTOCOLS - APPROACHING LIMIT //");
    }
    else if (command == "Penetrate") {
        broadcastToAllDevices("PENETRATE", 70);
        sendEmote("penetration sensors registering deep stimulation", 0);
        playRandomAnimation(gEroticAnimations);
        llInstantMessage(wearer, "// PENETRATION PROTOCOLS ACTIVE //");
    }
    else if (command == "Oral") {
        broadcastToAllDevices("ORAL", 60);
        sendEmote("oral stimulation protocols engaging", 0);
        llInstantMessage(wearer, "// ORAL STIMULATION DETECTED //");
    }
    else if (command == "Low Buzz") {
        broadcastToAllDevices("VIBRATE", 25);
        sendEmote("gentle vibration patterns detected", 2);
    }
    else if (command == "Med Buzz") {
        broadcastToAllDevices("VIBRATE", 60);
        sendEmote("moderate pleasure vibrations active", 0);
    }
    else if (command == "High Buzz") {
        broadcastToAllDevices("VIBRATE", 90);
        sendEmote("high-intensity pleasure overload detected", 0);
    }
    else if (command == "All Devices") {
        broadcastToAllDevices("STIMULATE", 60);
        sendEmote("all connected pleasure devices synchronized", 0);
    }
    else if (command == "INM Only") {
        sendToINM("STIMULATE", 60);
        sendEmote("genital stimulation protocols focused", 2);
    }
    else if (command == "Xcite Only") {
        sendToXcite("STIMULATE", 60);
        sendEmote("Xcite device stimulation active", 2);
    }
    else if (command == "Stop Erotic") {
        gEroticMode = FALSE;
        stopCurrentAnimation();
        broadcastToAllDevices("STOP", 0);
        sendToINM("STOP", 0);
        sendToXcite("STOP", 0);
        sendToSensations("STOP", 0);
        sendEmote("pleasure protocols deactivated", 2);
    }
}

processPainCommand(string command, key user) {
    if (!gSensoryActive) {
        llInstantMessage(user, "Sensory protocols are disabled.");
        return;
    }
    
    // Additional permission check for safety
    if (getAccessLevel(user) < ACCESS_ADMIN) {
        llInstantMessage(user, "Access denied. Administrator permissions required for pain protocols.");
        return;
    }
    
    gPainActive = TRUE;
    
    if (command == "Shock") {
        gShockActive = TRUE;
        sendEmote(llList2String(gShockEmotes, (integer)llFrand(llGetListLength(gShockEmotes))), 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(wearer, "// ELECTRICAL SHOCK DETECTED - PROTECTIVE PROTOCOLS ACTIVE //");
    }
    else if (command == "Poke/Spike") {
        gPokeActive = TRUE;
        sendEmote(llList2String(gPokeEmotes, (integer)llFrand(llGetListLength(gPokeEmotes))), 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(wearer, "// PUNCTURE DAMAGE DETECTED - EMERGENCY PROTOCOLS ACTIVE //");
    }
    else if (command == "Burn") {
        sendEmote("thermal damage detected... heat sensors registering dangerous levels", 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(wearer, "// THERMAL DAMAGE PROTOCOLS ACTIVE //");
    }
    else if (command == "Impact") {
        sendEmote("impact sensors register significant kinetic damage", 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(wearer, "// IMPACT DAMAGE DETECTED //");
    }
    else if (command == "Torture") {
        sendEmote("multiple pain receptors firing... torture protocols detected", 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(wearer, "// TORTURE SEQUENCE ACTIVE - SURVIVAL MODE ENGAGED //");
    }
    else if (command == "Agony") {
        sendEmote("pain threshold exceeded... agony protocols overwhelming all systems", 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(wearer, "// MAXIMUM PAIN THRESHOLD EXCEEDED //");
    }
    else if (command == "Stop Pain") {
        gPainActive = FALSE;
        clearPainRestrictions();
        sendEmote("pain protocols deactivated... systems recovering", 2);
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
        
        // Listen for all adult device system responses
        llListen(LOVENSE_CHANNEL, "", NULL_KEY, "");
        llListen(RLV_RELAY_CHANNEL, "", NULL_KEY, "");
        llListen(INM_CHANNEL, "", NULL_KEY, "");
        llListen(XCITE_CHANNEL, "", NULL_KEY, "");
        llListen(SENSATIONS_CHANNEL, "", NULL_KEY, "");
        llListen(AVS_CHANNEL, "", NULL_KEY, "");
        
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Sensory", NULL_KEY);
        
        llOwnerSay("Sensory module v1.2 initialized with adult device integration...");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            // Reduce sensory intensity at low battery
            if (gBatteryLevel <= 15.0 && (gEroticMode || gPainActive)) {
                llInstantMessage(wearer, "// Low power affecting sensory protocols //");
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
                llOwnerSay("Sensory Module permissions updated from master kernel.");
                llOwnerSay("Administrators: " + (string)llGetListLength(gAdministrators));
                llOwnerSay("Trusted Users: " + (string)llGetListLength(gTrustedUsers));
            }
        } 
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            
            // Check permissions using new system - require admin for adult content
            if (checkModuleAccess(user, ACCESS_ADMIN, "Sensory Module")) {
                gAdministrator = user;
                openMainMenu(user);
            }
        }
        else if (num == POWER_STATE_CHANGE) {
            if (msg == "OFF") {
                gPowerState = FALSE;
                gSensoryActive = FALSE;
                clearPainRestrictions();
                stopCurrentAnimation();
                broadcastToAllDevices("STOP", 0);
            } else {
                gPowerState = TRUE;
                gSensoryActive = TRUE;
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle menu interactions
        if (chan == gMenuChannel) {
            llSetTimerEvent(0.0);
            llListenRemove(gListenHandle);
            
            // Always check permissions in listen events
            integer access = getAccessLevel(id);

            if (msg == "Close") {
                llInstantMessage(id, "Sensory module menu closed.");
                return;
            }
            else if (msg == "-Back-") {
                openMainMenu(id);
                return;
            }
            else if (msg == "EROTIC") {
                if (access >= ACCESS_ADMIN) {
                    openEroticMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required for adult content.");
                }
            }
            else if (msg == "PAIN") {
                if (access >= ACCESS_ADMIN) {
                    openPainMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required for pain protocols.");
                }
            }
            else if (msg == "Devices") {
                if (access >= ACCESS_ADMIN) {
                    openDevicesMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required for device management.");
                }
            }
            else if (msg == "Stop All") {
                if (access >= ACCESS_ADMIN) {
                    gEroticMode = FALSE;
                    gPainActive = FALSE;
                    clearPainRestrictions();
                    stopCurrentAnimation();
                    broadcastToAllDevices("STOP", 0);
                    sendEmote("all sensory protocols deactivated", 2);
                    openMainMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (llSubStringIndex(msg, "[DISABLE]") != -1) {
                if (access >= ACCESS_ADMIN) {
                    gSensoryActive = FALSE;
                    llInstantMessage(wearer, "// Sensory experience protocols disabled //");
                    openMainMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (llSubStringIndex(msg, "[ENABLE]") != -1) {
                if (access >= ACCESS_ADMIN) {
                    gSensoryActive = TRUE;
                    llInstantMessage(wearer, "// Sensory experience protocols enabled //");
                    openMainMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            // Handle erotic commands
            else if (llListFindList(["Stimulate", "Climax", "Tease", "Edge", "Penetrate", "Oral", "Low Buzz", "Med Buzz", "High Buzz", "All Devices", "INM Only", "Xcite Only", "Stop Erotic"], [msg]) != -1) {
                if (access >= ACCESS_ADMIN) {
                    processEroticCommand(msg, id);
                    openEroticMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required for adult content.");
                }
            }
            // Handle pain commands  
            else if (llListFindList(["Shock", "Poke/Spike", "Burn", "Impact", "Torture", "Agony", "Stop Pain"], [msg]) != -1) {
                if (access >= ACCESS_ADMIN) {
                    processPainCommand(msg, id);
                    openPainMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required for pain protocols.");
                }
            }
            // Handle device commands
            else if (msg == "Scan All") {
                if (access >= ACCESS_ADMIN) {
                    // Scan for all device types
                    llSay(LOVENSE_CHANNEL, "LVS:DEVICE_SCAN");
                    llSay(INM_CHANNEL, "SCAN_GENITALS");
                    llSay(XCITE_CHANNEL, "DEVICE_SCAN");
                    llSay(SENSATIONS_CHANNEL, "SENS:SCAN");
                    llSensor("", NULL_KEY, PASSIVE, 20.0, PI);
                    llInstantMessage(id, "Scanning for all adult device types...");
                    openDevicesMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (msg == "Test Lovense") {
                if (access >= ACCESS_ADMIN) {
                    broadcastToLovense("TEST", 50);
                    llInstantMessage(id, "Test signal sent to Lovense devices.");
                    openDevicesMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (msg == "Test INM") {
                if (access >= ACCESS_ADMIN) {
                    sendToINM("TEST", 50);
                    llInstantMessage(id, "Test signal sent to INM genitals.");
                    openDevicesMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (msg == "Test Xcite") {
                if (access >= ACCESS_ADMIN) {
                    sendToXcite("TEST", 50);
                    llInstantMessage(id, "Test signal sent to Xcite devices.");
                    openDevicesMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (msg == "Test Sens") {
                if (access >= ACCESS_ADMIN) {
                    sendToSensations("TEST", 50);
                    llInstantMessage(id, "Test signal sent to Sensations devices.");
                    openDevicesMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (msg == "Connect All") {
                if (access >= ACCESS_ADMIN) {
                    broadcastToAllDevices("CONNECT", 0);
                    llInstantMessage(id, "Connection request sent to all device types.");
                    openDevicesMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
            else if (msg == "Sync Devices") {
                if (access >= ACCESS_ADMIN) {
                    broadcastToAllDevices("SYNC", 0);
                    llInstantMessage(id, "Synchronization request sent to all devices.");
                    openDevicesMenu(id);
                } else {
                    llInstantMessage(id, "Access denied. Administrator permissions required.");
                }
            }
        }
        // Handle Lovense device responses
        else if (chan == LOVENSE_CHANNEL && llSubStringIndex(msg, "LVS:") == 0) {
            list parts = llParseString2List(msg, [":"], []);
            string command = llList2String(parts, 1);
            
            if (command == "DEVICE_READY" || command == "CONNECTED") {
                string device = llList2String(parts, 2);
                if (llListFindList(gConnectedDevices, [device]) == -1) {
                    gConnectedDevices += [device];
                    llInstantMessage(wearer, "// Lovense device connected: " + device + " //");
                }
            }
        }
        // Handle INM responses
        else if (chan == INM_CHANNEL) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "GENITAL_READY" || command == "INM_CONNECTED") {
                string device = llList2String(parts, 1);
                if (llListFindList(gConnectedINM, [device]) == -1) {
                    gConnectedINM += [device];
                    llInstantMessage(wearer, "// INM genital system connected: " + device + " //");
                }
            }
            else if (command == "ORGASM_COMPLETE") {
                sendEmote("climax systems register successful completion", 2);
            }
        }
        // Handle Xcite responses
        else if (chan == XCITE_CHANNEL) {
            if (llSubStringIndex(msg, "XCITE_READY") != -1 || llSubStringIndex(msg, "CONNECTED") != -1) {
                string deviceKey = (string)id;
                if (llListFindList(gConnectedXcite, [deviceKey]) == -1) {
                    gConnectedXcite += [deviceKey];
                    llInstantMessage(wearer, "// Xcite device connected //");
                }
            }
        }
        // Handle Sensations responses
        else if (chan == SENSATIONS_CHANNEL && llSubStringIndex(msg, "SENS:") == 0) {
            list parts = llParseString2List(msg, [":"], []);
            string command = llList2String(parts, 1);
            
            if (command == "READY" || command == "CONNECTED") {
                string device = llList2String(parts, 2);
                if (llListFindList(gConnectedSensations, [device]) == -1) {
                    gConnectedSensations += [device];
                    llInstantMessage(wearer, "// Sensations device connected: " + device + " //");
                }
            }
        }
    }

    sensor(integer num_detected) {
        // Handle detection of RLV furniture or devices
        integer i;
        for (i = 0; i < num_detected; i++) {
            string name = llDetectedName(i);
            key detected = llDetectedKey(i);
            
            // Look for common RLV furniture indicators
            if (llSubStringIndex(llToLower(name), "rlv") != -1 || 
                llSubStringIndex(llToLower(name), "furniture") != -1 ||
                llSubStringIndex(llToLower(name), "toy") != -1) {
                
                llInstantMessage(wearer, "// Compatible device detected: " + name + " //");
                sendToRLVRelay("@sit:" + (string)detected + "=force", detected);
            }
        }
    }

    timer() {
        // Handle pain effect duration
        if (gTempRestrictions) {
            clearPainRestrictions();
            llInstantMessage(wearer, "// Pain effect duration expired - systems recovering //");
        } else {
            llListenRemove(gListenHandle);
        }
        llSetTimerEvent(0.0);
    }
}

//-- IMPLEMENTATION NOTES v1.2:
//-- 1. Added complete permissions system from template
//-- 2. All menu functions now check permissions before execution
//-- 3. Adult content requires administrator access for safety and consent
//-- 4. Permissions are synchronized from master kernel via UPDATE_CONFIG
//-- 5. Access levels displayed in menus for transparency
//-- 6. Config status shows synchronization state
//-- 7. Owner automatically has admin access as backup measure
//-- 8. All adult sensory operations require administrator permissions
//-- 9. Permission checks added to all listen event handlers
//-- 10. Proper error messages when access is denied
//-- 11. Adult content warnings displayed in menus
//-- 12. Safety-focused design for sensitive functionality
