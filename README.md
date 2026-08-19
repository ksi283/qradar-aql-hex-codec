# AQL Hex Codec Functions

A QRadar content extension that provides `hexCodec::decode` and `hexCodec::encode` AQL functions for converting between hex-encoded strings and ASCII/UTF-8 text.

## Use Case

Linux audit logs (auditd) forwarded to QRadar frequently contain hex-encoded fields such as `proctitle`, `cwd`, `exe`, and `cmdline`. These fields are unreadable in their raw form, making incident investigation difficult.

This extension allows analysts to decode those fields directly within AQL queries — no external scripts or custom log sources required.

**Before:**
```
proctitle = 2F7573722F7362696E2F737368640025324400690025324400696E7465726E616C2D73667470
```

**After applying `hexCodec::decode`:**
```
proctitle = /usr/sbin/sshd%-D-i%-internal-sftp
```

## Features

- **`hexCodec::decode(hex_string)`** — Decodes hex to ASCII/UTF-8 text
- **`hexCodec::encode(plain_string)`** — Encodes plain text to uppercase hex
- Handles spaces, `0x` prefix, mixed case input
- Returns `NULL` for invalid hex (odd length, non-hex characters)
- Safe: no exceptions thrown, bounded input length
- ES5 JavaScript for compatibility with QRadar 7.3.3 and later versions

## Supported QRadar Versions

| Version | Status |
|---------|--------|
| 7.3.3 Community Edition (Build 20191031163225) | Verified in lab |
| 7.5.0 UpdatePackage 6 (Build 20230519190832) | Verified in lab |
| 7.4.x | Not tested in this lab |
| QRadar on Cloud (QRoC) | Compatible (requires separate IBM approval) |
| < 7.3.3 | Not tested |

## Installation

1. Download the `.zip` extension package.
2. Log in to the QRadar Console as an administrator.
3. Navigate to **Admin** → **Extensions Management**.
4. Click **Add** and select the downloaded `.zip` file.
5. Follow the prompts to install. No restart is required.
6. The functions `hexCodec::decode` and `hexCodec::encode` are immediately available in AQL.

## Uninstallation

1. Navigate to **Admin** → **Extensions Management**.
2. Locate **AQL Hex Codec Functions** in the list.
3. Click **Uninstall** and confirm.
4. The AQL functions will no longer be available.

## Usage Examples

### 1. Decode auditd proctitle

```sql
SELECT
    LOGSOURCENAME(logsourceid) AS "Log Source",
    hexCodec::decode(proctitle) AS "Decoded Proctitle",
    username
FROM events
WHERE devicetype = 11
    AND proctitle IS NOT NULL
LIMIT 100
LAST 24 HOURS
```

### 2. Decode cwd and exe in one query

```sql
SELECT
    hexCodec::decode("cwd") AS "Working Directory",
    hexCodec::decode("exe") AS "Executable Path",
    hexCodec::decode("proctitle") AS "Process Title"
FROM events
WHERE LOGSOURCETYPENAME(devicetype) ILIKE '%Linux%'
    AND "cwd" IS NOT NULL
LIMIT 100
LAST 7 DAYS
```

### 3. Search for suspicious commands in decoded proctitle

```sql
SELECT
    starttime AS "Time",
    sourceip AS "Source",
    hexCodec::decode(proctitle) AS "Command"
FROM events
WHERE devicetype = 11
    AND hexCodec::decode(proctitle) ILIKE '%/etc/shadow%'
LIMIT 100
LAST 24 HOURS
```

### 4. Detect encoded reverse shell commands

```sql
SELECT
    starttime AS "Time",
    sourceip AS "Host",
    hexCodec::decode(proctitle) AS "Command",
    username
FROM events
WHERE devicetype = 11
    AND (
        hexCodec::decode(proctitle) ILIKE '%/dev/tcp/%'
        OR hexCodec::decode(proctitle) ILIKE '%nc -e%'
        OR hexCodec::decode(proctitle) ILIKE '%bash -i%'
    )
LIMIT 100
LAST 72 HOURS
```

### 5. Encode a known path for searching raw events

