# Public Channel Link Sharing

ThingLarp allows you to share live telemetry dashboards with clients, colleagues, or the public without requiring them to register an account.

---

## 1-Click Share Links

You can share any channel using direct deep-link URLs:

```text
https://thinglarp.iimarky123.io.vn/app/#/channel/{channel_id}
```

### How to Copy the Share Link
1. Open your channel in the Web Dashboard or native app.
2. Tap the **Share** icon (`🔗` / `Icons.share`) in the top app bar or next to your channel card.
3. The public link is automatically copied to your clipboard.

!!! tip "Private Channel Warning"
    If your channel is currently marked as **Private**, clicking the share button will display a prompt asking if you want to **Make Channel Public**. Anyone who opens a private link will see an *Access Denied* screen unless you toggle the channel to Public.

---

## Read-Only Public Viewer Mode

When an unauthenticated visitor opens a public link in any desktop or mobile browser:

- **Full Live Telemetry**: All sensor fields, latest values, and time-series charts load instantly.
- **Auto-Refresh**: Telemetry polls automatically every 10 seconds to keep charts up to date.
- **Privacy Protection**:
  - The **Devices** tab is hidden (device MQTT credentials are never exposed).
  - The **API Keys** tab is hidden (write keys are protected).
  - Channel deletion and field editing buttons are disabled.
- **Quick Sign-In**: An explicit **Sign In** button is visible in the header so registered owners can jump into edit mode at any time.
