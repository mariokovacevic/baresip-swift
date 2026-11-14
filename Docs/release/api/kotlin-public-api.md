# Kotlin public API surface (generated)

Generated with `javap -public` over `<module>/build/tmp/kotlin-classes/release` after `./gradlew :<module>:compileReleaseKotlin`. Classes under `.internal` packages, classes declared `internal` in source, synthetic `$$` classes, and members with module-mangled names (`name$module`) are left out. This approximates the binary-compatibility-validator's dump; that plugin is not configured in the project.

## baresipkit

```
public final class io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration {
  public io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration(java.lang.String, java.lang.String, java.lang.String, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipTransport, java.lang.String, java.lang.String, long, boolean, io.github.mariokovacevic.baresipkit.BaresipMediaEncryption, io.github.mariokovacevic.baresipkit.BaresipNatConfiguration, io.github.mariokovacevic.baresipkit.BaresipDtmfMode, java.util.List, java.util.List, java.util.List, boolean, boolean, boolean, java.util.List, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final java.lang.String getAor();
  public final java.lang.String getDisplayName();
  public final java.lang.String getRegistrar();
  public final java.lang.String getOutboundProxy();
  public final io.github.mariokovacevic.baresipkit.BaresipTransport getTransport();
  public final java.lang.String getAuthUser();
  public final java.lang.String getAuthPassword();
  public final long getRegisterExpires-UwyO8pc();
  public final boolean getSipOutbound();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaEncryption getMediaEncryption();
  public final io.github.mariokovacevic.baresipkit.BaresipNatConfiguration getNat();
  public final io.github.mariokovacevic.baresipkit.BaresipDtmfMode getDtmfMode();
  public final java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter> getContactParameters();
  public final java.util.List<java.lang.String> getAudioCodecs();
  public final java.util.List<java.lang.String> getVideoCodecs();
  public final boolean getAnswerEarlyMedia();
  public final boolean getAcceptTransfers();
  public final boolean getPictureUpdateOverSipInfo();
  public final java.util.List<java.lang.String> getIncomingHeaders();
  public final void validate();
  public final java.lang.String component1();
  public final java.lang.String component2();
  public final java.lang.String component3();
  public final java.lang.String component4();
  public final io.github.mariokovacevic.baresipkit.BaresipTransport component5();
  public final java.lang.String component6();
  public final java.lang.String component7();
  public final long component8-UwyO8pc();
  public final boolean component9();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaEncryption component10();
  public final io.github.mariokovacevic.baresipkit.BaresipNatConfiguration component11();
  public final io.github.mariokovacevic.baresipkit.BaresipDtmfMode component12();
  public final java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter> component13();
  public final java.util.List<java.lang.String> component14();
  public final java.util.List<java.lang.String> component15();
  public final boolean component16();
  public final boolean component17();
  public final boolean component18();
  public final java.util.List<java.lang.String> component19();
  public final io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration copy-ja2adrY(java.lang.String, java.lang.String, java.lang.String, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipTransport, java.lang.String, java.lang.String, long, boolean, io.github.mariokovacevic.baresipkit.BaresipMediaEncryption, io.github.mariokovacevic.baresipkit.BaresipNatConfiguration, io.github.mariokovacevic.baresipkit.BaresipDtmfMode, java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter>, java.util.List<java.lang.String>, java.util.List<java.lang.String>, boolean, boolean, boolean, java.util.List<java.lang.String>);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration(java.lang.String, java.lang.String, java.lang.String, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipTransport, java.lang.String, java.lang.String, long, boolean, io.github.mariokovacevic.baresipkit.BaresipMediaEncryption, io.github.mariokovacevic.baresipkit.BaresipNatConfiguration, io.github.mariokovacevic.baresipkit.BaresipDtmfMode, java.util.List, java.util.List, java.util.List, boolean, boolean, boolean, java.util.List, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipAccountID {
  public final long getRawValue();
  public static java.lang.String toString-impl(long);
  public java.lang.String toString();
  public static int hashCode-impl(long);
  public int hashCode();
  public static boolean equals-impl(long, java.lang.Object);
  public boolean equals(java.lang.Object);
  public static long constructor-impl(long);
  public static final io.github.mariokovacevic.baresipkit.BaresipAccountID box-impl(long);
  public final long unbox-impl();
  public static final boolean equals-impl0(long, long);
}
public final class io.github.mariokovacevic.baresipkit.BaresipAppLifecycle {
  public io.github.mariokovacevic.baresipkit.BaresipAppLifecycle(io.github.mariokovacevic.baresipkit.BaresipEngine);
  public final io.github.mariokovacevic.baresipkit.BaresipEngine getEngine();
  public final io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior getBackgroundBehavior();
  public final void setBackgroundBehavior(io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior);
  public final long getUnregisterTimeout-UwyO8pc();
  public final void setUnregisterTimeout-LRDsOJo(long);
  public final boolean isAway();
  public final void setChangeHandler(kotlin.jvm.functions.Function1<? super io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change, kotlin.Unit>);
  public final void start();
  public final void stop();
  public final void watchCalls$BaresipKit_baresipkit_release();
  public final void didEnterBackground$BaresipKit_baresipkit_release();
  public final void didBecomeActive$BaresipKit_baresipkit_release();
  public final java.lang.Object goAwayIfIdle$BaresipKit_baresipkit_release(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public static final java.lang.Object access$comeBack(io.github.mariokovacevic.baresipkit.BaresipAppLifecycle, kotlin.coroutines.Continuation);
  public static final java.lang.Object access$unregisterAll(io.github.mariokovacevic.baresipkit.BaresipAppLifecycle, kotlin.coroutines.Continuation);
}
public final class io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior> {
  public static final io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior STAY_ONLINE;
  public static final io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior SUSPEND;
  public static final io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior GO_OFFLINE;
  public static io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$BackgroundBehavior> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change> {
  public static final io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change SUSPENDED;
  public static final io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change WENT_OFFLINE;
  public static final io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change BACK_ONLINE;
  public static io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipAppLifecycle$Change> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration {
  public static final io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration$Companion Companion;
  public io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration(java.lang.String, java.lang.String, java.lang.String, java.lang.String, java.lang.Integer, java.lang.Integer, long, kotlin.ranges.IntRange, boolean, java.util.List, java.io.File, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final java.lang.String getSourceModule();
  public final java.lang.String getSourceDevice();
  public final java.lang.String getPlayerModule();
  public final java.lang.String getPlayerDevice();
  public final java.lang.Integer getSampleRate();
  public final java.lang.Integer getChannels();
  public final long getPacketTime-UwyO8pc();
  public final kotlin.ranges.IntRange getJitterBufferRange();
  public final boolean getAdaptiveJitterBuffer();
  public final java.util.List<java.lang.String> getCodecs();
  public final java.io.File getHoldMusicFile();
  public final java.lang.String component1();
  public final java.lang.String component2();
  public final java.lang.String component3();
  public final java.lang.String component4();
  public final java.lang.Integer component5();
  public final java.lang.Integer component6();
  public final long component7-UwyO8pc();
  public final kotlin.ranges.IntRange component8();
  public final boolean component9();
  public final java.util.List<java.lang.String> component10();
  public final java.io.File component11();
  public final io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration copy-k8zXyTc(java.lang.String, java.lang.String, java.lang.String, java.lang.String, java.lang.Integer, java.lang.Integer, long, kotlin.ranges.IntRange, boolean, java.util.List<java.lang.String>, java.io.File);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration();
  public io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration(java.lang.String, java.lang.String, java.lang.String, java.lang.String, java.lang.Integer, java.lang.Integer, long, kotlin.ranges.IntRange, boolean, java.util.List, java.io.File, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration$Companion {
  public final java.util.List<java.lang.String> getDEFAULT_CODECS();
  public io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipAudioEvent {
  public io.github.mariokovacevic.baresipkit.BaresipAudioEvent(boolean, boolean, io.github.mariokovacevic.baresipkit.BaresipError);
  public final boolean getInputRunning();
  public final boolean getOutputRunning();
  public final io.github.mariokovacevic.baresipkit.BaresipError getError();
  public final boolean component1();
  public final boolean component2();
  public final io.github.mariokovacevic.baresipkit.BaresipError component3();
  public final io.github.mariokovacevic.baresipkit.BaresipAudioEvent copy(boolean, boolean, io.github.mariokovacevic.baresipkit.BaresipError);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public interface io.github.mariokovacevic.baresipkit.BaresipCallController {
  public abstract boolean controls-_toeIIk(long);
  public abstract java.lang.Object placeCall-mNv01Hg(java.lang.String, boolean, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.BaresipCallID>);
  public abstract java.lang.Object answer--zJ10-c(long, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public abstract java.lang.Object end-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public abstract java.lang.Object setOnHold-7qpkdfE(boolean, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public abstract java.lang.Object setMuted-7qpkdfE(boolean, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public abstract void addMuteObserver(kotlin.jvm.functions.Function2<? super io.github.mariokovacevic.baresipkit.BaresipCallID, ? super java.lang.Boolean, kotlin.Unit>);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCallEndReason extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipCallEndReason> {
  public static final io.github.mariokovacevic.baresipkit.BaresipCallEndReason$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallEndReason ANSWERED_ELSEWHERE;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallEndReason DECLINED_ELSEWHERE;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallEndReason REPLACED;
  public static io.github.mariokovacevic.baresipkit.BaresipCallEndReason[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipCallEndReason valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipCallEndReason> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipCallEndReason$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipCallEndReason of(int);
  public io.github.mariokovacevic.baresipkit.BaresipCallEndReason$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCallID {
  public final long getRawValue();
  public static java.lang.String toString-impl(long);
  public java.lang.String toString();
  public static int hashCode-impl(long);
  public int hashCode();
  public static boolean equals-impl(long, java.lang.Object);
  public boolean equals(java.lang.Object);
  public static long constructor-impl(long);
  public static final io.github.mariokovacevic.baresipkit.BaresipCallID box-impl(long);
  public final long unbox-impl();
  public static final boolean equals-impl0(long, long);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCallInfo {
  public io.github.mariokovacevic.baresipkit.BaresipCallInfo(long, long, io.github.mariokovacevic.baresipkit.BaresipCallState, boolean, boolean, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, java.lang.String, java.lang.String, java.lang.String, java.lang.String, java.lang.String, long, long, boolean, io.github.mariokovacevic.baresipkit.BaresipCallID, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final long getId--jmX5X0();
  public final long getAccount-NTKvxsQ();
  public final io.github.mariokovacevic.baresipkit.BaresipCallState getState();
  public final boolean isOutgoing();
  public final boolean getHasVideo();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection getAudioDirection();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection getVideoDirection();
  public final java.lang.String getSipCallId();
  public final java.lang.String getRemoteUri();
  public final java.lang.String getRemoteDisplayName();
  public final java.lang.String getAudioCodec();
  public final java.lang.String getVideoCodec();
  public final long getSetupTime-UwyO8pc();
  public final long getDuration-UwyO8pc();
  public final boolean isMicrophoneMuted();
  public final io.github.mariokovacevic.baresipkit.BaresipCallID getReplacesCallId-iuPYccg();
  public final long component1--jmX5X0();
  public final long component2-NTKvxsQ();
  public final io.github.mariokovacevic.baresipkit.BaresipCallState component3();
  public final boolean component4();
  public final boolean component5();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection component6();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection component7();
  public final java.lang.String component8();
  public final java.lang.String component9();
  public final java.lang.String component10();
  public final java.lang.String component11();
  public final java.lang.String component12();
  public final long component13-UwyO8pc();
  public final long component14-UwyO8pc();
  public final boolean component15();
  public final io.github.mariokovacevic.baresipkit.BaresipCallID component16-iuPYccg();
  public final io.github.mariokovacevic.baresipkit.BaresipCallInfo copy-RriaAsE(long, long, io.github.mariokovacevic.baresipkit.BaresipCallState, boolean, boolean, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, java.lang.String, java.lang.String, java.lang.String, java.lang.String, java.lang.String, long, long, boolean, io.github.mariokovacevic.baresipkit.BaresipCallID);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipCallInfo(long, long, io.github.mariokovacevic.baresipkit.BaresipCallState, boolean, boolean, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, java.lang.String, java.lang.String, java.lang.String, java.lang.String, java.lang.String, long, long, boolean, io.github.mariokovacevic.baresipkit.BaresipCallID, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCallState extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipCallState> {
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState INCOMING;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState OUTGOING_INIT;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState OUTGOING_RINGING;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState EARLY_MEDIA;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState CONNECTED;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState STREAMS_RUNNING;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState PAUSING;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState PAUSED;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState RESUMING;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState PAUSED_BY_REMOTE;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState UPDATING;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState ENDED;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState FAILED;
  public static final io.github.mariokovacevic.baresipkit.BaresipCallState RELEASED;
  public final boolean isTerminal();
  public static io.github.mariokovacevic.baresipkit.BaresipCallState[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipCallState valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipCallState> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipCallState$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipCallState of(int);
  public io.github.mariokovacevic.baresipkit.BaresipCallState$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCallStatistics {
  public final long getId--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipStreamStatistics getAudio();
  public final io.github.mariokovacevic.baresipkit.BaresipStreamStatistics getVideo();
  public final io.github.mariokovacevic.baresipkit.BaresipIceState getIceState();
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType getLocalCandidate();
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType getRemoteCandidate();
  public final java.lang.String getLocalAddress();
  public final java.lang.String getRemoteAddress();
  public final double getMosEstimate();
  public final int getVideoTargetBitrate();
  public final long component1--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipStreamStatistics component2();
  public final io.github.mariokovacevic.baresipkit.BaresipStreamStatistics component3();
  public final io.github.mariokovacevic.baresipkit.BaresipIceState component4();
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType component5();
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType component6();
  public final java.lang.String component7();
  public final java.lang.String component8();
  public final double component9();
  public final int component10();
  public final io.github.mariokovacevic.baresipkit.BaresipCallStatistics copy-DsFoHIQ(long, io.github.mariokovacevic.baresipkit.BaresipStreamStatistics, io.github.mariokovacevic.baresipkit.BaresipStreamStatistics, io.github.mariokovacevic.baresipkit.BaresipIceState, io.github.mariokovacevic.baresipkit.BaresipCandidateType, io.github.mariokovacevic.baresipkit.BaresipCandidateType, java.lang.String, java.lang.String, double, int);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipCallStatistics(long, io.github.mariokovacevic.baresipkit.BaresipStreamStatistics, io.github.mariokovacevic.baresipkit.BaresipStreamStatistics, io.github.mariokovacevic.baresipkit.BaresipIceState, io.github.mariokovacevic.baresipkit.BaresipCandidateType, io.github.mariokovacevic.baresipkit.BaresipCandidateType, java.lang.String, java.lang.String, double, int, kotlin.jvm.internal.DefaultConstructorMarker);
}
public interface io.github.mariokovacevic.baresipkit.BaresipCameraHost {
  public static final io.github.mariokovacevic.baresipkit.BaresipCameraHost$Companion Companion;
  public abstract boolean start(io.github.mariokovacevic.baresipkit.BaresipCameraSource, java.lang.String, int, int, int);
  public abstract void stop(io.github.mariokovacevic.baresipkit.BaresipCameraSource);
  public abstract boolean switchDevice(io.github.mariokovacevic.baresipkit.BaresipCameraSource, java.lang.String);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCameraHost$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipCameraHost getInstalled$BaresipKit_baresipkit_release();
  public final void setInstalled$BaresipKit_baresipkit_release(io.github.mariokovacevic.baresipkit.BaresipCameraHost);
  public final void install(io.github.mariokovacevic.baresipkit.BaresipCameraHost);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCameraPosition extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipCameraPosition> {
  public static final io.github.mariokovacevic.baresipkit.BaresipCameraPosition FRONT;
  public static final io.github.mariokovacevic.baresipkit.BaresipCameraPosition BACK;
  public final java.lang.String getDeviceName();
  public final io.github.mariokovacevic.baresipkit.BaresipCameraPosition getToggled();
  public final boolean isMirroredInPreview();
  public static io.github.mariokovacevic.baresipkit.BaresipCameraPosition[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipCameraPosition valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipCameraPosition> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipCameraSource {
  public io.github.mariokovacevic.baresipkit.BaresipCameraSource(long);
  public final long getHandle$BaresipKit_baresipkit_release();
  public final boolean push-HOM7YUo(int, int, java.nio.ByteBuffer, java.nio.ByteBuffer, java.nio.ByteBuffer, int, int, int, long, int);
  public boolean equals(java.lang.Object);
  public int hashCode();
  public java.lang.String toString();
}
public final class io.github.mariokovacevic.baresipkit.BaresipCandidateType extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipCandidateType> {
  public static final io.github.mariokovacevic.baresipkit.BaresipCandidateType$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipCandidateType HOST;
  public static final io.github.mariokovacevic.baresipkit.BaresipCandidateType SERVER_REFLEXIVE;
  public static final io.github.mariokovacevic.baresipkit.BaresipCandidateType PEER_REFLEXIVE;
  public static final io.github.mariokovacevic.baresipkit.BaresipCandidateType RELAY;
  public static io.github.mariokovacevic.baresipkit.BaresipCandidateType[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipCandidateType valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipCandidateType> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipCandidateType$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType of(int);
  public io.github.mariokovacevic.baresipkit.BaresipCandidateType$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCertificateException extends java.lang.Exception {
  public io.github.mariokovacevic.baresipkit.BaresipCertificateException(io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason);
  public final io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason getReason();
}
public final class io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason> {
  public static final io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason UNREADABLE;
  public static final io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason NO_CERTIFICATE;
  public static final io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason NO_PRIVATE_KEY;
  public static final io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason ENCRYPTED_KEY;
  public static final io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason INVALID_CERTIFICATE;
  public final java.lang.String getDescription$BaresipKit_baresipkit_release();
  public static io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipCertificateException$Reason> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipCertificates {
  public static final io.github.mariokovacevic.baresipkit.BaresipCertificates INSTANCE;
  public final java.util.List<io.github.mariokovacevic.baresipkit.BaresipCertificates$Block> blocks$BaresipKit_baresipkit_release(byte[]);
  public final byte[] caBundle(byte[]);
  public final byte[] clientIdentity(byte[]);
  public final kotlin.Pair<java.lang.String, java.lang.String> split(byte[]);
  public final java.util.List<java.lang.String> summaries(byte[]);
}
public final class io.github.mariokovacevic.baresipkit.BaresipCertificates$Block {
  public io.github.mariokovacevic.baresipkit.BaresipCertificates$Block(java.lang.String, byte[], boolean);
  public final java.lang.String getLabel();
  public final byte[] getDer();
  public final boolean getEncrypted();
}
public final class io.github.mariokovacevic.baresipkit.BaresipConfiguration {
  public static final io.github.mariokovacevic.baresipkit.BaresipConfiguration$Companion Companion;
  public io.github.mariokovacevic.baresipkit.BaresipConfiguration(java.lang.String, java.util.UUID, java.lang.String, java.util.List, java.lang.String, boolean, kotlin.ranges.IntRange, int, io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration, io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration, io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration, io.github.mariokovacevic.baresipkit.BaresipLogLevel, boolean, boolean, boolean, int, kotlin.time.Duration, long, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final java.lang.String getUserAgent();
  public final java.util.UUID getInstanceUuid();
  public final java.lang.String getNetworkInterface();
  public final java.util.List<java.lang.String> getModules();
  public final java.lang.String getExtraConfiguration();
  public final boolean getIpv6();
  public final kotlin.ranges.IntRange getRtpPortRange();
  public final int getMaxCalls();
  public final io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration getAudio();
  public final io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration getVideo();
  public final io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration getTls();
  public final io.github.mariokovacevic.baresipkit.BaresipLogLevel getLogLevel();
  public final boolean getLogSipTrace();
  public final boolean getIceRelayOnly();
  public final boolean getVideoAdaptiveBitrate();
  public final int getVideoMinimumBitrate();
  public final kotlin.time.Duration getSessionTimer-FghU774();
  public final long getMinimumSessionTimer-UwyO8pc();
  public final java.lang.String component1();
  public final java.util.UUID component2();
  public final java.lang.String component3();
  public final java.util.List<java.lang.String> component4();
  public final java.lang.String component5();
  public final boolean component6();
  public final kotlin.ranges.IntRange component7();
  public final int component8();
  public final io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration component9();
  public final io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration component10();
  public final io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration component11();
  public final io.github.mariokovacevic.baresipkit.BaresipLogLevel component12();
  public final boolean component13();
  public final boolean component14();
  public final boolean component15();
  public final int component16();
  public final kotlin.time.Duration component17-FghU774();
  public final long component18-UwyO8pc();
  public final io.github.mariokovacevic.baresipkit.BaresipConfiguration copy-3RjvsBY(java.lang.String, java.util.UUID, java.lang.String, java.util.List<java.lang.String>, java.lang.String, boolean, kotlin.ranges.IntRange, int, io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration, io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration, io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration, io.github.mariokovacevic.baresipkit.BaresipLogLevel, boolean, boolean, boolean, int, kotlin.time.Duration, long);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipConfiguration();
  public io.github.mariokovacevic.baresipkit.BaresipConfiguration(java.lang.String, java.util.UUID, java.lang.String, java.util.List, java.lang.String, boolean, kotlin.ranges.IntRange, int, io.github.mariokovacevic.baresipkit.BaresipAudioConfiguration, io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration, io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration, io.github.mariokovacevic.baresipkit.BaresipLogLevel, boolean, boolean, boolean, int, kotlin.time.Duration, long, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipConfiguration$Companion {
  public final java.util.List<java.lang.String> getDEFAULT_MODULES();
  public io.github.mariokovacevic.baresipkit.BaresipConfiguration$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipContactParameter {
  public io.github.mariokovacevic.baresipkit.BaresipContactParameter(java.lang.String, java.lang.String);
  public final java.lang.String getName();
  public final java.lang.String getValue();
  public final java.lang.String component1();
  public final java.lang.String component2();
  public final io.github.mariokovacevic.baresipkit.BaresipContactParameter copy(java.lang.String, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipDiagnosticEvent {
  public io.github.mariokovacevic.baresipkit.BaresipDiagnosticEvent(io.github.mariokovacevic.baresipkit.BaresipLogLevel, java.lang.String);
  public final io.github.mariokovacevic.baresipkit.BaresipLogLevel getLevel();
  public final java.lang.String getMessage();
  public final io.github.mariokovacevic.baresipkit.BaresipLogLevel component1();
  public final java.lang.String component2();
  public final io.github.mariokovacevic.baresipkit.BaresipDiagnosticEvent copy(io.github.mariokovacevic.baresipkit.BaresipLogLevel, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipDtmfEvent {
  public io.github.mariokovacevic.baresipkit.BaresipDtmfEvent(char, boolean, boolean);
  public final char getDigit();
  public final boolean isEnd();
  public final boolean getViaSipInfo();
  public final char component1();
  public final boolean component2();
  public final boolean component3();
  public final io.github.mariokovacevic.baresipkit.BaresipDtmfEvent copy(char, boolean, boolean);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipDtmfMode extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipDtmfMode> {
  public static final io.github.mariokovacevic.baresipkit.BaresipDtmfMode AUTO;
  public static final io.github.mariokovacevic.baresipkit.BaresipDtmfMode RTP_EVENT;
  public static final io.github.mariokovacevic.baresipkit.BaresipDtmfMode SIP_INFO;
  public static io.github.mariokovacevic.baresipkit.BaresipDtmfMode[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipDtmfMode valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipDtmfMode> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipEngine implements java.lang.AutoCloseable {
  public static final io.github.mariokovacevic.baresipkit.BaresipEngine$Companion Companion;
  public io.github.mariokovacevic.baresipkit.BaresipEngine(io.github.mariokovacevic.baresipkit.BaresipConfiguration);
  public io.github.mariokovacevic.baresipkit.BaresipEngine(io.github.mariokovacevic.baresipkit.BaresipConfiguration, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final io.github.mariokovacevic.baresipkit.BaresipConfiguration getConfiguration();
  public final kotlinx.coroutines.flow.SharedFlow<io.github.mariokovacevic.baresipkit.BaresipEvent> getEvents();
  public final void setLogHandler(io.github.mariokovacevic.baresipkit.BaresipLogHandler);
  public final io.github.mariokovacevic.baresipkit.BaresipEngineState getState();
  public final boolean isEngineThread();
  public final java.lang.Object start(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object stop-VtjQ1oo(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object prepareForPushWakeUp(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object suspend(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object resumeFromBackground(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object networkDidChange(boolean, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object audioSessionDidActivate(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object audioSessionDidDeactivate(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object audioRouteDidChange(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object audioInterruption(boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object addAccount-PxoUvx4(io.github.mariokovacevic.baresipkit.BaresipAccountConfiguration, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.BaresipAccountID>);
  public final java.lang.Object removeAccount--DcK9hs(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setDefaultAccount--DcK9hs(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object register--DcK9hs(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object unregister--DcK9hs(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object updateCredentials-COfQSTc(long, java.lang.String, java.lang.String, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object updateContactParameters-COfQSTc(long, java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter>, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object accounts(kotlin.coroutines.Continuation<? super java.util.Map<io.github.mariokovacevic.baresipkit.BaresipAccountID, ? extends io.github.mariokovacevic.baresipkit.BaresipRegistrationState>>);
  public final io.github.mariokovacevic.baresipkit.BaresipRegistrationState registrationState-HziJOBc(long);
  public final java.lang.Object makeCall-TV35inQ(io.github.mariokovacevic.baresipkit.BaresipAccountID, java.lang.String, boolean, boolean, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.BaresipCallID>);
  public final java.lang.Object answer-XRL4cpc(long, boolean, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object sendProgress-XRL4cpc(long, boolean, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object reject-XRL4cpc(long, int, java.lang.String, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object hangup-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object hold-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object resume-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setActiveCall-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object sendDtmf-Wb1nNi8(long, java.lang.String, long, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object blindTransfer--zJ10-c(long, java.lang.String, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object attendedTransfer-u4tiay8(long, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object callInfo-I9_ACD0(long, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.BaresipCallInfo>);
  public final java.lang.Object incomingHeader-7qpkdfE(java.lang.String, long, kotlin.coroutines.Continuation<? super java.lang.String>);
  public final java.lang.Object activeCalls(kotlin.coroutines.Continuation<? super java.util.List<io.github.mariokovacevic.baresipkit.BaresipCallID>>);
  public final java.lang.Object callStatistics-I9_ACD0(long, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.BaresipCallStatistics>);
  public final java.lang.Object setMicrophoneMuted-7qpkdfE(boolean, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setAudioDirection-7qpkdfE(io.github.mariokovacevic.baresipkit.BaresipMediaDirection, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setVideoDirection-7qpkdfE(io.github.mariokovacevic.baresipkit.BaresipMediaDirection, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setVideoEnabled-7qpkdfE(boolean, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setCamera-7qpkdfE(java.lang.String, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object requestKeyframe-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setVideoMaxBitrate-7qpkdfE(java.lang.Integer, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object restartIce-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object startRecording--zJ10-c(long, java.io.File, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object stopRecording-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object sendMessage-1EnMdYU(java.lang.String, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipAccountID, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.BaresipMessageID>);
  public final java.lang.Object videoDevices(kotlin.coroutines.Continuation<? super java.util.List<java.lang.String>>);
  public final java.lang.Object setVideoRenderer-IeqBtVQ(io.github.mariokovacevic.baresipkit.BaresipVideoRenderer, long, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object startVideoPreview(java.lang.String, io.github.mariokovacevic.baresipkit.BaresipVideoRenderer, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object stopVideoPreview(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setCamera-7qpkdfE(io.github.mariokovacevic.baresipkit.BaresipCameraPosition, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public void close();
  public final void deliver$BaresipKit_baresipkit_release(io.github.mariokovacevic.baresipkit.BaresipEvent);
  public final void deliverLog$BaresipKit_baresipkit_release(io.github.mariokovacevic.baresipkit.BaresipLogEntry);
  public io.github.mariokovacevic.baresipkit.BaresipEngine();
  public static final java.lang.Object access$replaceSink(io.github.mariokovacevic.baresipkit.BaresipEngine, io.github.mariokovacevic.baresipkit.VideoSinkKey, io.github.mariokovacevic.baresipkit.VideoSinkBox, kotlin.jvm.functions.Function1, kotlin.coroutines.Continuation);
  public static final java.lang.Object access$onEngine(io.github.mariokovacevic.baresipkit.BaresipEngine, kotlin.jvm.functions.Function0, kotlin.coroutines.Continuation);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEngine$AbiVersion {
  public io.github.mariokovacevic.baresipkit.BaresipEngine$AbiVersion(int, int);
  public final int getMajor();
  public final int getMinor();
  public final int component1();
  public final int component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEngine$AbiVersion copy(int, int);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEngine$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipEngine$AbiVersion getAbiVersion();
  public final java.util.List<java.lang.String> getCapabilities();
  public final java.lang.String getCoreVersion();
  public final java.lang.String encodeContactParameters(java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter>);
  public io.github.mariokovacevic.baresipkit.BaresipEngine$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEngineState extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipEngineState> {
  public static final io.github.mariokovacevic.baresipkit.BaresipEngineState$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipEngineState IDLE;
  public static final io.github.mariokovacevic.baresipkit.BaresipEngineState STARTING;
  public static final io.github.mariokovacevic.baresipkit.BaresipEngineState READY;
  public static final io.github.mariokovacevic.baresipkit.BaresipEngineState RUNNING;
  public static final io.github.mariokovacevic.baresipkit.BaresipEngineState STOPPING;
  public static final io.github.mariokovacevic.baresipkit.BaresipEngineState STOPPED;
  public static final io.github.mariokovacevic.baresipkit.BaresipEngineState FAILED;
  public static io.github.mariokovacevic.baresipkit.BaresipEngineState[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipEngineState valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipEngineState> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipEngineState$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipEngineState of(int);
  public io.github.mariokovacevic.baresipkit.BaresipEngineState$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipError extends java.lang.Exception {
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Companion Companion;
  public io.github.mariokovacevic.baresipkit.BaresipError(io.github.mariokovacevic.baresipkit.BaresipError$Code, int, java.lang.Integer, java.lang.String, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipCallEndReason);
  public io.github.mariokovacevic.baresipkit.BaresipError(io.github.mariokovacevic.baresipkit.BaresipError$Code, int, java.lang.Integer, java.lang.String, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipCallEndReason, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final io.github.mariokovacevic.baresipkit.BaresipError$Code getCode();
  public final int getSystemErrno();
  public final java.lang.Integer getSipStatus();
  public final java.lang.String getSipReason();
  public final java.lang.String getDetail();
  public final io.github.mariokovacevic.baresipkit.BaresipCallEndReason getEndReason();
  public final boolean isFailure();
  public java.lang.String getMessage();
  public boolean equals(java.lang.Object);
  public int hashCode();
  public java.lang.String toString();
}
public final class io.github.mariokovacevic.baresipkit.BaresipError$Code extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipError$Code> {
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code OK;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code INVALID_ARGUMENT;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code INVALID_STATE;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code NOT_FOUND;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code NO_MEMORY;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code UNSUPPORTED;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code BUSY;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code TIMEOUT;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code NETWORK;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code TLS;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code AUTHENTICATION;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code SIP;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code MEDIA;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code BUFFER_TOO_SMALL;
  public static final io.github.mariokovacevic.baresipkit.BaresipError$Code INTERNAL_ERROR;
  public static io.github.mariokovacevic.baresipkit.BaresipError$Code[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipError$Code valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipError$Code> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipError$Code$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipError$Code of(int);
  public io.github.mariokovacevic.baresipkit.BaresipError$Code$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipError$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipError invalid(java.lang.String);
  public io.github.mariokovacevic.baresipkit.BaresipError$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public interface io.github.mariokovacevic.baresipkit.BaresipEvent {
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Audio implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public final io.github.mariokovacevic.baresipkit.BaresipCallID getCall-iuPYccg();
  public final io.github.mariokovacevic.baresipkit.BaresipAudioEvent getAudio();
  public final io.github.mariokovacevic.baresipkit.BaresipCallID component1-iuPYccg();
  public final io.github.mariokovacevic.baresipkit.BaresipAudioEvent component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Audio copy-UjIxOUY(io.github.mariokovacevic.baresipkit.BaresipCallID, io.github.mariokovacevic.baresipkit.BaresipAudioEvent);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Audio(io.github.mariokovacevic.baresipkit.BaresipCallID, io.github.mariokovacevic.baresipkit.BaresipAudioEvent, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Call implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public final long getCall--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipCallState getState();
  public final io.github.mariokovacevic.baresipkit.BaresipError getError();
  public final long component1--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipCallState component2();
  public final io.github.mariokovacevic.baresipkit.BaresipError component3();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Call copy--zJ10-c(long, io.github.mariokovacevic.baresipkit.BaresipCallState, io.github.mariokovacevic.baresipkit.BaresipError);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Call(long, io.github.mariokovacevic.baresipkit.BaresipCallState, io.github.mariokovacevic.baresipkit.BaresipError, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Diagnostic implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Diagnostic(io.github.mariokovacevic.baresipkit.BaresipDiagnosticEvent);
  public final io.github.mariokovacevic.baresipkit.BaresipDiagnosticEvent getDiagnostic();
  public final io.github.mariokovacevic.baresipkit.BaresipDiagnosticEvent component1();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Diagnostic copy(io.github.mariokovacevic.baresipkit.BaresipDiagnosticEvent);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Dtmf implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public final long getCall--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipDtmfEvent getDtmf();
  public final long component1--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipDtmfEvent component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Dtmf copy-I9_ACD0(long, io.github.mariokovacevic.baresipkit.BaresipDtmfEvent);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Dtmf(long, io.github.mariokovacevic.baresipkit.BaresipDtmfEvent, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Engine implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Engine(io.github.mariokovacevic.baresipkit.BaresipEngineState, io.github.mariokovacevic.baresipkit.BaresipError);
  public final io.github.mariokovacevic.baresipkit.BaresipEngineState getState();
  public final io.github.mariokovacevic.baresipkit.BaresipError getError();
  public final io.github.mariokovacevic.baresipkit.BaresipEngineState component1();
  public final io.github.mariokovacevic.baresipkit.BaresipError component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Engine copy(io.github.mariokovacevic.baresipkit.BaresipEngineState, io.github.mariokovacevic.baresipkit.BaresipError);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Ice implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public final long getCall--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipIceEvent getIce();
  public final long component1--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipIceEvent component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Ice copy-I9_ACD0(long, io.github.mariokovacevic.baresipkit.BaresipIceEvent);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Ice(long, io.github.mariokovacevic.baresipkit.BaresipIceEvent, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$IncomingCall implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public io.github.mariokovacevic.baresipkit.BaresipEvent$IncomingCall(io.github.mariokovacevic.baresipkit.BaresipCallInfo, boolean);
  public final io.github.mariokovacevic.baresipkit.BaresipCallInfo getInfo();
  public final boolean getEarlyVideo();
  public final io.github.mariokovacevic.baresipkit.BaresipCallInfo component1();
  public final boolean component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$IncomingCall copy(io.github.mariokovacevic.baresipkit.BaresipCallInfo, boolean);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Media implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public final long getCall--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaEventInfo getInfo();
  public final long component1--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaEventInfo component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Media copy-I9_ACD0(long, io.github.mariokovacevic.baresipkit.BaresipMediaEventInfo);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Media(long, io.github.mariokovacevic.baresipkit.BaresipMediaEventInfo, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Message implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Message(io.github.mariokovacevic.baresipkit.BaresipMessage);
  public final io.github.mariokovacevic.baresipkit.BaresipMessage getMessage();
  public final io.github.mariokovacevic.baresipkit.BaresipMessage component1();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Message copy(io.github.mariokovacevic.baresipkit.BaresipMessage);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$MessageStatus implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public io.github.mariokovacevic.baresipkit.BaresipEvent$MessageStatus(io.github.mariokovacevic.baresipkit.BaresipMessageStatus);
  public final io.github.mariokovacevic.baresipkit.BaresipMessageStatus getStatus();
  public final io.github.mariokovacevic.baresipkit.BaresipMessageStatus component1();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$MessageStatus copy(io.github.mariokovacevic.baresipkit.BaresipMessageStatus);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Network implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Network(io.github.mariokovacevic.baresipkit.BaresipNetworkEvent);
  public final io.github.mariokovacevic.baresipkit.BaresipNetworkEvent getNetwork();
  public final io.github.mariokovacevic.baresipkit.BaresipNetworkEvent component1();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Network copy(io.github.mariokovacevic.baresipkit.BaresipNetworkEvent);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Registration implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public final long getAccount-NTKvxsQ();
  public final io.github.mariokovacevic.baresipkit.BaresipRegistrationState getState();
  public final kotlin.time.Duration getExpires-FghU774();
  public final io.github.mariokovacevic.baresipkit.BaresipError getError();
  public final long component1-NTKvxsQ();
  public final io.github.mariokovacevic.baresipkit.BaresipRegistrationState component2();
  public final kotlin.time.Duration component3-FghU774();
  public final io.github.mariokovacevic.baresipkit.BaresipError component4();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Registration copy-ni6nxVA(long, io.github.mariokovacevic.baresipkit.BaresipRegistrationState, kotlin.time.Duration, io.github.mariokovacevic.baresipkit.BaresipError);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Registration(long, io.github.mariokovacevic.baresipkit.BaresipRegistrationState, kotlin.time.Duration, io.github.mariokovacevic.baresipkit.BaresipError, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Statistics implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public final long getCall--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipCallStatistics getStatistics();
  public final long component1--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipCallStatistics component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Statistics copy-I9_ACD0(long, io.github.mariokovacevic.baresipkit.BaresipCallStatistics);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Statistics(long, io.github.mariokovacevic.baresipkit.BaresipCallStatistics, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipEvent$Transfer implements io.github.mariokovacevic.baresipkit.BaresipEvent {
  public final long getCall--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipTransferEvent getTransfer();
  public final long component1--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipTransferEvent component2();
  public final io.github.mariokovacevic.baresipkit.BaresipEvent$Transfer copy-I9_ACD0(long, io.github.mariokovacevic.baresipkit.BaresipTransferEvent);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipEvent$Transfer(long, io.github.mariokovacevic.baresipkit.BaresipTransferEvent, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipFileLog {
  public io.github.mariokovacevic.baresipkit.BaresipFileLog(java.io.File, long, int);
  public io.github.mariokovacevic.baresipkit.BaresipFileLog(java.io.File, long, int, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final java.io.File getDirectory();
  public final void write(java.lang.String, java.lang.String);
  public final io.github.mariokovacevic.baresipkit.BaresipLogHandler handler(io.github.mariokovacevic.baresipkit.BaresipLogHandler);
  public final java.util.List<java.io.File> files();
}
public final class io.github.mariokovacevic.baresipkit.BaresipHandleStyle extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipHandleStyle> {
  public static final io.github.mariokovacevic.baresipkit.BaresipHandleStyle SIP_URI;
  public static final io.github.mariokovacevic.baresipkit.BaresipHandleStyle PHONE_NUMBER_WHEN_NUMERIC;
  public static io.github.mariokovacevic.baresipkit.BaresipHandleStyle[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipHandleStyle valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipHandleStyle> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipIceEvent {
  public io.github.mariokovacevic.baresipkit.BaresipIceEvent(io.github.mariokovacevic.baresipkit.BaresipIceState, io.github.mariokovacevic.baresipkit.BaresipCandidateType, io.github.mariokovacevic.baresipkit.BaresipCandidateType, java.lang.String, java.lang.String);
  public final io.github.mariokovacevic.baresipkit.BaresipIceState getState();
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType getLocalCandidate();
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType getRemoteCandidate();
  public final java.lang.String getLocalAddress();
  public final java.lang.String getRemoteAddress();
  public final io.github.mariokovacevic.baresipkit.BaresipIceState component1();
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType component2();
  public final io.github.mariokovacevic.baresipkit.BaresipCandidateType component3();
  public final java.lang.String component4();
  public final java.lang.String component5();
  public final io.github.mariokovacevic.baresipkit.BaresipIceEvent copy(io.github.mariokovacevic.baresipkit.BaresipIceState, io.github.mariokovacevic.baresipkit.BaresipCandidateType, io.github.mariokovacevic.baresipkit.BaresipCandidateType, java.lang.String, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipIceState extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipIceState> {
  public static final io.github.mariokovacevic.baresipkit.BaresipIceState$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipIceState NONE;
  public static final io.github.mariokovacevic.baresipkit.BaresipIceState GATHERING;
  public static final io.github.mariokovacevic.baresipkit.BaresipIceState CHECKING;
  public static final io.github.mariokovacevic.baresipkit.BaresipIceState CONNECTED;
  public static final io.github.mariokovacevic.baresipkit.BaresipIceState FAILED;
  public static io.github.mariokovacevic.baresipkit.BaresipIceState[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipIceState valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipIceState> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipIceState$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipIceState of(int);
  public io.github.mariokovacevic.baresipkit.BaresipIceState$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipLogDomain extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipLogDomain> {
  public static final io.github.mariokovacevic.baresipkit.BaresipLogDomain$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipLogDomain CORE;
  public static final io.github.mariokovacevic.baresipkit.BaresipLogDomain SIP;
  public static final io.github.mariokovacevic.baresipkit.BaresipLogDomain MEDIA;
  public static io.github.mariokovacevic.baresipkit.BaresipLogDomain[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipLogDomain valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipLogDomain> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipLogDomain$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipLogDomain of(int);
  public io.github.mariokovacevic.baresipkit.BaresipLogDomain$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipLogEntry {
  public io.github.mariokovacevic.baresipkit.BaresipLogEntry(io.github.mariokovacevic.baresipkit.BaresipLogLevel, io.github.mariokovacevic.baresipkit.BaresipLogDomain, java.lang.String);
  public final io.github.mariokovacevic.baresipkit.BaresipLogLevel getLevel();
  public final io.github.mariokovacevic.baresipkit.BaresipLogDomain getDomain();
  public final java.lang.String getMessage();
  public final io.github.mariokovacevic.baresipkit.BaresipLogLevel component1();
  public final io.github.mariokovacevic.baresipkit.BaresipLogDomain component2();
  public final java.lang.String component3();
  public final io.github.mariokovacevic.baresipkit.BaresipLogEntry copy(io.github.mariokovacevic.baresipkit.BaresipLogLevel, io.github.mariokovacevic.baresipkit.BaresipLogDomain, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public interface io.github.mariokovacevic.baresipkit.BaresipLogHandler {
  public abstract void log(io.github.mariokovacevic.baresipkit.BaresipLogEntry);
}
public final class io.github.mariokovacevic.baresipkit.BaresipLogLevel extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipLogLevel> {
  public static final io.github.mariokovacevic.baresipkit.BaresipLogLevel$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipLogLevel DEBUG;
  public static final io.github.mariokovacevic.baresipkit.BaresipLogLevel INFO;
  public static final io.github.mariokovacevic.baresipkit.BaresipLogLevel WARNING;
  public static final io.github.mariokovacevic.baresipkit.BaresipLogLevel ERROR;
  public static io.github.mariokovacevic.baresipkit.BaresipLogLevel[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipLogLevel valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipLogLevel> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipLogLevel$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipLogLevel of(int);
  public io.github.mariokovacevic.baresipkit.BaresipLogLevel$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipLogcat {
  public static final io.github.mariokovacevic.baresipkit.BaresipLogcat INSTANCE;
  public final io.github.mariokovacevic.baresipkit.BaresipLogHandler handler(java.lang.String);
}
public final class io.github.mariokovacevic.baresipkit.BaresipMediaDirection extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipMediaDirection> {
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaDirection$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaDirection INACTIVE;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaDirection SEND_ONLY;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaDirection RECEIVE_ONLY;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaDirection SEND_RECEIVE;
  public static io.github.mariokovacevic.baresipkit.BaresipMediaDirection[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipMediaDirection valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipMediaDirection> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipMediaDirection$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection of(int);
  public io.github.mariokovacevic.baresipkit.BaresipMediaDirection$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipMediaEncryption extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipMediaEncryption> {
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEncryption NONE;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEncryption SRTP_OPTIONAL;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEncryption SRTP_MANDATORY;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEncryption DTLS_SRTP;
  public static io.github.mariokovacevic.baresipkit.BaresipMediaEncryption[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipMediaEncryption valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipMediaEncryption> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipMediaEvent extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipMediaEvent> {
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent AUDIO_STARTED;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent REMOTE_HOLD;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent REMOTE_RESUME;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent ENCRYPTION_ESTABLISHED;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent KEYFRAME_REQUESTED;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent EARLY_VIDEO_AVAILABLE;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent RECORDING_STARTED;
  public static final io.github.mariokovacevic.baresipkit.BaresipMediaEvent RECORDING_STOPPED;
  public final int getCode$BaresipKit_baresipkit_release();
  public static io.github.mariokovacevic.baresipkit.BaresipMediaEvent[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipMediaEvent valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipMediaEvent> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipMediaEvent$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipMediaEvent of(int);
  public io.github.mariokovacevic.baresipkit.BaresipMediaEvent$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipMediaEventInfo {
  public io.github.mariokovacevic.baresipkit.BaresipMediaEventInfo(io.github.mariokovacevic.baresipkit.BaresipMediaEvent, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, java.lang.String);
  public final io.github.mariokovacevic.baresipkit.BaresipMediaEvent getEvent();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection getAudioDirection();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection getVideoDirection();
  public final java.lang.String getDetail();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaEvent component1();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection component2();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection component3();
  public final java.lang.String component4();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaEventInfo copy(io.github.mariokovacevic.baresipkit.BaresipMediaEvent, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, io.github.mariokovacevic.baresipkit.BaresipMediaDirection, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipMessage {
  public final io.github.mariokovacevic.baresipkit.BaresipAccountID getAccount-5AIbMXY();
  public final java.lang.String getFrom();
  public final java.lang.String getContentType();
  public final byte[] getBody();
  public final java.lang.String getText();
  public boolean equals(java.lang.Object);
  public int hashCode();
  public java.lang.String toString();
  public io.github.mariokovacevic.baresipkit.BaresipMessage(io.github.mariokovacevic.baresipkit.BaresipAccountID, java.lang.String, java.lang.String, byte[], kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipMessageID {
  public final long getRawValue();
  public static java.lang.String toString-impl(long);
  public java.lang.String toString();
  public static int hashCode-impl(long);
  public int hashCode();
  public static boolean equals-impl(long, java.lang.Object);
  public boolean equals(java.lang.Object);
  public static long constructor-impl(long);
  public static final io.github.mariokovacevic.baresipkit.BaresipMessageID box-impl(long);
  public final long unbox-impl();
  public static final boolean equals-impl0(long, long);
}
public final class io.github.mariokovacevic.baresipkit.BaresipMessageStatus {
  public final long getId-vUuD4mQ();
  public final boolean getDelivered();
  public final java.lang.Integer getSipStatus();
  public final io.github.mariokovacevic.baresipkit.BaresipError getError();
  public final long component1-vUuD4mQ();
  public final boolean component2();
  public final java.lang.Integer component3();
  public final io.github.mariokovacevic.baresipkit.BaresipError component4();
  public final io.github.mariokovacevic.baresipkit.BaresipMessageStatus copy-eRk59Xc(long, boolean, java.lang.Integer, io.github.mariokovacevic.baresipkit.BaresipError);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipMessageStatus(long, boolean, java.lang.Integer, io.github.mariokovacevic.baresipkit.BaresipError, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipNatConfiguration {
  public io.github.mariokovacevic.baresipkit.BaresipNatConfiguration(io.github.mariokovacevic.baresipkit.BaresipNatTraversal, java.lang.String, java.util.List, long, boolean, boolean, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final io.github.mariokovacevic.baresipkit.BaresipNatTraversal getMode();
  public final java.lang.String getStunUri();
  public final java.util.List<io.github.mariokovacevic.baresipkit.BaresipTurnServer> getTurnServers();
  public final long getRtpTimeout-UwyO8pc();
  public final boolean getRtcpMultiplexing();
  public final boolean getPinhole();
  public final io.github.mariokovacevic.baresipkit.BaresipNatTraversal component1();
  public final java.lang.String component2();
  public final java.util.List<io.github.mariokovacevic.baresipkit.BaresipTurnServer> component3();
  public final long component4-UwyO8pc();
  public final boolean component5();
  public final boolean component6();
  public final io.github.mariokovacevic.baresipkit.BaresipNatConfiguration copy-gwCluXo(io.github.mariokovacevic.baresipkit.BaresipNatTraversal, java.lang.String, java.util.List<io.github.mariokovacevic.baresipkit.BaresipTurnServer>, long, boolean, boolean);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipNatConfiguration();
  public io.github.mariokovacevic.baresipkit.BaresipNatConfiguration(io.github.mariokovacevic.baresipkit.BaresipNatTraversal, java.lang.String, java.util.List, long, boolean, boolean, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipNatTraversal extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipNatTraversal> {
  public static final io.github.mariokovacevic.baresipkit.BaresipNatTraversal NONE;
  public static final io.github.mariokovacevic.baresipkit.BaresipNatTraversal STUN;
  public static final io.github.mariokovacevic.baresipkit.BaresipNatTraversal ICE;
  public static io.github.mariokovacevic.baresipkit.BaresipNatTraversal[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipNatTraversal valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipNatTraversal> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipNetworkEvent {
  public io.github.mariokovacevic.baresipkit.BaresipNetworkEvent(boolean, java.lang.String);
  public final boolean getTransportsReset();
  public final java.lang.String getLocalAddress();
  public final boolean component1();
  public final java.lang.String component2();
  public final io.github.mariokovacevic.baresipkit.BaresipNetworkEvent copy(boolean, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor {
  public static final io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor$Companion Companion;
  public io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor(android.content.Context, io.github.mariokovacevic.baresipkit.BaresipEngine, boolean, boolean);
  public io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor(android.content.Context, io.github.mariokovacevic.baresipkit.BaresipEngine, boolean, boolean, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final void setChangeHandler(kotlin.jvm.functions.Function1<? super io.github.mariokovacevic.baresipkit.BaresipNetworkPath, kotlin.Unit>);
  public final void start();
  public final void stop();
  public static final void access$pathUpdated(io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor, io.github.mariokovacevic.baresipkit.BaresipNetworkPath);
}
public final class io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor$Companion {
  public final boolean shouldNotifyEngine(io.github.mariokovacevic.baresipkit.BaresipNetworkPath, io.github.mariokovacevic.baresipkit.BaresipNetworkPath);
  public io.github.mariokovacevic.baresipkit.BaresipNetworkMonitor$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipNetworkPath {
  public io.github.mariokovacevic.baresipkit.BaresipNetworkPath(java.lang.String, boolean);
  public final java.lang.String getInterfaceSummary();
  public final boolean isSatisfied();
  public final java.lang.String component1();
  public final boolean component2();
  public final io.github.mariokovacevic.baresipkit.BaresipNetworkPath copy(java.lang.String, boolean);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipPixelFormat extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipPixelFormat> {
  public static final io.github.mariokovacevic.baresipkit.BaresipPixelFormat$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipPixelFormat NV12;
  public static final io.github.mariokovacevic.baresipkit.BaresipPixelFormat I420;
  public static final io.github.mariokovacevic.baresipkit.BaresipPixelFormat BGRA;
  public static io.github.mariokovacevic.baresipkit.BaresipPixelFormat[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipPixelFormat valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipPixelFormat> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipPixelFormat$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipPixelFormat of(int);
  public io.github.mariokovacevic.baresipkit.BaresipPixelFormat$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipRegistrationState extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipRegistrationState> {
  public static final io.github.mariokovacevic.baresipkit.BaresipRegistrationState$Companion Companion;
  public static final io.github.mariokovacevic.baresipkit.BaresipRegistrationState NONE;
  public static final io.github.mariokovacevic.baresipkit.BaresipRegistrationState REGISTERING;
  public static final io.github.mariokovacevic.baresipkit.BaresipRegistrationState REGISTERED;
  public static final io.github.mariokovacevic.baresipkit.BaresipRegistrationState UNREGISTERING;
  public static final io.github.mariokovacevic.baresipkit.BaresipRegistrationState FAILED;
  public static io.github.mariokovacevic.baresipkit.BaresipRegistrationState[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipRegistrationState valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipRegistrationState> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipRegistrationState$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipRegistrationState of(int);
  public io.github.mariokovacevic.baresipkit.BaresipRegistrationState$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipStreamStatistics {
  public final long getTransmittedPackets();
  public final long getReceivedPackets();
  public final long getTransmittedBytes();
  public final long getReceivedBytes();
  public final int getReceivedLost();
  public final int getReceivedFractionLostPermille();
  public final long getReceivedJitter-UwyO8pc();
  public final long getRoundTripTime-UwyO8pc();
  public final long getTransmitBitrate();
  public final long getReceiveBitrate();
  public final long getJitterBufferDelay-UwyO8pc();
  public final boolean isSecure();
  public final long component1();
  public final long component2();
  public final long component3();
  public final long component4();
  public final int component5();
  public final int component6();
  public final long component7-UwyO8pc();
  public final long component8-UwyO8pc();
  public final long component9();
  public final long component10();
  public final long component11-UwyO8pc();
  public final boolean component12();
  public final io.github.mariokovacevic.baresipkit.BaresipStreamStatistics copy-glMb-gM(long, long, long, long, int, int, long, long, long, long, long, boolean);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipStreamStatistics(long, long, long, long, int, int, long, long, long, long, long, boolean, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration {
  public static final io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$Companion Companion;
  public final byte[] getCaCertificatesPem();
  public final byte[] getClientCertificatePem();
  public final java.util.List<java.lang.String> getPinnedSpkiSha256();
  public final java.lang.String getCipherList();
  public final io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion getMinimumVersion();
  public final boolean getVerifyServer();
  public io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration(byte[], byte[], java.util.List<java.lang.String>, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion);
  public io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration(byte[], byte[], java.util.List, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public boolean equals(java.lang.Object);
  public int hashCode();
  public io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration(byte[], byte[], java.util.List, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion, boolean, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$Companion {
  public final io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration insecureSkippingServerVerification();
  public io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion> {
  public static final io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion TLS_1_2;
  public static final io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion TLS_1_3;
  public final int getWire$BaresipKit_baresipkit_release();
  public static io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipTlsConfiguration$TlsVersion> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipTransferEvent {
  public io.github.mariokovacevic.baresipkit.BaresipTransferEvent(boolean, java.lang.Integer, java.lang.String);
  public final boolean getFailed();
  public final java.lang.Integer getSipStatus();
  public final java.lang.String getTargetUri();
  public final boolean component1();
  public final java.lang.Integer component2();
  public final java.lang.String component3();
  public final io.github.mariokovacevic.baresipkit.BaresipTransferEvent copy(boolean, java.lang.Integer, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipTransport extends java.lang.Enum<io.github.mariokovacevic.baresipkit.BaresipTransport> {
  public static final io.github.mariokovacevic.baresipkit.BaresipTransport UDP;
  public static final io.github.mariokovacevic.baresipkit.BaresipTransport TCP;
  public static final io.github.mariokovacevic.baresipkit.BaresipTransport TLS;
  public static final io.github.mariokovacevic.baresipkit.BaresipTransport WSS;
  public static io.github.mariokovacevic.baresipkit.BaresipTransport[] values();
  public static io.github.mariokovacevic.baresipkit.BaresipTransport valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.BaresipTransport> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.BaresipTurnServer {
  public io.github.mariokovacevic.baresipkit.BaresipTurnServer(java.lang.String, java.lang.String, java.lang.String);
  public io.github.mariokovacevic.baresipkit.BaresipTurnServer(java.lang.String, java.lang.String, java.lang.String, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final java.lang.String getUri();
  public final java.lang.String getUsername();
  public final java.lang.String getPassword();
  public final java.lang.String component1();
  public final java.lang.String component2();
  public final java.lang.String component3();
  public final io.github.mariokovacevic.baresipkit.BaresipTurnServer copy(java.lang.String, java.lang.String, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration {
  public io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration(java.lang.String, java.lang.String, int, int, int, int, java.util.List<java.lang.String>);
  public io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration(java.lang.String, java.lang.String, int, int, int, int, java.util.List, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final java.lang.String getSourceModule();
  public final java.lang.String getSourceDevice();
  public final int getWidth();
  public final int getHeight();
  public final int getFramesPerSecond();
  public final int getBitrate();
  public final java.util.List<java.lang.String> getCodecs();
  public final java.lang.String component1();
  public final java.lang.String component2();
  public final int component3();
  public final int component4();
  public final int component5();
  public final int component6();
  public final java.util.List<java.lang.String> component7();
  public final io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration copy(java.lang.String, java.lang.String, int, int, int, int, java.util.List<java.lang.String>);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.BaresipVideoConfiguration();
}
public final class io.github.mariokovacevic.baresipkit.BaresipVideoFrame {
  public final io.github.mariokovacevic.baresipkit.BaresipPixelFormat getFormat();
  public final int getWidth();
  public final int getHeight();
  public final java.util.List<java.nio.ByteBuffer> getPlanes();
  public final java.util.List<java.lang.Integer> getStrides();
  public final long getTimestamp-UwyO8pc();
  public final int getRotationDegrees();
  public io.github.mariokovacevic.baresipkit.BaresipVideoFrame(io.github.mariokovacevic.baresipkit.BaresipPixelFormat, int, int, java.util.List, java.util.List, long, int, kotlin.jvm.internal.DefaultConstructorMarker);
}
public interface io.github.mariokovacevic.baresipkit.BaresipVideoRenderer {
  public abstract void render(io.github.mariokovacevic.baresipkit.BaresipVideoFrame);
  public abstract void didChangeSize(int, int);
}
public final class io.github.mariokovacevic.baresipkit.SipIdentity {
  public io.github.mariokovacevic.baresipkit.SipIdentity(java.lang.String);
  public final java.lang.String getUser();
  public final java.lang.String getHost();
  public final boolean isEmpty();
  public final java.lang.String getPhoneNumber();
  public boolean equals(java.lang.Object);
  public int hashCode();
  public java.lang.String toString();
}
final class io.github.mariokovacevic.baresipkit.SipIdentity$Companion {
  public final java.lang.String hostWithoutPort(java.lang.String);
  public io.github.mariokovacevic.baresipkit.SipIdentity$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
```

