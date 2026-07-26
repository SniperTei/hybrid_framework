package com.sniper.androidwebbox.components.camera

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.core.content.PermissionChecker
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * QR / Barcode scanner Activity (Android).
 *
 * Backed by CameraX (AndroidX Jetpack) for the camera preview and ML Kit
 * barcode-scanning (bundled variant — no GMS dependency, works on HMS-only
 * / non-GMS ROMs) for decoding.
 *
 * Result contract (matches the previous ZXing extras for cross-platform
 * shape stability):
 *   - RESULT_OK with extras:
 *       SCAN_RESULT        -> decoded string (barcode.rawValue)
 *       SCAN_RESULT_FORMAT -> "QR_CODE" / "EAN_13" / ... (mapped from
 *                             ML Kit int format constants)
 *   - RESULT_CANCELED:    back button / cancel button / no camera permission
 *       (system default behavior for back press)
 *
 * Launching component must ensure CAMERA permission is granted before
 * starting this Activity; we re-check at onCreate and bail out if revoked.
 *
 * Optional input extra `qrOnly` (boolean) restricts detection to QR codes.
 */
class QrScannerActivity : AppCompatActivity() {

    private lateinit var previewView: PreviewView
    private lateinit var cameraExecutor: ExecutorService
    private var barcodeScanner: BarcodeScanner? = null
    private var hasFinished = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Permission guard. The launching component should have already
        // requested CAMERA; this is a fail-closed re-check in case the user
        // snuck into settings and revoked it.
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            finishWithCancel()
            return
        }

        val qrOnly = intent.getBooleanExtra(EXTRA_QR_ONLY, false)
        barcodeScanner = BarcodeScanning.getClient(
            if (qrOnly) {
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                    .build()
            } else {
                BarcodeScannerOptions.Builder().build()
            }
        )

        previewView = PreviewView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        setContentView(previewView)

        // Cancel button overlay (top-left, matching iOS scanner layout).
        val cancelButton = Button(this).apply {
            text = "取消"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.argb(128, 0, 0, 0))
            setOnClickListener { finishWithCancel() }
        }
        val cancelLp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.START
        ).apply {
            marginStart = 32
            topMargin = 48
        }
        addContentView(cancelButton, cancelLp)

        cameraExecutor = Executors.newSingleThreadExecutor()
        startCamera()
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                val selector = CameraSelector.DEFAULT_BACK_CAMERA
                val analyzer = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { ia ->
                        ia.setAnalyzer(cameraExecutor) { proxy -> analyzeFrame(proxy) }
                    }

                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(this, selector, preview, analyzer)
            } catch (t: Throwable) {
                finishWithCancel()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    private fun analyzeFrame(proxy: ImageProxy) {
        val mediaImage = proxy.image
        val scanner = barcodeScanner
        if (mediaImage == null || scanner == null) {
            proxy.close()
            return
        }
        val image = InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees)
        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                val first = barcodes.firstOrNull()
                if (first != null) finishWithSuccess(first)
            }
            .addOnCompleteListener { proxy.close() }
    }

    private fun finishWithSuccess(barcode: Barcode) {
        if (hasFinished) return
        hasFinished = true
        val data = Intent().apply {
            val raw = barcode.rawValue ?: barcode.displayValue ?: ""
            putExtra(EXTRA_SCAN_RESULT, raw)
            putExtra(EXTRA_SCAN_RESULT_FORMAT, formatToString(barcode.format))
        }
        setResult(Activity.RESULT_OK, data)
        finish()
    }

    private fun finishWithCancel() {
        if (hasFinished) return
        hasFinished = true
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        barcodeScanner?.close()
        if (::cameraExecutor.isInitialized) {
            cameraExecutor.shutdown()
        }
    }

    /**
     * Maps ML Kit int format constants to the cross-platform string names
     * used by the camera API contract (matches iOS AVMetadataObject.ObjectType
     * raw values and the previous ZXing formatName output).
     */
    private fun formatToString(format: Int): String = when (format) {
        Barcode.FORMAT_QR_CODE -> "QR_CODE"
        Barcode.FORMAT_EAN_13 -> "EAN_13"
        Barcode.FORMAT_EAN_8 -> "EAN_8"
        Barcode.FORMAT_UPC_A -> "UPC_A"
        Barcode.FORMAT_UPC_E -> "UPC_E"
        Barcode.FORMAT_CODE_128 -> "CODE_128"
        Barcode.FORMAT_CODE_39 -> "CODE_39"
        Barcode.FORMAT_CODE_93 -> "CODE_93"
        Barcode.FORMAT_CODABAR -> "CODABAR"
        Barcode.FORMAT_ITF -> "ITF"
        Barcode.FORMAT_PDF417 -> "PDF_417"
        Barcode.FORMAT_AZTEC -> "AZTEC"
        Barcode.FORMAT_DATA_MATRIX -> "DATA_MATRIX"
        else -> "UNKNOWN"
    }

    companion object {
        const val EXTRA_QR_ONLY = "qrOnly"
        const val EXTRA_SCAN_RESULT = "SCAN_RESULT"
        const val EXTRA_SCAN_RESULT_FORMAT = "SCAN_RESULT_FORMAT"
    }
}
