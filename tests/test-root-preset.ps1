param(
    [string]$Jdk='D:\Program\Unity\Hub\Editor\6000.3.20f1\Editor\Data\PlaybackEngines\AndroidPlayer\OpenJDK',
    [string]$Python='C:\Users\OOP\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
    [string]$Adb='D:\LDPlayer\LDPlayer9\adb.exe',
    [string]$Serial='127.0.0.1:5559'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output=Join-Path $repo 'app/build/root-preset-fixture'
New-Item -ItemType Directory -Force $output | Out-Null
& "$Jdk/bin/javac.exe" -d $output (Join-Path $PSScriptRoot 'RootPresetFixture.java')
if ($LASTEXITCODE) { throw 'Diagnostic bridge compilation failed' }
$stdlib=Get-ChildItem 'D:\App\.tools\kitsune-gradle-cache\caches\modules-2\files-2.1\org.jetbrains.kotlin\kotlin-stdlib' -Recurse -Filter 'kotlin-stdlib-1.9.20.jar' | Select-Object -First 1 -ExpandProperty FullName
if (!$stdlib) { throw 'Kotlin stdlib not found' }
$cp="$output;$(Join-Path $repo 'app/build/tmp/kotlin-classes/debug');$stdlib"
$data=@{}
& "$Jdk/bin/java.exe" -cp $cp RootPresetFixture | ForEach-Object {
    $parts=$_ -split '=',2
    $data[$parts[0]]=$parts[1]
}
if ($LASTEXITCODE) { throw 'Actual Kotlin planner invocation failed' }
$check=@'
import sys,base64,sqlite3
sql,verify=[base64.b64decode(x).decode() for x in sys.argv[1:3]]
db=sqlite3.connect(':memory:')
db.executescript("CREATE TABLE settings(key TEXT PRIMARY KEY,value INT);CREATE TABLE hidelist(package_name TEXT,process TEXT,PRIMARY KEY(package_name,process));INSERT INTO settings VALUES('root_access',3);INSERT INTO hidelist VALUES('com.other.app','com.other.app');")
for _ in range(2):
    db.executescript(sql)
    assert db.execute(verify).fetchall()==[(1,)]
assert db.execute('SELECT COUNT(*) FROM hidelist').fetchone()==(4,)
assert db.execute("SELECT value FROM settings WHERE key='root_access'").fetchone()==(3,)
db.execute("DELETE FROM hidelist WHERE process='com.vng.playtogether:adnw'")
assert db.execute(verify).fetchall()==[]
print('PASS actual SQL: flags, both games, secondary process, idempotence, preserve other data, missing-target rejection')
'@
$check64=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($check))
& $Python -c "exec(__import__('base64').b64decode('$check64'))" $data.sql $data.verifySql
if ($LASTEXITCODE) { throw 'SQLite preset checks failed' }
# Syntax check only: no root, files, daemon calls, or real settings changes on LD.
$script=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($data.script))
$script | & $Adb -s $Serial shell sh -n
if ($LASTEXITCODE) { throw 'Android shell syntax check failed' }
Write-Output 'PASS Android sh -n: generated boot hook (not executed)'
$fixture=@'
# Non-root stdin fixture: every root/mutation command is a shell function mock.
case_run() {
  MODE=$1; ARG=$2; EXPECT=$3; REMOVAL=$4
  OUTPUT=$(
    (
      id() { if [ "$MODE" = nonroot ]; then echo 2000; else echo 0; fi; }
      magisk() {
        case "$2" in
          SELECT*) [ "$MODE" = badverify ] || echo ldmask_preset=1 ;;
          *) [ "$MODE" != writefail ] ;;
        esac
      }
      rm() { echo MOCK_REMOVE_HOOK; }
      set -- "$ARG"
__SCRIPT__
    )
  ); STATUS=$?
  [ "$STATUS" = "$EXPECT" ] || { echo "FAIL $MODE/$ARG status=$STATUS"; return 1; }
  case "$OUTPUT" in *MOCK_REMOVE_HOOK*) SEEN=yes ;; *) SEEN=no ;; esac
  [ "$SEEN" = "$REMOVAL" ] || { echo "FAIL $MODE/$ARG removal=$SEEN"; return 1; }
  echo "PASS mock boot-hook $MODE/$ARG"
}
case_run success --persist-only 0 no || exit 1
case_run success boot 0 yes || exit 1
case_run badverify boot 1 no || exit 1
case_run writefail boot 1 no || exit 1
case_run nonroot boot 1 no || exit 1
'@
$fixture=$fixture.Replace('__SCRIPT__',$script)
$fixture | & $Adb -s $Serial shell sh
if ($LASTEXITCODE) { throw 'Mock boot-hook control-flow checks failed' }
