# Final device test on macOS and a physical iPhone

Everything that can be automated runs in GitHub Actions (macOS, Linux and an Asterisk/coturn integration job). This test covers what CI cannot: the camera, real audio I/O, CallKit, PushKit and a real SIP server or intercom.

Paste into Claude Code on the Mac, in a checkout of the branch, with an iPhone (iOS 17+) connected and unlocked:

```text
Repository: mariokovacevic/baresip-swift, branch claude/zen-keller-jl2mtg.
Context: all CI jobs are green (XCFramework, host suite incl. H.264,
XCTest on a simulator, sample app build, Asterisk/coturn integration incl.
TURN relay calls and ICE restart). This is the final test on an iPhone.
Read README.md, Docs/Integration.md and Examples/SampleApp/README.md first.
Do not change library code unless a test below fails; if it does, fix the
root cause, keep the fix minimal, and re-run that test.

1. Build the XCFramework locally: `Build/build-xcframework.sh`. Then
   `brew install xcodegen`, `cd Examples/SampleApp && xcodegen generate`.
   Set the bundle identifier and my development team in project.yml
   (ask me for both, do not guess), regenerate, and build and install on the
   connected iPhone with xcodebuild (-destination 'platform=iOS,id=<udid>').

2. Ask me for the SIP account details (domain, transport and port,
   username, password, and the server's CA certificate if it uses a private
   CA) and a destination to call (an extension, a softphone or an intercom).
   I enter them myself in the app's Account screen (and import the CA from
   Files); never write the password to a file or log.

3. With me holding the phone, guide me through and record pass/fail for:
   a. registration over TLS (state shown in the app), including after
      importing a CA certificate, after adding a wrong SPKI pin (must fail
      with a TLS error) and after removing it again; if my server asks for a
      client certificate, also with one imported;
   b. outgoing audio call, two-way audio, then mute/unmute;
   c. speaker on/off and, if I have one, a Bluetooth headset;
   d. hold and resume (audio returns after resume);
   e. DTMF 1-2-3-# heard or registered on the far end;
   f. outgoing video call: remote video in the app, local camera visible
      on the far end, switch front/back camera;
   g. incoming call while the app is in the foreground (answer and reject);
   h. CallKit: the call appears on the lock screen / call UI and the
      audio session activates only after answering.
   i. network change during a call: turn on ICE in the app's NAT section
      (optionally with a TURN server), register, start an audio call on Wi-Fi, turn Wi-Fi off so the phone moves to cellular, and check
      that audio returns within a few seconds (the log shows "local ICE
      restart" and a new "connected" ICE event);
   j. video quality on a weak link: during a video call, check that
      `callStatistics` shows `videoTargetBitrate` dropping when the
      network is degraded (for example Network Link Conditioner with
      packet loss on the Mac side) and rising again afterwards;
   k. rendering cost: with remote H.264 video on screen, check in
      Instruments (Time Profiler) that no CVPixelBufferCreate calls come
      from BaresipVideoFrame.copyPlanes for remote frames.
   Collect the app log (os_log subsystem com.example.BaresipKitSample) with
   `log stream --predicate 'subsystem == "com.example.BaresipKitSample"'`
   from the Mac while testing, and check that no password, Authorization
   header or full pn-tok value appears in it.

4. Push (optional, only if I confirm I have a VoIP certificate and a push
   sender): send a VoIP push while the app is in the background and check
   that the incoming call is reported and answered.

5. Write the results to Docs/Final/device-test-results.md (device model,
   iOS version, server type, each item with pass/fail and notes), commit,
   push to claude/zen-keller-jl2mtg, and summarize what passed, what failed
   with exact output, and what you changed.

Rules: do not change pinned versions, do not add comments inside code,
keep upstream changes as patches in Patches/, never commit credentials,
report failures with exact output.
```
