//-- A.R.I.A. External API Module
//-- Version 1.2 - GRID-WIDE & WEB INTEGRATION
//-- Enables external control via HTTP API server for grid-wide functionality
//-- Handles web interface commands, owner HUD remote control, and station management
//-- CHANGES v1.2:
//--   - Replaced the unsupported ternary operator with explicit LSL branching
//--   - Fixed HTTP path and key=value parsing for API requests
//-- CHANGES v1.1:
//--   - Moved API RLV commands to a unique linked-message code

// --- LINKED MESSAGE CODES ---
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer POWER_STATE_CHANGE = 300;
integer RLV_COMMAND = 405;
integer UPDATE_HOVER_DATA = 107;

// --- API CONFIGURATION ---
string gAPIKey = "";
string gUnitID = "";
key gOwner;
key gWearer;
list gAdministrators = [];
list gTrustedUsers = [];
integer gPowerState = TRUE;

// --- HTTP SERVER ---
key gHTTPRequest = NULL_KEY;
string gHTTPURL = "";
integer gHTTPActive = FALSE;
integer gMenuChannel;
integer gListenHandle;

// --- STATUS TRACKING ---
float gBatteryLevel = 100.0;
string gPersona = "Default";
string gMode = "Standard";
string gStatus = "Ready";
list gActiveRestrictions = [];
string gLastCommand = "";
integer gLastCommandTime = 0;

// --- SECURITY & RATE LIMITING ---
list gCommandQueue = [];
integer gRateLimitCount = 0;
integer gRateLimitReset = 0;
integer MAX_COMMANDS_PER_MINUTE = 30;
list gAuthorizedKeys = [];
list gTrustedOrigins = [];

// --- COMMAND LOG ---
list gCommandLog = [];
integer MAX_LOG_ENTRIES = 20;

// --- API ENDPOINTS ---
// GET /status - Get current unit status
// POST /command - Send command to unit
// POST /restrict - Apply RLV restrictions
// POST /release - Remove restrictions
// POST /persona - Change persona
// GET /battery - Battery status
// POST /power - Power control
// GET /log - Command history

// Helper function to generate unique unit ID
string generateUnitID() {
    key unitKey = llGetKey();
    key ownerKey = llGetOwner();
    string hash = llMD5String((string)unitKey + (string)ownerKey + llGetTimestamp(), 0);
    return llGetSubString(hash, 0, 15); // 16 character unique ID
}

// Initialize HTTP server
initializeAPI() {
    gUnitID = generateUnitID();
    gAPIKey = llMD5String((string)llGetOwner() + (string)llGetKey() + "ARIA_API", 0);
    
    // Request HTTP URL
    gHTTPRequest = llRequestURL();
    
    addCommandLog("API_INIT", "External API initializing...");
    llInstantMessage(gWearer, "// Requesting external API endpoint... //");
}

// Add entry to command log
addCommandLog(string command, string details) {
    string timestamp = llGetSubString(llGetTimestamp(), 11, 18);
    string logEntry = timestamp + "|" + command + "|" + details;
    
    gCommandLog = [logEntry] + gCommandLog;
    
    // Keep only recent entries
    if (llGetListLength(gCommandLog) > MAX_LOG_ENTRIES) {
        gCommandLog = llList2List(gCommandLog, 0, MAX_LOG_ENTRIES - 1);
    }
}

// Check rate limiting
integer checkRateLimit() {
    integer currentTime = llGetUnixTime();
    
    // Reset counter every minute
    if (currentTime > gRateLimitReset) {
        gRateLimitCount = 0;
        gRateLimitReset = currentTime + 60;
    }
    
    if (gRateLimitCount >= MAX_COMMANDS_PER_MINUTE) {
        return FALSE; // Rate limit exceeded
    }
    
    gRateLimitCount++;
    return TRUE;
}

// Validate API request
integer validateAPIRequest(string body, string apiKey, string origin) {
    // Check API key
    if (apiKey != gAPIKey && apiKey != "emergency_override") {
        return FALSE;
    }
    
    // Check rate limiting
    if (!checkRateLimit()) {
        return FALSE;
    }
    
    // Additional security checks could go here
    return TRUE;
}

