import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
import amazecc as api
import amazecc_campus as campus

class CollegeTest(unittest.TestCase):
    def test_room_ranges_and_single_rooms(self):
        for room,ranges,expected in [('A-301','116 – 405',True),('D1-301','116-405, 600-700',True),('105','101, 105, 109',True),('406','116 - 405',False),('','1-9999',False),('101','1001-1200',False)]:
            with self.subTest(room=room,ranges=ranges):self.assertEqual(campus.room_matches(room,ranges),expected)
    def test_month_rollover_and_invalid_dates(self):
        rows=[{'Date':'31','RoomNumber':'1-400'},{'Date':'1','RoomNumber':'1-400'},{'Date':'29','RoomNumber':'1-400'}]
        self.assertEqual([r['date'] for r in campus.laundry_events(rows,'301',dt.date(2025,1,31))],['2025-01-31','2025-02-01'])
        self.assertEqual(campus.laundry_events(rows,'301',dt.date(2024,2,28))[0]['date'],'2024-02-29')
        self.assertEqual(campus.laundry_events([{'Date':'1','RoomNumber':'1-400'}],'301',dt.date(2025,12,31))[0]['date'],'2026-01-01')
    def test_group_block_mapping(self):
        self.assertEqual(campus.resource('laundry',dict(gender='Female',block='C',mess='Veg')),('VITC-CG-L.json','VITC-C-F-L.json'))
        self.assertEqual(campus.resource('laundry',dict(gender='Male',block='C',mess='Veg'))[0],'VITC-CB-L.json')
        self.assertIsNone(campus.resource('laundry',dict(gender='Female',block='D1',mess='Veg')))
    def test_profile_preserves_unknown_and_override(self):
        self.assertEqual(campus.profile({}, {})['gender'],'')
        self.assertEqual(campus.profile({'campusBlock':'D2','campusRoom':'210'},{'gender':'female','blockName':'C BLOCK','roomNo':'100','messInfo':'NON'}),dict(gender='Female',block='D2',room='210',mess='Non Veg'))
    def test_failed_fetch_keeps_cache_and_freshness(self):
        cache={'laundry/VITC-A-L.json':{'rows':[{'Date':'2','RoomNumber':'1-10'}],'fetchedAt':100}}
        with patch.object(campus.urllib.request,'urlopen',side_effect=OSError('offline')):result=campus.load_resource('laundry',dict(gender='Male',block='A',mess='Veg'),cache,online=True)
        self.assertEqual(result['fetchedAt'],100);self.assertTrue(result['offline'])
    def test_fallback_never_uses_another_block_cache(self):
        cache={'laundry/VITC-A-L.json':{'rows':[{'Date':'99','RoomNumber':'1-10'}],'fetchedAt':100}}
        with patch.object(campus.urllib.request,'urlopen',side_effect=OSError('offline')):result=campus.load_resource('laundry',dict(gender='Male',block='D1',mess='Veg'),cache,online=True)
        self.assertEqual(result['fetchedAt'],0);self.assertFalse(any(r['Date']=='99' for r in result['rows']));self.assertTrue(result['sourceUpdated'])
    def test_grades_keep_failed_semesters_and_zero_scores(self):
        previous={'old':{'gpa':8,'courses':[{'title':'Saved'}]}}
        result=api.build_grade_history({'grades':{'old':None,'new':{'gpa':'9.5','grades':[{'courseTitle':'Algorithms','courseCode':'C1','grandTotal':'0','grade':'F','details':[{'component':'CAT I','scoredMark':'0','maxMark':'50','weightageMark':'0','weightagePercent':'15'}]}]}}},previous)
        self.assertEqual(result['old'],previous['old']);self.assertEqual(result['new']['gpa'],9.5)
        course=result['new']['courses'][0];self.assertEqual(course['total'],0);self.assertEqual(course['assessments'][0]['weighted'],0);self.assertNotIn('credits',course)
    def test_missing_marks_are_unknown(self):
        course=api.build_grade_history({'grades':{'s':{'gpa':'--','grades':[{'courseTitle':'Test','details':[{'component':'FAT','scoredMark':'Not Published'}]}]}}})['s']
        self.assertIsNone(course['gpa']);self.assertIsNone(course['courses'][0]['assessments'][0]['scored'])
    def test_offline_mode_never_requests_provider(self):
        with patch.object(campus.urllib.request,'urlopen') as request:
            result=campus.load_resource('laundry',dict(gender='Male',block='D1',mess='Veg'),{})
        request.assert_not_called();self.assertTrue(result['rows']);self.assertTrue(result['offline'])
    def test_private_snapshot_permissions(self):
        with tempfile.TemporaryDirectory() as folder:
            path=str(Path(folder)/'snapshot.json');api.write_private(path,{'room':'301'});self.assertEqual(Path(path).stat().st_mode&0o777,0o600)
if __name__=='__main__':unittest.main()
