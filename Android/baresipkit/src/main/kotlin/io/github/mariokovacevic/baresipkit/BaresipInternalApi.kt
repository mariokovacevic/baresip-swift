package io.github.mariokovacevic.baresipkit

/**
 * Marks API that BaresipKit's own modules use to work together, such as the camera source that
 * baresipkit-video feeds. It is public only because those modules are separate libraries.
 *
 * This API is not covered by Semantic Versioning: it can change or be removed in any release.
 * Using it requires `@OptIn(BaresipInternalApi::class)`.
 */
@RequiresOptIn(
    message = "BaresipKit plumbing for its own modules; it is not covered by Semantic Versioning.",
    level = RequiresOptIn.Level.ERROR,
)
@Retention(AnnotationRetention.BINARY)
@Target(
    AnnotationTarget.CLASS,
    AnnotationTarget.FUNCTION,
    AnnotationTarget.PROPERTY,
    AnnotationTarget.CONSTRUCTOR,
    AnnotationTarget.TYPEALIAS,
)
annotation class BaresipInternalApi
