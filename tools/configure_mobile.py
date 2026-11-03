"""Idempotently add the development auth callback to generated Flutter runners."""
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

ANDROID_NS = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ANDROID_NS)


def configure_android(path):
    tree = ET.parse(path)
    root = tree.getroot()
    attr = lambda name: '{' + ANDROID_NS + '}' + name
    if not any(p.get(attr('name')) == 'android.permission.INTERNET' for p in root.findall('uses-permission')):
        ET.SubElement(root, 'uses-permission', {attr('name'): 'android.permission.INTERNET'})
    activity = root.find('application/activity')
    if activity is None:
        raise ValueError('Android MainActivity not found; configure the callback manually.')
    # app_links (used by supabase_flutter) owns auth callbacks, not Router.
    routing = next((meta for meta in activity.findall('meta-data')
                    if meta.get(attr('name')) == 'flutter_deeplinking_enabled'), None)
    if routing is None:
        routing = ET.SubElement(activity, 'meta-data', {attr('name'): 'flutter_deeplinking_enabled'})
    routing.set(attr('value'), 'false')
    found = any(data.get(attr('scheme')) == 'io.vstudy.app' and data.get(attr('host')) == 'login-callback'
                for data in activity.findall('intent-filter/data'))
    if not found:
        intent = ET.SubElement(activity, 'intent-filter')
        ET.SubElement(intent, 'action', {attr('name'): 'android.intent.action.VIEW'})
        for category in ['android.intent.category.DEFAULT', 'android.intent.category.BROWSABLE']:
            ET.SubElement(intent, 'category', {attr('name'): category})
        ET.SubElement(intent, 'data', {attr('scheme'): 'io.vstudy.app', attr('host'): 'login-callback'})
    ET.indent(tree, space='    ')
    tree.write(path, encoding='utf-8', xml_declaration=True)


def configure_ios(path):
    with open(path, 'rb') as stream:
        config = plistlib.load(stream)
    config['FlutterDeepLinkingEnabled'] = False
    types = config.setdefault('CFBundleURLTypes', [])
    if not any('io.vstudy.app' in entry.get('CFBundleURLSchemes', []) for entry in types):
        types.append({'CFBundleURLName': 'io.vstudy.app.auth', 'CFBundleURLSchemes': ['io.vstudy.app']})
    with open(path, 'wb') as stream:
        plistlib.dump(config, stream, sort_keys=False)


if __name__ == '__main__':
    root = Path(__file__).resolve().parent.parent
    configure_android(root / 'android/app/src/main/AndroidManifest.xml')
    configure_ios(root / 'ios/Runner/Info.plist')
