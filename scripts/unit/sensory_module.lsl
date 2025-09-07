//-- A.R.I.A. Sensory Module (Add-on)
//-- Version 1.1 - Syntax Error Fix
//-- Handles erotic and pain sensory experiences with external device integration
//-- Supports Lovense, RLV furniture, INM, Xcite, and other adult scripted objects
//-- CHANGELOG: Fixed variable scope issues with channel definitions

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

// --- STATE VARIABLES ---
float gBatteryLevel = 100.0;
integer gMenuChannel;
integer gListenHandle;
key gAdministrator;
key gWearer;
list gAdministrators;
list gTrustedUsers;
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
        llInstantMessage(gWearer, "// " + emote + " //");
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
    string inmCmd = command + "|" + (string)intensity + "|" + (string)gWearer;
    llSay(INM_CHANNEL, inmCmd);
    llWhisper(INM_CHANNEL, inmCmd);
    
    // Also try direct genital commands
    llSay(INM_CHANNEL, "STIM|" + (string)intensity);
    llSay(INM_CHANNEL, "ORGASM|" + (string)intensity);
}

sendToXcite(string command, integer intensity) {
    // Xcite! system commands
    string xciteCmd = (string)gWearer + ":" + command + ":" + (string)intensity;
    llSay(XCITE_CHANNEL, xciteCmd);
    
    // Alternative Xcite format
    llSay(XCITE_CHANNEL, command + " " + (string)intensity);
}

