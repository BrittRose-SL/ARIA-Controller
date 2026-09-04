//-- A.R.I.A. Permissions Module (Add-on)
//-- Version 3.3 - OPENCOLLAR STYLE AUTH SYSTEM
//-- September 12, 2025 - Complete rewrite using OpenCollar auth architecture
//-- CHANGES v3.3:
//--   - Addressed station responses to the requesting station object
//-- CHANGES v3.2:
//--   - Corrected auth-level comparisons to match the OpenCollar ordering
//--   - Normalized permission-list lookups to key values
//--   - Rejected malformed auth requests before sending replies
//--   - Added persistent permission state using linkset data
//--   - Added authenticated station permission sync and update handlers
//-- CHANGES v3.0: 
//--   - Implemented OpenCollar-style CalcAuth() function
//--   - Added AUTH_REQUEST/AUTH_REPLY protocol
//--   - Replaced old permission lists with g_lOwner, g_lTrust, g_lBlock
//--   - Added group and public access support
//--   - Implemented range limiting
//--   - Asynchronous permission checking system

// --- LINKED MESSAGE CODES ---
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer AUTH_REQUEST = 600;
integer AUTH_REPLY = 601;
integer PERMISSION_DATA_REQUEST = 602;

// --- STATION COMMUNICATION ---
integer gStationLinkChannel = -18795462;

// --- OPENCOLLAR STYLE AUTH CONSTANTS ---
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_BLOCKED = 598;
integer CMD_NOACCESS = 599;

// --- STATE VARIABLES ---
integer gMenuChannel;
integer gListenHandle;
key gCurrentUser;
key g_kWearer;

// --- OPENCOLLAR STYLE USER LISTS ---
list g_lOwner;              // Owner list (replaces gPrimaryAdmin + gAdministrators)
list g_lTrust;              // Trusted users (replaces gTrustedUsers)
list g_lBlock;              // Blocked users (new)
key g_kGroup = NULL_KEY;    // Group access key
integer g_iPublic = FALSE;  // Public access flag
integer g_iLimitRange = TRUE; // Range limiting flag
integer g_iWearerAdminMode = TRUE;

// --- PERSISTENT STATE KEYS ---
string PERMISSION_OWNERS_KEY = "aria.permission.owners";
string PERMISSION_TRUSTED_KEY = "aria.permission.trusted";
string PERMISSION_BLOCKED_KEY = "aria.permission.blocked";
string PERMISSION_GROUP_KEY = "aria.permission.group";
string PERMISSION_PUBLIC_KEY = "aria.permission.public";
string PERMISSION_RANGE_KEY = "aria.permission.range";
string PERMISSION_WEARER_ADMIN_KEY = "aria.permission.wearer_admin";

// --- MENU & SENSOR VARIABLES ---
integer gPermissionState = 0;
list gScanResults_Keys;
list gScanResults_Names;
integer gScanResults_Page;

// --- PERMISSION STATES ---
// 0 = none, 1 = add owner, 2 = remove owner, 3 = add trusted, 4 = remove trusted
// 5 = add block, 6 = remove block

// --- OPENCOLLAR AUTH SYSTEM CORE FUNCTIONS ---

// Main authorization calculation function - replaces all getAccessLevel functions
integer CalcAuth(key kID) {
    // Special case: If no owners exist and wearer is requesting access (and not blocked)
    if(llGetListLength(g_lOwner) == 0 && kID == g_kWearer && 
    llListFindList(g_lBlock, [kID]) == -1) {
        return CMD_OWNER;
    }
    
    // Standard hierarchy check
    if(llListFindList(g_lBlock, [kID]) != -1) return CMD_BLOCKED;
    if(llListFindList(g_lOwner, [kID]) != -1) return CMD_OWNER;
    if(llListFindList(g_lTrust, [kID]) != -1) return CMD_TRUSTED;
    if(kID == g_kWearer) return CMD_WEARER;
    
    // Group and public access only apply to nearby avatars/objects
    if(in_range(kID)) {
        if(g_kGroup != NULL_KEY && llSameGroup(kID)) return CMD_GROUP;
        if(g_iPublic) return CMD_EVERYONE;
    }
    
    return CMD_NOACCESS;
}

// Range checking function
integer in_range(key kID) {
    if(!g_iLimitRange) return TRUE;
    if(kID == g_kWearer) return TRUE;
    vector pos = llList2Vector(llGetObjectDetails(kID, [OBJECT_POS]), 0);
    return llVecDist(llGetPos(), pos) <= 20.0;
}