## baresipkit-audio

```
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioController {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Companion Companion;
  public io.github.mariokovacevic.baresipkit.audio.BaresipAudioController(android.content.Context, io.github.mariokovacevic.baresipkit.BaresipEngine, kotlin.jvm.functions.Function1<? super io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute, kotlin.Unit>);
  public io.github.mariokovacevic.baresipkit.audio.BaresipAudioController(android.content.Context, io.github.mariokovacevic.baresipkit.BaresipEngine, kotlin.jvm.functions.Function1, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final void configureForVoip(boolean);
  public final java.lang.Object activate(kotlin.coroutines.Continuation<? super java.lang.Boolean>);
  public final java.lang.Object deactivate(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object didActivateFromTelecom(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object didDeactivateFromTelecom(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final void release();
  public final void setSpeakerEnabled(boolean);
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute getCurrentRoute();
  public final java.util.List<io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput> getAvailableOutputs();
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput getCurrentOutput();
  public final void selectOutput(io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput);
  public static final void access$devicesChanged(io.github.mariokovacevic.baresipkit.audio.BaresipAudioController, android.media.AudioDeviceInfo[]);
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation extends java.lang.Enum<io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation> {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation INACTIVE;
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation CONTROLLER;
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation TELECOM;
  public static io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation[] values();
  public static io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Companion {
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse focusResponse(int, io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Activation);
  public final boolean restartsAudio(java.util.List<java.lang.Integer>);
  public io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse extends java.lang.Enum<io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse> {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse PAUSE_ENGINE;
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse RESUME_ENGINE;
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse STAY;
  public static io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse[] values();
  public static io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.audio.BaresipAudioController$FocusResponse> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput$Companion Companion;
  public io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput(java.lang.String, java.lang.String, io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute);
  public final java.lang.String getId();
  public final java.lang.String getName();
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute getRoute();
  public final java.lang.String component1();
  public final java.lang.String component2();
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute component3();
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput copy(java.lang.String, java.lang.String, io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput$Companion {
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput getEARPIECE();
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput getSPEAKER();
  public io.github.mariokovacevic.baresipkit.audio.BaresipAudioOutput$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public interface io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Companion Companion;
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Bluetooth implements io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Bluetooth INSTANCE;
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Companion {
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute of(int);
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Earpiece implements io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Earpiece INSTANCE;
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Other implements io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute {
  public io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Other(int);
  public final int getType();
  public final int component1();
  public final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Other copy(int);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Speaker implements io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$Speaker INSTANCE;
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$WiredHeadset implements io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute {
  public static final io.github.mariokovacevic.baresipkit.audio.BaresipAudioRoute$WiredHeadset INSTANCE;
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
```