```sql
SELECT *
FROM events
WHERE proctitle = hexCodec::encode('/usr/sbin/sshd')
LIMIT 100
LAST 24 HOURS
```

## Behavior Notes

| Input | `hexCodec::decode` returns |
|-------|--------------------------|
| Valid hex (`48656C6C6F`) | Decoded text (`Hello`) |
| Hex with spaces (`48 65 6C 6C 6F`) | Decoded text (`Hello`) |
| `0x` prefix (`0x48656C6C6F`) | Decoded text (`Hello`) |
| Mixed case (`48656c6c6f`) | Decoded text (`Hello`) |
| Empty string | Empty string |
| `NULL` | `NULL` |
| Odd-length hex (`4865C`) | `NULL` |
| Non-hex characters (`ZZZZ`) | `NULL` |
| Input > 131072 chars | Truncated at limit, then decoded |

## Performance

- Single-pass decode with no regex for hex validation — O(n) performance.
- Input capped at 131,072 hex characters (64KB decoded output).
- No external dependencies or network calls.
- Suitable for use in queries scanning millions of events.

## Development & Building

### Prerequisites

- Linux/macOS shell with `zip` installed
- IBM QRadar SIEM (7.3.3+ or 7.5.0+) for testing
- Optional: SSH access to QRadar appliance for CLI installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/ksi283/qradar-aql-hex-codec.git
cd qradar-aql-hex-codec
```

2. Build the extension package:
```bash
chmod +x scripts/build-extension.sh
./scripts/build-extension.sh
```

3. The build outputs:
   - `dist/hexcodec-lab.zip` — Install via GUI (Extensions Management)
   - `dist/hexcodec.xml` — Install via CLI (`contentManagement.pl`)
   - `dist/AQL-Hex-Codec-Functions-1.0.0-docs.zip` — Documentation bundle

### Testing

Run the smoke tests immediately after installation:

```sql
-- Test 1: Basic decode
SELECT hexCodec::decode('48656C6C6F') AS decoded
FROM events LIMIT 1 LAST 7 DAYS

-- Expected: decoded = Hello

-- Test 2: Invalid hex returns NULL
SELECT hexCodec::decode('ZZZZ') AS decoded
FROM events LIMIT 1 LAST 7 DAYS

-- Expected: decoded = NULL

-- Test 3: Encode roundtrip
SELECT hexCodec::encode(hexCodec::decode('48656C6C6F')) AS roundtrip
FROM events LIMIT 1 LAST 7 DAYS

