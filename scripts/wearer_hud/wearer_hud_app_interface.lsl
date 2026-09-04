//-- A.R.I.A. Wearer HUD - Enhanced App Interface v4.0.1
//-- Visual Module & Restriction Status - September 8, 2025
//-- Right-side app status display with checkmarks and X indicators
//-- Attach to RIGHT SIDE HUD position
//-- CHANGES v4.0.2: Fixed status and list synchronization with the main HUD controller
//-- CHANGES v4.0.1: Fixed syntax error - removed unsupported 'static' keyword,
//                   moved compactMode to global scope for proper state management

string VERSION = "4.0.2";
string BUILD_DATE = "2025-09-08";

// Status indicator characters
string CHECK_ACTIVE = "✅";      // Module installed and active
string CHECK_INACTIVE = "✔️";    // Module installed but inactive
string X_MISSING = "❌";         // Module not installed
string X_BLOCKED = "🚫";         // Module blocked/error
string DOT_NEUTRAL = "⚪";       // Neutral/unknown status

// Restriction level indicators
string RESTRICTION_ACTIVE = "🔴";    // Restriction currently applied
string RESTRICTION_INACTIVE = "🟢";  // Restriction available but not applied
string RESTRICTION_UNAVAILABLE = "⚫"; // Restriction not available

// State variables
key gOwner;
integer gVisible = TRUE;
string gConnectedUnit = "";
integer gCompactMode = FALSE;    // Display mode toggle (moved from static local)

// Module tracking
list gInstalledModules = [];     // List of installed module names
list gActiveModules = [];        // List of currently active modules
list gBlockedModules = [];       // List of blocked/error modules

// High-level restriction categories
list gRestrictionCategories = [
    "Vision", "Mobility", "Communication", "Interaction", 
    "Inventory", "Teleport", "Attachment", "Avatar"
];

// Restriction status tracking
list gActiveRestrictions = [];       // Currently active restrictions
list gAvailableRestrictions = [];   // Available but inactive restrictions

// Configuration
integer UPDATE_INTERVAL = 3;

//-- MODULE STATUS FUNCTIONS --

// Check if module is installed
integer isModuleInstalled(string moduleName) {
    return (llListFindList(gInstalledModules, [moduleName]) != -1);
}

// Check if module is active
integer isModuleActive(string moduleName) {
    return (llListFindList(gActiveModules, [moduleName]) != -1);
}

// Check if module is blocked
integer isModuleBlocked(string moduleName) {
    return (llListFindList(gBlockedModules, [moduleName]) != -1);
}

// Get module status indicator
string getModuleStatusIcon(string moduleName) {
    if (isModuleBlocked(moduleName)) {
        return X_BLOCKED;
    }
    else if (!isModuleInstalled(moduleName)) {
        return X_MISSING;
    }
    else if (isModuleActive(moduleName)) {
        return CHECK_ACTIVE;
    }
    else {
        return CHECK_INACTIVE;
    }
}

// Get module status text
string getModuleStatusText(string moduleName) {
    if (isModuleBlocked(moduleName)) {
        return "BLOCKED";
    }
    else if (!isModuleInstalled(moduleName)) {
        return "NOT INSTALLED";
    }
    else if (isModuleActive(moduleName)) {
        return "ACTIVE";
    }
    else {
        return "INSTALLED";
    }
}

//-- RESTRICTION STATUS FUNCTIONS --

// Check if restriction category is active
integer isRestrictionActive(string category) {
    // Check if any restrictions in this category are active
    integer i;
    for (i = 0; i < llGetListLength(gActiveRestrictions); i++) {
        string restriction = llList2String(gActiveRestrictions, i);
        if (llSubStringIndex(llToLower(restriction), llToLower(category)) != -1) {
            return TRUE;
        }
    }
    return FALSE;
}

// Check if restriction category is available
integer isRestrictionAvailable(string category) {
    // Check if any restrictions in this category are available
    integer i;
    for (i = 0; i < llGetListLength(gAvailableRestrictions); i++) {
        string restriction = llList2String(gAvailableRestrictions, i);
        if (llSubStringIndex(llToLower(restriction), llToLower(category)) != -1) {
            return TRUE;
        }
    }
    // Also check active restrictions
    return isRestrictionActive(category);
}

// Get restriction status indicator
string getRestrictionStatusIcon(string category) {
    if (isRestrictionActive(category)) {
        return RESTRICTION_ACTIVE;
    }
    else if (isRestrictionAvailable(category)) {
        return RESTRICTION_INACTIVE;
    }
    else {
        return RESTRICTION_UNAVAILABLE;
    }
}

