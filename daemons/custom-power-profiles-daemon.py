#!/usr/bin/env python3
"""
Custom Power Profiles Daemon Replacement
Replaces the original power-profiles-daemon with our enhanced system
Implements D-Bus interface compatible with KDE Power Management
"""

import os
import sys
import signal
import subprocess
import time
import logging
from pathlib import Path
from threading import Thread
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

# Add src directory to path for imports
daemon_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(daemon_dir.parent / "src"))

from config.power_config import PowerConfig

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] CUSTOM-POWER-DAEMON: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/custom-power-daemon.log'),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

class CustomPowerProfilesDaemon(dbus.service.Object):
    """
    Custom Power Profiles Daemon
    Compatible D-Bus interface with enhanced functionality
    """
    
    DBUS_SERVICE = 'net.hadess.PowerProfiles'
    DBUS_PATH = '/net/hadess/PowerProfiles'
    DBUS_INTERFACE = 'net.hadess.PowerProfiles'
    
    def __init__(self):
        # D-Bus setup
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        self.bus = dbus.SystemBus()
        bus_name = dbus.service.BusName(self.DBUS_SERVICE, self.bus)
        dbus.service.Object.__init__(self, bus_name, self.DBUS_PATH)

        # Load configuration with dynamic paths
        self.config = PowerConfig()

        # Power profiles state
        self.active_profile = "balanced"
        self.profiles = [
            {
                "Profile": "power-saver",
                "PlatformDriver": "platform_profile",
                "Driver": "platform_profile"
            },
            {
                "Profile": "balanced",
                "PlatformDriver": "platform_profile",
                "Driver": "platform_profile"
            },
            {
                "Profile": "performance",
                "PlatformDriver": "platform_profile",
                "Driver": "platform_profile"
            }
        ]

        self.holds = []
        self.performance_degraded = ""
        self.performance_inhibited = ""
        self.actions = ["trickle_charge", "ai_optimization", "emergency_mode"]
        self.version = "3.0-universal"  # Updated version

        # Get script paths from configuration
        self.performance_script = self.config.get_script_path("performance_manager")
        self.ai_manager_script = self.config.get_script_path("ai_process_manager")
        self.emergency_script = self.config.get_script_path("emergency_cleanup")

        log.info("🤖 Custom Power Profiles Daemon initialized (Universal Edition)")
        log.info(f"📋 Available profiles: {[p['Profile'] for p in self.profiles]}")
        log.info(f"📁 Install directory: {self.config.paths.install_dir}")

        # Warn if scripts not found
        if not self.performance_script:
            log.warning("⚠️  Performance manager script not found")
        if not self.ai_manager_script:
            log.warning("⚠️  AI manager script not found")
        if not self.emergency_script:
            log.warning("⚠️  Emergency cleanup script not found")
        
    # D-Bus Properties
    @dbus.service.method(DBUS_INTERFACE, in_signature='', out_signature='as')
    def GetActions(self):
        """Get available actions"""
        return self.actions
        
    @dbus.service.method(DBUS_INTERFACE, in_signature='', out_signature='s') 
    def GetActiveProfile(self):
        """Get current active profile"""
        return self.active_profile
        
    @dbus.service.method(DBUS_INTERFACE, in_signature='s', out_signature='')
    def SetActiveProfile(self, profile):
        """Set active profile"""
        if profile in [p["Profile"] for p in self.profiles]:
            old_profile = self.active_profile
            self.active_profile = profile
            
            # Execute profile change
            self._execute_profile_change(profile)
            
            log.info(f"🔄 Profile changed: {old_profile} → {profile}")
            
            # Emit D-Bus signal
            self.PropertiesChanged(
                self.DBUS_INTERFACE,
                {"ActiveProfile": profile},
                []
            )
        else:
            raise dbus.exceptions.DBusException(f"Profile '{profile}' not available")
            
    @dbus.service.method(DBUS_INTERFACE, in_signature='', out_signature='aa{sv}')
    def GetProfiles(self):
        """Get available profiles"""
        return [dbus.Dictionary(p, signature='sv') for p in self.profiles]
        
    @dbus.service.method(DBUS_INTERFACE, in_signature='', out_signature='s')
    def GetVersion(self):
        """Get daemon version"""
        return self.version
        
    @dbus.service.method(DBUS_INTERFACE, in_signature='sss', out_signature='u')  
    def HoldProfile(self, profile, reason, application_id):
        """Hold a profile (prevent changes)"""
        hold_id = len(self.holds)
        self.holds.append({
            "Profile": profile,
            "Reason": reason, 
            "ApplicationId": application_id
        })
        log.info(f"🔒 Profile hold: {profile} by {application_id} ({reason})")
        return hold_id
        
    @dbus.service.method(DBUS_INTERFACE, in_signature='u', out_signature='')
    def ReleaseProfile(self, hold_id):
        """Release a profile hold"""
        if hold_id < len(self.holds):
            hold = self.holds[hold_id]
            log.info(f"🔓 Profile released: {hold['Profile']} by {hold['ApplicationId']}")
            del self.holds[hold_id]
            self.ProfileReleased(hold_id)
        
    # D-Bus Properties interface
    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature='ss', out_signature='v')
    def Get(self, interface_name, property_name):
        """Get property value"""
        if interface_name == self.DBUS_INTERFACE:
            if property_name == 'ActiveProfile':
                return self.active_profile
            elif property_name == 'Profiles':
                return [dbus.Dictionary(p, signature='sv') for p in self.profiles]
            elif property_name == 'Actions':
                return self.actions
            elif property_name == 'Version':
                return self.version
            elif property_name == 'PerformanceDegraded':
                return self.performance_degraded
            elif property_name == 'PerformanceInhibited':
                return self.performance_inhibited
            elif property_name == 'ActiveProfileHolds':
                return [dbus.Dictionary(h, signature='sv') for h in self.holds]
        raise dbus.exceptions.DBusException(f"Property '{property_name}' not found")
        
    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature='s', out_signature='a{sv}')
    def GetAll(self, interface_name):
        """Get all properties"""
        if interface_name == self.DBUS_INTERFACE:
            return dbus.Dictionary({
                'ActiveProfile': dbus.String(self.active_profile),
                'Profiles': dbus.Array([dbus.Dictionary(p, signature='sv') for p in self.profiles], signature='a{sv}'),
                'Actions': dbus.Array(self.actions, signature='s'),
                'Version': dbus.String(self.version),
                'PerformanceDegraded': dbus.String(self.performance_degraded),
                'PerformanceInhibited': dbus.String(self.performance_inhibited),
                'ActiveProfileHolds': dbus.Array([dbus.Dictionary(h, signature='sv') for h in self.holds], signature='a{sv}')
            }, signature='sv')
        return {}
        
    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature='ssv')
    def Set(self, interface_name, property_name, value):
        """Set property value"""
        if interface_name == self.DBUS_INTERFACE and property_name == 'ActiveProfile':
            self.SetActiveProfile(value)
        else:
            raise dbus.exceptions.DBusException(f"Property '{property_name}' not writable")
    
    # D-Bus Signals
    @dbus.service.signal(DBUS_INTERFACE, signature='u')
    def ProfileReleased(self, hold_id):
        """Signal when profile hold is released"""
        pass
        
    @dbus.service.signal(dbus.PROPERTIES_IFACE, signature='sa{sv}as')
    def PropertiesChanged(self, interface_name, changed_properties, invalidated_properties):
        """Signal when properties change"""
        pass
    
    def _execute_profile_change(self, profile):
        """Execute the actual profile change using our scripts"""
        if not self.performance_script:
            log.error("❌ Performance manager script not available")
            return

        try:
            if profile == "performance":
                log.info("🔥 Executing PERFORMANCE profile")
                subprocess.run([self.performance_script, "performance"],
                             timeout=30, capture_output=True)

            elif profile == "balanced":
                log.info("⚖️ Executing BALANCED profile")
                subprocess.run([self.performance_script, "balanced"],
                             timeout=30, capture_output=True)

            elif profile == "power-saver":
                log.info("🔋 Executing POWER-SAVER profile")
                subprocess.run([self.performance_script, "powersave"],
                             timeout=30, capture_output=True)

        except subprocess.TimeoutExpired:
            log.error(f"⚠️ Profile change timeout for {profile}")
        except FileNotFoundError:
            log.error(f"❌ Script not found: {self.performance_script}")
        except Exception as e:
            log.error(f"❌ Profile change failed for {profile}: {e}")

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    log.info("🛑 Custom Power Profiles Daemon shutting down")
    sys.exit(0)

def main():
    """Main daemon function"""
    # Check if we're running as root
    if os.geteuid() != 0:
        log.error("❌ Must run as root for D-Bus system service")
        sys.exit(1)
        
    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    log.info("🚀 Starting Custom Power Profiles Daemon")
    
    try:
        # Create daemon instance
        daemon = CustomPowerProfilesDaemon()
        
        # Start GLib main loop
        mainloop = GLib.MainLoop()
        log.info("✅ Custom Power Profiles Daemon running")
        log.info("🔌 D-Bus service: net.hadess.PowerProfiles")
        log.info("📍 D-Bus path: /net/hadess/PowerProfiles")
        
        mainloop.run()
        
    except Exception as e:
        log.error(f"💥 Daemon failed to start: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()