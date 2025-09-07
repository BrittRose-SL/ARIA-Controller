//-- A.R.I.A. Maintenance & Utilities Module (Add-on)
//-- Version 1.0 - COMPREHENSIVE SYSTEM MAINTENANCE
//-- Provides system health monitoring, backup/restore, diagnostics, and utility functions
//-- Integrates with all existing modules for comprehensive system maintenance

// --- LINKED MESSAGE CODES ---
integer UPDATE_BATTERY = 101;
integer UPDATE_CONFIG = 102;
integer MODULE_REGISTER = 200;
integer OPEN_MY_MENU = 201;
integer POWER_STATE_CHANGE = 300;
integer UPDATE_HOVER_DATA = 107;

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

// --- MAINTENANCE STATE ---
integer gMaintenanceMode = FALSE;
integer gSystemScanActive = FALSE;
integer gAutoRepairEnabled = TRUE;
integer gDiagnosticsActive = FALSE;
float gSystemHealth = 100.0;
integer gLastMaintenanceTime = 0;
integer gMaintenanceInterval = 86400; // 24 hours in seconds

// --- SYSTEM MONITORING ---
list gModuleStatus = []; // [module_name, status, module_name, status, ...]
list gSystemErrors = [];
list gPerformanceLog = [];
integer gErrorCount = 0;
integer gWarningCount = 0;

// --- BACKUP & RESTORE ---
string gBackupData = "";
integer gBackupTimestamp = 0;
list gConfigBackups = []; // Stores multiple backup configurations

// --- MENU STATES ---
integer MENU_STATE_NONE = 0;
integer MENU_STATE_BACKUP_NAME = 1;
integer MENU_STATE_RESTORE_SELECT = 2;
integer MENU_STATE_MAINTENANCE_INTERVAL = 3;
integer gMenuState = 0;

// --- HELPER FUNCTIONS ---
updateSystemHealth() {
    float health = 100.0;
    
    // Battery impact on health
    if (gBatteryLevel <= 5.0) health -= 40.0;
    else if (gBatteryLevel <= 15.0) health -= 20.0;
    else if (gBatteryLevel <= 25.0) health -= 10.0;
    
    // Error impact on health
    health -= (gErrorCount * 5.0);
    health -= (gWarningCount * 2.0);
    
    // Module status impact
    integer activeModules = llGetListLength(gModuleStatus) / 2;
    integer faultyModules = 0;
    integer i;
    for (i = 1; i < llGetListLength(gModuleStatus); i += 2) {
        string status = llList2String(gModuleStatus, i);
        if (status == "ERROR" || status == "FAULT") {
            faultyModules++;
        }
    }
    
    if (activeModules > 0) {
        float moduleHealthImpact = ((float)faultyModules / (float)activeModules) * 30.0;
        health -= moduleHealthImpact;
    }
    
    // Maintenance impact
    integer timeSinceLastMaintenance = llGetUnixTime() - gLastMaintenanceTime;
    if (timeSinceLastMaintenance > gMaintenanceInterval * 2) {
        health -= 15.0; // Overdue maintenance
    }
    
    if (health < 0.0) health = 0.0;
    if (health > 100.0) health = 100.0;
    
    gSystemHealth = health;
    
    // Send health data to main module for hover text
    string hoverData = "SYSTEM|Health|" + (string)((integer)gSystemHealth) + "|Errors:" + (string)gErrorCount + "|Warnings:" + (string)gWarningCount;
    llMessageLinked(LINK_ROOT, UPDATE_HOVER_DATA, hoverData, NULL_KEY);
}

string getHealthStatus() {
    if (gSystemHealth >= 90.0) return "EXCELLENT";
    else if (gSystemHealth >= 75.0) return "GOOD";
    else if (gSystemHealth >= 50.0) return "FAIR";
    else if (gSystemHealth >= 25.0) return "POOR";
    else return "CRITICAL";
}

vector getHealthColor() {
    if (gSystemHealth >= 75.0) return <0.0, 1.0, 0.0>; // Green
    else if (gSystemHealth >= 50.0) return <1.0, 1.0, 0.0>; // Yellow
    else if (gSystemHealth >= 25.0) return <1.0, 0.5, 0.0>; // Orange
    else return <1.0, 0.0, 0.0>; // Red
}