## baresipkit-video

```
public final class io.github.mariokovacevic.baresipkit.video.BaresipCamera implements io.github.mariokovacevic.baresipkit.BaresipCameraHost {
  public static final io.github.mariokovacevic.baresipkit.video.BaresipCamera$Companion Companion;
  public boolean start(io.github.mariokovacevic.baresipkit.BaresipCameraSource, java.lang.String, int, int, int);
  public void stop(io.github.mariokovacevic.baresipkit.BaresipCameraSource);
  public boolean switchDevice(io.github.mariokovacevic.baresipkit.BaresipCameraSource, java.lang.String);
  public final java.util.List<java.lang.String> deviceNames();
  public static final int access$displayRotationDegrees(io.github.mariokovacevic.baresipkit.video.BaresipCamera);
  public io.github.mariokovacevic.baresipkit.video.BaresipCamera(android.content.Context, kotlin.jvm.internal.DefaultConstructorMarker);
}
final class io.github.mariokovacevic.baresipkit.video.BaresipCamera$Capture {
  public io.github.mariokovacevic.baresipkit.video.BaresipCamera$Capture(io.github.mariokovacevic.baresipkit.video.BaresipCamera, io.github.mariokovacevic.baresipkit.BaresipCameraSource, int, int, int);
  public final io.github.mariokovacevic.baresipkit.BaresipCameraSource getSource();
  public final int getWidth();
  public final int getHeight();
  public final int getFps();
  public final java.lang.String getCameraId();
  public final void setCameraId(java.lang.String);
  public final android.hardware.camera2.CameraDevice getDevice();
  public final void setDevice(android.hardware.camera2.CameraDevice);
  public final android.hardware.camera2.CameraCaptureSession getSession();
  public final void setSession(android.hardware.camera2.CameraCaptureSession);
  public final android.media.ImageReader getReader();
  public final void setReader(android.media.ImageReader);
  public final boolean getFront();
  public final void setFront(boolean);
  public final int getSensorOrientation();
  public final void setSensorOrientation(int);
  public final boolean getClosed();
  public final void setClosed(boolean);
  public final void open(java.lang.String);
  public final void close();
  public static final void access$startSession(io.github.mariokovacevic.baresipkit.video.BaresipCamera$Capture, android.hardware.camera2.CameraDevice, android.view.Surface, android.util.Range);
}
public final class io.github.mariokovacevic.baresipkit.video.BaresipCamera$Companion {
  public final io.github.mariokovacevic.baresipkit.video.BaresipCamera install(android.content.Context);
  public io.github.mariokovacevic.baresipkit.video.BaresipCamera$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.video.BaresipVideoFrameRelay implements io.github.mariokovacevic.baresipkit.BaresipVideoRenderer {
  public io.github.mariokovacevic.baresipkit.video.BaresipVideoFrameRelay(kotlin.jvm.functions.Function1<? super io.github.mariokovacevic.baresipkit.BaresipVideoFrame, kotlin.Unit>, kotlin.jvm.functions.Function2<? super java.lang.Integer, ? super java.lang.Integer, kotlin.Unit>);
  public io.github.mariokovacevic.baresipkit.video.BaresipVideoFrameRelay(kotlin.jvm.functions.Function1, kotlin.jvm.functions.Function2, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final void setHandlers(kotlin.jvm.functions.Function1<? super io.github.mariokovacevic.baresipkit.BaresipVideoFrame, kotlin.Unit>, kotlin.jvm.functions.Function2<? super java.lang.Integer, ? super java.lang.Integer, kotlin.Unit>);
  public void render(io.github.mariokovacevic.baresipkit.BaresipVideoFrame);
  public void didChangeSize(int, int);
  public io.github.mariokovacevic.baresipkit.video.BaresipVideoFrameRelay();
}
public final class io.github.mariokovacevic.baresipkit.video.BaresipVideoView extends android.opengl.GLSurfaceView {
  public static final java.lang.String VERTEX_SHADER;
  public static final java.lang.String FRAGMENT_SHADER;
  public io.github.mariokovacevic.baresipkit.video.BaresipVideoView(android.content.Context, android.util.AttributeSet);
  public io.github.mariokovacevic.baresipkit.video.BaresipVideoView(android.content.Context, android.util.AttributeSet, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode getScaleMode();
  public final void setScaleMode(io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode);
  public final boolean isMirrored();
  public final void setMirrored(boolean);
  public final io.github.mariokovacevic.baresipkit.BaresipVideoRenderer getRenderer();
  public final void flush();
  public final android.graphics.Bitmap snapshot();
  public io.github.mariokovacevic.baresipkit.video.BaresipVideoView(android.content.Context);
}
final class io.github.mariokovacevic.baresipkit.video.BaresipVideoView$Companion {
  public io.github.mariokovacevic.baresipkit.video.BaresipVideoView$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
final class io.github.mariokovacevic.baresipkit.video.BaresipVideoView$Drawer implements android.opengl.GLSurfaceView$Renderer {
  public io.github.mariokovacevic.baresipkit.video.BaresipVideoView$Drawer(io.github.mariokovacevic.baresipkit.video.BaresipVideoView);
  public void onSurfaceCreated(javax.microedition.khronos.opengles.GL10, javax.microedition.khronos.egl.EGLConfig);
  public void onSurfaceChanged(javax.microedition.khronos.opengles.GL10, int, int);
  public void onDrawFrame(javax.microedition.khronos.opengles.GL10);
}
public final class io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode extends java.lang.Enum<io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode> {
  public static final io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode FIT;
  public static final io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode FILL;
  public static io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode[] values();
  public static io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode> getEntries();
}
```

