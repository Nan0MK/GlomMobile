# Builds GlomRemastered.apk (arm64-v8a, sideload, no Play Services).
# Odin's own Android link on Windows passes quoted paths that the NDK clang
# treats as the filename, so this compiles an object with Odin and links with
# clang. Shared mode also emits an empty main; object mode's main starts the
# runtime and calls the game, which is what Raylib's android_main expects.
# libraylib.a must be the arm64 static library without native_app_glue
# (this script drops that member if a fresh archive still has it).

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$odin = "C:\LL\odin-windows-amd64-dev-2026-01\dist\odin.exe"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$ndk = "$sdk\ndk\27.2.12479018"
$pre = "$ndk\toolchains\llvm\prebuilt\windows-x86_64"
$clang = "$pre\bin\clang.exe"
$ar = "$pre\bin\llvm-ar.exe"
$sysroot = "$pre\sysroot"
$libdir = "$sysroot\usr\lib\aarch64-linux-android\29"
$bt = "$sdk\build-tools\35.0.0"
$java = "C:\LL\Eclipse Adoptium\jdk-25.0.2.10-hotspot"
$env:JAVA_HOME = $java
$env:ODIN_ANDROID_NDK = $ndk

$ray = Join-Path $root "raylib\android\arm64\libraylib.a"
if (-not (Test-Path $ray)) {
	throw "Missing $ray. Build Raylib 5.5 with PLATFORM=Android, ABI arm64-v8a, API 29."
}
$members = & $ar t $ray
if ($members -contains "android_native_app_glue.c.o") {
	& $ar d $ray "android_native_app_glue.c.o"
	if ($LASTEXITCODE -ne 0) { throw "llvm-ar could not remove native_app_glue from libraylib.a" }
}

$libDir = Join-Path $root "android\lib\arm64-v8a"
New-Item -ItemType Directory -Force -Path $libDir | Out-Null
$obj = Join-Path $libDir "libmain.o"
$so = Join-Path $libDir "libmain.so"
$glueO = Join-Path $libDir "android_native_app_glue.o"

& $odin build src -target:linux_arm64 -subtarget:android -build-mode:obj -o:speed -minimum-os-version:29 "-out:$obj"
if ($LASTEXITCODE -ne 0) { throw "odin build failed: $LASTEXITCODE" }

$glueC = "$ndk\sources\android\native_app_glue\android_native_app_glue.c"
$compile = @(
	"--target=aarch64-linux-android29",
	"--sysroot=$sysroot",
	"-c", $glueC,
	"-o", $glueO,
	"-I$ndk\sources\android\native_app_glue",
	"-I$sysroot\usr\include",
	"-I$sysroot\usr\include\aarch64-linux-android"
)
& $clang @compile
if ($LASTEXITCODE -ne 0) { throw "glue compile failed: $LASTEXITCODE" }

$link = @(
	"--target=aarch64-linux-android29",
	"--sysroot=$sysroot",
	"-shared",
	"-Wl,--no-undefined",
	"-Wl,-z,max-page-size=16384",
	"-u", "ANativeActivity_onCreate",
	"-o", $so,
	$obj,
	$ray,
	$glueO,
	"-L$libdir",
	"-landroid", "-llog", "-lEGL", "-lGLESv2", "-lOpenSLES", "-latomic", "-lm", "-ldl", "-lc"
)
& $clang @link
if ($LASTEXITCODE -ne 0) { throw "link failed: $LASTEXITCODE" }

$build = Join-Path $root "build"
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory -Force -Path "$build\assets" | Out-Null
Copy-Item -Recurse (Join-Path $root "..\GlomRemastered\resources") "$build\assets\resources"

& py -3 (Join-Path $root "android\make_icon.py")
if ($LASTEXITCODE -ne 0) { throw "icon build failed: $LASTEXITCODE" }

$compiled = Join-Path $build "compiled-res.zip"
& "$bt\aapt2.exe" compile --dir "$root\android\res" -o $compiled
if ($LASTEXITCODE -ne 0) { throw "aapt2 compile failed: $LASTEXITCODE" }

$unsigned = Join-Path $build "unsigned.apk"
$aligned = Join-Path $build "aligned.apk"
& "$bt\aapt2.exe" link -I "$sdk\platforms\android-35\android.jar" --manifest "$root\android\AndroidManifest.xml" -A "$build\assets" -o $unsigned --min-sdk-version 29 --target-sdk-version 35 $compiled
if ($LASTEXITCODE -ne 0) { throw "aapt2 failed: $LASTEXITCODE" }

$adder = Join-Path $build "add_so.py"
@'
import sys, zipfile
apk, so = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(apk, "a") as z:
    info = zipfile.ZipInfo("lib/arm64-v8a/libmain.so")
    info.compress_type = zipfile.ZIP_STORED
    info.external_attr = 0o100644 << 16
    with open(so, "rb") as f:
        z.writestr(info, f.read())
'@ | Set-Content -Path $adder -Encoding ascii
& py -3 $adder $unsigned $so
if ($LASTEXITCODE -ne 0) { throw "adding libmain.so failed: $LASTEXITCODE" }

& "$bt\zipalign.exe" -f -P 16 4 $unsigned $aligned
if ($LASTEXITCODE -ne 0) { throw "zipalign failed: $LASTEXITCODE" }

$signing = Join-Path $root "android\signing.local.ps1"
if (-not (Test-Path $signing)) {
	throw "Missing $signing. Copy android\signing.local.ps1.example and set the keystore passwords."
}
. $signing
if (-not $storePass -or -not $keyPass) {
	throw "android\signing.local.ps1 must set `$storePass and `$keyPass."
}

$ks = Join-Path $root "android\glom.keystore"
if (-not (Test-Path $ks)) {
	& "$java\bin\keytool.exe" -genkeypair -keystore $ks -alias glom -keyalg RSA -keysize 2048 -validity 10000 -storepass $storePass -keypass $keyPass -dname "CN=Glom Remastered, O=Glom, C=US"
	if ($LASTEXITCODE -ne 0) { throw "keytool failed: $LASTEXITCODE" }
}

$apk = Join-Path $root "GlomRemastered.apk"
& "$bt\apksigner.bat" sign --ks $ks --ks-key-alias glom --ks-pass "pass:$storePass" --key-pass "pass:$keyPass" --out $apk $aligned
if ($LASTEXITCODE -ne 0) { throw "apksigner failed: $LASTEXITCODE" }
& "$bt\apksigner.bat" verify --verbose $apk
if ($LASTEXITCODE -ne 0) { throw "apksigner verify failed: $LASTEXITCODE" }

Write-Output "signed $apk"
