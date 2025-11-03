#!/usr/bin/env python3
"""
Test Monthly Exam Deletion
Tests the delete monthly exam functionality
"""
from app import create_app, db
from models import MonthlyExam, IndividualExam, MonthlyMark, MonthlyRanking
import json

def test_delete_monthly_exam():
    """Test complete delete monthly exam workflow"""
    app = create_app()
    
    with app.test_client() as client:
        print("=" * 60)
        print("TEST: Monthly Exam Deletion")
        print("=" * 60)
        
        # Step 1: Login as teacher
        print("\n1. Login as Teacher")
        login_response = client.post('/api/auth/login',
            json={'phoneNumber': '01711111111', 'password': 'teacher123'},
            content_type='application/json'
        )
        print(f"   Status: {login_response.status_code}")
        assert login_response.status_code == 200, "Login failed"
        login_data = login_response.get_json()
        if login_data.get('success'):
            print(f"   ✅ Logged in successfully")
        else:
            print(f"   ❌ Login failed: {login_data}")
        
        # Step 2: Create a test monthly exam
        print("\n2. Create Test Monthly Exam")
        create_response = client.post('/api/monthly-exams',
            json={
                'title': 'Test Delete Exam - January 2026',
                'month': 1,
                'year': 2026,
                'batch_id': 1,
                'individual_exams': [
                    {
                        'subject': 'Math',
                        'title': 'Math Test',
                        'marks': 50,
                        'exam_date': '2026-01-15'
                    },
                    {
                        'subject': 'English',
                        'title': 'English Test',
                        'marks': 30,
                        'exam_date': '2026-01-16'
                    }
                ]
            },
            content_type='application/json'
        )
        print(f"   Status: {create_response.status_code}")
        create_data = create_response.get_json()
        
        if create_response.status_code == 201:
            # Get the exam ID from the response
            if 'data' in create_data and 'monthly_exam' in create_data['data']:
                exam_id = create_data['data']['monthly_exam']['id']
            elif 'data' in create_data and 'id' in create_data['data']:
                exam_id = create_data['data']['id']
            else:
                exam_id = create_data['data']['monthly_exam']['id']
            print(f"   ✅ Created exam ID: {exam_id}")
        else:
            print(f"   ℹ️  Exam may already exist, trying to fetch")
            # Get existing exams
            list_response = client.get('/api/monthly-exams?batch_id=1')
            list_data = list_response.get_json()
            exam_id = list_data['data'][-1]['id']  # Get last exam
            print(f"   Using existing exam ID: {exam_id}")
        
        # Step 3: Check exam exists
        print("\n3. Verify Exam Exists")
        with app.app_context():
            exam = db.session.get(MonthlyExam, exam_id)
            if exam:
                print(f"   ✅ Exam found: {exam.title}")
                ind_exams = IndividualExam.query.filter_by(monthly_exam_id=exam_id).count()
                marks = MonthlyMark.query.filter_by(monthly_exam_id=exam_id).count()
                rankings = MonthlyRanking.query.filter_by(monthly_exam_id=exam_id).count()
                print(f"   Individual Exams: {ind_exams}")
                print(f"   Marks: {marks}")
                print(f"   Rankings: {rankings}")
            else:
                print(f"   ❌ Exam not found!")
                return
        
        # Step 4: Try to delete (should fail if marks exist)
        print("\n4. Attempt Delete")
        delete_response = client.delete(f'/api/monthly-exams/{exam_id}')
        print(f"   Status: {delete_response.status_code}")
        delete_data = delete_response.get_json()
        print(f"   Response: {json.dumps(delete_data, indent=2)}")
        
        if delete_response.status_code == 400:
            print(f"   ℹ️  Cannot delete: {delete_data.get('error')}")
            print("   This is expected if marks have been entered")
        elif delete_response.status_code == 200:
            print(f"   ✅ {delete_data.get('message')}")
            
            # Step 5: Verify deletion
            print("\n5. Verify Deletion")
            with app.app_context():
                exam = db.session.get(MonthlyExam, exam_id)
                if exam:
                    print(f"   ❌ Exam still exists!")
                else:
                    print(f"   ✅ Exam successfully deleted from database")
                    
                    # Check cascaded deletes
                    ind_exams = IndividualExam.query.filter_by(monthly_exam_id=exam_id).count()
                    rankings = MonthlyRanking.query.filter_by(monthly_exam_id=exam_id).count()
                    print(f"   Individual Exams remaining: {ind_exams}")
                    print(f"   Rankings remaining: {rankings}")
                    
                    if ind_exams == 0 and rankings == 0:
                        print(f"   ✅ All associated data deleted")
                    else:
                        print(f"   ⚠️  Some associated data still exists")
        else:
            print(f"   ❌ Unexpected response: {delete_data.get('error')}")
        
        # Step 6: Try to delete non-existent exam
        print("\n6. Test Delete Non-Existent Exam")
        delete_response = client.delete('/api/monthly-exams/99999')
        print(f"   Status: {delete_response.status_code}")
        delete_data = delete_response.get_json()
        print(f"   Message: {delete_data.get('error')}")
        if delete_response.status_code == 404:
            print(f"   ✅ Correct error handling for non-existent exam")
        
        print("\n" + "=" * 60)
        print("TEST COMPLETED")
        print("=" * 60)

if __name__ == '__main__':
    test_delete_monthly_exam()