## baresipkit-telecom

```
public final class io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest {
  public static final io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest$Companion Companion;
  public io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest(java.lang.String, boolean, boolean);
  public io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest(java.lang.String, boolean, boolean, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final java.lang.String getDestination();
  public final boolean getVideo();
  public final boolean getCallsNow();
  public final java.lang.String component1();
  public final boolean component2();
  public final boolean component3();
  public final io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest copy(java.lang.String, boolean, boolean);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest$Companion {
  public final io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest from(android.content.Intent);
  public final io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest parse$BaresipKit_baresipkit_telecom_release(java.lang.String, java.lang.String, int);
  public io.github.mariokovacevic.baresipkit.telecom.BaresipRedialRequest$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter implements io.github.mariokovacevic.baresipkit.BaresipCallController {
  public static final io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter$Companion Companion;
  public static final int BUSY;
  public static final int DECLINE;
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter(android.content.Context, io.github.mariokovacevic.baresipkit.BaresipEngine, io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration, kotlin.jvm.functions.Function1<? super io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall, kotlin.Unit>);
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter(android.content.Context, io.github.mariokovacevic.baresipkit.BaresipEngine, io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration, kotlin.jvm.functions.Function1, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final io.github.mariokovacevic.baresipkit.BaresipEngine getEngine();
  public final io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration getConfiguration();
  public final void close();
  public final io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall telecomCall-_toeIIk(long);
  public boolean controls-_toeIIk(long);
  public void addMuteObserver(kotlin.jvm.functions.Function2<? super io.github.mariokovacevic.baresipkit.BaresipCallID, ? super java.lang.Boolean, kotlin.Unit>);
  public final java.lang.Object reportIncomingCallFromPush(java.util.UUID, java.lang.String, java.lang.String, boolean, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall>);
  public java.lang.Object placeCall-mNv01Hg(java.lang.String, boolean, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.BaresipCallID>);
  public java.lang.Object answer--zJ10-c(long, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public java.lang.Object end-I9_ACD0(long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public java.lang.Object setOnHold-7qpkdfE(boolean, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public java.lang.Object setMuted-7qpkdfE(boolean, long, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public static final java.lang.Object access$expirePushCall(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter, java.util.UUID, kotlin.coroutines.Continuation);
  public static final java.lang.Object access$systemAnswered(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter, io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall, boolean, kotlin.coroutines.Continuation);
  public static final java.lang.Object access$systemEnded(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter, io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall, kotlin.coroutines.Continuation);
  public static final void access$systemMuted(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter, io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall, boolean);
  public static final java.lang.Object access$linkTransferredCall-I9_ACD0(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter, long, kotlin.coroutines.Continuation);
  public static final java.lang.Object access$handOver-I9_ACD0(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter, long, kotlin.coroutines.Continuation);
  public static final java.lang.Object access$adoptReplacement(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter, io.github.mariokovacevic.baresipkit.BaresipCallInfo, kotlin.coroutines.Continuation);
  public static final java.lang.Object access$state-XRL4cpc(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter, long, io.github.mariokovacevic.baresipkit.BaresipCallState, io.github.mariokovacevic.baresipkit.BaresipError, kotlin.coroutines.Continuation);
}
public final class io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter$Companion {
  public final long getREPLACEMENT_TIMEOUT-UwyO8pc();
  public final int disconnectCode(io.github.mariokovacevic.baresipkit.BaresipError);
  public final android.telecom.DisconnectCause disconnectCause(io.github.mariokovacevic.baresipkit.BaresipError);
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomAdapter$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall {
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomCall(java.util.UUID, java.lang.String, java.lang.String, boolean, boolean);
  public final java.util.UUID getUuid();
  public final java.lang.String getRemoteUri();
  public final java.lang.String getDisplayName();
  public final boolean getHasVideo();
  public final boolean isOutgoing();
  public final kotlinx.coroutines.flow.MutableStateFlow<io.github.mariokovacevic.baresipkit.BaresipCallID> getEngineCall$BaresipKit_baresipkit_telecom_release();
  public final kotlinx.coroutines.flow.MutableStateFlow<androidx.core.telecom.CallEndpointCompat> getEndpoint$BaresipKit_baresipkit_telecom_release();
  public final kotlinx.coroutines.flow.MutableStateFlow<java.util.List<androidx.core.telecom.CallEndpointCompat>> getEndpoints$BaresipKit_baresipkit_telecom_release();
  public final kotlinx.coroutines.flow.MutableStateFlow<java.lang.Boolean> getMuted$BaresipKit_baresipkit_telecom_release();
  public final kotlinx.coroutines.CompletableDeferred<androidx.core.telecom.CallControlScope> getReady$BaresipKit_baresipkit_telecom_release();
  public final kotlinx.coroutines.flow.StateFlow<io.github.mariokovacevic.baresipkit.BaresipCallID> getCall();
  public final kotlinx.coroutines.flow.StateFlow<androidx.core.telecom.CallEndpointCompat> getCurrentEndpoint();
  public final kotlinx.coroutines.flow.StateFlow<java.util.List<androidx.core.telecom.CallEndpointCompat>> getAvailableEndpoints();
  public final kotlinx.coroutines.flow.StateFlow<java.lang.Boolean> isMuted();
  public final java.lang.Object requestEndpoint(androidx.core.telecom.CallEndpointCompat, kotlin.coroutines.Continuation<? super kotlin.Unit>);
}
public final class io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration {
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration(boolean, long, boolean, boolean, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipHandleStyle, long, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final boolean getSupportsVideo();
  public final long getPushInviteTimeout-UwyO8pc();
  public final boolean getSendsCameraOnAnswer();
  public final boolean getMatchesPushWithoutCaller();
  public final java.lang.String getCallUuidHeader();
  public final io.github.mariokovacevic.baresipkit.BaresipHandleStyle getHandleStyle();
  public final long getActionTimeout-UwyO8pc();
  public final boolean component1();
  public final long component2-UwyO8pc();
  public final boolean component3();
  public final boolean component4();
  public final java.lang.String component5();
  public final io.github.mariokovacevic.baresipkit.BaresipHandleStyle component6();
  public final long component7-UwyO8pc();
  public final io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration copy-w1iV6c0(boolean, long, boolean, boolean, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipHandleStyle, long);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration();
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomConfiguration(boolean, long, boolean, boolean, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipHandleStyle, long, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException extends java.lang.Exception {
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason, java.lang.String, java.lang.Integer);
  public io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException(io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason, java.lang.String, java.lang.Integer, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason getReason();
  public final java.lang.String getAction();
  public final java.lang.Integer getErrorCode();
}
public final class io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason extends java.lang.Enum<io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason> {
  public static final io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason ACTION_TIMED_OUT;
  public static final io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason REFUSED;
  public static io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason[] values();
  public static io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.telecom.BaresipTelecomException$Reason> getEntries();
}
```