performSystemScan() {
    gSystemScanActive = TRUE;
    gSystemErrors = [];
    gErrorCount = 0;
    gWarningCount = 0;
    
    llInstantMessage(gWearer, "// System scan initiated... //");
    
    // Check battery status
    if (gBatteryLevel <= 5.0) {
        gSystemErrors += ["CRITICAL: Battery level critical (" + (string)((integer)gBatteryLevel) + "%)"];
        gErrorCount++;
    } else if (gBatteryLevel <= 15.0) {
        gSystemErrors += ["WARNING: Low battery (" + (string)((integer)gBatteryLevel) + "%)"];
        gWarningCount++;
    }
    
    // Check power state
    if (!gPowerState) {
        gSystemErrors += ["ERROR: System powered down"];
        gErrorCount++;
    }
    
    // Check module statuses (simulated - in real implementation would query each module)
    integer moduleCount = llGetListLength(gModuleStatus) / 2;
    if (moduleCount == 0) {
        gSystemErrors += ["WARNING: No modules detected"];
        gWarningCount++;
    }
    
    // Check maintenance schedule
    integer timeSinceLastMaintenance = llGetUnixTime() - gLastMaintenanceTime;
    if (timeSinceLastMaintenance > gMaintenanceInterval) {
        gSystemErrors += ["NOTICE: Scheduled maintenance overdue"];
        gWarningCount++;
    }
    
    updateSystemHealth();
    gSystemScanActive = FALSE;
    
    string report = "System scan complete.\n";
    report += "Health: " + (string)((integer)gSystemHealth) + "% (" + getHealthStatus() + ")\n";
    report += "Errors: " + (string)gErrorCount + " | Warnings: " + (string)gWarningCount;
    
    llInstantMessage(gAdministrator, report);
    llInstantMessage(gWearer, "// System scan complete. Health: " + (string)((integer)gSystemHealth) + "% //");
}

performMaintenance() {
    gMaintenanceMode = TRUE;
    llInstantMessage(gWearer, "// Entering maintenance mode... //");
    
    // Clear error logs
    gSystemErrors = [];
    gErrorCount = 0;
    gWarningCount = 0;
    
    // Reset module statuses
    integer i;
    for (i = 1; i < llGetListLength(gModuleStatus); i += 2) {
        gModuleStatus = llListReplaceList(gModuleStatus, ["OK"], i, i);
    }
    
    // Update maintenance timestamp
    gLastMaintenanceTime = llGetUnixTime();
    
    // Improve system health
    gSystemHealth += 20.0;
    if (gSystemHealth > 100.0) gSystemHealth = 100.0;
    
    updateSystemHealth();
    
    gMaintenanceMode = FALSE;
    llInstantMessage(gWearer, "// Maintenance complete. System health restored. //");
    llInstantMessage(gAdministrator, "Maintenance cycle completed successfully.\nSystem health: " + (string)((integer)gSystemHealth) + "%");
}

string getCurrentConfig() {
    // Create a backup string of current configuration
    string config = "ARIA_BACKUP_v1.0|";
    config += (string)llGetUnixTime() + "|";
    config += llList2CSV(gAdministrators) + "|";
    config += llList2CSV(gTrustedUsers) + "|";
    config += (string)gBatteryLevel + "|";
    config += (string)gSystemHealth + "|";
    config += (string)gMaintenanceInterval + "|";
    config += (string)gAutoRepairEnabled + "|";
    config += (string)gLastMaintenanceTime;
    
    return config;
}

restoreFromConfig(string config) {
    list parts = llParseString2List(config, ["|"], []);
    
    if (llGetListLength(parts) < 9) {
        llInstantMessage(gAdministrator, "ERROR: Invalid backup format");
        return;
    }
    
    string version = llList2String(parts, 0);
    if (version != "ARIA_BACKUP_v1.0") {
        llInstantMessage(gAdministrator, "ERROR: Unsupported backup version: " + version);
        return;
    }
    
    // Restore configuration
    gBackupTimestamp = (integer)llList2String(parts, 1);
    // Note: Admin/trusted lists should be carefully restored
    gBatteryLevel = (float)llList2String(parts, 4);
    gSystemHealth = (float)llList2String(parts, 5);
    gMaintenanceInterval = (integer)llList2String(parts, 6);
    gAutoRepairEnabled = (integer)llList2String(parts, 7);
    gLastMaintenanceTime = (integer)llList2String(parts, 8);
    
    updateSystemHealth();
    
    string date = llGetDate();
    llInstantMessage(gAdministrator, "Configuration restored from backup dated: " + date);
    llInstantMessage(gWearer, "// System configuration restored from backup //");
}