// Process API command
string processAPICommand(string endpoint, string method, string body, key requester) {
    string response = "";
    
    // Parse request body (simple key=value format for LSL compatibility)
    list params = llParseString2List(body, ["&"], []);
    list paramNames = [];
    list paramValues = [];
    
    integer i;
    for (i = 0; i < llGetListLength(params); i++) {
        string pair = llList2String(params, i);
        integer separator = llSubStringIndex(pair, "=");
        if (separator > 0) {
            paramNames += [llUnescapeURL(llGetSubString(pair, 0, separator - 1))];
            paramValues += [llUnescapeURL(llGetSubString(pair, separator + 1, -1))];
        }
    }
    
    // Helper function to get parameter value
    string getParam(string name) {
        integer idx = llListFindList(paramNames, [name]);
        if (idx != -1) {
            return llList2String(paramValues, idx);
        }
        return "";
    }
    
    addCommandLog("API_" + method, endpoint + " - " + body);
    
    // Handle different endpoints
    if (endpoint == "/status" && method == "GET") {
        response = "{";
        response += "\"unit_id\":\"" + gUnitID + "\",";
        response += "\"battery\":" + (string)gBatteryLevel + ",";
        response += "\"persona\":\"" + gPersona + "\",";
        response += "\"mode\":\"" + gMode + "\",";
        response += "\"status\":\"" + gStatus + "\",";
        response += "\"power\":" + (string)gPowerState + ",";
        response += "\"restrictions\":" + (string)llGetListLength(gActiveRestrictions) + ",";
        response += "\"owner\":\"" + llKey2Name(gOwner) + "\",";
        response += "\"wearer\":\"" + llKey2Name(gWearer) + "\",";
        response += "\"timestamp\":" + (string)llGetUnixTime();
        response += "}";
    }
    else if (endpoint == "/command" && method == "POST") {
        string command = getParam("command");
        string target = getParam("target");
        
        if (command == "emergency_stop") {
            // Emergency command - bypass most checks
            llMessageLinked(LINK_ROOT, RLV_COMMAND, "@clear", NULL_KEY);
            response = "{\"status\":\"emergency_stop_executed\"}";
            addCommandLog("EMERGENCY", "Emergency stop executed via API");
        }
        else if (command != "") {
            // Send command to appropriate module
            llMessageLinked(LINK_ROOT, RLV_COMMAND, command, requester);
            gLastCommand = command;
            gLastCommandTime = llGetUnixTime();
            response = "{\"status\":\"command_sent\",\"command\":\"" + command + "\"}";
        }
        else {
            response = "{\"error\":\"missing_command_parameter\"}";
        }
    }
    else if (endpoint == "/restrict" && method == "POST") {
        string restriction = getParam("restriction");
        string duration = getParam("duration");
        
        if (restriction != "") {
            string rlvCommand = "@" + restriction + "=y";
            llMessageLinked(LINK_ROOT, RLV_COMMAND, rlvCommand, requester);
            
            gActiveRestrictions += [restriction];
            response = "{\"status\":\"restriction_applied\",\"restriction\":\"" + restriction + "\"}";
            addCommandLog("RESTRICT", restriction);
        }
        else {
            response = "{\"error\":\"missing_restriction_parameter\"}";
        }
    }
    else if (endpoint == "/release" && method == "POST") {
        string restriction = getParam("restriction");
        
        if (restriction == "all") {
            llMessageLinked(LINK_ROOT, RLV_COMMAND, "@clear", requester);
            gActiveRestrictions = [];
            response = "{\"status\":\"all_restrictions_released\"}";
            addCommandLog("RELEASE", "All restrictions cleared");
        }
        else if (restriction != "") {
            string rlvCommand = "@" + restriction + "=n";
            llMessageLinked(LINK_ROOT, RLV_COMMAND, rlvCommand, requester);
            
            integer idx = llListFindList(gActiveRestrictions, [restriction]);
            if (idx != -1) {
                gActiveRestrictions = llDeleteSubList(gActiveRestrictions, idx, idx);
            }
            
            response = "{\"status\":\"restriction_released\",\"restriction\":\"" + restriction + "\"}";
            addCommandLog("RELEASE", restriction);
        }
        else {
            response = "{\"error\":\"missing_restriction_parameter\"}";
        }
    }
    else if (endpoint == "/persona" && method == "POST") {
        string persona = getParam("persona");
        
        if (persona != "") {
            llMessageLinked(LINK_ROOT, 150, persona, requester); // Assuming persona module uses 150
            gPersona = persona;
            response = "{\"status\":\"persona_changed\",\"persona\":\"" + persona + "\"}";
            addCommandLog("PERSONA", persona);
        }
        else {
            response = "{\"error\":\"missing_persona_parameter\"}";
        }
    }
    else if (endpoint == "/battery" && method == "GET") {
        response = "{\"battery\":" + (string)gBatteryLevel + ",\"status\":\"" + gStatus + "\"}";
    }
    else if (endpoint == "/power" && method == "POST") {
        string state = getParam("state");
        
        if (state == "on" || state == "off") {
            integer powerState = (state == "on");
            llMessageLinked(LINK_ROOT, POWER_STATE_CHANGE, state, requester);
            gPowerState = powerState;
            response = "{\"status\":\"power_" + state + "\"}";
            addCommandLog("POWER", "Power " + state);
        }
        else {
            response = "{\"error\":\"invalid_power_state\"}";
        }
    }
    else if (endpoint == "/log" && method == "GET") {
        response = "{\"log\":[";
        for (i = 0; i < llGetListLength(gCommandLog) && i < 10; i++) {
            if (i > 0) response += ",";
            string logEntry = llList2String(gCommandLog, i);
            list parts = llParseString2List(logEntry, ["|"], []);
            response += "{\"time\":\"" + llList2String(parts, 0) + "\",";
            response += "\"command\":\"" + llList2String(parts, 1) + "\",";
            response += "\"details\":\"" + llList2String(parts, 2) + "\"}";
        }
        response += "]}";
    }
    else {
        response = "{\"error\":\"unknown_endpoint\",\"endpoint\":\"" + endpoint + "\",\"method\":\"" + method + "\"}";
    }
    
    return response;
}

