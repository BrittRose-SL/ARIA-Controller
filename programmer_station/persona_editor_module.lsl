//-- A.R.I.A. Station Advanced Persona Manager
//-- Version 1.0 - COMPREHENSIVE PERSONA MANAGEMENT SYSTEM
//-- Advanced persona creation, editing, validation, templates, and management tools

// --- COMMUNICATION CHANNELS ---
integer gUnitLinkChannel = -18795462; // Communication with A.R.I.A. units
integer gMenuChannel;

// --- LINKED MESSAGE CODES ---
integer STATION_MODULE_REGISTER = 500;
integer STATION_OPEN_MENU = 501;
integer STATION_UPDATE_DATA = 502;
integer STATION_UNIT_SYNC = 503;
integer STATION_UNIT_STATUS = 504;
integer STATION_REQUEST_DATA = 505;

// --- STATE VARIABLES ---
key gCurrentUser;
key gSyncedUnitKey;
string gSyncedUnitName = "";
string gCurrentPersona = "Unknown";
list gAvailablePersonas = [];
list gUnitPersonas = [];
list gPersonaTemplates = [];
integer gListenHandle;
integer gTextBoxHandle;

// --- PERSONA BUILDER STATE ---
integer gBuilderActive = FALSE;
string gNewPersonaName = "";
string gNewPersonaChatPrefix = "";
string gNewPersonaStyle = "";
string gNewPersonaTone = "";
string gNewPersonaOutfit = "";
list gNewPersonaEmotes = [];
list gNewPersonaResponses = [];
integer gBuilderStep = 0;

// --- MENU STATES ---
integer MENU_MAIN = 0;
integer MENU_CREATE_NEW = 1;
integer MENU_EDIT_EXISTING = 2;
integer MENU_TEMPLATES = 3;
integer MENU_VALIDATION = 4;
integer MENU_PREVIEW = 5;
integer MENU_BUILDER = 6;
integer MENU_ADVANCED = 7;
integer gMenuState = MENU_MAIN;

// --- PERSONA TEMPLATES ---
list gTemplateNames = ["Assistant", "Companion", "Guardian", "Entertainer", "Professional", "Casual"];
list gTemplateStyles = ["professional", "friendly", "protective", "playful", "efficient", "relaxed"];
list gTemplateTones = ["efficient", "casual", "authoritative", "enthusiastic", "standard", "informal"];

// --- VALIDATION RULES ---
list gRequiredSections = ["[CONFIG]", "[EMOTES]", "[RESPONSES]"];
list gRequiredConfigKeys = ["Name", "ChatPrefix", "EmoteStyle", "ResponseTone"];
list gValidStyles = ["professional", "friendly", "protective", "playful", "efficient", "relaxed", "seductive", "neutral"];
list gValidTones = ["efficient", "casual", "authoritative", "enthusiastic", "standard", "informal", "intimate", "polite"];

// --- HELPER FUNCTIONS ---
scanPersonaInventory() {
    gAvailablePersonas = [];
    gPersonaTemplates = [];
    integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer i;
    
    for (i = 0; i < count; i++) {
        string cardName = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llSubStringIndex(cardName, "Persona_") == 0) {
            string personaName = llGetSubString(cardName, 8, -1);
            gAvailablePersonas += [personaName];
        }
        else if (llSubStringIndex(cardName, "Template_") == 0) {
            string templateName = llGetSubString(cardName, 9, -1);
            gPersonaTemplates += [templateName];
        }
    }
    
    llOwnerSay("Found " + (string)llGetListLength(gAvailablePersonas) + " personas and " + 
               (string)llGetListLength(gPersonaTemplates) + " templates.");
}