// Get restriction status text
string getRestrictionStatusText(string category) {
    if (isRestrictionActive(category)) {
        return "ACTIVE";
    }
    else if (isRestrictionAvailable(category)) {
        return "AVAILABLE";
    }
    else {
        return "N/A";
    }
}

//-- DISPLAY FUNCTIONS --

// Enhanced app status display with visual indicators
updateAppStatusDisplay() {
    if (!gVisible) {
        llSetText("", <1,1,1>, 0.0);
        return;
    }
    
    string display = "═══ APP STATUS ═══\n\n";
    
    if (gConnectedUnit == "") {
        display += "🔴 DISCONNECTED\n\n";
        display += "MODULES: Offline\n";
        display += "RESTRICTIONS: N/A\n";
    } else {
        display += "🟢 CONNECTED\n\n";
        
        // Module status section
        display += "═══ MODULES ═══\n";
        
        // Core modules to display
        list coreModules = [
            "Security", "Diagnostic", "Personality", 
            "RLV", "Sensors", "Communication"
        ];
        
        integer i;
        for (i = 0; i < llGetListLength(coreModules); i++) {
            string moduleName = llList2String(coreModules, i);
            string icon = getModuleStatusIcon(moduleName);
            string status = getModuleStatusText(moduleName);
            
            // Truncate module name if too long
            string displayName = moduleName;
            if (llStringLength(displayName) > 8) {
                displayName = llGetSubString(displayName, 0, 7) + "..";
            }
            
            display += icon + " " + displayName + "\n";
        }
        
        // Summary line
        integer totalInstalled = llGetListLength(gInstalledModules);
        integer totalActive = llGetListLength(gActiveModules);
        display += "\nTotal: " + (string)totalInstalled + " installed, " + (string)totalActive + " active\n\n";
        
        // Restriction status section
        display += "═══ RESTRICTIONS ═══\n";
        
        for (i = 0; i < llGetListLength(gRestrictionCategories); i++) {
            string category = llList2String(gRestrictionCategories, i);
            string icon = getRestrictionStatusIcon(category);
            string status = getRestrictionStatusText(category);
            
            // Truncate category name if too long
            string displayName = category;
            if (llStringLength(displayName) > 8) {
                displayName = llGetSubString(displayName, 0, 7) + "..";
            }
            
            display += icon + " " + displayName + "\n";
        }
        
        // Restriction summary
        integer activeCount = 0;
        for (i = 0; i < llGetListLength(gRestrictionCategories); i++) {
            string category = llList2String(gRestrictionCategories, i);
            if (isRestrictionActive(category)) {
                activeCount++;
            }
        }
        
        display += "\nActive: " + (string)activeCount + "/" + (string)llGetListLength(gRestrictionCategories);
    }
    
    // Color coding based on status
    vector color;
    if (gConnectedUnit == "") {
        color = <0.5, 0.5, 0.5>; // Gray when disconnected
    } else {
        integer totalActiveRestrictions = 0;
        integer i;
        for (i = 0; i < llGetListLength(gRestrictionCategories); i++) {
            string category = llList2String(gRestrictionCategories, i);
            if (isRestrictionActive(category)) {
                totalActiveRestrictions++;
            }
        }
        
        if (totalActiveRestrictions > 0) {
            color = <1.0, 0.3, 0.3>; // Red when restrictions active
        } else {
            color = <0.3, 0.8, 1.0>; // Blue when normal
        }
    }
    
    llSetText(display, color, 1.0);
}

// Compact display mode
updateCompactAppDisplay() {
    if (!gVisible) {
        llSetText("", <1,1,1>, 0.0);
        return;
    }
    
    string display = "";
    
    if (gConnectedUnit == "") {
        display = "🔴 APP OFFLINE\nNo modules available";
    }
    else {
        display = "🟢 APP CONNECTED\n";
        
        // Quick module status
        integer totalActive = llGetListLength(gActiveModules);
        integer totalInstalled = llGetListLength(gInstalledModules);
        display += "📦 Modules: " + (string)totalActive + "/" + (string)totalInstalled + "\n";
        
        // Quick restriction status
        integer activeRestrictions = 0;
        integer i;
        for (i = 0; i < llGetListLength(gRestrictionCategories); i++) {
            string category = llList2String(gRestrictionCategories, i);
            if (isRestrictionActive(category)) {
                activeRestrictions++;
            }
        }
        
        display += "🚫 Restrictions: " + (string)activeRestrictions + "/" + (string)llGetListLength(gRestrictionCategories);
    }
    
    // Color coding
    vector color;
    if (gConnectedUnit == "") {
        color = <0.5, 0.5, 0.5>;
    } else {
        integer activeCount = 0;
        integer i;
        for (i = 0; i < llGetListLength(gRestrictionCategories); i++) {
            string category = llList2String(gRestrictionCategories, i);
            if (isRestrictionActive(category)) {
                activeCount++;
            }
        }
        
        if (activeCount > 0) {
            color = <1.0, 0.3, 0.3>;
        } else {
            color = <0.3, 0.8, 1.0>;
        }
    }
    
    llSetText(display, color, 1.0);
}

