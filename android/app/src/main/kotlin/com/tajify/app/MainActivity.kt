package com.tajify.app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaMuxer
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {

    private val CHANNEL = "create_content/trimmer"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "trimVideo") {
                val inputPath = call.argument<String>("inputPath")
                val start = call.argument<Double>("start") ?: 0.0
                val end = call.argument<Double>("end") ?: 0.0

                if (inputPath.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "inputPath is required", null)
                    return@setMethodCallHandler
                }
                if (end <= start) {
                    result.error("INVALID_ARGS", "End time must be greater than start time", null)
                    return@setMethodCallHandler
                }

                try {
                    val outputPath = trimVideo(inputPath, start, end)
                    result.success(outputPath)
                } catch (e: Exception) {
                    result.error("TRIM_FAILED", e.localizedMessage ?: "Unable to trim video", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun trimVideo(inputPath: String, startSec: Double, endSec: Double): String {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)
        val trackCount = extractor.trackCount
        val startUs = (startSec * 1_000_000L).toLong()
        val endUs = (endSec * 1_000_000L).toLong()

        val outputFile = File(cacheDir, "trimmed_${System.currentTimeMillis()}.mp4")
        if (outputFile.exists()) {
            outputFile.delete()
        }
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        val trackIndexMap = mutableMapOf<Int, Int>()
        for (i in 0 until trackCount) {
            val format = extractor.getTrackFormat(i)
            trackIndexMap[i] = muxer.addTrack(format)
        }

        muxer.start()
        for (i in 0 until trackCount) {
            extractor.selectTrack(i)
        }
        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

        val bufferSize = 1 * 1024 * 1024
        val buffer = ByteBuffer.allocate(bufferSize)
        val bufferInfo = MediaCodec.BufferInfo()

        while (true) {
            val trackIndex = extractor.sampleTrackIndex
            if (trackIndex < 0) break

            bufferInfo.offset = 0
            bufferInfo.size = extractor.readSampleData(buffer, 0)
            if (bufferInfo.size < 0) break

            val sampleTime = extractor.sampleTime
            if (sampleTime < 0) break

            if (sampleTime < startUs) {
                extractor.advance()
                continue
            }
            if (sampleTime > endUs) break

            bufferInfo.presentationTimeUs = (sampleTime - startUs).coerceAtLeast(0L)
            bufferInfo.flags = extractor.sampleFlags

            val muxerTrackIndex = trackIndexMap[trackIndex] ?: continue
            muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
            extractor.advance()
        }

        extractor.release()
        muxer.stop()
        muxer.release()

        return outputFile.absolutePath
    }
}

