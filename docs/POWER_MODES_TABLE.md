<!--
   FORAI Analytics Headers - 2025-07-20T03:18:21.429956
   Agent: claude-code
   Session: unified_20250720_031821_807589
   Context: Systematic FORAI header application - Markdown files batch
   File: POWER_MODES_TABLE.md
   Auto-tracking: Enabled
   Memory-integrated: True
-->

# 📊 Power Modes Detailed Configuration Table

## 🎯 System Power Modes

| **Mode** | **CPU Governor** | **CPU Max Freq** | **GPU Power** | **AI Priority** | **Use Case** |
|----------|------------------|------------------|---------------|-----------------|--------------|
| 🔥 **Performance** | `performance` | 2.83GHz (100%) | `high` | Normal (0) | Gaming, Heavy Work |
| ⚖️ **Balanced** | `balanced` | Dynamic | `default` | Lower (+5) | Daily Use |
| 🔋 **Power Save** | `powersave` | Reduced | `low` | Lowest (+10) | Battery, Stability |
| 🚨 **Emergency** | `powersave` | Minimal | `low` | Variable | Blackscreen Prevention |

## 🤖 AI Process Management Modes

| **Mode** | **Claude CLI Priority** | **Other AI Priority** | **CPU Limits** | **System Mode** | **Memory** |
|----------|-------------------------|----------------------|----------------|----------------|------------|
| 🚀 **AI Performance** | Highest (-10) | High (-5) | Unlimited | Auto Performance | Optimized |
| ⚖️ **AI Stability** | Lower (+5) | Lower (+5) | None | Current | Current |
| 🔍 **AI Monitor** | Current | Current | None | Current | Monitor Only |
| 🚨 **AI Emergency** | Killed | Killed | Killed | Power Save | Cleared |

## 📈 Detailed Settings by Mode

### 🔥 Performance Mode
```bash
# System Settings
powerprofilesctl set performance
echo "high" > /sys/class/drm/card1/device/power_profile

# CPU Settings
- Governor: performance
- Max Frequency: 2833 MHz
- Turbo Boost: Enabled

# GPU Settings  
- Power Profile: high
- Clock Speed: Maximum
- Memory Clock: Maximum

# AI Process Priorities
- Claude CLI: renice 0 (normal)
- Other AI: renice 0 (normal)
- CPU Limits: None

# Use Cases
- Gaming (maximum FPS)
- Video encoding/rendering
- AI model training
- Heavy compilation
```

### ⚖️ Balanced Mode
```bash
# System Settings
powerprofilesctl set balanced
echo "default" > /sys/class/drm/card1/device/power_profile

# CPU Settings
- Governor: balanced/ondemand
- Max Frequency: Dynamic (up to 2833 MHz)
- Turbo Boost: Enabled when needed

# GPU Settings
- Power Profile: default
- Clock Speed: Dynamic
- Memory Clock: Dynamic

# AI Process Priorities
- Claude CLI: renice +5 (lower)
- Other AI: renice +5 (lower)
- CPU Limits: None

# Use Cases
- Daily desktop work
- Web browsing
- Light development
- Office applications
```

### 🔋 Power Save Mode
```bash
# System Settings
powerprofilesctl set power-saver
echo "low" > /sys/class/drm/card1/device/power_profile

# CPU Settings
- Governor: powersave
- Max Frequency: Reduced (~1.5-2.0 GHz)
- Turbo Boost: Disabled

# GPU Settings
- Power Profile: low
- Clock Speed: Minimum
- Memory Clock: Reduced

# AI Process Priorities
- Claude CLI: renice +10 (lowest)
- Other AI: renice +10 (lowest)
- CPU Limits: None

# Use Cases
- Battery conservation
- System stability testing
- Background tasks
- Overheating prevention
```