openMainMenu(key admin_id) {
    string dialog = "\n[ MAINTENANCE & UTILITIES ]\n";
    dialog += "System Health: " + (string)((integer)gSystemHealth) + "% (" + getHealthStatus() + ")\n";
    dialog += "Errors: " + (string)gErrorCount + " | Warnings: " + (string)gWarningCount + "\n";
    dialog += "Battery: " + (string)((integer)gBatteryLevel) + "%\n";
    
    if (gMaintenanceMode) {
        dialog += "\nðŸ"§ MAINTENANCE MODE ACTIVE";
    }
    
    if (gSystemScanActive) {
        dialog += "\nðŸ" SYSTEM SCAN IN PROGRESS";
    }
    
    integer daysSince = (llGetUnixTime() - gLastMaintenanceTime) / 86400;
    dialog += "\nLast Maintenance: " + (string)daysSince + " days ago";
    
    list buttons = [
        "System Scan",
        "Maintenance", 
        "Diagnostics",
        "Backup",
        "Restore",
        "Auto-Repair",
        "View Logs",
        "Settings",
        "-Main-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openDiagnosticsMenu(key admin_id) {
    string dialog = "\n[ SYSTEM DIAGNOSTICS ]\n";
    dialog += "Detailed system analysis and troubleshooting.\n\n";
    dialog += "System Health: " + (string)((integer)gSystemHealth) + "%\n";
    dialog += "Active Modules: " + (string)(llGetListLength(gModuleStatus) / 2) + "\n";
    dialog += "Memory Usage: " + (string)llGetUsedMemory() + " bytes\n";
    dialog += "Free Memory: " + (string)llGetFreeMemory() + " bytes\n";
    
    list buttons = [
        "Memory Test",
        "Module Status",
        "RLV Test",
        "Performance",
        "Reset Errors",
        "Force Restart",
        "-Back-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openBackupMenu(key admin_id) {
    string dialog = "\n[ BACKUP & RESTORE ]\n";
    dialog += "Manage system configuration backups.\n\n";
    dialog += "Available Backups: " + (string)llGetListLength(gConfigBackups) + "\n";
    
    if (gBackupTimestamp > 0) {
        integer daysSince = (llGetUnixTime() - gBackupTimestamp) / 86400;
        dialog += "Last Backup: " + (string)daysSince + " days ago\n";
    } else {
        dialog += "No recent backups found\n";
    }
    
    list buttons = [
        "Create Backup",
        "Quick Backup",
        "List Backups",
        "Restore Latest",
        "Export Config",
        "Clear Backups",
        "-Back-"
    ];
    
    llListenRemove(gListenHandle);
    gListenHandle = llListen(gMenuChannel, "", admin_id, "");
    llDialog(admin_id, dialog, buttons, gMenuChannel);
    llSetTimerEvent(30.0);
}

openSettingsMenu(key admin_id) {
    string dialog = "\n[ MAINTENANCE SETTINGS ]\n";
    dialog += "Configure maintenance parameters.\n\n";
    dialog += "Auto-Repair: ";
    if (gAutoRepairEnabled) dialog += "ENABLED\n";
    else dialog += "DISABLED\n";
    
    dialog += "Maintenance Interval: " + (string)(gMaintenanceInterval / 3600) + " hours\n";
    dialog += "Health Monitoring: ACTIVE\n";
    
    list buttons = [
        "Toggle Auto-Repair",
        "Set Interval",
        "Reset Health",
        "Factory Reset",
        "Debug Mode",
        "-Back-"
    ];
    
    llListenRemove(gListenHandle);
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

// --- MAIN SCRIPT LOGIC ---
default {
    state_entry() {
        gWearer = llGetOwner();
        gMenuChannel = (integer)("0x" + llGetSubString(llGetKey(), -8, -2));
        
        // Initialize maintenance system
        gLastMaintenanceTime = llGetUnixTime();
        gSystemHealth = 100.0;
        gMaintenanceMode = FALSE;
        gSystemScanActive = FALSE;
        gAutoRepairEnabled = TRUE;
        gDiagnosticsActive = FALSE;
        
        // Initialize tracking lists
        gModuleStatus = [];
        gSystemErrors = [];
        gPerformanceLog = [];
        gConfigBackups = [];
        gErrorCount = 0;
        gWarningCount = 0;
        gMenuState = MENU_STATE_NONE;
        
        // Register with main module
        llMessageLinked(LINK_ROOT, MODULE_REGISTER, "Maintenance", NULL_KEY);
        
        // Start periodic health monitoring
        llSetTimerEvent(300.0); // Check every 5 minutes
        
        updateSystemHealth();
        
        llOwnerSay("Maintenance & Utilities module v1.0 initialized.");
        llInstantMessage(gWearer, "// System health monitoring active //");
    }

    link_message(integer sender, integer num, string msg, key id) {
        if (num == UPDATE_BATTERY) {
            gBatteryLevel = (float)msg;
            updateSystemHealth();
            
            // Auto-repair for battery issues
            if (gAutoRepairEnabled && gBatteryLevel <= 10.0) {
                llInstantMessage(gWearer, "// Auto-repair: Implementing power conservation measures //");
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
                llInstantMessage(gWearer, "// System diagnostics online //");
            } else {
                gPowerState = FALSE;
                llInstantMessage(gWearer, "// System diagnostics offline //");
            }
            updateSystemHealth();
        }
        else if (num == OPEN_MY_MENU) {
            key user = (key)msg;
            if (llListFindList(gAdministrators, [user]) != -1) {
                gAdministrator = user;
                openMainMenu(user);
            } else {
                llInstantMessage(user, "Access denied. Administrator permissions required for maintenance functions.");
            }
        }
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan != gMenuChannel) return;
        
        // Verify user still has permissions
        if (llListFindList(gAdministrators, [id]) == -1) {
            llInstantMessage(id, "Access denied. Administrator permissions required.");
            return;
        }
        
        llListenRemove(gListenHandle);
        llListenRemove(gTextBoxHandle);

        // Handle text input
        if (gMenuState != MENU_STATE_NONE) {
            if (gMenuState == MENU_STATE_BACKUP_NAME) {
                string backupName = msg + "|" + getCurrentConfig();
                gConfigBackups += [backupName];
                gBackupTimestamp = llGetUnixTime();
                llInstantMessage(id, "Backup '" + msg + "' created successfully.");
            }
            else if (gMenuState == MENU_STATE_MAINTENANCE_INTERVAL) {
                integer hours = (integer)msg;
                if (hours >= 1 && hours <= 168) { // 1 hour to 1 week
                    gMaintenanceInterval = hours * 3600;
                    llInstantMessage(id, "Maintenance interval set to " + (string)hours + " hours.");
                } else {
                    llInstantMessage(id, "Invalid interval. Please enter 1-168 hours.");
                }
            }
            
            gMenuState = MENU_STATE_NONE;
            openMainMenu(id);
            return;
        }

        if (msg == "-Main-") {
            llInstantMessage(id, "Returning to main menu.");
            return;
        }
        else if (msg == "-Back-") {
            openMainMenu(id);
            return;
        }
        else if (msg == "System Scan") {
            performSystemScan();
            openMainMenu(id);
            return;
        }
        else if (msg == "Maintenance") {
            performMaintenance();
            openMainMenu(id);
            return;
        }
        else if (msg == "Diagnostics") {
            openDiagnosticsMenu(id);
            return;
        }
        else if (msg == "Backup") {
            openBackupMenu(id);
            return;
        }
        else if (msg == "Restore") {
            if (llGetListLength(gConfigBackups) > 0) {
                // For now, restore latest backup
                string latestBackup = llList2String(gConfigBackups, -1);
                list parts = llParseString2List(latestBackup, ["|"], []);
                string config = llDumpList2String(llDeleteSubList(parts, 0, 0), "|");
                restoreFromConfig(config);
            } else {
                llInstantMessage(id, "No backups available to restore.");
            }
            openMainMenu(id);
            return;
        }
        else if (msg == "Auto-Repair") {
            gAutoRepairEnabled = !gAutoRepairEnabled;
            string status = "DISABLED";
            if (gAutoRepairEnabled) status = "ENABLED";
            llInstantMessage(id, "Auto-repair " + status + ".");
            llInstantMessage(gWearer, "// Auto-repair protocols " + status + " //");
            openMainMenu(id);
            return;
        }
        else if (msg == "View Logs") {
            string report = "\n=== SYSTEM ERROR LOG ===\n";
            if (llGetListLength(gSystemErrors) == 0) {
                report += "No errors recorded.\n";
            } else {
                integer i;
                for (i = 0; i < llGetListLength(gSystemErrors) && i < 10; i++) {
                    report += "• " + llList2String(gSystemErrors, i) + "\n";
                }
                if (llGetListLength(gSystemErrors) > 10) {
                    report += "... and " + (string)(llGetListLength(gSystemErrors) - 10) + " more entries\n";
                }
            }
            report += "\nSystem Health: " + (string)((integer)gSystemHealth) + "%";
            
            llInstantMessage(id, report);
            openMainMenu(id);
            return;
        }
        else if (msg == "Settings") {
            openSettingsMenu(id);
            return;
        }
        // Diagnostics menu options
        else if (msg == "Memory Test") {
            integer used = llGetUsedMemory();
            integer free = llGetFreeMemory();
            integer total = used + free;
            float usage = ((float)used / (float)total) * 100.0;
            
            string report = "Memory Test Results:\n";
            report += "Total: " + (string)total + " bytes\n";
            report += "Used: " + (string)used + " bytes (" + (string)((integer)usage) + "%)\n";
            report += "Free: " + (string)free + " bytes\n";
            
            if (usage > 90.0) {
                report += "WARNING: High memory usage detected!";
                gSystemErrors += ["WARNING: Memory usage at " + (string)((integer)usage) + "%"];
                gWarningCount++;
            } else {
                report += "Memory usage within normal parameters.";
            }
            
            llInstantMessage(id, report);
            openDiagnosticsMenu(id);
            return;
        }
        else if (msg == "Module Status") {
            string report = "\n=== MODULE STATUS ===\n";
            if (llGetListLength(gModuleStatus) == 0) {
                report += "No modules detected.\n";
            } else {
                integer i;
                for (i = 0; i < llGetListLength(gModuleStatus); i += 2) {
                    string module = llList2String(gModuleStatus, i);
                    string status = llList2String(gModuleStatus, i + 1);
                    report += "• " + module + ": " + status + "\n";
                }
            }
            
            llInstantMessage(id, report);
            openDiagnosticsMenu(id);
            return;
        }
        else if (msg == "RLV Test") {
            llOwnerSay("@version");
            llInstantMessage(id, "RLV version query sent. Check main unit for response.");
            openDiagnosticsMenu(id);
            return;
        }
        else if (msg == "Performance") {
            string report = "\nPerformance Metrics:\n";
            report += "System Health: " + (string)((integer)gSystemHealth) + "%\n";
            report += "Battery Efficiency: " + (string)((integer)(gBatteryLevel / 100.0 * 100.0)) + "%\n";
            report += "Uptime: " + (string)((llGetUnixTime() - gLastMaintenanceTime) / 3600) + " hours\n";
            report += "Error Rate: " + (string)gErrorCount + " errors recorded\n";
            
            llInstantMessage(id, report);
            openDiagnosticsMenu(id);
            return;
        }
        else if (msg == "Reset Errors") {
            gSystemErrors = [];
            gErrorCount = 0;
            gWarningCount = 0;
            updateSystemHealth();
            llInstantMessage(id, "Error logs cleared.");
            llInstantMessage(gWearer, "// Error logs have been cleared //");
            openDiagnosticsMenu(id);
            return;
        }
        else if (msg == "Force Restart") {
            llInstantMessage(id, "Forcing system restart...");
            llInstantMessage(gWearer, "// SYSTEM RESTART INITIATED //");
            llSleep(2.0);
            llResetScript();
        }
        // Settings menu options
        else if (msg == "Toggle Auto-Repair") {
            gAutoRepairEnabled = !gAutoRepairEnabled;
            string status = "DISABLED";
            if (gAutoRepairEnabled) status = "ENABLED";
            llInstantMessage(id, "Auto-repair " + status + ".");
            openSettingsMenu(id);
            return;
        }
        else if (msg == "Set Interval") {
            gMenuState = MENU_STATE_MAINTENANCE_INTERVAL;
            openTextBox(id, "\nSet maintenance interval (hours):\n\nCurrent: " + (string)(gMaintenanceInterval / 3600) + " hours\nRange: 1-168 hours (1 week max)");
            return;
        }
        else if (msg == "Set Health Alert") {
            gMenuState = MENU_STATE_HEALTH_THRESHOLD;
            openTextBox(id, "\nSet health alert threshold (%):\n\nCurrent: 25%\nRange: 10-90%\nAlert when health drops below this level");
            return;
        }
        else if (msg == "Reset Health") {
            gSystemHealth = 100.0;
            gSystemErrors = [];
            gErrorCount = 0;
            gWarningCount = 0;
            updateSystemHealth();
            llInstantMessage(id, "System health reset to 100%.");
            llInstantMessage(gWearer, "// System health has been restored //");
            openSettingsMenu(id);
            return;
        }
        else if (msg == "Emergency Reset") {
            llInstantMessage(id, "WARNING: This will perform emergency system reset. Confirm by selecting again.");
            // Could implement confirmation dialog here
            openSettingsMenu(id);
            return;
        }
        else if (msg == "Debug Mode") {
            gDiagnosticsActive = !gDiagnosticsActive;
            string status = "DISABLED";
            if (gDiagnosticsActive) status = "ENABLED";
            llInstantMessage(id, "Debug mode " + status + ".");
            llInstantMessage(gWearer, "// Debug mode " + status + " //");
            openSettingsMenu(id);
            return;
        }
        else {
            openMainMenu(id);
        }
    }
    
    timer() {
        // Periodic maintenance check
        if (gMenuState == MENU_STATE_NONE) {
            llListenRemove(gListenHandle);
            llListenRemove(gTextBoxHandle);
        }
        
        // Automatic system health monitoring
        updateSystemHealth();
        
        // Auto-repair functionality
        if (gAutoRepairEnabled) {
            if (gSystemHealth < 75.0 && !gMaintenanceMode) {
                llInstantMessage(gWearer, "// Auto-repair protocols engaged - correcting system deficiencies //");
                
                // Attempt automatic corrections
                if (gErrorCount > 5) {
                    gSystemErrors = llList2List(gSystemErrors, -3, -1); // Keep only last 3 errors
                    gErrorCount = llGetListLength(gSystemErrors);
                }
                
                if (gWarningCount > 10) {
                    gWarningCount = 5; // Reset warning count
                }
                
                updateSystemHealth();
            }
            
            // Automatic maintenance scheduling
            integer timeSinceLastMaintenance = llGetUnixTime() - gLastMaintenanceTime;
            if (timeSinceLastMaintenance > gMaintenanceInterval && !gMaintenanceMode) {
                llInstantMessage(gWearer, "// Automatic maintenance cycle initiated //");
                performMaintenance();
            }
        }
        
        // Check for critical conditions
        if (gSystemHealth <= 25.0) {
            llInstantMessage(gWearer, "// WARNING: System health critical - immediate attention required //");
            
            // Send urgent notification to admins
            integer i;
            for (i = 0; i < llGetListLength(gAdministrators); i++) {
                key admin = llList2Key(gAdministrators, i);
                llInstantMessage(admin, "URGENT: " + llKey2Name(gWearer) + " system health critical (" + (string)((integer)gSystemHealth) + "%)");
            }
        }
        
        // Set next timer interval based on system state
        if (gSystemHealth < 50.0) {
            llSetTimerEvent(60.0); // Check every minute when health is poor
        } else if (gSystemHealth < 75.0) {
            llSetTimerEvent(180.0); // Check every 3 minutes when health is fair
        } else {
            llSetTimerEvent(300.0); // Normal 5-minute intervals
        }
    }
    
    changed(integer c) {
        if (c & CHANGED_OWNER) {
            llResetScript();
        }
        
        if (c & CHANGED_INVENTORY) {
            // Check if maintenance-related items were added/removed
            llInstantMessage(gWearer, "// Inventory change detected - updating system catalog //");
            updateSystemHealth();
        }
    }
}