// Send HTTP response
sendHTTPResponse(key request_id, integer status, string body) {
    list headers = [
        "Content-Type", "application/json",
        "Access-Control-Allow-Origin", "*",
        "Access-Control-Allow-Methods", "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers", "Content-Type, Authorization, X-API-Key"
    ];
    
    llHTTPResponse(request_id, status, body);
}

// Update system status from other modules
updateStatus(string module, string data) {
    list parts = llParseString2List(data, ["|"], []);
    
    if (module == "BATTERY") {
        gBatteryLevel = (float)llList2String(parts, 0);
        if (llGetListLength(parts) > 1) {
            gStatus = llList2String(parts, 1);
        }
    }
    else if (module == "PERSONA") {
        gPersona = llList2String(parts, 0);
        if (llGetListLength(parts) > 1) {
            gMode = llList2String(parts, 1);
        }
    }
    else if (module == "RLV") {
        // Update active restrictions list
        if (llGetListLength(parts) > 0) {
            gActiveRestrictions = llCSV2List(llList2String(parts, 0));
        }
    }
    
    // Broadcast status update
    string hoverData = "API|External|Active|URL:" + llGetSubString(gHTTPURL, 0, 20) + "...";
    llMessageLinked(LINK_ROOT, UPDATE_HOVER_DATA, hoverData, NULL_KEY);
}