sendToSensations(string command, integer intensity) {
    // Sensations system commands
    string sensCmd = "SENS:" + command + ":" + (string)intensity + ":" + (string)gWearer;
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

openMainMenu(key admin_id) {
    string dialog = "\n[ SENSORY EXPERIENCE PROTOCOLS ]\n[---------------------]\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    dialog += "Status: ";
    if (gSensoryActive) dialog += "ACTIVE";
    else dialog += "INACTIVE";
    
    list buttons = ["EROTIC", "PAIN", "Stop All"];
    if (gSensoryActive) buttons += ["[DISABLE]"];
    else buttons += ["[ENABLE]"];
    buttons += ["Devices", "-Main-"];

    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openEroticMenu(key admin_id) {
    string dialog = "\n[ EROTIC SENSORY PROTOCOLS ]\n[---------------------]\n";
    dialog += "Connected: Lovense(" + (string)llGetListLength(gConnectedDevices) + ") ";
    dialog += "INM(" + (string)llGetListLength(gConnectedINM) + ") ";
    dialog += "Xcite(" + (string)llGetListLength(gConnectedXcite) + ")\n";
    
    list buttons = ["Stimulate", "Climax", "Tease", "Edge", "Penetrate", "Oral"];
    buttons += ["Low Buzz", "Med Buzz", "High Buzz", "All Devices", "INM Only", "Xcite Only"];
    buttons += ["Stop Erotic", "<-- Back"];

    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openPainMenu(key admin_id) {
    string dialog = "\n[ PAIN SENSORY PROTOCOLS ]\n[---------------------]\n";
    dialog += "Simulate damage and pain responses\n";
    
    list buttons = ["Shock", "Poke/Spike", "Burn", "Impact", "Torture", "Agony"];
    buttons += ["Stop Pain", "<-- Back"];

    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openDevicesMenu(key admin_id) {
    string dialog = "\n[ CONNECTED ADULT DEVICES ]\n[---------------------]\n";
    dialog += "Lovense: " + (string)llGetListLength(gConnectedDevices) + " devices\n";
    dialog += "INM Genitals: " + (string)llGetListLength(gConnectedINM) + " detected\n";
    dialog += "Xcite: " + (string)llGetListLength(gConnectedXcite) + " devices\n";
    dialog += "Sensations: " + (string)llGetListLength(gConnectedSensations) + " devices\n";
    
    list buttons = ["Scan All", "Test Lovense", "Test INM", "Test Xcite", "Test Sens"];
    buttons += ["Connect All", "Sync Devices", "<-- Back"];

    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

processEroticCommand(string command, key admin_id) {
    if (!gSensoryActive) {
        llInstantMessage(admin_id, "Sensory protocols are disabled.");
        return;
    }
    
    gEroticMode = TRUE;
    
    if (command == "Stimulate") {
        sendEmote(llList2String(gEroticEmotes, (integer)llFrand(llGetListLength(gEroticEmotes))), 0);
        playRandomAnimation(gEroticAnimations);
        broadcastToAllDevices("VIBRATE", 40);
        llInstantMessage(gWearer, "// Pleasure stimulation protocols active //");
    }
    else if (command == "Climax") {
        sendEmote("systems overload with intense pleasure as climax protocols engage", 0);
        playRandomAnimation(gEroticAnimations);
        broadcastToAllDevices("CLIMAX", 95);
        sendToINM("ORGASM", 100);
        llInstantMessage(gWearer, "// CLIMAX SEQUENCE INITIATED //");
    }
    else if (command == "Tease") {
        sendEmote("pleasure sensors detect teasing stimulation... arousal increasing", 0);
        broadcastToAllDevices("PULSE", 25);
        llInstantMessage(gWearer, "// Teasing protocols engaged //");
    }
    else if (command == "Edge") {
        sendEmote("approaching climax threshold... systems maintaining edge state", 0);
        broadcastToAllDevices("EDGE", 80);
        sendToINM("EDGE", 85);
        llInstantMessage(gWearer, "// EDGE PROTOCOL ACTIVE - CLIMAX DENIED //");
    }
    else if (command == "Penetrate") {
        sendEmote("penetration sensors active... depth and pressure monitored", 0);
        sendToINM("PENETRATE", 60);
        sendToXcite("PENETRATE", 60);
        llInstantMessage(gWearer, "// Penetration simulation active //");
    }
    else if (command == "Oral") {
        sendEmote("oral stimulation protocols detected... pleasure receptors responding", 0);
        sendToINM("ORAL", 50);
        sendToXcite("ORAL", 50);
        llInstantMessage(gWearer, "// Oral stimulation protocols active //");
    }
    else if (command == "Low Buzz") {
        broadcastToAllDevices("VIBRATE", 25);
        sendEmote("low-intensity pleasure signals detected", 2);
    }
    else if (command == "Med Buzz") {
        broadcastToAllDevices("VIBRATE", 50);
        sendEmote("medium-intensity pleasure protocols active", 2);
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

processPainCommand(string command, key admin_id) {
    if (!gSensoryActive) {
        llInstantMessage(admin_id, "Sensory protocols are disabled.");
        return;
    }
    
    gPainActive = TRUE;
    
    if (command == "Shock") {
        gShockActive = TRUE;
        sendEmote(llList2String(gShockEmotes, (integer)llFrand(llGetListLength(gShockEmotes))), 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(gWearer, "// ELECTRICAL SHOCK DETECTED - PROTECTIVE PROTOCOLS ACTIVE //");
    }
    else if (command == "Poke/Spike") {
        gPokeActive = TRUE;
        sendEmote(llList2String(gPokeEmotes, (integer)llFrand(llGetListLength(gPokeEmotes))), 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(gWearer, "// PUNCTURE DAMAGE DETECTED - EMERGENCY PROTOCOLS ACTIVE //");
    }
    else if (command == "Burn") {
        sendEmote("thermal damage detected... heat sensors registering dangerous levels", 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(gWearer, "// THERMAL DAMAGE PROTOCOLS ACTIVE //");
    }
    else if (command == "Impact") {
        sendEmote("impact sensors register significant kinetic damage", 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(gWearer, "// IMPACT DAMAGE DETECTED //");
    }
    else if (command == "Torture") {
        sendEmote("multiple pain receptors firing... torture protocols detected", 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(gWearer, "// TORTURE SEQUENCE ACTIVE - SURVIVAL MODE ENGAGED //");
    }
    else if (command == "Agony") {
        sendEmote("pain threshold exceeded... agony protocols overwhelming all systems", 0);
        playRandomAnimation(gPainAnimations);
        applyPainRestrictions();
        llInstantMessage(gWearer, "// MAXIMUM PAIN THRESHOLD EXCEEDED //");
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
        gWearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Listen for all adult device system responses
        llListen(LOVENSE_CHANNEL, "", NULL_KEY, "");
        llListen(RLV_RELAY_CHANNEL, "", NULL_KEY, "");
        llListen(INM_CHANNEL, "", NULL_KEY, "");
        llListen(XCITE_CHANNEL, "", NULL_KEY, "");
        llListen(SENSATIONS_CHANNEL, "", NULL_KEY, "");
        llListen(AVS_CHANNEL, "", NULL_KEY, "");
        
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Sensory", NULL_KEY);
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            // Reduce sensory intensity at low battery
            if (gBatteryLevel <= 15.0 && (gEroticMode || gPainActive)) {
                llInstantMessage(gWearer, "// Low power affecting sensory protocols //");
            }
        } 
        else if (num == UPDATE_CONFIG) {
            list parts = llParseString2List(msg, ["|"], []);
            gAdministrators = llCSV2List(llList2String(parts, 0));
            gTrustedUsers = llCSV2List(llList2String(parts, 1));
        } 
        else if (num == OPEN_MY_MENU) {
            if (llGetLinkName(sender) == "main_module") {
                openMainMenu((key)msg);
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

            if (msg == "-Main-") { return; }
            else if (msg == "<-- Back") { openMainMenu(id); }
            else if (msg == "EROTIC") { openEroticMenu(id); }
            else if (msg == "PAIN") { openPainMenu(id); }
            else if (msg == "Devices") { openDevicesMenu(id); }
            else if (msg == "Stop All") {
                gEroticMode = FALSE;
                gPainActive = FALSE;
                clearPainRestrictions();
                stopCurrentAnimation();
                broadcastToAllDevices("STOP", 0);
                sendEmote("all sensory protocols deactivated", 2);
                openMainMenu(id);
            }
            else if (llSubStringIndex(msg, "[DISABLE]") != -1) {
                gSensoryActive = FALSE;
                llInstantMessage(gWearer, "// Sensory experience protocols disabled //");
                openMainMenu(id);
            }
            else if (llSubStringIndex(msg, "[ENABLE]") != -1) {
                gSensoryActive = TRUE;
                llInstantMessage(gWearer, "// Sensory experience protocols enabled //");
                openMainMenu(id);
            }
            // Handle erotic commands
            else if (llListFindList(["Stimulate", "Climax", "Tease", "Edge", "Penetrate", "Oral", "Low Buzz", "Med Buzz", "High Buzz", "All Devices", "INM Only", "Xcite Only", "Stop Erotic"], [msg]) != -1) {
                processEroticCommand(msg, id);
                openEroticMenu(id);
            }
            // Handle pain commands  
            else if (llListFindList(["Shock", "Poke/Spike", "Burn", "Impact", "Torture", "Agony", "Stop Pain"], [msg]) != -1) {
                processPainCommand(msg, id);
                openPainMenu(id);
            }
            // Handle device commands
            else if (msg == "Scan All") {
                // Scan for all device types
                llSay(LOVENSE_CHANNEL, "LVS:DEVICE_SCAN");
                llSay(INM_CHANNEL, "SCAN_GENITALS");
                llSay(XCITE_CHANNEL, "DEVICE_SCAN");
                llSay(SENSATIONS_CHANNEL, "SENS:SCAN");
                llSensor("", NULL_KEY, PASSIVE, 20.0, PI);
                llInstantMessage(id, "Scanning for all adult device types...");
                openDevicesMenu(id);
            }
            else if (msg == "Test Lovense") {
                broadcastToLovense("TEST", 50);
                llInstantMessage(id, "Test signal sent to Lovense devices.");
                openDevicesMenu(id);
            }
            else if (msg == "Test INM") {
                sendToINM("TEST", 50);
                llInstantMessage(id, "Test signal sent to INM genitals.");
                openDevicesMenu(id);
            }
            else if (msg == "Test Xcite") {
                sendToXcite("TEST", 50);
                llInstantMessage(id, "Test signal sent to Xcite devices.");
                openDevicesMenu(id);
            }
            else if (msg == "Test Sens") {
                sendToSensations("TEST", 50);
                llInstantMessage(id, "Test signal sent to Sensations devices.");
                openDevicesMenu(id);
            }
            else if (msg == "Connect All") {
                broadcastToAllDevices("CONNECT", 0);
                llInstantMessage(id, "Connection request sent to all device types.");
                openDevicesMenu(id);
            }
            else {
                openMainMenu(id);
            }
        }
        // Handle adult device system responses
        else if (chan == LOVENSE_CHANNEL && llSubStringIndex(msg, "LVS:") == 0) {
            list parts = llParseString2List(msg, [":"], []);
            string command = llList2String(parts, 1);
            
            if (command == "CONNECTED") {
                string device = llList2String(parts, 2);
                if (llListFindList(gConnectedDevices, [device]) == -1) {
                    gConnectedDevices += [device];
                    llInstantMessage(gWearer, "// Lovense device connected: " + device + " //");
                }
            }
            else if (command == "DISCONNECTED") {
                string device = llList2String(parts, 2);
                integer idx = llListFindList(gConnectedDevices, [device]);
                if (idx != -1) {
                    gConnectedDevices = llDeleteSubList(gConnectedDevices, idx, idx);
                    llInstantMessage(gWearer, "// Lovense device disconnected: " + device + " //");
                }
            }
        }
        // Handle INM (It's Not Mine) responses
        else if (chan == INM_CHANNEL) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "GENITAL_READY" || command == "INM_CONNECTED") {
                string device = llList2String(parts, 1);
                if (llListFindList(gConnectedINM, [device]) == -1) {
                    gConnectedINM += [device];
                    llInstantMessage(gWearer, "// INM genital system connected: " + device + " //");
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
                    llInstantMessage(gWearer, "// Xcite device connected //");
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
                    llInstantMessage(gWearer, "// Sensations device connected: " + device + " //");
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
                
                llInstantMessage(gWearer, "// Compatible device detected: " + name + " //");
                sendToRLVRelay("@sit:" + (string)detected + "=force", detected);
            }
        }
    }

    timer() {
        // Handle pain effect duration
        if (gTempRestrictions) {
            clearPainRestrictions();
            llInstantMessage(gWearer, "// Pain effect duration expired - systems recovering //");
        } else {
            llListenRemove(gListenHandle);
        }
    }
}