//-- MODULE MANAGEMENT FUNCTIONS --

// Add a module to installed list
addInstalledModule(string moduleName) {
    if (llListFindList(gInstalledModules, [moduleName]) == -1) {
        gInstalledModules += [moduleName];
        updateDisplayBasedOnMode();
    }
}

// Remove a module from installed list
removeInstalledModule(string moduleName) {
    integer index = llListFindList(gInstalledModules, [moduleName]);
    if (index >= 0) {
        gInstalledModules = llDeleteSubList(gInstalledModules, index, index);
        // Also remove from active if it was active
        removeActiveModule(moduleName);
        updateDisplayBasedOnMode();
    }
}

// Add a module to active list
addActiveModule(string moduleName) {
    if (llListFindList(gActiveModules, [moduleName]) == -1) {
        gActiveModules += [moduleName];
        // Ensure it's also in installed list
        addInstalledModule(moduleName);
        updateDisplayBasedOnMode();
    }
}

// Remove a module from active list
removeActiveModule(string moduleName) {
    integer index = llListFindList(gActiveModules, [moduleName]);
    if (index >= 0) {
        gActiveModules = llDeleteSubList(gActiveModules, index, index);
        updateDisplayBasedOnMode();
    }
}

// Add a module to blocked list
addBlockedModule(string moduleName) {
    if (llListFindList(gBlockedModules, [moduleName]) == -1) {
        gBlockedModules += [moduleName];
        // Remove from active if it was active
        removeActiveModule(moduleName);
        updateDisplayBasedOnMode();
    }
}

// Remove a module from blocked list
removeBlockedModule(string moduleName) {
    integer index = llListFindList(gBlockedModules, [moduleName]);
    if (index >= 0) {
        gBlockedModules = llDeleteSubList(gBlockedModules, index, index);
        updateDisplayBasedOnMode();
    }
}

//-- RESTRICTION MANAGEMENT FUNCTIONS --

// Add active restriction
addActiveRestriction(string restriction) {
    if (llListFindList(gActiveRestrictions, [restriction]) == -1) {
        gActiveRestrictions += [restriction];
        updateDisplayBasedOnMode();
    }
}

// Remove active restriction
removeActiveRestriction(string restriction) {
    integer index = llListFindList(gActiveRestrictions, [restriction]);
    if (index >= 0) {
        gActiveRestrictions = llDeleteSubList(gActiveRestrictions, index, index);
        updateDisplayBasedOnMode();
    }
}

// Add available restriction
addAvailableRestriction(string restriction) {
    if (llListFindList(gAvailableRestrictions, [restriction]) == -1) {
        gAvailableRestrictions += [restriction];
        updateDisplayBasedOnMode();
    }
}

// Update display based on current mode
updateDisplayBasedOnMode() {
    if (gCompactMode) {
        updateCompactAppDisplay();
    } else {
        updateAppStatusDisplay();
    }
}