// Convert auth level to readable string
string Auth2Str(integer iAuth) {
    if(iAuth == CMD_OWNER) return "Owner";
    else if(iAuth == CMD_TRUSTED) return "Trusted";
    else if(iAuth == CMD_GROUP) return "Group";
    else if(iAuth == CMD_WEARER) return "Wearer";
    else if(iAuth == CMD_EVERYONE) return "Public";
    else if(iAuth == CMD_BLOCKED) return "Blocked";
    else if(iAuth == CMD_NOACCESS) return "No Access";
    else return "Unknown = " + (string)iAuth;
}

// --- HELPER FUNCTIONS ---
open_menu(key id, string str, list btns) {
    llListenRemove(gListenHandle);
    gMenuChannel = (integer)("0x" + llGetSubString((string)id, -7, -1));
    gListenHandle = llListen(gMenuChannel, "", id, "");
    llDialog(id, str, btns, gMenuChannel);
    llSetTimerEvent(30.0);
}

// Add unique person to list (prevents duplicates)
list AddUniquePerson(list lList, key kID) {
    if(llListFindList(lList, [kID]) == -1) {
        lList += [kID];
    }
    return lList;
}

// Remove person from list
list RemovePerson(list lList, key kID) {
    integer idx = llListFindList(lList, [kID]);
    if(idx != -1) {
        lList = llDeleteSubList(lList, idx, idx);
    }
    return lList;
}

savePermissionState() {
    llLinksetDataWrite(PERMISSION_OWNERS_KEY, llList2CSV(g_lOwner));
    llLinksetDataWrite(PERMISSION_TRUSTED_KEY, llList2CSV(g_lTrust));
    llLinksetDataWrite(PERMISSION_BLOCKED_KEY, llList2CSV(g_lBlock));
    llLinksetDataWrite(PERMISSION_GROUP_KEY, (string)g_kGroup);
    llLinksetDataWrite(PERMISSION_PUBLIC_KEY, (string)g_iPublic);
    llLinksetDataWrite(PERMISSION_RANGE_KEY, (string)g_iLimitRange);
    llLinksetDataWrite(PERMISSION_WEARER_ADMIN_KEY, (string)g_iWearerAdminMode);
}

loadPermissionState() {
    string owners = llLinksetDataRead(PERMISSION_OWNERS_KEY);
    string trusted = llLinksetDataRead(PERMISSION_TRUSTED_KEY);
    string blocked = llLinksetDataRead(PERMISSION_BLOCKED_KEY);
    string groupKey = llLinksetDataRead(PERMISSION_GROUP_KEY);
    string publicAccess = llLinksetDataRead(PERMISSION_PUBLIC_KEY);
    string rangeLimit = llLinksetDataRead(PERMISSION_RANGE_KEY);
    string wearerAdmin = llLinksetDataRead(PERMISSION_WEARER_ADMIN_KEY);

    if(owners != "") g_lOwner = llCSV2List(owners);
    if(trusted != "") g_lTrust = llCSV2List(trusted);
    if(blocked != "") g_lBlock = llCSV2List(blocked);
    if(groupKey != "") g_kGroup = (key)groupKey;
    if(publicAccess != "") g_iPublic = (integer)publicAccess;
    if(rangeLimit != "") g_iLimitRange = (integer)rangeLimit;
    if(wearerAdmin != "") g_iWearerAdminMode = (integer)wearerAdmin;
}

sendPermissionList(key destination) {
    string response = "PERMISSION_LIST_RESPONSE|" + llList2CSV(g_lOwner) + "|";
    response += llList2CSV(g_lTrust) + "|" + (string)g_iWearerAdminMode;
    llRegionSayTo(destination, gStationLinkChannel, response);
}

sendPermissionUpdateResponse(key destination, string action, string userType, string result) {
    string response = "PERMISSION_UPDATE_RESPONSE|" + action + "|" + userType + "|" + result;
    llRegionSayTo(destination, gStationLinkChannel, response);
}

