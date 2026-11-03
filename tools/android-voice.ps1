# Makes sure the Android app has what Hisaab needs: microphone (voice typing),
# and permission to open WhatsApp / web links. Safe to run many times.
$m = Join-Path $PSScriptRoot '..\android\app\src\main\AndroidManifest.xml'
if (-not (Test-Path -LiteralPath $m)) { exit 0 }
$x = [IO.File]::ReadAllText($m)
$orig = $x

if ($x -notmatch 'RECORD_AUDIO') {
  $perms = "`n    <uses-permission android:name=""android.permission.RECORD_AUDIO""/>" +
           "`n    <uses-permission android:name=""android.permission.INTERNET""/>" +
           "`n    <uses-permission android:name=""android.permission.BLUETOOTH""/>" +
           "`n    <uses-permission android:name=""android.permission.BLUETOOTH_ADMIN""/>" +
           "`n    <uses-permission android:name=""android.permission.BLUETOOTH_CONNECT""/>"
  $x = ([regex]'(<manifest[^>]*>)').Replace($x, { param($mm) $mm.Value + $perms }, 1)
}
if ($x -notmatch '<queries>') {
  $x = $x.Replace('</manifest>', "    <queries>`n    </queries>`n</manifest>")
}
$add = ''
if ($x -notmatch 'android.speech.RecognitionService') {
  $add += "`n        <intent>`n            <action android:name=""android.speech.RecognitionService""/>`n        </intent>"
}
if ($x -notmatch 'android:scheme="https"') {
  $add += "`n        <intent>`n            <action android:name=""android.intent.action.VIEW""/>`n            <data android:scheme=""https""/>`n        </intent>"
}
if ($x -notmatch 'com.whatsapp"') {
  $add += "`n        <package android:name=""com.whatsapp""/>`n        <package android:name=""com.whatsapp.w4b""/>"
}
if ($add) { $x = ([regex]'<queries>').Replace($x, '<queries>' + $add, 1) }
$x = $x.Replace('android:label="hisaab"', 'android:label="Hisaab"')

if ($x -ne $orig) {
  [IO.File]::WriteAllText($m, $x)
  Write-Host 'Android: permissions for voice typing and WhatsApp are set.'
}
