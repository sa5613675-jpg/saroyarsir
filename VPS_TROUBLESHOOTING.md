# VPS Troubleshooting Guide

## Issue: Fixes Not Working on VPS

If you're still experiencing the same problems on VPS after pulling the latest code, follow these steps:

## Step 1: Verify You Have Latest Code

On your VPS, run:

```bash
cd /var/www/saroyarsir
git fetch origin
git status
```

You should see: "Your branch is up to date with 'origin/main'"

If not, run:
```bash
git pull origin main
```

Expected commit: **be5fb26** or later

## Step 2: Verify the Fixes Are in the Code

Run this command on VPS to check if fixes are present:

```bash
cd /var/www/saroyarsir
grep -n "db.session.get(MonthlyExam" routes/monthly_exams.py
```

**Expected output:** Should show line number with `db.session.get(MonthlyExam, exam_id)`

If you see `MonthlyExam.query.get(exam_id)` instead, the code wasn't pulled correctly.

Check archived filter:
```bash
grep -n "Filter out archived students from rankings" routes/monthly_exams.py
```

**Expected output:** Should show line number with this comment

## Step 3: Restart Application

### If using systemd service:
```bash
sudo systemctl restart smartgardenhub
sudo systemctl status smartgardenhub
```

### If running manually:
```bash
pkill -f "python.*app.py"
cd /var/www/saroyarsir
source venv/bin/activate
nohup python app.py > logs/app.log 2>&1 &
```

## Step 4: Test Delete Monthly Exam

### Quick Python Test:
```bash
cd /var/www/saroyarsir
python3 << 'EOF'
from app import create_app, db
from models import MonthlyExam, MonthlyMark
import json

app = create_app()

# Test with app context
with app.app_context():
    with app.test_client() as client:
        # Login as teacher
        login = client.post('/api/auth/login',
            json={'phoneNumber': '01711111111', 'password': 'teacher123'},
            content_type='application/json'
        )
        print(f"Login: {login.status_code}")
        
        # Find an exam to delete (one without marks)
        exams = MonthlyExam.query.all()
        print(f"\nTotal monthly exams: {len(exams)}")
        
        for exam in exams:
            marks = MonthlyMark.query.filter_by(monthly_exam_id=exam.id).count()
            print(f"  Exam {exam.id}: {exam.title} - Marks: {marks}")
            
            if marks == 0:
                print(f"\n  ✓ Exam {exam.id} can be deleted (no marks)")
                
                # Test delete
                delete_response = client.delete(f'/api/monthly-exams/{exam.id}')
                result = delete_response.get_json()
                print(f"  Delete Status: {delete_response.status_code}")
                print(f"  Response: {json.dumps(result, indent=2)}")
                break
        else:
            print("\n  All exams have marks - cannot test delete")
EOF
```

## Step 5: Test Archived Students Filter

```bash
cd /var/www/saroyarsir
python3 << 'EOF'
from app import create_app
from models import User, UserRole, Batch
import json

app = create_app()

with app.app_context():
    with app.test_client() as client:
        # Login as teacher
        client.post('/api/auth/login',
            json={'phoneNumber': '01711111111', 'password': 'teacher123'},
            content_type='application/json'
        )
        
        # Check archived students
        archived = User.query.filter_by(role=UserRole.STUDENT, is_archived=True).all()
        active = User.query.filter_by(role=UserRole.STUDENT, is_archived=False, is_active=True).all()
        
        print(f"Archived students: {len(archived)}")
        for s in archived:
            print(f"  - {s.full_name} (ID: {s.id})")
        
        print(f"\nActive students: {len(active)}")
        
        # Test rankings endpoint
        response = client.get('/api/monthly-exams/1/ranking')
        data = response.get_json()
        
        if data.get('success'):
            rankings = data['data'].get('nearby_rankings', []) or data['data'].get('rankings', [])
            print(f"\nRankings returned: {len(rankings)} students")
            
            # Check if any archived student appears
            archived_ids = [s.id for s in archived]
            found_archived = [r for r in rankings if r.get('user_id') in archived_ids]
            
            if found_archived:
                print("❌ PROBLEM: Archived students found in rankings!")
                for r in found_archived:
                    print(f"  - {r.get('student_name')} (ID: {r.get('user_id')})")
            else:
                print("✅ GOOD: No archived students in rankings")
        else:
            print(f"Error getting rankings: {data.get('error')}")
EOF
```

## Step 6: Clear ALL Caches

