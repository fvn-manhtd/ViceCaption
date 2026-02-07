# VibeCaption

## Development Instructions

### Running Tests

You can run the test suite using `xcodebuild` in the terminal.

**Command:**

```bash
xcodebuild test -scheme VibeCaption -destination 'platform=macOS'
```

This command performs the following:
1. Builds the project for the macOS platform.
2. Runs the tests defined in the `VibeCaptionTests` target.


```bash
xcodebuild test -scheme VibeCaption -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED="NO"
```


Export to json error
```
xcrun xcresulttool get object --legacy --path  /Users/tranmanh/Library/Developer/Xcode/DerivedData/VibeCaption-asamzmnudkqxovgylmlvmretfzuu/Logs/Test/Test-VibeCaption-2026.02.07_19-35-11-+0900.xcresult > test-result1.json
```