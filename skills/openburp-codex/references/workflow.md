# Workflow Reference

Use this reference when the user wants Codex to operate Burp on an authorized target.

## Recommended sequence

1. Confirm the target is authorized.
2. Decide whether the user wants a setup check or an actual test.
3. For setup checks, send one request or open one page only.
4. For active testing, keep HTTP actions inside Burp and browser actions inside the Burp-proxied browser.
5. If the user wants evidence in proxy history, route the action through `burp-browser`.
6. Summarize evidence clearly so the user can find it in Burp history or Repeater.

## Good prompt shapes

Setup validation:

```text
Use $openburp-codex to confirm Burp integration against https://staging.example.com. I have explicit authorization. Start with one request only.
```

Replay a request:

```text
Use $openburp-codex to resend this request through Burp Repeater and compare the response body. The target is an internal staging app I control.
```

Browser confirmation:

```text
Use $openburp-codex to load this authorized staging page through Burp, click the login button, and tell me whether the request appears in proxy history.
```

## Safe defaults

- If the user says "just test the integration", do one request or one page load.
- If the user gives a public domain without saying it is authorized, stop.
- If the user wants a vulnerability assessment, start with reconnaissance and minimal evidence collection before escalating to more intrusive steps.