-- Expected: roundtrip = 48656C6C6F
```

For detailed build and deployment instructions, see [BUILD_AND_DEPLOY.md](BUILD_AND_DEPLOY.md).

## Architecture

This extension implements custom AQL functions using IBM QRadar's Content Extension framework:

- **Language:** ES5 JavaScript (compatible with QRadar 7.3.3+)
- **Deployment:** XML-based content extension package
- **Function Registration:** Declared via `<custom_aql_function>` tags in manifest
- **Execution Context:** Server-side execution within QRadar's AQL query engine
- **Input Validation:** Client-side length limits, server-side hex validation
- **Error Handling:** Returns `NULL` for invalid input (no exceptions thrown)

### Function Implementation

Both functions follow a defensive programming approach:
- Null-safe: `NULL` input → `NULL` output
- Bounded input length to prevent resource exhaustion
- Single-pass algorithms for optimal performance
- No external dependencies or network calls

## Troubleshooting

### Common Issues

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| `Unable to successfully validate supplied extension file` | Wrong ZIP structure or invalid XML | Use `dist/hexcodec-lab.zip` (only `hexcodec.xml` at root) or CLI with `dist/hexcodec.xml` |
| `hexCodec::decode` not recognized in AQL | Extension not installed or not propagated | Reinstall; wait 60s for multi-host propagation; retry query |
| `No results were returned` | No events in query time range | Run `SELECT COUNT(*) FROM events LIMIT 1 LAST 7 DAYS` to verify data exists; broaden time range |
| Decoded output shows garbled characters | Input contains non-UTF-8 binary data | Expected behavior for binary data; auditd uses UTF-8 text |
| Function returns `NULL` for valid-looking hex | Input has odd length or non-hex chars | Check input with `LENGTH()` and verify characters are `[0-9A-Fa-f]` |

### Debugging Tips

1. **Verify Extension Installation:**
   - Navigate to **Admin** → **Extensions Management**
   - Confirm **AQL Hex Codec Functions** shows status **INSTALLED**
   - Check both `decode` and `encode` functions are listed

2. **Test with Known Values:**
   ```sql
   SELECT hexCodec::decode('48656C6C6F') AS test FROM events LIMIT 1 LAST 7 DAYS
   ```
   Should return `Hello`. If it returns `NULL` or error, extension is not properly installed.

3. **Check QRadar Logs:**
   ```bash
   # On QRadar Console appliance
   tail -f /var/log/qradar.log | grep -i "hexcodec\|custom.*function"
   ```

4. **Validate Input Data:**
   ```sql
   SELECT 
       proctitle AS raw,
       LENGTH(proctitle) AS len,
       hexCodec::decode(proctitle) AS decoded
   FROM events
   WHERE proctitle IS NOT NULL
   LIMIT 10 LAST 24 HOURS
   ```

### Known Limitations

- **Max input length:** 131,072 characters (decode) / 65,536 characters (encode)
- **Character encoding:** UTF-8 only; other encodings may produce garbled output
- **Binary data:** Non-text binary data will decode but may display as symbols
- **QRadar version:** Requires QRadar 7.3.3 or later (ES5 JavaScript engine)

## Security Considerations

### Input Validation

- All inputs are validated before processing
- Length limits enforced to prevent resource exhaustion attacks
- Invalid hex characters safely rejected (returns `NULL`, no exceptions)
- No code injection vectors: pure data transformation

### Best Practices

1. **Use in WHERE clauses carefully:**
   ```sql
   -- ❌ Bad: decodes all events then filters (slow)
   SELECT * FROM events 
   WHERE hexCodec::decode(proctitle) ILIKE '%passwd%'
   
   -- ✅ Good: filter first, then decode (fast)
   SELECT hexCodec::decode(proctitle) AS cmd
   FROM events 
   WHERE proctitle IS NOT NULL 
       AND proctitle ILIKE '%706173737764%'  -- 'passwd' in hex
   ```

2. **Limit result sets:** Always use `LIMIT` to prevent excessive decoding operations

3. **Validate sources:** Only decode fields from trusted log sources (auditd, syslog)

4. **Monitor performance:** Use QRadar's query performance metrics to detect slow queries

### Permissions

- Extension installation requires **Admin** role
- AQL function execution uses standard QRadar user permissions
- No additional privileges needed to use the functions

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository** and create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow code standards:**
   - ES5 JavaScript only (QRadar 7.3.3 compatibility)
   - Defensive programming: null checks, bounds validation
   - Single-pass algorithms preferred
   - No external dependencies

3. **Test thoroughly:**
   - Test on QRadar 7.3.3 and 7.5.0 minimum
   - Include AQL test queries
   - Verify edge cases (null, empty, invalid input)

4. **Update documentation:**
   - Update README.md with new features
   - Add examples to usage section
   - Update CHANGELOG.md

5. **Submit a pull request:**
   - Describe the changes clearly
   - Reference any related issues
   - Include test results

### Code Review Criteria

- ✅ ES5 JavaScript compatibility
- ✅ Null-safe error handling
- ✅ Input validation and bounds checking
- ✅ Performance: O(n) or better
- ✅ No external dependencies
- ✅ Documentation and examples included
- ✅ Tested on QRadar 7.3.3 and 7.5.0

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

### Latest Changes

**Version 1.0.0** (Released: TBD)
- Initial release with `hexCodec::decode` and `hexCodec::encode`
- Verified on QRadar 7.3.3 CE (Build 20191031163225)
- Verified on QRadar 7.5.0 UP6 (Build 20230519190832)
- ES5 JavaScript for maximum compatibility
- Apache 2.0 license

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

## Contact & Support

- **Author:** ksi283
- **Organization:** ksi283
- **Email:** nvloc.dev@gmail.com
- **Repository:** https://github.com/ksi283/qradar-aql-hex-codec
- **Issues:** https://github.com/ksi283/qradar-aql-hex-codec/issues
