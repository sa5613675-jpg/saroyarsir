# Deploy Online Exam UX Fix to VPS

## What's Fixed (v2.0)
✅ **No more browser popup blocking!**
- Replaced all `confirm()` dialogs with beautiful modal confirmations
- Smooth exam start with preview of exam details
- Smart submission confirmation showing answered count
- Mobile-optimized with better touch experience

## Quick Deploy (Recommended)

```bash
# SSH to VPS
ssh root@your-vps-ip

# Navigate to project
cd /var/www/saroyarsir

# Quick deploy (pulls latest code + restarts service)
bash quick_deploy.sh
```

## Manual Deploy

```bash
# SSH to VPS
ssh root@your-vps-ip

# Navigate to project
cd /var/www/saroyarsir

# Pull latest changes
git stash  # Save any local changes
git pull --rebase origin main
git stash pop  # Restore local changes if any

# Restart service
sudo systemctl restart saro.service

# Check status
sudo systemctl status saro.service
```

## Verify Deployment

1. **Check commit version:**
   ```bash
   cd /var/www/saroyarsir
   git log -1 --oneline
   # Should show: f028a03 Fix online exam UX: Replace browser popups...
   ```

2. **Check service status:**
   ```bash
   sudo systemctl status saro.service
   # Should show: active (running)
   ```

3. **Test in browser:**
   - Login as a student
   - Go to Online Exams tab
   - Look for green "v2.0" badge
   - Click "Start Exam" - should see beautiful modal (not browser confirm)
   - Click "Submit Exam" - should see answered count modal

## Troubleshooting

### Service won't start
```bash
# Check logs
sudo journalctl -u saro.service -n 50 --no-pager

# Common issues:
# 1. Database locked - restart helps
# 2. Port in use - check: sudo lsof -i :8001
# 3. Permission issues - check: ls -la /var/www/saroyarsir/smartgardenhub.db
```

### Old version still showing
```bash
# Hard refresh in browser (clears cache)
# Chrome/Firefox: Ctrl + Shift + R
# Safari: Cmd + Shift + R

# Or clear browser cache completely
```

### Database connection errors
```bash
# Check database
cd /var/www/saroyarsir
python3 optimize_sqlite.py

# Fix permissions
sudo chown www-data:www-data smartgardenhub.db
sudo chmod 664 smartgardenhub.db
```

## What Changed

### Before (v1.3)
```javascript
// Blocking browser confirm dialog
if (!confirm('Start exam?')) {
    return;
}
// Popup blockers could interfere here
await fetch('/api/...');
```

### After (v2.0)
```javascript
// Show beautiful modal
this.showStartConfirm = true;

// User confirms in modal
confirmStartExam() {
    // Smooth, no popup blocking
    await fetch('/api/...');
}
```

## Features Added

### Start Exam Modal
- Exam title and details
- Duration and question count
- Pass percentage threshold
- Warning about timer starting
- Beautiful UI with icons

### Submit Exam Modal
- Shows answered vs total questions
- Color-coded progress (green/orange)
- Warning for incomplete submissions
- Reminder about finality
- Review vs Submit buttons

## Next Steps After Deploy

1. Test with real students
2. Monitor for any errors: `sudo journalctl -u saro.service -f`
3. Collect feedback on new UX
4. Check mobile experience on actual phones

## Rollback (if needed)

```bash
cd /var/www/saroyarsir
git checkout c6f255c  # Previous version (v1.3)
sudo systemctl restart saro.service
```

## Support

If issues persist:
1. Check browser console (F12) for JavaScript errors
2. Check service logs for server errors
3. Verify database not corrupted
4. Test on different browser/device
