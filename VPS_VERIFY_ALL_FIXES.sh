#!/bin/bash

echo "================================"
echo "🔍 VERIFY ALL FIXES ON VPS"
echo "================================"
echo ""

cat << 'VPSCMD'
cd /var/www/saroyarsir

echo "1️⃣ Current Git Commit:"
git log --oneline -1
echo ""

echo "2️⃣ Checking Fee Fix (routes/fees.py):"
if grep -q "others_fee=other_fee" routes/fees.py; then
    echo "✅ Fee fix: others_fee mapping found"
    grep -n "others_fee=other_fee" routes/fees.py | head -3
else
    echo "❌ Fee fix: NOT found"
fi
echo ""

echo "3️⃣ Checking SMS Template Fix (routes/monthly_exams.py):"
if grep -q "PRIORITY 1.*database" routes/monthly_exams.py; then
    echo "✅ SMS fix: Database priority found"
    grep -n "PRIORITY 1" routes/monthly_exams.py | head -2
else
    echo "❌ SMS fix: NOT found"
fi
echo ""

echo "4️⃣ Checking SMS Template Storage (routes/sms_templates.py):"
if grep -q "saved_to_database.*True" routes/sms_templates.py; then
    echo "✅ SMS storage: Database-only storage found"
else
    echo "❌ SMS storage: NOT found"
fi
echo ""

echo "5️⃣ Database Columns:"
source venv/bin/activate
python3 << 'EOF'
from app import create_app
from models import db

app = create_app('production')
with app.app_context():
    result = db.session.execute(db.text("PRAGMA table_info(fees)")).fetchall()
    columns = [row[1] for row in result]
    
    if 'exam_fee' in columns:
        print("✅ exam_fee column exists")
    else:
        print("❌ exam_fee column MISSING")
    
    if 'others_fee' in columns:
        print("✅ others_fee column exists")
    else:
        print("❌ others_fee column MISSING")
EOF
deactivate
echo ""

echo "================================"
echo "📊 Summary:"
echo "================================"
echo "All 3 issues should show ✅"
echo "If any show ❌, the fix is not deployed"
echo "================================"

VPSCMD
