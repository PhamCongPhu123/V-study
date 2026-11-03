import importlib.util
import plistlib
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('mobile', Path(__file__).resolve().parents[1] / 'tools/configure_mobile.py')
mobile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mobile)


class MobileConfigurationTest(unittest.TestCase):
    def test_android_preserves_launcher_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'AndroidManifest.xml'
            path.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><activity android:name=".MainActivity"><intent-filter><action android:name="android.intent.action.MAIN"/></intent-filter></activity></application></manifest>')
            mobile.configure_android(path)
            mobile.configure_android(path)
            root = ET.parse(path).getroot()
            self.assertEqual(len(root.findall('uses-permission')), 1)
            self.assertEqual(len(root.findall('application/activity/intent-filter')), 2)
            self.assertEqual(root.find('application/activity/meta-data').get('{' + mobile.ANDROID_NS + '}value'), 'false')
            self.assertEqual(root.find('application/activity/intent-filter/action').get('{' + mobile.ANDROID_NS + '}name'), 'android.intent.action.MAIN')

    def test_ios_preserves_existing_schemes_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Info.plist'
            with path.open('wb') as stream:
                plistlib.dump({'CFBundleDisplayName': 'Vstudy', 'CFBundleURLTypes': [{'CFBundleURLSchemes': ['existing']}]}, stream)
            mobile.configure_ios(path)
            mobile.configure_ios(path)
            with path.open('rb') as stream:
                config = plistlib.load(stream)
            self.assertEqual(config['CFBundleDisplayName'], 'Vstudy')
            self.assertIs(config['FlutterDeepLinkingEnabled'], False)
            self.assertEqual([entry['CFBundleURLSchemes'] for entry in config['CFBundleURLTypes']], [['existing'], ['io.vstudy.app']])


if __name__ == '__main__':
    unittest.main()
