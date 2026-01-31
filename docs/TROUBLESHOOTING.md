# Troubleshooting

## No sudo access
```bash
sudo visudo
# Add: username ALL=(ALL) NOPASSWD: /usr/bin/powerprofilesctl
```

## MSR not loading
```bash
sudo modprobe msr
echo "msr" | sudo tee /etc/modules-load.d/msr.conf
```