## baresipkit-push

```
public final class io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter {
  public io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter(io.github.mariokovacevic.baresipkit.BaresipEngine, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipAccountID, java.util.List, kotlin.jvm.functions.Function2, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final io.github.mariokovacevic.baresipkit.push.BaresipPushTokens getCurrentTokens();
  public final void setErrorHandler(kotlin.jvm.functions.Function2<? super io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step, ? super java.lang.Throwable, kotlin.Unit>);
  public final void bind-HziJOBc(long);
  public final void updateToken(java.lang.String);
  public final void updateAppId(java.lang.String);
  public final void updateAdditionalContactParameters(java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter>);
  public final java.lang.Object handle(java.util.Map<java.lang.String, java.lang.String>, kotlin.coroutines.Continuation<? super java.lang.Boolean>);
  public io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter(io.github.mariokovacevic.baresipkit.BaresipEngine, java.lang.String, io.github.mariokovacevic.baresipkit.BaresipAccountID, java.util.List, kotlin.jvm.functions.Function2, kotlin.jvm.internal.DefaultConstructorMarker);
  public static final java.lang.Object access$sendPending(io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter, kotlin.coroutines.Continuation);
}
public final class io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step extends java.lang.Enum<io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step> {
  public static final io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step CONTACT_PARAMETERS;
  public static final io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step INCOMING_PUSH;
  public static final io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step ENGINE_WAKE_UP;
  public static io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step[] values();
  public static io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.push.BaresipPushAdapter$Step> getEntries();
}
public final class io.github.mariokovacevic.baresipkit.push.BaresipPushCall {
  public static final io.github.mariokovacevic.baresipkit.push.BaresipPushCall$Companion Companion;
  public io.github.mariokovacevic.baresipkit.push.BaresipPushCall(java.lang.String, java.lang.String, boolean, java.util.UUID);
  public final java.lang.String getRemoteUri();
  public final java.lang.String getDisplayName();
  public final boolean getHasVideo();
  public final java.util.UUID getUuid();
  public final java.lang.String component1();
  public final java.lang.String component2();
  public final boolean component3();
  public final java.util.UUID component4();
  public final io.github.mariokovacevic.baresipkit.push.BaresipPushCall copy(java.lang.String, java.lang.String, boolean, java.util.UUID);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.push.BaresipPushCall$Companion {
  public final io.github.mariokovacevic.baresipkit.push.BaresipPushCall from(java.util.Map<java.lang.String, java.lang.String>);
  public io.github.mariokovacevic.baresipkit.push.BaresipPushCall$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.push.BaresipPushTokens {
  public io.github.mariokovacevic.baresipkit.push.BaresipPushTokens(java.lang.String, java.lang.String, java.lang.String, boolean, int, java.lang.String);
  public io.github.mariokovacevic.baresipkit.push.BaresipPushTokens(java.lang.String, java.lang.String, java.lang.String, boolean, int, java.lang.String, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final java.lang.String getAppId();
  public final java.lang.String getToken();
  public final java.lang.String getPlatform();
  public final boolean getSilent();
  public final int getTimeout();
  public final java.lang.String getChannel();
  public final java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter> getContactParameters();
  public final java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter> mergedContactParameters$BaresipKit_baresipkit_push_release(java.util.List<io.github.mariokovacevic.baresipkit.BaresipContactParameter>);
  public final java.lang.String component1();
  public final java.lang.String component2();
  public final java.lang.String component3();
  public final boolean component4();
  public final int component5();
  public final java.lang.String component6();
  public final io.github.mariokovacevic.baresipkit.push.BaresipPushTokens copy(java.lang.String, java.lang.String, java.lang.String, boolean, int, java.lang.String);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
```