processStationRequest(string command, list parts, key source) {
    if(llGetListLength(parts) < 3) return;

    key requester = (key)llList2String(parts, llGetListLength(parts) - 1);
    key targetUnit = (key)llList2String(parts, llGetListLength(parts) - 2);
    if(targetUnit != llGetKey()) return;
    if(requester == NULL_KEY || CalcAuth(requester) > CMD_OWNER) return;

    if(command == "REQUEST_PERMISSION_LIST") {
        sendPermissionList(source);
    }
    else if(command == "ADD_ADMINISTRATOR" || command == "ADD_OWNER") {
        if(llGetListLength(parts) < 4) return;
        key target = (key)llList2String(parts, 1);
        if(target != NULL_KEY) {
            g_lOwner = AddUniquePerson(g_lOwner, target);
            g_lTrust = RemovePerson(g_lTrust, target);
            g_lBlock = RemovePerson(g_lBlock, target);
            savePermissionState();
            sendPermissionUpdateResponse(source, "ADD", "ADMINISTRATOR", "SUCCESS");
        }
    }
    else if(command == "ADD_TRUSTED") {
        if(llGetListLength(parts) < 4) return;
        key target = (key)llList2String(parts, 1);
        if(target != NULL_KEY) {
            g_lTrust = AddUniquePerson(g_lTrust, target);
            g_lOwner = RemovePerson(g_lOwner, target);
            g_lBlock = RemovePerson(g_lBlock, target);
            savePermissionState();
            sendPermissionUpdateResponse(source, "ADD", "TRUSTED", "SUCCESS");
        }
    }
    else if(command == "REMOVE_ADMINISTRATOR" || command == "REMOVE_OWNER") {
        if(llGetListLength(parts) < 4) return;
        key target = (key)llList2String(parts, 1);
        g_lOwner = RemovePerson(g_lOwner, target);
        savePermissionState();
        sendPermissionUpdateResponse(source, "REMOVE", "ADMINISTRATOR", "SUCCESS");
    }
    else if(command == "REMOVE_TRUSTED") {
        if(llGetListLength(parts) < 4) return;
        key target = (key)llList2String(parts, 1);
        g_lTrust = RemovePerson(g_lTrust, target);
        savePermissionState();
        sendPermissionUpdateResponse(source, "REMOVE", "TRUSTED", "SUCCESS");
    }
    else if(command == "TOGGLE_WEARER_MODE") {
        g_iWearerAdminMode = !g_iWearerAdminMode;
        savePermissionState();
        llRegionSayTo(source, gStationLinkChannel, "WEARER_MODE_RESPONSE|SUCCESS");
    }
}

// --- PERMISSION MANAGEMENT FUNCTIONS ---

// Main permission menu
openPermissionMenu(key user) {
    integer auth = CalcAuth(user);
    
    if(auth > CMD_WEARER) {
        llInstantMessage(user, "Access denied. Insufficient permissions for Permission module.");
        return;
    }
    
    gCurrentUser = user;
    string dialog = "\n[ A.R.I.A. PERMISSIONS ]\n";
    dialog += "Your Access: " + Auth2Str(auth) + "\n\n";
    dialog += "Owners: " + (string)llGetListLength(g_lOwner) + "\n";
    dialog += "Trusted: " + (string)llGetListLength(g_lTrust) + "\n";
    dialog += "Blocked: " + (string)llGetListLength(g_lBlock) + "\n";
    
    list buttons = [];
    
    // Owner management (only owners can modify)
    if(auth <= CMD_OWNER) {
        buttons += ["+ Owner", "- Owner"];
    }
    
    // Trust management (owners and wearer can modify)
    if(auth <= CMD_OWNER || (auth == CMD_WEARER && g_iWearerAdminMode)) {
        buttons += ["+ Trust", "- Trust"];
    }
    
    // Block management (only owners can modify)
    if(auth <= CMD_OWNER) {
        buttons += ["+ Block", "- Block"];
    }
    
    // Access settings (only owners can modify)
    if(auth <= CMD_OWNER) {
        if(g_iPublic) buttons += ["Public: ON"];
        else buttons += ["Public: OFF"];
        
        if(g_iLimitRange) buttons += ["Range: ON"];
        else buttons += ["Range: OFF"];
    }
    
    buttons += ["Get Auth", "CLOSE"];
    
    open_menu(user, dialog, buttons);
}

// Scan for nearby users
startUserScan(key requester, integer mode) {
    gPermissionState = mode;
    gCurrentUser = requester;
    gScanResults_Keys = [];
    gScanResults_Names = [];
    gScanResults_Page = 0;
    
    llSensor("", "", AGENT, 20.0, PI);
}

