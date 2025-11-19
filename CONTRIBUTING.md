# Contributing to PowerManagement

Thank you for your interest in contributing to PowerManagement! This document provides guidelines and instructions for contributing.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Adding Hardware Support](#adding-hardware-support)
- [Documentation](#documentation)

## 🤝 Code of Conduct

### Our Standards

- **Be Respectful** - Treat everyone with respect and kindness
- **Be Inclusive** - Welcome contributors of all backgrounds and experience levels
- **Be Professional** - Keep discussions technical and constructive
- **Be Patient** - Remember that everyone is learning

### Unacceptable Behavior

- Harassment, discrimination, or offensive comments
- Personal attacks or trolling
- Publishing private information without permission
- Any conduct that creates an unwelcoming environment

## 🚀 Getting Started

### Prerequisites

- Linux system (Ubuntu, Debian, Fedora, Arch, etc.)
- Python 3.6+
- Git
- Basic knowledge of bash scripting and Python
- Understanding of Linux power management

### Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/PowerManagement.git
cd PowerManagement

# Add upstream remote
git remote add upstream https://github.com/milhy545/PowerManagement.git
```

### Stay Updated

```bash
# Fetch upstream changes
git fetch upstream

# Merge upstream changes into your branch
git merge upstream/main
```

## 💻 Development Setup

### Install in Development Mode

```bash
# Install dependencies
./install.sh

# Set up development environment
export PYTHONPATH="$PWD/src:$PYTHONPATH"
export POWER_MGMT_DIR="$PWD"

# Add to ~/.bashrc for persistence
echo 'export PYTHONPATH="/path/to/PowerManagement/src:$PYTHONPATH"' >> ~/.bashrc
echo 'export POWER_MGMT_DIR="/path/to/PowerManagement"' >> ~/.bashrc
```

### Development Tools

```bash
# Python linting
pip3 install pylint black mypy

# Shell script checking
sudo apt install shellcheck  # Ubuntu/Debian
sudo dnf install shellcheck  # Fedora
```

## 🔧 Making Changes

### Branch Naming

Use descriptive branch names:

```bash
git checkout -b feature/add-battery-management
git checkout -b fix/sensor-detection-crash
git checkout -b docs/improve-installation-guide
```

**Prefixes:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test additions/changes
- `perf/` - Performance improvements

### Commit Messages

Follow conventional commits format:

```
type(scope): short description

Longer description if needed.

- Bullet points for changes
- Reference issues: Fixes #123
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `refactor` - Code refactoring
- `test` - Testing
- `perf` - Performance
- `chore` - Maintenance

**Examples:**
```bash
git commit -m "feat(sensors): Add support for ITE IT8712F chip"
git commit -m "fix(gpu): Handle missing nvidia-smi gracefully"
git commit -m "docs(readme): Update installation instructions"
```

## 🧪 Testing

### Run Test Suite

```bash
# Full test suite
./tests/test_sensors.sh

# Individual component tests
python3 -m pytest tests/

# Specific test
python3 tests/test_hardware_detector.py
```

### Manual Testing

Before submitting:

1. **Test on Real Hardware**
   ```bash
   # Test sensor detection
   python3 src/sensors/universal_sensor_detector.py

   # Test GPU monitoring
   python3 src/sensors/gpu_monitor.py

   # Test power profiles
   ./scripts/performance_manager.sh test
   ```

2. **Check for Errors**
   ```bash
   # Python syntax check
   python3 -m py_compile src/**/*.py

   # Shell script check
   shellcheck scripts/*.sh integrations/*.sh
   ```

3. **Verify Documentation**
   ```bash
   # Check README renders correctly
   grip README.md  # Requires: pip install grip
   ```

### Test Coverage

Aim for:
- **Python Code**: 80%+ coverage
- **Shell Scripts**: Test critical paths
- **Integration Tests**: Test end-to-end workflows

## 📤 Submitting Changes

### Pull Request Process

1. **Update Documentation**
   - Update README.md if adding features
   - Update relevant docs/ files
   - Add entries to CHANGELOG.md

2. **Ensure Tests Pass**
   ```bash
   ./tests/test_sensors.sh
   ```

3. **Update CHANGELOG**
   ```markdown
   ## [Unreleased]

   ### Added
   - New feature description

   ### Fixed
   - Bug fix description
   ```

4. **Create Pull Request**
   - Use a clear title: "feat: Add temperature alert notifications"
   - Fill out PR template completely
   - Reference related issues: "Fixes #123"
   - Add screenshots/logs if applicable

5. **Address Review Comments**
   - Respond to all review comments
   - Make requested changes
   - Mark conversations as resolved

### PR Requirements

✅ **Required:**
- All tests pass
- Documentation updated
- CHANGELOG.md updated
- Commit messages follow conventions
- No merge conflicts

⭐ **Nice to Have:**
- Test coverage increased
- Performance improvements documented
- Examples added to docs/

## 📝 Coding Standards

### Python Style

Follow [PEP 8](https://pep8.org/):

```python
# Good
def detect_cpu_temperature(sensor_path: str) -> Optional[float]:
    """
    Detect CPU temperature from sensor path.

    Args:
        sensor_path: Path to temperature sensor file

    Returns:
        Temperature in Celsius or None if unavailable
    """
    try:
        with open(sensor_path, 'r') as f:
            temp_raw = int(f.read().strip())
            return temp_raw / 1000.0
    except (FileNotFoundError, ValueError) as e:
        logger.warning(f"Failed to read {sensor_path}: {e}")
        return None
```

**Requirements:**
- Type hints for function signatures
- Docstrings for all public functions/classes
- Error handling with specific exceptions
- Logging instead of print statements

### Shell Script Style

```bash
#!/bin/bash
set -euo pipefail

# Good
detect_gpu_card() {
    local card_path

    for card in /sys/class/drm/card[0-9]; do
        if [ -f "$card/device/power_profile" ]; then
            echo "$card"
            return 0
        fi
    done

    return 1
}
```

**Requirements:**
- Use `set -euo pipefail`
- Quote variables: `"$variable"`
- Use `local` for function variables
- Return meaningful exit codes
- Comment complex sections

### Code Organization

```
src/
├── hardware/       # Hardware detection
├── sensors/        # Sensor monitoring
├── frequency/      # CPU frequency control
├── config/         # Configuration management
└── services/       # Background services

scripts/           # User-facing scripts
integrations/      # Third-party integrations
tests/            # Test suite
docs/             # Documentation
```

## 🖥️ Adding Hardware Support

### Adding New CPU Support

1. **Update Hardware Detector**
   ```python
   # src/hardware/hardware_detector.py

   def _detect_cpu_generation(self, vendor, model_name):
       if vendor == CPUVendor.INTEL:
           if "Raptor Lake" in model_name:
               return CPUGeneration.RAPTORLAKE
   ```

2. **Add Thermal Thresholds**
   ```python
   thermal_limits = {
       CPUGeneration.RAPTORLAKE: {
           'max_temp': 100,
           'critical_temp': 95,
           # ...
       }
   }
   ```

3. **Test on Real Hardware**
   - Run full test suite
   - Verify thermal monitoring
   - Check frequency scaling

4. **Update Documentation**
   - Add to UNIVERSAL_HARDWARE.md
   - Update README compatibility list

### Adding New Sensor Chip

1. **Update Sensor Detector**
   ```python
   # src/sensors/universal_sensor_detector.py

   def _detect_sysfs_hwmon(self):
       # Add chip detection logic
       if "it8712" in chip_name:
           # Handle ITE IT8712F specific quirks
   ```

2. **Handle Edge Cases**
   - Missing sensors
   - Different sysfs paths
   - Atypical naming

3. **Add Tests**
   ```bash
   # tests/test_sensors.sh
   test_it8712_detection
   ```

### Adding New GPU Support

1. **Update GPU Monitor**
   ```python
   # src/sensors/gpu_monitor.py

   def _detect_nouveau_gpus(self):
       # Add Nouveau (open-source NVIDIA) support
   ```

2. **Test Multi-GPU Scenarios**

3. **Update Documentation**

## 📚 Documentation

### Documentation Standards

- **Clear and Concise** - Get to the point quickly
- **Examples** - Provide code examples
- **Screenshots** - Add visuals where helpful
- **Up-to-Date** - Update docs with code changes

### Documentation Files

- `README.md` - Overview and quick start
- `docs/UNIVERSAL_HARDWARE.md` - Hardware compatibility
- `docs/SENSOR_MONITORING.md` - Sensor features
- `docs/INTEGRATIONS.md` - Integration guides
- `CHANGELOG.md` - Version history
- `CONTRIBUTING.md` - This file

### Writing Documentation

```markdown
# Feature Name

## Overview
Brief description of the feature.

## Installation
\`\`\`bash
# Installation commands
\`\`\`

## Usage
\`\`\`bash
# Usage examples
\`\`\`

## Troubleshooting
Common issues and solutions.
```

## ❓ Questions?

- **Issues**: [GitHub Issues](https://github.com/milhy545/PowerManagement/issues)
- **Discussions**: [GitHub Discussions](https://github.com/milhy545/PowerManagement/discussions)
- **Email**: Contact maintainers for private inquiries

## 🎉 Recognition

Contributors will be:
- Listed in CHANGELOG.md
- Mentioned in release notes
- Added to contributors list (if significant contributions)

Thank you for contributing to PowerManagement! 🚀