// Process status updates from other scripts
processStatusUpdate(string command, list parameters) {
    if (command == "STATUS_UPDATE") {
        gConnectedUnit = llList2String(parameters, 0);
        updateDisplayBasedOnMode();
    }
    else if (command == "CONNECTION_UPDATE") {
        gConnectedUnit = llList2String(parameters, 0);
        updateDisplayBasedOnMode();
    }
    else if (command == "MODULE_INSTALLED") {
        string moduleName = llList2String(parameters, 0);
        addInstalledModule(moduleName);
    }
    else if (command == "MODULE_REMOVED") {
        string moduleName = llList2String(parameters, 0);
        removeInstalledModule(moduleName);
    }
    else if (command == "MODULE_ACTIVATED") {
        string moduleName = llList2String(parameters, 0);
        addActiveModule(moduleName);
    }
    else if (command == "MODULE_DEACTIVATED") {
        string moduleName = llList2String(parameters, 0);
        removeActiveModule(moduleName);
    }
    else if (command == "MODULE_BLOCKED") {
        string moduleName = llList2String(parameters, 0);
        addBlockedModule(moduleName);
    }
    else if (command == "MODULE_UNBLOCKED") {
        string moduleName = llList2String(parameters, 0);
        removeBlockedModule(moduleName);
    }
    else if (command == "RESTRICTION_ACTIVATED") {
        string restriction = llList2String(parameters, 0);
        addActiveRestriction(restriction);
    }
    else if (command == "RESTRICTION_DEACTIVATED") {
        string restriction = llList2String(parameters, 0);
        removeActiveRestriction(restriction);
    }
    else if (command == "RESTRICTION_AVAILABLE") {
        string restriction = llList2String(parameters, 0);
        addAvailableRestriction(restriction);
    }
    else if (command == "MODULES_UPDATE") {
        // Full module list update
        gActiveModules = [];
        integer i;
        for (i = 0; i < llGetListLength(parameters); i++) {
            string module = llList2String(parameters, i);
            if (module != "") {
                gActiveModules += [module];
                addInstalledModule(module); // Ensure it's in installed list too
            }
        }
        updateDisplayBasedOnMode();
    }
    else if (command == "RESTRICTIONS_UPDATE") {
        // Full restriction list update
        gActiveRestrictions = [];
        integer i;
        for (i = 0; i < llGetListLength(parameters); i++) {
            string restriction = llList2String(parameters, i);
            if (restriction != "") {
                gActiveRestrictions += [restriction];
            }
        }
        updateDisplayBasedOnMode();
    }
    else if (command == "VISIBILITY") {
        gVisible = (integer)llList2String(parameters, 0);
        updateDisplayBasedOnMode();
    }
}

// Core initialization
initializeAppInterface() {
    llOwnerSay("🔧 A.R.I.A. Enhanced App Interface v" + VERSION + " initializing...");
    llOwnerSay("📦 Visual module status indicators enabled");
    llOwnerSay("🚫 Visual restriction status indicators enabled");
    
    gOwner = llGetOwner();
    
    // Make prim invisible but keep hovertext
    llSetAlpha(0.0, ALL_SIDES);
    
    // Initialize with some default modules for demo
    gInstalledModules = ["Security", "Diagnostic", "RLV"];
    gActiveModules = ["Security"];
    
    // Initialize some available restrictions
    gAvailableRestrictions = ["Vision Block", "Movement Restrict", "Chat Limit", "TP Block"];
    
    // Set initial display
    updateDisplayBasedOnMode();
    
    // Set update timer
    llSetTimerEvent(UPDATE_INTERVAL);
    
    llOwnerSay("✅ Enhanced App Interface ready (Right Side)");
}

// Main event handlers
default {
    state_entry() {
        initializeAppInterface();
    }
    
    attach(key id) {
        if (id) {
            llOwnerSay("📱 Enhanced App Interface attached to right side");
        } else {
            llOwnerSay("📱 Enhanced App Interface detached");
        }
        
        llSleep(0.5);
        updateDisplayBasedOnMode();
    }
    
    timer() {
        // Regular display refresh
        updateDisplayBasedOnMode();
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        list parts = llParseString2List(str, ["|"], []);
        string command = llList2String(parts, 0);
        
        if (num == 1000) {
            // General status updates
            list data = llDeleteSubList(parts, 0, 0);
            processStatusUpdate(command, data);
        }
        else if (num == 1001) {
            // Module updates
            list data = llDeleteSubList(parts, 0, 0);
            processStatusUpdate(command, data);
        }
        else if (num == 1002) {
            // Restriction updates
            list data = llDeleteSubList(parts, 0, 0);
            processStatusUpdate(command, data);
        }
        else if (num == 2000) {
            // Visibility and display commands
            if (command == "VISIBILITY") {
                gVisible = (integer)llList2String(parts, 1);
                updateDisplayBasedOnMode();
                
                if (gVisible) {
                    llOwnerSay("📦 App Interface display shown");
                } else {
                    llOwnerSay("📦 App Interface display hidden");
                }
            }
            else if (command == "DISPLAY_MODE") {
                string mode = llList2String(parts, 1);
                if (mode == "COMPACT") {
                    gCompactMode = TRUE;
                    updateCompactAppDisplay();
                } else {
                    gCompactMode = FALSE;
                    updateAppStatusDisplay();
                }
            }
        }
    }
    
    touch_start(integer total_number) {
        if (llDetectedKey(0) == gOwner) {
            // Toggle between standard and compact display
            gCompactMode = !gCompactMode;
            
            if (gCompactMode) {
                updateCompactAppDisplay();
                llOwnerSay("📱 App Interface: Compact mode");
            } else {
                updateAppStatusDisplay();
                llOwnerSay("📦 App Interface: Standard mode");
            }
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
}