// Build scan results menu
showScanResults() {
    if(llGetListLength(gScanResults_Keys) == 0) {
        llInstantMessage(gCurrentUser, "No users found nearby. Try again when closer to people.");
        openPermissionMenu(gCurrentUser);
        return;
    }
    
    string dialog = "\n[ SELECT USER ]\n\n";
    
    if(gPermissionState == 1) dialog += "Add as Owner:\n";
    else if(gPermissionState == 2) dialog += "Remove Owner:\n";
    else if(gPermissionState == 3) dialog += "Add as Trusted:\n";
    else if(gPermissionState == 4) dialog += "Remove Trusted:\n";
    else if(gPermissionState == 5) dialog += "Add to Blocked:\n";
    else if(gPermissionState == 6) dialog += "Remove from Blocked:\n";
    
    integer start = gScanResults_Page * 9;
    integer end = start + 8;
    if(end >= llGetListLength(gScanResults_Names)) {
        end = llGetListLength(gScanResults_Names) - 1;
    }
    
    list buttons = [];
    integer i;
    for(i = start; i <= end && i < llGetListLength(gScanResults_Names); i++) {
        string name = llList2String(gScanResults_Names, i);
        if(llStringLength(name) > 24) {
            name = llGetSubString(name, 0, 23);
        }
        buttons += [name];
        dialog += name + "\n";
    }
    
    // Add navigation if needed
    if(gScanResults_Page > 0) buttons += ["< PREV"];
    if(end < llGetListLength(gScanResults_Names) - 1) buttons += ["NEXT >"];
    
    buttons += ["BACK", "CLOSE"];
    
    open_menu(gCurrentUser, dialog, buttons);
}