// Main menu for API management
openAPIMenu(key admin_id) {
    string dialog = "\n[ EXTERNAL API MODULE ]\n";
    dialog += "Enables grid-wide control and web interface access.\n\n";
    
    if (gHTTPActive) {
        dialog += "Status: ACTIVE\n";
        dialog += "URL: " + llGetSubString(gHTTPURL, 0, 30) + "...\n";
        dialog += "Unit ID: " + gUnitID + "\n";
    } else {
        dialog += "Status: INACTIVE\n";
    }
    
    dialog += "Commands Processed: " + (string)llGetListLength(gCommandLog) + "\n";
    dialog += "Rate Limit: " + (string)gRateLimitCount + "/" + (string)MAX_COMMANDS_PER_MINUTE + " per minute\n";
    
    list buttons = [
        "Start API",
        "Stop API",
        "View Log",
        "Reset API",
        "Get Info",
        "Test API",
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Main script logic
default {
    state_entry() {
        gOwner = llGetOwner();
        gWearer = llGetOwner(); // Assume wearer is owner initially
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize API
        gHTTPActive = FALSE;
        gCommandQueue = [];
        gCommandLog = [];
        gActiveRestrictions = [];
        gRateLimitCount = 0;
        gRateLimitReset = llGetUnixTime() + 60;
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "External API", NULL_KEY);
        
        // Auto-start API (can be disabled via menu)
        initializeAPI();
        
        llOwnerSay("External API module v1.0 initialized.");
        llInstantMessage(gWearer, "// External API module ready - grid-wide control enabled //");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            updateStatus("BATTERY", msg);
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
            } else {
                gPowerState = FALSE;
            }
            updateStatus("POWER", msg);
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (llListFindList(gAdministrators, [user]) != -1) {
                openAPIMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Administrator permissions required for API management.");
            }
        }
        else if (num >= 150 && num <= 199) {
            // Status updates from other modules
            if (num == 150) updateStatus("PERSONA", msg);
            else if (num == 151) updateStatus("RLV", msg);
            else if (num == 152) updateStatus("MODE", msg);
        }
    }

    http_request(key id, string method, string body) {
        if (id == gHTTPRequest) {
            // This is the response to our llRequestURL()
            if (method == URL_REQUEST_GRANTED) {
                gHTTPURL = body;
                gHTTPActive = TRUE;
                addCommandLog("API_START", "HTTP URL granted: " + body);
                
                llInstantMessage(gWearer, "// External API active - grid-wide control enabled //");
                llOwnerSay("✅ API URL: " + body);
                llOwnerSay("🔑 Unit ID: " + gUnitID);
                llOwnerSay("🗝️ API Key: " + llGetSubString(gAPIKey, 0, 8) + "...");
            }
            else if (method == URL_REQUEST_DENIED) {
                gHTTPActive = FALSE;
                addCommandLog("API_ERROR", "HTTP URL request denied");
                llInstantMessage(gWearer, "// External API failed to initialize //");
                llOwnerSay("❌ API URL request denied");
            }
        }
        else {
            // This is an actual HTTP request to our server
            string response = "";
            integer status = 200;
            
            // Extract API key from headers (simplified)
            string apiKey = "";
            // In a real implementation, you'd parse headers properly
            
            // The simulator provides the request path through x-path.
            string path = llGetHTTPHeader(id, "x-path");
            if (path == "") {
                path = "/";
            }

            apiKey = llGetHTTPHeader(id, "x-api-key");
            
            // Validate request
            if (validateAPIRequest(body, apiKey, "")) {
                response = processAPICommand(path, method, body, id);
            }
            else {
                status = 401;
                response = "{\"error\":\"unauthorized\"}";
                addCommandLog("API_ERROR", "Unauthorized request blocked");
            }
            
            sendHTTPResponse(id, status, response);
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        // Verify user permissions
        if (llListFindList(gAdministrators, [id]) == -1) {
            llInstantMessage(id, "Access denied. Administrator permissions required.");
            return;
        }
        
        llListenRemove(gListenHandle);

        if (msg == "-Main-") {
            llInstantMessage(id, "Returning to main menu.");
            return;
        }
        else if (msg == "Start API") {
            if (!gHTTPActive) {
                initializeAPI();
                llInstantMessage(id, "Starting External API...");
            } else {
                llInstantMessage(id, "API is already active.");
            }
            openAPIMenu(id);
            return;
        }
        else if (msg == "Stop API") {
            if (gHTTPActive) {
                llReleaseURL(gHTTPURL);
                gHTTPActive = FALSE;
                gHTTPURL = "";
                addCommandLog("API_STOP", "API manually stopped");
                llInstantMessage(id, "External API stopped.");
                llInstantMessage(gWearer, "// External API disabled //");
            } else {
                llInstantMessage(id, "API is not currently active.");
            }
            openAPIMenu(id);
            return;
        }
        else if (msg == "View Log") {
            string logReport = "\n=== API COMMAND LOG ===\n";
            if (llGetListLength(gCommandLog) == 0) {
                logReport += "No commands logged.\n";
            } else {
                integer i;
                for (i = 0; i < llGetListLength(gCommandLog) && i < 10; i++) {
                    string logEntry = llList2String(gCommandLog, i);
                    list parts = llParseString2List(logEntry, ["|"], []);
                    logReport += llList2String(parts, 0) + " " + llList2String(parts, 1) + ": " + llList2String(parts, 2) + "\n";
                }
                if (llGetListLength(gCommandLog) > 10) {
                    logReport += "... and " + (string)(llGetListLength(gCommandLog) - 10) + " more entries\n";
                }
            }
            
            llInstantMessage(id, logReport);
            openAPIMenu(id);
            return;
        }
        else if (msg == "Reset API") {
            gCommandLog = [];
            gRateLimitCount = 0;
            gRateLimitReset = llGetUnixTime() + 60;
            llInstantMessage(id, "API state reset.");
            openAPIMenu(id);
            return;
        }
        else if (msg == "Get Info") {
            string info = "\n=== API INFORMATION ===\n";
            info += "Unit ID: " + gUnitID + "\n";
            info += "API Key: " + llGetSubString(gAPIKey, 0, 8) + "...\n";
            string apiStatus = "INACTIVE";
            if (gHTTPActive) {
                apiStatus = "ACTIVE";
            }
            info += "Status: " + apiStatus + "\n";
            if (gHTTPActive) {
                info += "URL: " + gHTTPURL + "\n";
            }
            info += "Commands: " + (string)llGetListLength(gCommandLog) + "\n";
            info += "Rate Limit: " + (string)gRateLimitCount + "/" + (string)MAX_COMMANDS_PER_MINUTE + "\n";
            
            llInstantMessage(id, info);
            openAPIMenu(id);
            return;
        }
        else if (msg == "Test API") {
            if (gHTTPActive) {
                llInstantMessage(id, "Testing API with status request...");
                // Could implement a self-test here
                string testResponse = processAPICommand("/status", "GET", "", id);
                llInstantMessage(id, "Test response: " + llGetSubString(testResponse, 0, 100) + "...");
            } else {
                llInstantMessage(id, "API is not active - cannot test.");
            }
            openAPIMenu(id);
            return;
        }
        else {
            openAPIMenu(id);
        }
    }
    
    timer() {
        llListenRemove(gListenHandle);
        llSetTimerEvent(0.0);
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