### 🚨 Emergency Mode
```bash
# System Settings
powerprofilesctl set power-saver
echo "low" > /sys/class/drm/card1/device/power_profile

# CPU Settings
- Governor: powersave
- Max Frequency: Minimum safe
- All cores: conservative

# GPU Settings
- Power Profile: low
- Clock Speed: Minimum
- All unnecessary features: Disabled

# AI Process Management
- All AI processes: Killed
- Memory: Cleared (drop_caches)
- CPU limits: Removed

# Use Cases
- Blackscreen recovery
- System overheating
- Process explosion cleanup
- Emergency stabilization
```

### 🚀 AI Performance Mode
```bash
# System Actions
1. Activates Performance Mode automatically
2. Sets AI process priorities

# Claude CLI Specific
- Priority: -10 (highest possible)
- CPU Affinity: All cores available
- Memory: No limits
- I/O Priority: High

# Other AI Processes
- Priority: -5 (high)
- CPU Access: Unrestricted
- Background priority: Disabled

# System Optimization
- Memory: Synced and optimized
- CPU Limits: All removed (pkill cpulimit)
- System Mode: Full performance
- GPU: High power mode

# Use Cases
- AI model inference
- Large language model processing
- Real-time AI applications
- Claude CLI intensive work
```

## 🔧 Technical Implementation Details

### Priority Levels Explained
```bash
Priority Range: -20 (highest) to +19 (lowest)
- -20 to -10: Real-time priority (system critical)
- -10 to -1:  High priority (our AI Performance mode)
-  0:         Normal priority (default)
- +1 to +10:  Lower priority (background tasks)
- +11 to +19: Lowest priority (batch jobs)
```

### GPU Power Profile Effects
```bash
"low":     Minimum clock speeds, maximum power saving
"default": Balanced performance and power consumption  
"high":    Maximum clock speeds, maximum performance
"auto":    Dynamic adjustment based on load
```

### CPU Governor Behavior
```bash
"performance":  Always maximum frequency
"balanced":     Intel P-State balanced performance
"powersave":    Always minimum frequency
"ondemand":     Frequency scales with load
"conservative": Gradual frequency scaling
```

## 📊 Performance Impact Measurements

### Before Power Management
- **System Load**: 4.43 average
- **Memory Usage**: 5.0Gi / 7.8Gi (64%)
- **CPU Frequency**: Variable, unstable
- **GPU Issues**: Frequent blackscreens
- **AI Performance**: Inconsistent

### After Power Management
| Mode | Load | Memory | CPU Freq | GPU Stability | AI Performance |
|------|------|--------|----------|---------------|----------------|
| Performance | 0.46 | 2.6Gi (33%) | 2.83GHz | Stable | Maximum |
| Balanced | 0.8 | 2.7Gi (34%) | Dynamic | Stable | Good |
| Power Save | 0.3 | 2.5Gi (32%) | ~1.8GHz | Very Stable | Limited |
| Emergency | 0.1 | 1.8Gi (23%) | Minimum | Recovery | None |

## 🛡️ Safety Mechanisms

### Process Protection
- Maximum 10 instances of performance_manager.sh
- Timeout protection (5-8 seconds per operation)
- Error handling with graceful fallback
- Emergency cleanup available

### System Protection
- Blackscreen prevention in Emergency mode
- Memory management and cleanup
- CPU thermal protection
- GPU power limiting

### Data Protection
- Configuration backup before changes
- Logging of all operations
- Rollback capability
- Safe mode testing (dry-run)

## 🚀 Quick Reference Commands

```bash
# System Modes
./performance_manager.sh performance  # Max power
./performance_manager.sh balanced     # Smart balance  
./performance_manager.sh powersave    # Power saving
./performance_manager.sh emergency    # Emergency recovery

# AI Modes  
./ai_process_manager.sh performance   # AI max performance
./ai_process_manager.sh optimize      # AI stability
./ai_process_manager.sh emergency     # AI emergency stop

# Monitoring
./performance_manager.sh status       # System status
./ai_process_manager.sh show         # AI processes
./ai_process_manager.sh monitor      # Real-time monitoring

# GUI Access
./power_gui.sh                       # Graphical interface
```

---
**Last Updated**: 2025-07-10  
**Version**: 2.0  
**Tested On**: Intel Core2 Quad Q9550 + AMD Radeon RV710