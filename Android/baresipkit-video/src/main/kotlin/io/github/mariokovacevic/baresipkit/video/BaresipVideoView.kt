package io.github.mariokovacevic.baresipkit.video

import android.content.Context
import android.graphics.Bitmap
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.util.AttributeSet
import io.github.mariokovacevic.baresipkit.BaresipPixelFormat
import io.github.mariokovacevic.baresipkit.BaresipVideoFrame
import io.github.mariokovacevic.baresipkit.BaresipVideoRenderer
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Shows a call's video or the camera preview. Pass [renderer] to
 * [io.github.mariokovacevic.baresipkit.BaresipEngine.setVideoRenderer] or
 * [io.github.mariokovacevic.baresipkit.BaresipEngine.startVideoPreview].
 *
 * Frames are copied off the media thread and drawn with OpenGL ES 2, converting YUV to RGB in a
 * shader.
 */
class BaresipVideoView
    @JvmOverloads
    constructor(
        context: Context,
        attributes: AttributeSet? = null,
    ) : GLSurfaceView(context, attributes) {
        /** How a frame fills the view. */
        enum class ScaleMode {
            /** The whole frame is visible, with bars where the aspect ratios differ. */
            FIT,

            /** The view is filled; the frame is cropped where the aspect ratios differ. */
            FILL,
        }

        /** How a frame fills the view. [ScaleMode.FILL] by default. */
        @Volatile var scaleMode: ScaleMode = ScaleMode.FILL

        /** Whether the picture is mirrored, as for the front camera's preview. */
        @Volatile var isMirrored: Boolean = false

        private val lock = Any()
        private var pending: StagedFrame? = null
        private var latest: StagedFrame? = null
        private val drawer = Drawer()

        init {
            setEGLContextClientVersion(2)
            setRenderer(drawer)
            renderMode = RENDERMODE_WHEN_DIRTY
        }

        /** The renderer that hands frames to this view. */
        val renderer: BaresipVideoRenderer =
            object : BaresipVideoRenderer {
                override fun render(frame: BaresipVideoFrame) {
                    synchronized(lock) {
                        pending = StagedFrame.of(frame, pending) ?: return
                    }
                    requestRender()
                }

                override fun didChangeSize(
                    width: Int,
                    height: Int,
                ) = Unit
            }

        /** Clears the picture, for example when a call ends. */
        fun flush() {
            synchronized(lock) {
                pending = null
                latest = null
            }
            requestRender()
        }

        /** The last frame shown, as a bitmap, or `null` before the first frame. */
        fun snapshot(): Bitmap? = synchronized(lock) { latest ?: pending }?.bitmap()

        private inner class Drawer : Renderer {
            private var program = 0
            private val textures = IntArray(3)
            private var viewWidth = 1
            private var viewHeight = 1
            private val vertices: FloatBuffer =
                ByteBuffer.allocateDirect(16 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()

            override fun onSurfaceCreated(
                gl: GL10?,
                config: EGLConfig?,
            ) {
                program = link(VERTEX_SHADER, FRAGMENT_SHADER)
                GLES20.glGenTextures(3, textures, 0)
                for (texture in textures) {
                    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
                    GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
                    GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
                    GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
                    GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
                }
            }

            override fun onSurfaceChanged(
                gl: GL10?,
                width: Int,
                height: Int,
            ) {
                viewWidth = width.coerceAtLeast(1)
                viewHeight = height.coerceAtLeast(1)
                GLES20.glViewport(0, 0, width, height)
            }

            override fun onDrawFrame(gl: GL10?) {
                val frame =
                    synchronized(lock) {
                        pending?.let {
                            latest = it
                            pending = null
                        }
                        latest
                    }
                GLES20.glClearColor(0f, 0f, 0f, 1f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                if (frame == null) return
                GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
                upload(0, frame.y, frame.width, frame.height, GLES20.GL_LUMINANCE)
                val nv12 = frame.format == BaresipPixelFormat.NV12
                if (nv12) {
                    upload(1, frame.u, frame.chromaWidth, frame.chromaHeight, GLES20.GL_LUMINANCE_ALPHA)
                } else {
                    upload(1, frame.u, frame.chromaWidth, frame.chromaHeight, GLES20.GL_LUMINANCE)
                    upload(2, frame.v ?: frame.u, frame.chromaWidth, frame.chromaHeight, GLES20.GL_LUMINANCE)
                }
                GLES20.glUseProgram(program)
                GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "y"), 0)
                GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "u"), 1)
                GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "v"), 2)
                GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "nv12"), if (nv12) 1 else 0)
                val quad =
                    VideoGeometry.quad(
                        frame.width,
                        frame.height,
                        frame.rotationDegrees,
                        viewWidth,
                        viewHeight,
                        scaleMode == ScaleMode.FILL,
                        isMirrored,
                    )
                vertices.clear()
                vertices.put(quad)
                vertices.position(0)
                val position = GLES20.glGetAttribLocation(program, "position")
                val coordinate = GLES20.glGetAttribLocation(program, "coordinate")
                GLES20.glEnableVertexAttribArray(position)
                GLES20.glEnableVertexAttribArray(coordinate)
                GLES20.glVertexAttribPointer(position, 2, GLES20.GL_FLOAT, false, 16, vertices)
                vertices.position(2)
                GLES20.glVertexAttribPointer(coordinate, 2, GLES20.GL_FLOAT, false, 16, vertices)
                GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            }

            private fun upload(
                unit: Int,
                data: ByteBuffer,
                width: Int,
                height: Int,
                format: Int,
            ) {
                GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + unit)
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[unit])
                data.position(0)
                GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, format, width, height, 0, format, GLES20.GL_UNSIGNED_BYTE, data)
            }

            private fun link(
                vertex: String,
                fragment: String,
            ): Int {
                val id = GLES20.glCreateProgram()
                GLES20.glAttachShader(id, compile(GLES20.GL_VERTEX_SHADER, vertex))
                GLES20.glAttachShader(id, compile(GLES20.GL_FRAGMENT_SHADER, fragment))
                GLES20.glLinkProgram(id)
                return id
            }

            private fun compile(
                type: Int,
                source: String,
            ): Int {
                val shader = GLES20.glCreateShader(type)
                GLES20.glShaderSource(shader, source)
                GLES20.glCompileShader(shader)
                return shader
            }
        }

        private companion object {
            const val VERTEX_SHADER =
                "attribute vec2 position;\nattribute vec2 coordinate;\nvarying vec2 uv;\n" +
                    "void main() { gl_Position = vec4(position, 0.0, 1.0); uv = coordinate; }\n"
            const val FRAGMENT_SHADER =
                "precision mediump float;\nvarying vec2 uv;\nuniform sampler2D y;\nuniform sampler2D u;\n" +
                    "uniform sampler2D v;\nuniform int nv12;\n" +
                    "void main() {\n" +
                    "  float l = 1.164 * (texture2D(y, uv).r - 0.0625);\n" +
                    "  float cb; float cr;\n" +
                    "  if (nv12 == 1) { vec4 c = texture2D(u, uv); cb = c.r - 0.5; cr = c.a - 0.5; }\n" +
                    "  else { cb = texture2D(u, uv).r - 0.5; cr = texture2D(v, uv).r - 0.5; }\n" +
                    "  gl_FragColor = vec4(l + 1.596 * cr, l - 0.813 * cr - 0.391 * cb, l + 2.018 * cb, 1.0);\n" +
                    "}\n"
        }
    }
