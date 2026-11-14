package io.github.mariokovacevic.baresipkit

/**
 * Marks the builders of BaresipKit's configuration types, such as [BaresipConfiguration.Builder].
 *
 * Inside a nested builder block only the inner builder's settings can be set without naming the
 * outer builder, so a setting cannot land on the wrong configuration by accident.
 */
@DslMarker
@Target(AnnotationTarget.CLASS)
public annotation class BaresipConfigurationDsl