### On VPS Server:
```bash
# Clear Python cache
cd /var/www/saroyarsir
find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find . -type f -name "*.pyc" -delete

# Restart application
sudo systemctl restart smartgardenhub
```

### In Browser:
1. Press `Ctrl + Shift + Delete`
2. Select "All time"
3. Check "Cached images and files" and "Cookies"
4. Click "Clear data"
5. Close all browser tabs
6. Open new tab and visit: `http://YOUR_VPS_IP:8001`

### Or use Incognito/Private mode:
- `Ctrl + Shift + N` (Chrome/Edge)
- `Ctrl + Shift + P` (Firefox)

## Step 7: Check Logs

```bash
# Service logs
sudo journalctl -u smartgardenhub -n 100 --no-pager

# Application logs
tail -100 /var/www/saroyarsir/logs/error.log
tail -100 /var/www/saroyarsir/logs/access.log
```

Look for errors like:
- `NameError: name 'current_user' is not defined`
- `NameError: name 'current_app' is not defined`
- `AttributeError: 'Query' object has no attribute 'get'`

## Common Problems & Solutions

### Problem 1: "Not found" when deleting

**Cause:** Old code still running

**Solution:**
```bash
cd /var/www/saroyarsir
git pull origin main
sudo systemctl restart smartgardenhub
# Wait 5 seconds
sudo systemctl status smartgardenhub
```

### Problem 2: Archived students still visible

**Cause:** Browser cache or old ranking data

**Solution:**
1. Clear browser cache completely (Ctrl+Shift+Delete)
2. Use Incognito mode
3. On VPS, recalculate rankings:

```bash
cd /var/www/saroyarsir
python3 << 'EOF'
from app import create_app, db
from models import MonthlyRanking, User

app = create_app()
with app.app_context():
    # Delete rankings for archived students
    archived_students = User.query.filter_by(is_archived=True).all()
    archived_ids = [s.id for s in archived_students]
    
    deleted = 0
    for uid in archived_ids:
        count = MonthlyRanking.query.filter_by(user_id=uid).delete()
        deleted += count
    
    db.session.commit()
    print(f"Deleted {deleted} ranking records for archived students")
EOF
```

### Problem 3: Service won't start

**Check status:**
```bash
sudo systemctl status smartgardenhub
```

**Check what's wrong:**
```bash
sudo journalctl -u smartgardenhub -n 50
```

**Common fixes:**
```bash
# Port already in use
sudo lsof -i :8001
sudo kill -9 <PID>

# Permission issues
sudo chown -R root:root /var/www/saroyarsir
sudo chmod -R 755 /var/www/saroyarsir

# Python environment issues
cd /var/www/saroyarsir
source venv/bin/activate
pip install -r requirements.txt
```

## Manual Test in Browser

1. **Test Delete:**
   - Login: http://YOUR_VPS_IP:8001
   - Teacher: 01711111111 / teacher123
   - Go to: Monthly Exams → Monthly Periods tab
   - Try to delete an exam without marks
   - Expected: Success or "Cannot delete - marks entered"
   - Should NOT see: "Not found" error

2. **Test Archived Filter:**
   - Go to: Archive section
   - Note archived student names
   - Go to: Attendance
   - Verify archived students DON'T appear
   - Go to: Monthly Exams → Rankings
   - Verify archived students DON'T appear

## Still Not Working?

If issues persist after following all steps:

1. **Verify git commit:**
   ```bash
   cd /var/www/saroyarsir
   git log -1 --oneline
   ```
   Should show: `be5fb26` or later

2. **Check file content directly:**
   ```bash
   grep -A 5 "def delete_monthly_exam" /var/www/saroyarsir/routes/monthly_exams.py | head -10
   ```
   Should show `db.session.get(MonthlyExam, exam_id)`

3. **Nuclear option - Full redeploy:**
   ```bash
   cd /var/www/saroyarsir
   git fetch --all
   git reset --hard origin/main
   sudo systemctl restart smartgardenhub
   ```

## Get Help

If still having issues, collect this info:

```bash
cd /var/www/saroyarsir
echo "=== System Info ===" > /tmp/debug.txt
git log -1 >> /tmp/debug.txt
echo "" >> /tmp/debug.txt
echo "=== Service Status ===" >> /tmp/debug.txt
sudo systemctl status smartgardenhub >> /tmp/debug.txt 2>&1
echo "" >> /tmp/debug.txt
echo "=== Recent Logs ===" >> /tmp/debug.txt
sudo journalctl -u smartgardenhub -n 50 >> /tmp/debug.txt 2>&1
cat /tmp/debug.txt
```

Send the output for debugging.
