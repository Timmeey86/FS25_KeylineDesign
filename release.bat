@echo off
for %%a in ("%~dp0\.") do set "MOD_NAME=%%~nxa"
set "TEMP_FOLDER=%LOCALAPPDATA%\FarmSimTemp\%MOD_NAME%"
echo Copying relevant files to temp folder
robocopy . "%TEMP_FOLDER%" /mir /XD ".vscode" ".git" "img" "rust" /XF "*.py" "*.fsproj" "*.bat" "*.md" "*.txt" "*.zip" ".gitignore" ".exe"
echo Creating zip file
set "ZIP_FILE_PATH=%~dp0\%MOD_NAME%.zip"
if exist "%ZIP_FILE_PATH%" del -q "%ZIP_FILE_PATH%"
pushd "%TEMP_FOLDER%"
tar -a -c -f "%ZIP_FILE_PATH%" "*.*"
popd

echo Creating rust executable
pushd %~dp0rust
cargo build --release
copy /Y "%~dp0rust\target\x86_64-pc-windows-msvc\release\keyline_calc.exe" "%~dp0keyline_calc.exe"
popd