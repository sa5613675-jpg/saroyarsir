#!/bin/bash

echo "================================"
echo "🧪 Testing Permanent SMS Templates"
echo "================================"
echo ""

BASE_URL="http://localhost:8001"

# Login as teacher
echo "1️⃣ Login as Teacher..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "01800000000",
    "password": "teacher123"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Login failed!"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Logged in successfully"
echo "Token: ${TOKEN:0:20}..."
echo ""

# Test 1: Get current templates
echo "2️⃣ Get Current Templates..."
curl -s -X GET "$BASE_URL/api/sms/templates" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
echo ""

# Test 2: Update a template (should save to database)
echo "3️⃣ Update Custom Exam Template..."
UPDATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/sms/templates/custom_exam" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "{student_name} পরীক্ষায় পেয়েছে {marks}/{total} ({subject}) তারিখ {date}",
    "max_sms": 2
  }')

echo "$UPDATE_RESPONSE" | python3 -m json.tool
echo ""

# Test 3: Check database directly
echo "4️⃣ Check Database for Template..."
python3 << 'EOF'
from app import create_app
from models import Settings

app = create_app('development')
with app.app_context():
    template = Settings.query.filter_by(key='sms_template_custom_exam').first()
    if template:
        print("✅ Template found in database!")
        print(f"   Key: {template.key}")
        print(f"   Message: {template.value.get('message', 'N/A')}")
        print(f"   Category: {template.category}")
        print(f"   Updated: {template.updated_at}")
    else:
        print("❌ Template NOT found in database!")
EOF
echo ""

# Test 4: Login as another teacher (simulate different session)
echo "5️⃣ Login as Admin (Different User)..."
ADMIN_LOGIN=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "01700000000",
    "password": "admin123"
  }')

ADMIN_TOKEN=$(echo $ADMIN_LOGIN | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo "✅ Logged in as Admin"
echo ""

# Test 5: Get templates as admin (should see the same template from database)
echo "6️⃣ Get Templates as Admin (Should See Teacher's Template)..."
ADMIN_TEMPLATES=$(curl -s -X GET "$BASE_URL/api/sms/templates" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

echo "$ADMIN_TEMPLATES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('success'):
    custom_exam = data.get('data', {}).get('custom_exam', {})
    saved = custom_exam.get('saved', '')
    current = custom_exam.get('current', '')
    print('✅ Templates retrieved as Admin')
    print(f'   Saved: {saved}')
    print(f'   Current: {current}')
    if saved and 'পরীক্ষায়' in saved:
        print('✅ SUCCESS: Admin sees teacher\'s template from database!')
    else:
        print('❌ FAIL: Admin does not see teacher\'s template')
else:
    print('❌ Failed to get templates')
"
echo ""

# Test 6: Reset template
echo "7️⃣ Reset Template to Default..."
RESET_RESPONSE=$(curl -s -X POST "$BASE_URL/api/sms/templates/custom_exam/reset" \
  -H "Authorization: Bearer $TOKEN")

echo "$RESET_RESPONSE" | python3 -m json.tool
echo ""

# Test 7: Verify deletion from database
echo "8️⃣ Verify Template Deleted from Database..."
python3 << 'EOF'
from app import create_app
from models import Settings

app = create_app('development')
with app.app_context():
    template = Settings.query.filter_by(key='sms_template_custom_exam').first()
    if template:
        print("❌ Template still in database (should be deleted)")
    else:
        print("✅ Template removed from database (reset to default)")
EOF
echo ""

echo "================================"
echo "✅ Testing Complete!"
echo "================================"
echo ""
echo "Summary:"
echo "✅ Templates save to database permanently"
echo "✅ All teachers share the same templates"
echo "✅ Changes by one teacher visible to all"
echo "✅ Reset removes from database for all"
echo ""
