#!/usr/bin/env python3
"""
Power Management Configuration System
Handles paths, settings, and hardware-specific configurations
Eliminates hardcoded paths and makes system portable
"""

import os
import json
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict


@dataclass
class PathConfig:
    """Dynamic path configuration"""
    # Base paths
    install_dir: str
    scripts_dir: str
    src_dir: str
    config_dir: str
    log_dir: str

    # Script paths
    performance_manager: str
    ai_process_manager: str
    emergency_cleanup: str
    cpu_frequency_manager: str
    smart_thermal_manager: str

    # Log files
    main_log: str
    cpu_log: str
    thermal_log: str


@dataclass
class ThermalConfig:
    """Thermal management configuration"""
    comfort_temp: int = 65
    warning_temp: int = 70
    critical_temp: int = 80
    emergency_temp: int = 85  # Will be adjusted based on CPU


@dataclass
class FrequencyConfig:
    """CPU frequency configuration"""
    min_freq_mhz: int
    max_freq_mhz: int
    performance_freq: int
    balanced_freq: int
    powersave_freq: int
    emergency_freq: int


class PowerConfig:
    """Central configuration manager"""

    DEFAULT_CONFIG_LOCATIONS = [
        "/etc/power-management/config.json",
        "~/.config/power-management/config.json",
        "./config/config.json",
    ]

    def __init__(self, config_file: Optional[str] = None):
        """
        Initialize configuration

        Args:
            config_file: Optional path to config file. If None, will search default locations.
        """
        self.config_file = self._find_config_file(config_file)
        self.paths = self._setup_paths()
        self.thermal = ThermalConfig()
        self.frequency: Optional[FrequencyConfig] = None

        # Load from file if exists
        if self.config_file and Path(self.config_file).exists():
            self.load()

    def _find_config_file(self, config_file: Optional[str]) -> Optional[str]:
        """Find configuration file"""
        if config_file:
            return config_file

        # Search default locations
        for location in self.DEFAULT_CONFIG_LOCATIONS:
            path = Path(location).expanduser()
            if path.exists():
                return str(path)

        # Return first writable location for creating new config
        for location in self.DEFAULT_CONFIG_LOCATIONS:
            path = Path(location).expanduser()
            try:
                path.parent.mkdir(parents=True, exist_ok=True)
                return str(path)
            except (OSError, PermissionError):
                continue

        return None

    def _setup_paths(self) -> PathConfig:
        """Setup dynamic paths based on script location"""
        # Detect installation directory
        # Try to find where we're actually installed
        current_file = Path(__file__).resolve()
        install_dir = current_file.parent.parent.parent  # Go up from src/config/

        # Verify this is correct by checking for key files
        if not (install_dir / "scripts").exists():
            # Fallback: use current working directory
            install_dir = Path.cwd()

        install_dir = str(install_dir)

        # Setup all paths
        scripts_dir = os.path.join(install_dir, "scripts")
        src_dir = os.path.join(install_dir, "src")
        config_dir = os.path.join(install_dir, "config")
        log_dir = os.environ.get("POWER_MGMT_LOG_DIR", "/tmp")

        return PathConfig(
            install_dir=install_dir,
            scripts_dir=scripts_dir,
            src_dir=src_dir,
            config_dir=config_dir,
            log_dir=log_dir,
            # Script paths
            performance_manager=os.path.join(scripts_dir, "performance_manager.sh"),
            ai_process_manager=os.path.join(scripts_dir, "ai_process_manager.sh"),
            emergency_cleanup=os.path.join(scripts_dir, "EMERGENCY_CLEANUP.sh"),
            cpu_frequency_manager=os.path.join(src_dir, "frequency", "cpu_frequency_manager.py"),
            smart_thermal_manager=os.path.join(scripts_dir, "smart_thermal_manager.py"),
            # Log files
            main_log=os.path.join(log_dir, "performance_manager.log"),
            cpu_log=os.path.join(log_dir, "cpu_frequency_manager.log"),
            thermal_log=os.path.join(log_dir, "thermal_manager.log"),
        )

    def set_frequency_config(self, min_freq: int, max_freq: int):
        """
        Set frequency configuration based on detected hardware

        Args:
            min_freq: Minimum CPU frequency in MHz
            max_freq: Maximum CPU frequency in MHz
        """
        # Calculate optimal frequencies for each profile
        freq_range = max_freq - min_freq

        self.frequency = FrequencyConfig(
            min_freq_mhz=min_freq,
            max_freq_mhz=max_freq,
            performance_freq=max_freq,  # 100% for performance
            balanced_freq=min_freq + int(freq_range * 0.7),  # 70% for balanced
            powersave_freq=min_freq + int(freq_range * 0.5),  # 50% for powersave
            emergency_freq=min_freq,  # Minimum for emergency
        )

    def set_thermal_config(self, max_safe_temp: int):
        """
        Set thermal configuration based on CPU capabilities

        Args:
            max_safe_temp: Maximum safe temperature for CPU
        """
        # Set thresholds as percentages of max safe temp
        # This ensures we're conservative across all CPUs
        self.thermal.comfort_temp = int(max_safe_temp * 0.65)  # 65%
        self.thermal.warning_temp = int(max_safe_temp * 0.75)  # 75%
        self.thermal.critical_temp = int(max_safe_temp * 0.85)  # 85%
        self.thermal.emergency_temp = int(max_safe_temp * 0.95)  # 95%

    def save(self) -> bool:
        """Save configuration to file"""
        if not self.config_file:
            return False

        try:
            config_data = {
                "paths": asdict(self.paths),
                "thermal": asdict(self.thermal),
                "frequency": asdict(self.frequency) if self.frequency else None,
            }

            config_path = Path(self.config_file)
            config_path.parent.mkdir(parents=True, exist_ok=True)

            with open(config_path, "w") as f:
                json.dump(config_data, f, indent=2)

            return True
        except Exception as e:
            print(f"Failed to save config: {e}")
            return False

    def load(self) -> bool:
        """Load configuration from file"""
        if not self.config_file or not Path(self.config_file).exists():
            return False

        try:
            with open(self.config_file, "r") as f:
                config_data = json.load(f)

            # Load paths
            if "paths" in config_data:
                self.paths = PathConfig(**config_data["paths"])

            # Load thermal
            if "thermal" in config_data:
                self.thermal = ThermalConfig(**config_data["thermal"])

            # Load frequency
            if "frequency" in config_data and config_data["frequency"]:
                self.frequency = FrequencyConfig(**config_data["frequency"])

            return True
        except Exception as e:
            print(f"Failed to load config: {e}")
            return False

    def get_script_path(self, script_name: str) -> Optional[str]:
        """Get path to a script, checking if it exists"""
        path_map = {
            "performance_manager": self.paths.performance_manager,
            "ai_process_manager": self.paths.ai_process_manager,
            "emergency_cleanup": self.paths.emergency_cleanup,
            "cpu_frequency_manager": self.paths.cpu_frequency_manager,
            "smart_thermal_manager": self.paths.smart_thermal_manager,
        }

        script_path = path_map.get(script_name)
        if script_path and Path(script_path).exists():
            return script_path
        return None

    def print_config(self):
        """Print current configuration"""
        print("=" * 60)
        print("⚙️  POWER MANAGEMENT CONFIGURATION")
        print("=" * 60)
        print()

        print("📁 PATHS:")
        print(f"   Install Dir: {self.paths.install_dir}")
        print(f"   Scripts Dir: {self.paths.scripts_dir}")
        print(f"   Config File: {self.config_file or 'Not set'}")
        print()

        print("🌡️  THERMAL CONFIG:")
        print(f"   Comfort:    < {self.thermal.comfort_temp}°C")
        print(f"   Warning:    {self.thermal.warning_temp}°C")
        print(f"   Critical:   {self.thermal.critical_temp}°C")
        print(f"   Emergency:  {self.thermal.emergency_temp}°C")
        print()

        if self.frequency:
            print("⚡ FREQUENCY CONFIG:")
            print(f"   Range:       {self.frequency.min_freq_mhz}-{self.frequency.max_freq_mhz} MHz")
            print(f"   Performance: {self.frequency.performance_freq} MHz")
            print(f"   Balanced:    {self.frequency.balanced_freq} MHz")
            print(f"   Powersave:   {self.frequency.powersave_freq} MHz")
            print(f"   Emergency:   {self.frequency.emergency_freq} MHz")
            print()

        print("=" * 60)


def get_default_config() -> PowerConfig:
    """Get default configuration instance"""
    return PowerConfig()


def main():
    """Test configuration system"""
    config = PowerConfig()

    # Simulate hardware detection
    config.set_frequency_config(min_freq=1200, max_freq=3000)
    config.set_thermal_config(max_safe_temp=100)

    # Print configuration
    config.print_config()

    # Test save
    if config.save():
        print("✅ Configuration saved successfully")
    else:
        print("⚠️  Could not save configuration")

    # Test script path lookup
    print("\n📝 Script Paths:")
    for script in ["performance_manager", "cpu_frequency_manager", "ai_process_manager"]:
        path = config.get_script_path(script)
        status = "✅" if path else "❌"
        print(f"   {status} {script}: {path or 'Not found'}")


if __name__ == "__main__":
    main()