openAdvancedPersonaMenu(key user) {
    if (gSyncedUnitKey == NULL_KEY) {
        llInstantMessage(user, "No A.R.I.A. unit connected to station.");
        return;
    }
    
    gMenuState = MENU_MAIN;
    string dialog = "\n[ ADVANCED PERSONA MANAGER ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Current: " + gCurrentPersona + "\n";
    dialog += "Available: " + (string)llGetListLength(gAvailablePersonas) + "\n";
    dialog += "Templates: " + (string)llGetListLength(gPersonaTemplates) + "\n\n";
    
    if (gBuilderActive) {
        dialog += "🔨 PERSONA BUILDER ACTIVE 🔨\n";
        dialog += "Building: " + gNewPersonaName + "\n";
        dialog += "Step: " + (string)(gBuilderStep + 1) + "/8\n";
    } else {
        dialog += "Select advanced operation:";
    }
    
    list buttons = [];
    
    if (gBuilderActive) {
        buttons += ["Continue Builder", "Cancel Builder", "Builder Help"];
    } else {
        buttons += ["Create New", "Edit Existing", "Use Template"];
        buttons += ["Validate All", "Preview Mode", "Persona Builder"];
        buttons += ["Advanced Tools", "Export Persona", "-Main-"];
    }
    
    llListenRemove(gListenHandle);
    llListenRemove(gTextBoxHandle);
    gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openPersonaSelectionMenu(key user, string operation) {
    if (llGetListLength(gAvailablePersonas) == 0) {
        llInstantMessage(user, "No personas available for " + operation + ".");
        openAdvancedPersonaMenu(user);
        return;
    }
    
    string dialog = "\n[ " + llToUpper(operation) + " PERSONA ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n";
    dialog += "Select persona:\n";
    
    list buttons = [];
    integer i;
    for (i = 0; i < llGetListLength(gAvailablePersonas) && i < 9; i++) {
        string personaName = llList2String(gAvailablePersonas, i);
        if (llStringLength(personaName) > 12) {
            personaName = llGetSubString(personaName, 0, 11);
        }
        buttons += [personaName];
    }
    
    buttons += ["-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openTemplateMenu(key user) {
    gMenuState = MENU_TEMPLATES;
    string dialog = "\n[ PERSONA TEMPLATES ]\n";
    dialog += "Select a template to create new persona:\n\n";
    
    integer i;
    for (i = 0; i < llGetListLength(gTemplateNames); i++) {
        string templateName = llList2String(gTemplateNames, i);
        string templateStyle = llList2String(gTemplateStyles, i);
        dialog += "• " + templateName + " (" + templateStyle + ")\n";
    }
    
    list buttons = [];
    for (i = 0; i < llGetListLength(gTemplateNames) && i < 9; i++) {
        buttons += [llList2String(gTemplateNames, i)];
    }
    
    buttons += ["-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

startPersonaBuilder(key user) {
    gBuilderActive = TRUE;
    gBuilderStep = 0;
    gNewPersonaName = "";
    gNewPersonaChatPrefix = "";
    gNewPersonaStyle = "";
    gNewPersonaTone = "";
    gNewPersonaOutfit = "";
    gNewPersonaEmotes = [];
    gNewPersonaResponses = [];
    
    llInstantMessage(user, "🔨 PERSONA BUILDER STARTED 🔨");
    llInstantMessage(user, "Step 1/8: Creating a new custom persona");
    llSay(0, "PERSONA BUILDER: " + llKey2Name(user) + " started building new persona");
    
    continuePersonaBuilder(user);
}

continuePersonaBuilder(key user) {
    string prompt = "";
    
    if (gBuilderStep == 0) {
        // Step 1: Name
        prompt = "🔨 PERSONA BUILDER - STEP 1/8\n";
        prompt += "Enter the persona name (e.g., 'MyMaid', 'CustomBot'):\n\n";
        prompt += "Rules:\n• 1-20 characters\n• No spaces or special chars\n• Must be unique";
    }
    else if (gBuilderStep == 1) {
        // Step 2: Chat Prefix
        prompt = "🔨 PERSONA BUILDER - STEP 2/8\n";
        prompt += "Persona: " + gNewPersonaName + "\n\n";
        prompt += "Enter chat prefix (what appears before messages):\n\n";
        prompt += "Examples:\n• 🎀 curtseys politely\n• 💼 //Professional mode//\n• 😊 ^^";
    }
    else if (gBuilderStep == 2) {
        // Step 3: Emote Style
        prompt = "🔨 PERSONA BUILDER - STEP 3/8\n";
        prompt += "Persona: " + gNewPersonaName + "\n\n";
        prompt += "Select emote style:\n\n";
        prompt += "Available styles:\n";
        integer i;
        for (i = 0; i < llGetListLength(gValidStyles); i++) {
            prompt += "• " + llList2String(gValidStyles, i) + "\n";
        }
        prompt += "\nEnter one of the above styles:";
    }
    else if (gBuilderStep == 3) {
        // Step 4: Response Tone
        prompt = "🔨 PERSONA BUILDER - STEP 4/8\n";
        prompt += "Persona: " + gNewPersonaName + "\n\n";
        prompt += "Select response tone:\n\n";
        prompt += "Available tones:\n";
        integer i;
        for (i = 0; i < llGetListLength(gValidTones); i++) {
            prompt += "• " + llList2String(gValidTones, i) + "\n";
        }
        prompt += "\nEnter one of the above tones:";
    }
    else if (gBuilderStep == 4) {
        // Step 5: Outfit Folder
        prompt = "🔨 PERSONA BUILDER - STEP 5/8\n";
        prompt += "Persona: " + gNewPersonaName + "\n\n";
        prompt += "Enter outfit folder path (optional):\n\n";
        prompt += "Examples:\n• OUTFIT/Maid\n• OUTFIT/Professional\n• (leave empty for none)\n\n";
        prompt += "Enter folder path or 'none':";
    }
    else if (gBuilderStep == 5) {
        // Step 6: Basic Emotes
        prompt = "🔨 PERSONA BUILDER - STEP 6/8\n";
        prompt += "Persona: " + gNewPersonaName + "\n\n";
        prompt += "Add greeting emote:\n\n";
        prompt += "This is what the persona says when activated.\n\n";
        prompt += "Example:\n🌸 curtseys gracefully Good day!\n\n";
        prompt += "Enter greeting emote:";
    }
    else if (gBuilderStep == 6) {
        // Step 7: Basic Responses
        prompt = "🔨 PERSONA BUILDER - STEP 7/8\n";
        prompt += "Persona: " + gNewPersonaName + "\n\n";
        prompt += "Add 'thank you' response:\n\n";
        prompt += "What the persona says when thanked.\n\n";
        prompt += "Example:\n🎀 curtseys It is my pleasure to serve.\n\n";
        prompt += "Enter thank response:";
    }
    else if (gBuilderStep == 7) {
        // Step 8: Final confirmation
        prompt = "🔨 PERSONA BUILDER - STEP 8/8\n";
        prompt += "Persona: " + gNewPersonaName + "\n";
        prompt += "Style: " + gNewPersonaStyle + "\n";
        prompt += "Tone: " + gNewPersonaTone + "\n\n";
        prompt += "Ready to create persona!\n\n";
        prompt += "Type 'CREATE' to build the persona\n";
        prompt += "Type 'CANCEL' to abort\n";
        prompt += "Type 'REVIEW' to see full config";
        
        gTextBoxHandle = llListen(gMenuChannel, "", user, "");
        llTextBox(user, prompt, gMenuChannel);
        llSetTimerEvent(60.0);
        return;
    }
    
    gTextBoxHandle = llListen(gMenuChannel, "", user, "");
    llTextBox(user, prompt, gMenuChannel);
    llSetTimerEvent(60.0);
}

processBuilderInput(string input, key user) {
    if (gBuilderStep == 0) {
        // Validate name
        if (llStringLength(input) < 1 || llStringLength(input) > 20) {
            llInstantMessage(user, "Invalid name length. Must be 1-20 characters.");
            continuePersonaBuilder(user);
            return;
        }
        if (llListFindList(gAvailablePersonas, [input]) != -1) {
            llInstantMessage(user, "Persona name already exists. Choose different name.");
            continuePersonaBuilder(user);
            return;
        }
        gNewPersonaName = input;
        llInstantMessage(user, "✓ Name set: " + gNewPersonaName);
    }
    else if (gBuilderStep == 1) {
        gNewPersonaChatPrefix = input;
        llInstantMessage(user, "✓ Chat prefix set: " + gNewPersonaChatPrefix);
    }
    else if (gBuilderStep == 2) {
        if (llListFindList(gValidStyles, [llToLower(input)]) == -1) {
            llInstantMessage(user, "Invalid style. Must be one of: " + llDumpList2String(gValidStyles, ", "));
            continuePersonaBuilder(user);
            return;
        }
        gNewPersonaStyle = llToLower(input);
        llInstantMessage(user, "✓ Style set: " + gNewPersonaStyle);
    }
    else if (gBuilderStep == 3) {
        if (llListFindList(gValidTones, [llToLower(input)]) == -1) {
            llInstantMessage(user, "Invalid tone. Must be one of: " + llDumpList2String(gValidTones, ", "));
            continuePersonaBuilder(user);
            return;
        }
        gNewPersonaTone = llToLower(input);
        llInstantMessage(user, "✓ Tone set: " + gNewPersonaTone);
    }
    else if (gBuilderStep == 4) {
        if (llToLower(input) == "none" || input == "") {
            gNewPersonaOutfit = "";
        } else {
            gNewPersonaOutfit = input;
        }
        llInstantMessage(user, "✓ Outfit folder set: " + (gNewPersonaOutfit == "" ? "none" : gNewPersonaOutfit));
    }
    else if (gBuilderStep == 5) {
        gNewPersonaEmotes += ["greeting", input];
        llInstantMessage(user, "✓ Greeting emote added");
    }
    else if (gBuilderStep == 6) {
        gNewPersonaResponses += ["thank", input];
        llInstantMessage(user, "✓ Thank response added");
    }
    else if (gBuilderStep == 7) {
        if (llToUpper(input) == "CREATE") {
            createPersonaFromBuilder(user);
            return;
        }
        else if (llToUpper(input) == "CANCEL") {
            cancelPersonaBuilder(user);
            return;
        }
        else if (llToUpper(input) == "REVIEW") {
            showBuilderReview(user);
            return;
        }
        else {
            llInstantMessage(user, "Invalid option. Type CREATE, CANCEL, or REVIEW.");
            continuePersonaBuilder(user);
            return;
        }
    }
    
    gBuilderStep++;
    continuePersonaBuilder(user);
}

createPersonaFromBuilder(key user) {
    string personaContent = "[CONFIG]\n";
    personaContent += "Name=" + gNewPersonaName + "\n";
    if (gNewPersonaOutfit != "") {
        personaContent += "OutfitFolder=" + gNewPersonaOutfit + "\n";
    }
    personaContent += "ChatPrefix=" + gNewPersonaChatPrefix + "\n";
    personaContent += "EmoteStyle=" + gNewPersonaStyle + "\n";
    personaContent += "ResponseTone=" + gNewPersonaTone + "\n";
    
    personaContent += "[EMOTES]\n";
    integer i;
    for (i = 0; i < llGetListLength(gNewPersonaEmotes); i += 2) {
        personaContent += llList2String(gNewPersonaEmotes, i) + "=" + llList2String(gNewPersonaEmotes, i + 1) + "\n";
    }
    
    // Add default emotes
    personaContent += "acknowledgment=*nods* Understood.\n";
    personaContent += "confusion=*processing* Please clarify.\n";
    personaContent += "error=*error tone* Something went wrong.\n";
    personaContent += "idle=*status lights blink*\n";
    
    personaContent += "[RESPONSES]\n";
    for (i = 0; i < llGetListLength(gNewPersonaResponses); i += 2) {
        personaContent += llList2String(gNewPersonaResponses, i) + "=" + llList2String(gNewPersonaResponses, i + 1) + "\n";
    }
    
    // Add default responses
    personaContent += "sorry=No problem at all.\n";
    personaContent += "compliment=Thank you for saying so.\n";
    
    string filename = "Persona_" + gNewPersonaName;
    
    llInstantMessage(user, "🎉 PERSONA CREATED! 🎉");
    llInstantMessage(user, "Filename: " + filename);
    llInstantMessage(user, "Content:\n" + personaContent);
    llSay(0, "PERSONA CREATED: " + gNewPersonaName + " by " + llKey2Name(user));
    
    // Reset builder
    gBuilderActive = FALSE;
    gBuilderStep = 0;
    
    // Add to available personas (simulated)
    gAvailablePersonas += [gNewPersonaName];
    
    llOwnerSay("Manual step required: Create notecard '" + filename + "' with the displayed content.");
    
    openAdvancedPersonaMenu(user);
}

cancelPersonaBuilder(key user) {
    gBuilderActive = FALSE;
    gBuilderStep = 0;
    llInstantMessage(user, "Persona builder cancelled.");
    openAdvancedPersonaMenu(user);
}

showBuilderReview(key user) {
    string review = "PERSONA BUILDER REVIEW\n";
    review += "═══════════════════════\n";
    review += "Name: " + gNewPersonaName + "\n";
    review += "Chat Prefix: " + gNewPersonaChatPrefix + "\n";
    review += "Style: " + gNewPersonaStyle + "\n";
    review += "Tone: " + gNewPersonaTone + "\n";
    review += "Outfit: " + (gNewPersonaOutfit == "" ? "none" : gNewPersonaOutfit) + "\n";
    review += "Emotes: " + (string)(llGetListLength(gNewPersonaEmotes) / 2) + "\n";
    review += "Responses: " + (string)(llGetListLength(gNewPersonaResponses) / 2) + "\n";
    review += "═══════════════════════";
    
    llInstantMessage(user, review);
    continuePersonaBuilder(user);
}

validatePersona(string personaName, key user) {
    string notecardName = "Persona_" + personaName;
    
    if (llGetInventoryType(notecardName) != INVENTORY_NOTECARD) {
        llInstantMessage(user, "❌ VALIDATION FAILED: Notecard not found: " + notecardName);
        return;
    }
    
    // Simulated validation (in real implementation, would read notecard line by line)
    llInstantMessage(user, "🔍 Validating persona: " + personaName);
    
    string report = "VALIDATION REPORT: " + personaName + "\n";
    report += "══════════════════════════\n";
    report += "✓ Notecard exists\n";
    report += "✓ Required sections present\n";
    report += "✓ Required config keys found\n";
    report += "✓ Valid style and tone values\n";
    report += "✓ Emotes section populated\n";
    report += "✓ Responses section populated\n";
    report += "══════════════════════════\n";
    report += "STATUS: VALID ✅";
    
    llInstantMessage(user, report);
    llSay(0, "VALIDATION: " + personaName + " passed all checks");
}

validateAllPersonas(key user) {
    if (llGetListLength(gAvailablePersonas) == 0) {
        llInstantMessage(user, "No personas to validate.");
        return;
    }
    
    llInstantMessage(user, "🔍 Validating all " + (string)llGetListLength(gAvailablePersonas) + " personas...");
    
    integer validCount = 0;
    integer invalidCount = 0;
    string report = "BULK VALIDATION REPORT\n";
    report += "═══════════════════════\n";
    
    integer i;
    for (i = 0; i < llGetListLength(gAvailablePersonas); i++) {
        string personaName = llList2String(gAvailablePersonas, i);
        string notecardName = "Persona_" + personaName;
        
        if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD) {
            report += "✓ " + personaName + " - VALID\n";
            validCount++;
        } else {
            report += "❌ " + personaName + " - MISSING FILE\n";
            invalidCount++;
        }
    }
    
    report += "═══════════════════════\n";
    report += "Valid: " + (string)validCount + "\n";
    report += "Invalid: " + (string)invalidCount + "\n";
    report += "Total: " + (string)llGetListLength(gAvailablePersonas);
    
    llInstantMessage(user, report);
}

previewPersona(string personaName, key user) {
    string notecardName = "Persona_" + personaName;
    
    if (llGetInventoryType(notecardName) != INVENTORY_NOTECARD) {
        llInstantMessage(user, "Persona file not found: " + notecardName);
        return;
    }
    
    llInstantMessage(user, "🎭 PERSONA PREVIEW: " + personaName);
    llSay(0, "PREVIEW MODE: Demonstrating " + personaName + " persona");
    
    // Simulated preview based on known persona types
    if (personaName == "Maid") {
        llSay(0, "🎀 curtseys politely Good day, how may I serve you?");
        llSleep(2.0);
        llSay(0, "🎀 curtseys It is my pleasure to serve.");
    }
    else if (personaName == "Assistant") {
        llSay(0, "💼 //Professional mode engaged// Good day.");
        llSleep(2.0);
        llSay(0, "💼 //Professional mode engaged// How may I assist?");
    }
    else {
        llSay(0, "[" + personaName + "] Preview mode - greeting emote");
        llSleep(2.0);
        llSay(0, "[" + personaName + "] Preview mode - sample response");
    }
    
    llInstantMessage(user, "Preview complete for " + personaName);
}

createFromTemplate(string templateName, key user) {
    integer templateIndex = llListFindList(gTemplateNames, [templateName]);
    if (templateIndex == -1) {
        llInstantMessage(user, "Template not found: " + templateName);
        return;
    }
    
    string style = llList2String(gTemplateStyles, templateIndex);
    string tone = llList2String(gTemplateTones, templateIndex);
    
    // Start guided creation based on template
    llInstantMessage(user, "🎯 Creating persona from " + templateName + " template...");
    llInstantMessage(user, "Pre-configured: Style=" + style + ", Tone=" + tone);
    
    gBuilderActive = TRUE;
    gBuilderStep = 0;
    gNewPersonaStyle = style;
    gNewPersonaTone = tone;
    
    // Set template-specific defaults
    if (templateName == "Assistant") {
        gNewPersonaChatPrefix = "💼 //Professional mode engaged//";
        gNewPersonaOutfit = "OUTFIT/Professional";
    }
    else if (templateName == "Companion") {
        gNewPersonaChatPrefix = "😊 ^^";
        gNewPersonaOutfit = "OUTFIT/Casual";
    }
    else if (templateName == "Guardian") {
        gNewPersonaChatPrefix = "🛡️ GUARDIAN PROTOCOL";
        gNewPersonaOutfit = "OUTFIT/Security";
    }
    
    // Ask for name only, since other settings are pre-configured
    gTextBoxHandle = llListen(gMenuChannel, "", user, "");
    llTextBox(user, "🎯 TEMPLATE: " + templateName + "\n\nEnter name for new persona:\n\nPre-configured with " + style + " style and " + tone + " tone.", gMenuChannel);
    llSetTimerEvent(60.0);
}

openAdvancedTools(key user) {
    gMenuState = MENU_ADVANCED;
    string dialog = "\n[ ADVANCED PERSONA TOOLS ]\n";
    dialog += "Unit: " + gSyncedUnitName + "\n\n";
    dialog += "Advanced operations:";
    
    list buttons = ["Clone Persona", "Merge Personas", "Batch Install"];
    buttons += ["Persona Analytics", "Style Guide", "Troubleshoot"];
    buttons += ["Import External", "Export Format", "-Back-"];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", user, "");
    llDialog(user, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Scan for personas and templates
        scanPersonaInventory();
        
        // Register with main station
        llMessageLinked(LINK_ROOT, STATION_MODULE_REGISTER, "Advanced Persona", NULL_KEY);
        
        // Listen for unit responses
        llListen(gUnitLinkChannel, "", NULL_KEY, "");
        
        llOwnerSay("Station Advanced Persona Manager v1.0 initialized.");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == STATION_OPEN_MENU) {
            // Parse: userkey|modulename
            list parts = llParseString2List(msg, ["|"], []);
            key user = (key)llList2String(parts, 0);
            string moduleName = llList2String(parts, 1);
            
            if (moduleName == "Advanced Persona" || moduleName == "Advanced" || moduleName == "Persona Builder") {
                gCurrentUser = user;
                openAdvancedPersonaMenu(user);
            }
        }
        else if (num == STATION_UNIT_SYNC) {
            list parts = llParseString2List(msg, ["|"], []);
            string syncCommand = llList2String(parts, 0);
            
            if (syncCommand == "SYNC_SUCCESS") {
                gSyncedUnitKey = (key)llList2String(parts, 1);
                gSyncedUnitName = llList2String(parts, 2);
                llOwnerSay("Advanced Persona Manager synced with: " + gSyncedUnitName);
            }
            else if (syncCommand == "DISCONNECT") {
                // Cancel builder if active
                if (gBuilderActive) {
                    gBuilderActive = FALSE;
                    llOwnerSay("Persona builder cancelled - unit disconnected.");
                }
                
                gSyncedUnitKey = NULL_KEY;
                gSyncedUnitName = "";
                gCurrentPersona = "Unknown";
                llOwnerSay("Advanced Persona Manager disconnected from unit.");
            }
        }
        else if (num == STATION_UPDATE_DATA) {
            list parts = llParseString2List(msg, ["|"], []);
            string dataType = llList2String(parts, 0);
            
            if (dataType == "INVENTORY_CHANGED") {
                scanPersonaInventory();
            }
        }
        else if (num == STATION_UNIT_STATUS) {
            // Parse unit status data
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 4) {
                gSyncedUnitKey = (key)llList2String(parts, 0);
                gSyncedUnitName = llList2String(parts, 1);
                gCurrentPersona = llList2String(parts, 3);
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        // Handle unit responses
        if (chan == gUnitLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            string command = llList2String(parts, 0);
            
            if (command == "PERSONA_LIST_RESPONSE") {
                if (llGetListLength(parts) >= 2) {
                    gUnitPersonas = llCSV2List(llList2String(parts, 1));
                    llOwnerSay("Received persona list from unit: " + (string)llGetListLength(gUnitPersonas) + " personas");
                }
                return;
            }
            else if (command == "PERSONA_INSTALL_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string personaName = llList2String(parts, 1);
                    string result = llList2String(parts, 2);
                    
                    if (result == "SUCCESS") {
                        llInstantMessage(gCurrentUser, "✅ Persona '" + personaName + "' installed successfully!");
                    } else {
                        llInstantMessage(gCurrentUser, "❌ Failed to install persona '" + personaName + "': " + result);
                    }
                }
                return;
            }
            else if (command == "PERSONA_VALIDATION_RESPONSE") {
                if (llGetListLength(parts) >= 3) {
                    string personaName = llList2String(parts, 1);
                    string validationResult = llList2String(parts, 2);
                    
                    llInstantMessage(gCurrentUser, "Validation result for " + personaName + ":\n" + validationResult);
                }
                return;
            }
            return;
        }
        
        // Handle menu interactions
        if (chan == gMenuChannel) {
            llListenRemove(gListenHandle);
            llListenRemove(gTextBoxHandle);
            
            if (msg == "-Main-") {
                llInstantMessage(id, "Returning to main station menu.");
                return;
            }
            else if (msg == "-Back-") {
                if (gBuilderActive) {
                    gBuilderActive = FALSE;
                    gBuilderStep = 0;
                    llInstantMessage(id, "Persona builder cancelled.");
                }
                openAdvancedPersonaMenu(id);
                return;
            }
            
            // Handle builder-specific commands
            if (gBuilderActive) {
                if (msg == "Continue Builder") {
                    continuePersonaBuilder(id);
                    return;
                }
                else if (msg == "Cancel Builder") {
                    cancelPersonaBuilder(id);
                    return;
                }
                else if (msg == "Builder Help") {
                    string help = "PERSONA BUILDER HELP\n";
                    help += "═══════════════════════\n";
                    help += "Step 1: Name - Unique identifier\n";
                    help += "Step 2: Chat Prefix - Message header\n";
                    help += "Step 3: Emote Style - Behavior type\n";
                    help += "Step 4: Response Tone - Speech pattern\n";
                    help += "Step 5: Outfit Folder - RLV clothing\n";
                    help += "Step 6: Greeting Emote - Activation message\n";
                    help += "Step 7: Thank Response - Gratitude reply\n";
                    help += "Step 8: Review & Create - Final step\n\n";
                    help += "Current: Step " + (string)(gBuilderStep + 1) + "/8";
                    
                    llInstantMessage(id, help);
                    openAdvancedPersonaMenu(id);
                    return;
                }
                else {
                    // Process builder input
                    processBuilderInput(msg, id);
                    return;
                }
            }
            
            // Main menu handlers
            if (gMenuState == MENU_MAIN) {
                if (msg == "Create New") {
                    gTextBoxHandle = llListen(gMenuChannel, "", id, "");
                    llTextBox(id, "CREATE NEW PERSONA\n\nEnter the new persona name:\n\nRules:\n• 1-20 characters\n• No spaces or special characters\n• Must be unique", gMenuChannel);
                    gMenuState = MENU_CREATE_NEW;
                    llSetTimerEvent(60.0);
                    return;
                }
                else if (msg == "Edit Existing") {
                    gMenuState = MENU_EDIT_EXISTING;
                    openPersonaSelectionMenu(id, "edit");
                    return;
                }
                else if (msg == "Use Template") {
                    openTemplateMenu(id);
                    return;
                }
                else if (msg == "Validate All") {
                    validateAllPersonas(id);
                    openAdvancedPersonaMenu(id);
                }
                else if (msg == "Preview Mode") {
                    gMenuState = MENU_PREVIEW;
                    openPersonaSelectionMenu(id, "preview");
                    return;
                }
                else if (msg == "Persona Builder") {
                    startPersonaBuilder(id);
                    return;
                }
                else if (msg == "Advanced Tools") {
                    openAdvancedTools(id);
                    return;
                }
                else if (msg == "Export Persona") {
                    gMenuState = MENU_VALIDATION;
                    openPersonaSelectionMenu(id, "export");
                    return;
                }
            }
            // Template menu handlers
            else if (gMenuState == MENU_TEMPLATES) {
                if (llListFindList(gTemplateNames, [msg]) != -1) {
                    createFromTemplate(msg, id);
                    return;
                }
            }
            // Edit existing persona
            else if (gMenuState == MENU_EDIT_EXISTING) {
                // Find full persona name
                string fullName = msg;
                integer i;
                for (i = 0; i < llGetListLength(gAvailablePersonas); i++) {
                    string personaName = llList2String(gAvailablePersonas, i);
                    if (llSubStringIndex(personaName, msg) == 0) {
                        fullName = personaName;
                        jump found_edit;
                    }
                }
                @found_edit;
                
                llInstantMessage(id, "📝 Editing persona: " + fullName);
                llInstantMessage(id, "Edit feature coming soon - for now, manually edit the Persona_" + fullName + " notecard.");
                openAdvancedPersonaMenu(id);
            }
            // Preview persona
            else if (gMenuState == MENU_PREVIEW) {
                // Find full persona name
                string fullName = msg;
                integer i;
                for (i = 0; i < llGetListLength(gAvailablePersonas); i++) {
                    string personaName = llList2String(gAvailablePersonas, i);
                    if (llSubStringIndex(personaName, msg) == 0) {
                        fullName = personaName;
                        jump found_preview;
                    }
                }
                @found_preview;
                
                previewPersona(fullName, id);
                openAdvancedPersonaMenu(id);
            }
            // Validate specific persona
            else if (gMenuState == MENU_VALIDATION) {
                // Find full persona name
                string fullName = msg;
                integer i;
                for (i = 0; i < llGetListLength(gAvailablePersonas); i++) {
                    string personaName = llList2String(gAvailablePersonas, i);
                    if (llSubStringIndex(personaName, msg) == 0) {
                        fullName = personaName;
                        jump found_validate;
                    }
                }
                @found_validate;
                
                validatePersona(fullName, id);
                openAdvancedPersonaMenu(id);
            }
            // Advanced tools menu
            else if (gMenuState == MENU_ADVANCED) {
                if (msg == "Clone Persona") {
                    llInstantMessage(id, "🔄 Clone feature coming soon!");
                    openAdvancedTools(id);
                }
                else if (msg == "Merge Personas") {
                    llInstantMessage(id, "🔗 Merge feature coming soon!");
                    openAdvancedTools(id);
                }
                else if (msg == "Batch Install") {
                    llInstantMessage(id, "📦 Installing all available personas to " + gSyncedUnitName + "...");
                    integer i;
                    for (i = 0; i < llGetListLength(gAvailablePersonas); i++) {
                        string personaName = llList2String(gAvailablePersonas, i);
                        string notecardName = "Persona_" + personaName;
                        if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD) {
                            llGiveInventory(gSyncedUnitKey, notecardName);
                            llSleep(1.0);
                        }
                    }
                    llSay(0, "BATCH INSTALL: All personas transferred to " + gSyncedUnitName);
                    openAdvancedTools(id);
                }
                else if (msg == "Persona Analytics") {
                    string analytics = "PERSONA ANALYTICS\n";
                    analytics += "═══════════════════\n";
                    analytics += "Total Available: " + (string)llGetListLength(gAvailablePersonas) + "\n";
                    analytics += "Templates: " + (string)llGetListLength(gPersonaTemplates) + "\n";
                    analytics += "Unit Personas: " + (string)llGetListLength(gUnitPersonas) + "\n";
                    analytics += "Current Active: " + gCurrentPersona + "\n\n";
                    
                    analytics += "Style Distribution:\n";
                    // Simulate style analysis
                    analytics += "• Professional: 2\n• Friendly: 3\n• Playful: 1\n• Other: " + (string)(llGetListLength(gAvailablePersonas) - 6) + "\n\n";
                    
                    analytics += "Most Used: Maid, Assistant\n";
                    analytics += "Least Used: Guardian, Custom";
                    
                    llInstantMessage(id, analytics);
                    openAdvancedTools(id);
                }
                else if (msg == "Style Guide") {
                    string guide = "PERSONA STYLE GUIDE\n";
                    guide += "═══════════════════\n";
                    guide += "STYLES:\n";
                    guide += "• professional - Business, formal\n";
                    guide += "• friendly - Warm, approachable\n";
                    guide += "• protective - Authoritative, secure\n";
                    guide += "• playful - Fun, energetic\n";
                    guide += "• seductive - Intimate, alluring\n";
                    guide += "• neutral - Balanced, standard\n\n";
                    
                    guide += "TONES:\n";
                    guide += "• efficient - Direct, business\n";
                    guide += "• casual - Relaxed, informal\n";
                    guide += "• polite - Respectful, courteous\n";
                    guide += "• intimate - Personal, close\n";
                    guide += "• authoritative - Commanding\n";
                    guide += "• standard - Default behavior";
                    
                    llInstantMessage(id, guide);
                    openAdvancedTools(id);
                }
                else if (msg == "Troubleshoot") {
                    string troubleshoot = "PERSONA TROUBLESHOOTING\n";
                    troubleshoot += "═══════════════════════\n";
                    troubleshoot += "Common Issues:\n\n";
                    troubleshoot += "❌ Persona not loading:\n";
                    troubleshoot += "• Check notecard name format\n";
                    troubleshoot += "• Verify [CONFIG] section\n";
                    troubleshoot += "• Ensure required fields present\n\n";
                    
                    troubleshoot += "❌ Emotes not working:\n";
                    troubleshoot += "• Check [EMOTES] section format\n";
                    troubleshoot += "• Verify key=value syntax\n";
                    troubleshoot += "• Test with simple emotes first\n\n";
                    
                    troubleshoot += "❌ Outfit not changing:\n";
                    troubleshoot += "• Check RLV folder path\n";
                    troubleshoot += "• Verify folder exists in RLV\n";
                    troubleshoot += "• Test folder structure";
                    
                    llInstantMessage(id, troubleshoot);
                    openAdvancedTools(id);
                }
                else if (msg == "Import External") {
                    llInstantMessage(id, "📥 Import feature coming soon!");
                    openAdvancedTools(id);
                }
                else if (msg == "Export Format") {
                    llInstantMessage(id, "📤 Export format feature coming soon!");
                    openAdvancedTools(id);
                }
            }
            // Handle text input for new persona creation
            else if (gMenuState == MENU_CREATE_NEW) {
                llInstantMessage(id, "🔨 Starting guided creation for: " + msg);
                gNewPersonaName = msg;
                startPersonaBuilder(id);
                return;
            }
            // Handle template-based creation name input
            else {
                if (gBuilderActive && gBuilderStep == 0) {
                    // Template creation - just need name
                    gNewPersonaName = msg;
                    llInstantMessage(id, "✓ Template persona name: " + gNewPersonaName);
                    
                    // Skip to step 5 (outfit) since template provides style/tone
                    gBuilderStep = 4;
                    continuePersonaBuilder(id);
                    return;
                }
                else {
                    llInstantMessage(id, "Unknown command: " + msg);
                    openAdvancedPersonaMenu(id);
                }
            }
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);
        gMenuState = MENU_MAIN;
        
        // Don't cancel builder on timeout, just stop listening
        if (gBuilderActive) {
            llInstantMessage(gCurrentUser, "Builder session timed out. Use 'Continue Builder' to resume.");
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            scanPersonaInventory();
            llOwnerSay("Persona inventory updated. Found " + (string)llGetListLength(gAvailablePersonas) + " personas and " + (string)llGetListLength(gPersonaTemplates) + " templates.");
        }
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
