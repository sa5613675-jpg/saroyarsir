#!/bin/bash
#
# EMERGENCY DEPLOYMENT - Fix Online Exam Submission
# Run this on your VPS to fix the "Failed to submit" error
#

set -e  # Exit on any error

echo "🚨 EMERGENCY DEPLOYMENT: Fixing Online Exam Submission"
echo "========================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (use sudo)${NC}"
    exit 1
fi

# Navigate to project directory
PROJECT_DIR="/var/www/saroyarsir"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}❌ Project directory not found: $PROJECT_DIR${NC}"
    exit 1
fi

cd $PROJECT_DIR
echo -e "${GREEN}✅ In project directory: $PROJECT_DIR${NC}"

# Show current commit
echo ""
echo "📋 Current commit:"
git log -1 --oneline
echo ""

# Stash any local changes
echo "💾 Stashing local changes (if any)..."
if [ -n "$(git status --porcelain)" ]; then
    git stash
    echo -e "${YELLOW}⚠️  Local changes stashed${NC}"
else
    echo -e "${GREEN}✅ No local changes to stash${NC}"
fi

# Pull latest code
echo ""
echo "📥 Pulling latest code from GitHub..."
git fetch origin
git pull --rebase origin main

# Pop stash if we stashed anything
if git stash list | grep -q "stash@{0}"; then
    echo "📤 Restoring local changes..."
    git stash pop || echo -e "${YELLOW}⚠️  Could not restore stashed changes (review manually)${NC}"
fi

# Show new commit
echo ""
echo "📋 New commit:"
git log -1 --oneline
echo ""

# Verify critical files exist
echo "🔍 Verifying critical files..."
if [ ! -f "routes/online_exams.py" ]; then
    echo -e "${RED}❌ Missing routes/online_exams.py${NC}"
    exit 1
fi
if [ ! -f "templates/templates/partials/student_online_exams.html" ]; then
    echo -e "${RED}❌ Missing student_online_exams.html${NC}"
    exit 1
fi
echo -e "${GREEN}✅ All critical files present${NC}"

# Check database permissions
echo ""
echo "🔐 Checking database permissions..."
DB_FILE="smartgardenhub.db"
if [ -f "$DB_FILE" ]; then
    chown www-data:www-data $DB_FILE
    chmod 664 $DB_FILE
    echo -e "${GREEN}✅ Database permissions fixed${NC}"
else
    echo -e "${YELLOW}⚠️  Database file not found (might be first run)${NC}"
fi

# Restart service
echo ""
echo "🔄 Restarting saro.service..."
systemctl restart saro.service

# Wait for service to start
sleep 2

# Check service status
echo ""
echo "📊 Service Status:"
if systemctl is-active --quiet saro.service; then
    echo -e "${GREEN}✅ Service is running${NC}"
    systemctl status saro.service --no-pager | head -10
else
    echo -e "${RED}❌ Service failed to start!${NC}"
    echo ""
    echo "📋 Last 20 log lines:"
    journalctl -u saro.service -n 20 --no-pager
    exit 1
fi

# Check if service is listening on port
echo ""
echo "🔌 Checking if service is listening on port 8001..."
sleep 1
if lsof -i :8001 -sTCP:LISTEN > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service is listening on port 8001${NC}"
else
    echo -e "${RED}❌ Service is NOT listening on port 8001${NC}"
    echo "Check logs: sudo journalctl -u saro.service -n 50 --no-pager"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "📋 What was fixed:"
echo "  ✅ Exam submission error (eager loading fix)"
echo "  ✅ Beautiful modal confirmations (v2.0)"
echo "  ✅ Better error handling"
echo ""
echo "🧪 Test Now:"
echo "  1. Login as student at gsteaching.com/student"
echo "  2. Go to Online Exams tab"
echo "  3. Look for green 'v2.0' badge"
echo "  4. Start an exam"
echo "  5. Answer questions and submit"
echo "  6. Should see results modal ✅"
echo ""
echo "📊 Monitor logs in real-time:"
echo "  sudo journalctl -u saro.service -f"
echo ""
echo "🔄 Hard refresh in browser (clear cache):"
echo "  Ctrl + Shift + R"
echo ""