## baresipkit-compose

```
public final class io.github.mariokovacevic.baresipkit.compose.BaresipCallVideoKt {
  public static final void BaresipCallVideo-eDTftz8(io.github.mariokovacevic.baresipkit.BaresipEngine, long, androidx.compose.ui.Modifier, io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource, io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode, boolean, kotlin.jvm.functions.Function1<? super io.github.mariokovacevic.baresipkit.video.BaresipVideoView, kotlin.Unit>, androidx.compose.runtime.Composer, int, int);
  public static final void BaresipCameraPreview(io.github.mariokovacevic.baresipkit.BaresipEngine, androidx.compose.ui.Modifier, java.lang.String, boolean, androidx.compose.runtime.Composer, int, int);
  public static final void BaresipCallVideo(io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall, androidx.compose.ui.Modifier, io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource, io.github.mariokovacevic.baresipkit.video.BaresipVideoView$ScaleMode, kotlin.jvm.functions.Function1<? super io.github.mariokovacevic.baresipkit.video.BaresipVideoView, kotlin.Unit>, androidx.compose.runtime.Composer, int, int);
  public static final void BaresipSelfView-7VBEges(io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall, androidx.compose.ui.Modifier, long, float, boolean, androidx.compose.runtime.Composer, int, int);
}
public interface io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply {
}
public final class io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply$Confirmed implements io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply {
  public static final io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply$Confirmed INSTANCE;
  public static final int $stable;
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply$NoReply implements io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply {
  public static final io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply$NoReply INSTANCE;
  public static final int $stable;
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply$Other implements io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply {
  public static final int $stable;
  public io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply$Other(char);
  public final char getDigit();
  public final char component1();
  public final io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply$Other copy(char);
  public java.lang.String toString();
  public int hashCode();
  public boolean equals(java.lang.Object);
}
public final class io.github.mariokovacevic.baresipkit.compose.BaresipPhone {
  public static final int $stable;
  public io.github.mariokovacevic.baresipkit.compose.BaresipPhone(io.github.mariokovacevic.baresipkit.BaresipEngine, io.github.mariokovacevic.baresipkit.BaresipCallController, kotlinx.coroutines.CoroutineScope);
  public io.github.mariokovacevic.baresipkit.compose.BaresipPhone(io.github.mariokovacevic.baresipkit.BaresipEngine, io.github.mariokovacevic.baresipkit.BaresipCallController, kotlinx.coroutines.CoroutineScope, int, kotlin.jvm.internal.DefaultConstructorMarker);
  public final io.github.mariokovacevic.baresipkit.BaresipEngine getEngine();
  public final kotlinx.coroutines.CoroutineScope getScope$BaresipKit_baresipkit_compose_release();
  public final java.util.Map<io.github.mariokovacevic.baresipkit.BaresipAccountID, io.github.mariokovacevic.baresipkit.BaresipRegistrationState> getRegistrations();
  public final java.util.List<io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall> getCalls();
  public final io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall getActiveCall();
  public final io.github.mariokovacevic.baresipkit.BaresipCallController getCallController();
  public final void setCallController(io.github.mariokovacevic.baresipkit.BaresipCallController);
  public final boolean getResumesHeldCallWhenActiveCallEnds();
  public final void setResumesHeldCallWhenActiveCallEnds(boolean);
  public final io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall getIncomingCall();
  public final java.lang.Object run(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall call-_toeIIk(long);
  public final java.lang.Object makeCall--3T8-3M(java.lang.String, io.github.mariokovacevic.baresipkit.BaresipAccountID, boolean, boolean, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall>);
  public final java.lang.Object makeActive(io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall call(java.lang.String);
  public final java.lang.Object callWasAnswered$BaresipKit_baresipkit_compose_release(io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final void apply$BaresipKit_baresipkit_compose_release(io.github.mariokovacevic.baresipkit.BaresipEvent);
  public final java.lang.Object synchronize$BaresipKit_baresipkit_compose_release(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall applySnapshot-I9_ACD0$BaresipKit_baresipkit_compose_release(long, io.github.mariokovacevic.baresipkit.BaresipCallState);
}
public final class io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall {
  public static final io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall$Companion Companion;
  public static final int $stable;
  public final long getId--jmX5X0();
  public final io.github.mariokovacevic.baresipkit.BaresipEngine getEngine();
  public final kotlin.time.TimeMark getStartedAt();
  public final io.github.mariokovacevic.baresipkit.BaresipCallState getState();
  public final io.github.mariokovacevic.baresipkit.BaresipError getError();
  public final java.lang.String getRemoteUri();
  public final java.lang.String getRemoteDisplayName();
  public final boolean isOutgoing();
  public final boolean isDirectionKnown();
  public final boolean getHasVideo();
  public final boolean isMuted();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection getAudioDirection();
  public final io.github.mariokovacevic.baresipkit.BaresipMediaDirection getVideoDirection();
  public final java.lang.String getAudioCodec();
  public final java.lang.String getVideoCodec();
  public final kotlin.time.TimeMark getConnectedAt();
  public final boolean isSendingVideo();
  public final io.github.mariokovacevic.baresipkit.BaresipCameraPosition getCamera();
  public final boolean isPreviewing();
  public final java.lang.String getReceivedDtmf();
  public final io.github.mariokovacevic.baresipkit.compose.BaresipPhone getPhone$BaresipKit_baresipkit_compose_release();
  public final void setPhone$BaresipKit_baresipkit_compose_release(io.github.mariokovacevic.baresipkit.compose.BaresipPhone);
  public final boolean isRinging();
  public final boolean isOnHold();
  public final boolean isHeldByRemote();
  public final boolean isConnected();
  public final boolean isReceivingVideo();
  public final java.lang.String getDisplayName();
  public final boolean isPeer(java.lang.String);
  public final java.lang.Object answer(boolean, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object startPreview(boolean, boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object reject(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object hangUp(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setMuted(boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setOnHold(boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setVideoEnabled(boolean, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object setCamera(io.github.mariokovacevic.baresipkit.BaresipCameraPosition, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object switchCamera(kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object sendDtmf(java.lang.String, kotlin.coroutines.Continuation<? super kotlin.Unit>);
  public final java.lang.Object sendDtmf-exY8QGI(java.lang.String, char, long, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply>);
  public final java.lang.Object sendDtmf-1Y68eR8$BaresipKit_baresipkit_compose_release(java.lang.String, char, long, kotlin.jvm.functions.Function2<? super java.lang.String, ? super kotlin.coroutines.Continuation<? super kotlin.Unit>, ? extends java.lang.Object>, kotlin.coroutines.Continuation<? super io.github.mariokovacevic.baresipkit.compose.BaresipDtmfReply>);
  public final void refresh();
  public final void update$BaresipKit_baresipkit_compose_release(io.github.mariokovacevic.baresipkit.BaresipCallState, io.github.mariokovacevic.baresipkit.BaresipError);
  public final void update$BaresipKit_baresipkit_compose_release(io.github.mariokovacevic.baresipkit.BaresipCallInfo);
  public final void markOutgoing$BaresipKit_baresipkit_compose_release(java.lang.String, boolean);
  public final void applyMuted$BaresipKit_baresipkit_compose_release(boolean);
  public final void didReceiveDtmf$BaresipKit_baresipkit_compose_release(char);
  public io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall(long, io.github.mariokovacevic.baresipkit.BaresipCallState, io.github.mariokovacevic.baresipkit.BaresipEngine, kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall$Companion {
  public final java.lang.String userPart(java.lang.String);
  public final boolean samePeer(java.lang.String, java.lang.String);
  public io.github.mariokovacevic.baresipkit.compose.BaresipPhoneCall$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
}
public final class io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource extends java.lang.Enum<io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource> {
  public static final io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource REMOTE;
  public static final io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource LOCAL;
  public static io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource[] values();
  public static io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource valueOf(java.lang.String);
  public static kotlin.enums.EnumEntries<io.github.mariokovacevic.baresipkit.compose.BaresipVideoSource> getEntries();
}
```

