# Advanced settings and custom HTTP headers

Settings now has a separate **Advanced** section, with an **Advanced options**
row after Display and before About. The advanced screen is a general home for
future advanced settings; its first section is **Custom HTTP headers**.

## Using headers

1. Open Advanced from Settings. Before the first login, enter the HTTPS server
   and username on the account form, then use its Advanced navigation button.
2. Add headers manually using name/value pairs. There is no Cloudflare template.
3. Values are masked; tap a row to edit, or use Show value in the editor.
4. To remove a header, swipe **right to left**. UIKit reveals the red trash/Delete
   action. Tap it, then confirm deletion. Full-swipe deletion is disabled. Cancel
   preserves the row; a Keychain failure also preserves it. There is no Delete
   action inside the editor. The last deletion leaves the Add header row and an
   empty-state footer. UIKit owns the swipe, retraction and row-removal animations.
5. The Send custom headers switch stops sending without deleting saved values.
   Editing and removal remain available while sending is off.

The first manually added header enables sending. If there are already headers,
adding/editing preserves the current switch. Changes affect new tasks and
retries; redirects within an existing task retain that task's snapshot.

## Cloudflare Access

For a policy accepting Service Tokens (typically Service Auth), manually add
`CF-Access-Client-Id` and `CF-Access-Client-Secret`. These authenticate against the
gateway; Seafile login/2FA still runs independently.

Headers are restricted to the account's **exact HTTPS origin**, including port.
A fileserver on another origin does not receive them. Neither do external
storage links, other accounts, subdomains or redirects to HTTP. Default and
explicit HTTPS port 443 are equivalent. The server URL's base path and username
also participate in the storage key, isolating installations in subpaths.

## Implementation

- `SeafCustomHeaders`: validates names/values, applies the origin policy and
  atomically stores the enabled flag and pairs in Keychain. No header values go
  into account info, Realm, preferences, iCloud or logs. One device-local,
  non-synchronizing Keychain item per normalized URL/username uses
  `AfterFirstUnlockThisDeviceOnly`. Before the first device unlock, an inaccessible
  Keychain fails the request rather than silently sending without its headers.
- `SeafHeaderSessionManager`: AFNetworking subclass applying headers when tasks
  are created, including data, multipart, file/data/stream uploads, downloads and
  raw data/download tasks. Neither the shared serializer nor global session
  defaults contain account headers. Requests keep their bodies, multipart
  boundaries and existing Seafile authentication. Conflicting names fail instead
  of overwriting an existing request header.
- Both account managers (login and API) use this subclass. Saved accounts select
  their scope before constructor-triggered server-info requests. Login selects
  the typed username before task creation. The thumbnail ping and comment-image
  downloads use the raw task wrapper instead of bypassing the header policy.
  Native collaborator avatars also receive an explicit account, with account
  isolation in their in-memory avatar cache. Native Wiki downloads use the
  wrapper while retaining their ephemeral cookie session.
- A task retains its profile snapshot solely in memory. On redirect the wrapper
  removes inherited custom headers and applies the origin policy again;
  cross-origin hops also drop explicit Authorization/Cookie headers. HTTP method
  and body follow NSURLSession's standard 302/307/308 behavior.
- App, Files, Share and Action targets use the same explicit Keychain access
  group `$(AppIdentifierPrefix)com.seafile.custom-headers`. Existing wildcard
  groups are preserved for existing client-certificate behavior. The profiles
  are read at each task creation, so extension processes do not keep stale
  settings. Account deletion attempts to remove its Keychain item; logout retains
  it so the next Seafile login can still pass through the gateway.
- An ambiguous 401 while custom headers are active does not destroy the Seafile
  token. The existing explicit Seafile wipe-header path is retained. A genuinely
  expired Seafile session in this mode may require signing in again manually.
- `SeafAdvancedSettingsViewController`: native inset-grouped UIKit table and
  editor, Dynamic Type, native destructive trailing actions, Spanish/English
  strings, native navigation and alert confirmation. Programmatic sections are
  mapped separately from static storyboard sections on both phone and tablet.

Names use the HTTP token grammar; duplicates are case-insensitive. HTTP transport
and authentication fields (`Authorization`, `Host`, `Cookie`, content framing,
hop-by-hop fields and `X-Seafile-*`) are reserved. Values may not be empty or
contain control characters. Limits: 20 pairs, 128 name bytes, 4096 value bytes,
16 KiB aggregate names/values. Values are preserved without trimming.

## Boundaries and validation still required

This covers the native account network stack. **WKWebView subresources,
JavaScript fetch/WebSocket traffic and interactive SSO are not intercepted**.
Those browser-based features need a separate gateway/browser-session solution;
loading a WKWebView's initial URL with headers would not cover its subresources.
The pre-login editor currently requires a username and therefore supports normal
Seafile login, not initial SSO. Never advertise complete Wiki/SSO compatibility
behind an Access policy that requires these headers on every browser request.

Signing profiles must authorize the new explicit Keychain group on every target.
All processes must use the same AppIdentifierPrefix. Verify the expanded Info.plist
value and entitlements on signed devices. Reinstalling on another device requires
entering values again. A Keychain cleanup failure during account removal is logged
by numeric code only; the account's unused item may require later cleanup.

Run the production-policy tests on macOS with Xcode Command Line Tools:

```sh
Tests/CustomHeaders/run.sh
```

They exercise validation, limits, case-insensitive duplicates, exact origin,
spoofed hosts/userinfo, account isolation, multipart/body/auth preservation,
disabled profiles, collisions and redirect credential stripping. They do not
access Keychain or contact a real server.

Before merging, build the app and all four extensions after `pod install` (the
podspec includes the new Pod classes automatically). On a signed iPhone/iPad,
verify Keychain sharing/error handling, cold start/first unlock, pre-login Access
credentials and Seafile 2FA, encrypted block transfers, redirects 302/307/308,
Files/Share/Action, photo backup, account changes, cancellation of deletion,
deleting the last header, failed saves, Dynamic Type and VoiceOver. Also check
unconfigured accounts and SSO/Wiki regressions with no headers configured.

The development environment is Linux without Xcode/Apple SDKs. The native tests,
iOS build and device checks have not been executed here. Repository/JSON/plist,
project membership, localizations and whitespace checks can be validated here;
they do not replace the Apple-platform checks above.