// Process user selection from scan
processUserSelection(string selection) {
    integer idx = llListFindList(gScanResults_Names, [selection]);
    if(idx == -1) return;
    
    key selectedUser = llList2String(gScanResults_Keys, idx);
    string userName = llList2String(gScanResults_Names, idx);
    
    if(gPermissionState == 1) { // Add Owner
        g_lOwner = AddUniquePerson(g_lOwner, selectedUser);
        // Remove from other lists
        g_lTrust = RemovePerson(g_lTrust, selectedUser);
        g_lBlock = RemovePerson(g_lBlock, selectedUser);
        llInstantMessage(gCurrentUser, userName + " added as Owner.");
        llInstantMessage(selectedUser, "You have been added as owner of " + llKey2Name(g_kWearer) + "'s A.R.I.A. unit.");
    }
    else if(gPermissionState == 2) { // Remove Owner
        g_lOwner = RemovePerson(g_lOwner, selectedUser);
        llInstantMessage(gCurrentUser, userName + " removed from Owners.");
        llInstantMessage(selectedUser, "You have been removed as owner of " + llKey2Name(g_kWearer) + "'s A.R.I.A. unit.");
    }
    else if(gPermissionState == 3) { // Add Trusted
        g_lTrust = AddUniquePerson(g_lTrust, selectedUser);
        // Remove from block list
        g_lBlock = RemovePerson(g_lBlock, selectedUser);
        llInstantMessage(gCurrentUser, userName + " added as Trusted user.");
        llInstantMessage(selectedUser, "You have been added as trusted user of " + llKey2Name(g_kWearer) + "'s A.R.I.A. unit.");
    }
    else if(gPermissionState == 4) { // Remove Trusted
        g_lTrust = RemovePerson(g_lTrust, selectedUser);
        llInstantMessage(gCurrentUser, userName + " removed from Trusted users.");
        llInstantMessage(selectedUser, "You have been removed as trusted user of " + llKey2Name(g_kWearer) + "'s A.R.I.A. unit.");
    }
    else if(gPermissionState == 5) { // Add Block
        g_lBlock = AddUniquePerson(g_lBlock, selectedUser);
        // Remove from other lists
        g_lOwner = RemovePerson(g_lOwner, selectedUser);
        g_lTrust = RemovePerson(g_lTrust, selectedUser);
        llInstantMessage(gCurrentUser, userName + " added to Blocked list.");
        llInstantMessage(selectedUser, "You have been blocked from " + llKey2Name(g_kWearer) + "'s A.R.I.A. unit.");
    }
    else if(gPermissionState == 6) { // Remove Block
        g_lBlock = RemovePerson(g_lBlock, selectedUser);
        llInstantMessage(gCurrentUser, userName + " removed from Blocked list.");
        llInstantMessage(selectedUser, "You have been unblocked from " + llKey2Name(g_kWearer) + "'s A.R.I.A. unit.");
    }
    
    // Reset state and return to main menu
    gPermissionState = 0;
    openPermissionMenu(gCurrentUser);
}

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        g_kWearer = llGetOwner();

        loadPermissionState();
        
        // Initialize with owner as first owner if no owners exist
        if(llGetListLength(g_lOwner) == 0) {
            g_lOwner = [g_kWearer];
            savePermissionState();
        }
        
        gMenuChannel = (integer)("0x" + llGetSubString((string)llGetKey(), -7, -1));
        
        llOwnerSay("A.R.I.A. Permission Module v3.2 initialized with OpenCollar auth system.");
        
        // Register with master kernel
        llMessageLinked(LINK_SET, MODULE_REGISTER, "Permissions", NULL_KEY);

        llListen(gStationLinkChannel, "", NULL_KEY, "");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if(num == AUTH_REQUEST) {
            // This is the core of the new auth system
            if(id != NULL_KEY && msg != "") {
                integer iAuth = CalcAuth(id);
                llMessageLinked(LINK_SET, AUTH_REPLY, "AuthReply|" + (string)id + "|" + (string)iAuth, msg);
            }
        }
        else if(num == OPEN_MY_MENU) {
            openPermissionMenu((key)msg);
        }
        else if(num == MODULE_REGISTER) {
            // Ignore - this is our own registration
            gCurrentUser = gCurrentUser;
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if(chan == gStationLinkChannel) {
            list parts = llParseString2List(msg, ["|"], []);
            processStationRequest(llList2String(parts, 0), parts, id);
            return;
        }
        if(chan != gMenuChannel) return;
        if(id != gCurrentUser) return;
        
        llSetTimerEvent(0.0);
        llListenRemove(gListenHandle);
        
        if(msg == "CLOSE") return;
        
        if(gPermissionState == 0) { // Main menu
            if(msg == "+ Owner") {
                startUserScan(id, 1);
            }
            else if(msg == "- Owner") {
                startUserScan(id, 2);
            }
            else if(msg == "+ Trust") {
                startUserScan(id, 3);
            }
            else if(msg == "- Trust") {
                startUserScan(id, 4);
            }
            else if(msg == "+ Block") {
                startUserScan(id, 5);
            }
            else if(msg == "- Block") {
                startUserScan(id, 6);
            }
            else if(msg == "Public: ON" || msg == "Public: OFF") {
                integer auth = CalcAuth(id);
                if(auth <= CMD_OWNER) {
                    g_iPublic = !g_iPublic;
                    if(g_iPublic) {
                        llInstantMessage(id, "Public access enabled.");
                    } else {
                        llInstantMessage(id, "Public access disabled.");
                    }
                    openPermissionMenu(id);
                }
            }
            else if(msg == "Range: ON" || msg == "Range: OFF") {
                integer auth = CalcAuth(id);
                if(auth <= CMD_OWNER) {
                    g_iLimitRange = !g_iLimitRange;
                    if(g_iLimitRange) {
                        llInstantMessage(id, "Range limiting enabled (20m).");
                    } else {
                        llInstantMessage(id, "Range limiting disabled.");
                    }
                    openPermissionMenu(id);
                }
            }
            else if(msg == "Get Auth") {
                integer auth = CalcAuth(id);
                llInstantMessage(id, "Your access level: " + Auth2Str(auth) + " (" + (string)auth + ")");
                openPermissionMenu(id);
            }
        }
        else { // User selection menu
            if(msg == "BACK") {
                gPermissionState = 0;
                openPermissionMenu(id);
            }
            else if(msg == "< PREV") {
                gScanResults_Page--;
                if(gScanResults_Page < 0) gScanResults_Page = 0;
                showScanResults();
            }
            else if(msg == "NEXT >") {
                gScanResults_Page++;
                showScanResults();
            }
            else {
                processUserSelection(msg);
            }
        }
    }

    sensor(integer detected) {
        gScanResults_Keys = [];
        gScanResults_Names = [];
        
        integer i;
        for(i = 0; i < detected; i++) {
            key detected_key = llDetectedKey(i);
            string detected_name = llDetectedName(i);
            
            // Don't include self
            if(detected_key != g_kWearer) {
                gScanResults_Keys += [detected_key];
                gScanResults_Names += [detected_name];
            }
        }
        
        showScanResults();
    }

    no_sensor() {
        llInstantMessage(gCurrentUser, "No users detected nearby. Try again when closer to people.");
        gPermissionState = 0;
        openPermissionMenu(gCurrentUser);
    }

    timer() {
        llSetTimerEvent(0.0);
        llListenRemove(gListenHandle);
        gPermissionState = 0;
    }
}
