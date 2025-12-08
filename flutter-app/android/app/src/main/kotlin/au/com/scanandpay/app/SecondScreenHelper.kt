package au.com.scanandpay.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Typeface
import android.util.Log
import com.topwise.cloudpos.aidl.smallscreen.AidlSmallScreen
import com.topwise.cloudpos.aidl.smallscreen.BitmapAlign
import com.topwise.cloudpos.aidl.smallscreen.SmallScreenDisplayMode
import com.topwise.cloudpos.service.DeviceServiceManager

object SecondScreenHelper {
    private const val TAG = "SecondScreen"
    private var smallScreen: AidlSmallScreen? = null
    private var initialized = false

    fun initialize(): Boolean {
        if (initialized) return true
        return try {
            smallScreen = DeviceServiceManager.getInstance().smallScreenManager
            initialized = smallScreen != null
            if (initialized) {
                Log.d(TAG, "Second screen ready")
            }
            initialized
        } catch (e: Exception) {
            Log.d(TAG, "Not a T6 device: ${e.message}")
            false
        }
    }

    fun showQrCode(context: Context, qrBitmap: Bitmap, title: String? = null, amount: String? = null) {
        if (!initialize()) return
        try {
            smallScreen?.let { screen ->
                screen.stopAppControl()

                val screenSize = screen.getSmallScreenSize() ?: return
                val screenWidth = screenSize[0]
                val screenHeight = screenSize[1]

                // Create composite bitmap
                val compositeBitmap = Bitmap.createBitmap(screenWidth, screenHeight, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(compositeBitmap)
                canvas.drawColor(Color.WHITE)

                // Layout math
                val topMargin = screenHeight * 0.02f
                val horizontalPadding = screenWidth * 0.05f
                val titleAreaHeight = screenHeight * 0.15f
                val amountAreaHeight = screenHeight * 0.12f
                val qrMargin = screenHeight * 0.03f

                var yPosition = topMargin

                // --- TITLE SECTION ---
                title?.let { text ->
                    val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = Color.BLACK
                        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                    }

                    // Font Sizing
                    val maxTitleSize = screenHeight * 0.10f
                    val minTitleSize = screenHeight * 0.04f
                    titlePaint.textSize = calculateTextSize(
                        text, titlePaint,
                        screenWidth - (horizontalPadding * 2),
                        titleAreaHeight,
                        minTitleSize, maxTitleSize
                    )

                    val titleBaseline = yPosition + titleAreaHeight / 2 + (titlePaint.textSize / 3)

                    // SPECIAL LOGIC: Display "Scan & " text + PayID logo PNG
                    if (text.equals("Scan & PayID", ignoreCase = true)) {
                        try {
                            val prefix = "Scan & "
                            val prefixWidth = titlePaint.measureText(prefix)

                            // Load PayID logo
                            val logoId = context.resources.getIdentifier("payid_logo", "drawable", context.packageName)

                            if (logoId != 0) {
                                val logoBitmap = BitmapFactory.decodeResource(context.resources, logoId)

                                // Scale logo to fit title area while maintaining aspect ratio
                                val targetLogoHeight = titleAreaHeight * 0.8f
                                val scale = targetLogoHeight / logoBitmap.height
                                val targetLogoWidth = logoBitmap.width * scale

                                // Calculate total width and center the group
                                val spacing = 10f
                                val totalGroupWidth = prefixWidth + spacing + targetLogoWidth
                                val startX = (screenWidth - totalGroupWidth) / 2f

                                // Draw "Scan & " text
                                titlePaint.textAlign = Paint.Align.LEFT
                                canvas.drawText(prefix, startX, titleBaseline, titlePaint)

                                // Draw PayID logo next to text
                                val matrix = Matrix()
                                matrix.postScale(scale, scale)
                                matrix.postTranslate(startX + prefixWidth + spacing, yPosition + (titleAreaHeight - targetLogoHeight) / 2)
                                canvas.drawBitmap(logoBitmap, matrix, null)
                            } else {
                                // Fallback to text if logo not found
                                titlePaint.textAlign = Paint.Align.CENTER
                                canvas.drawText(text, screenWidth / 2f, titleBaseline, titlePaint)
                            }
                        } catch (e: Exception) {
                            // Fallback to text on error
                            titlePaint.textAlign = Paint.Align.CENTER
                            canvas.drawText(text, screenWidth / 2f, titleBaseline, titlePaint)
                        }
                    } else {
                        titlePaint.textAlign = Paint.Align.CENTER
                        canvas.drawText(text, screenWidth / 2f, titleBaseline, titlePaint)
                    }
                    yPosition += titleAreaHeight
                }

                // --- AMOUNT SECTION ---
                amount?.let {
                    val amountPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = Color.BLACK
                        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                        textAlign = Paint.Align.CENTER
                    }
                    val maxAmountSize = screenHeight * 0.13f
                    val minAmountSize = screenHeight * 0.05f
                    amountPaint.textSize = calculateTextSize(it, amountPaint, screenWidth - (horizontalPadding * 2), amountAreaHeight, minAmountSize, maxAmountSize)
                    val amountBaseline = yPosition + amountAreaHeight / 2 + (amountPaint.textSize / 3)
                    canvas.drawText(it, screenWidth / 2f, amountBaseline, amountPaint)
                    yPosition += amountAreaHeight
                }

                // --- QR CODE SECTION ---
                val availableQrHeight = screenHeight - yPosition - (qrMargin * 2)
                val availableQrWidth = screenWidth - (qrMargin * 2)
                val maxQrSize = minOf(availableQrHeight, availableQrWidth).toInt()

                val scaledQrBitmap = if (qrBitmap.width > maxQrSize || qrBitmap.height > maxQrSize) {
                    Bitmap.createScaledBitmap(qrBitmap, maxQrSize, maxQrSize, true)
                } else {
                    qrBitmap
                }

                val qrLeft = (screenWidth - scaledQrBitmap.width) / 2f
                val qrTop = yPosition + qrMargin
                canvas.drawBitmap(scaledQrBitmap, qrLeft, qrTop, null)

                screen.displayText("", com.topwise.cloudpos.aidl.smallscreen.SmallScreenTextSize.TEXT_SIZE_NORMAL,
                    SmallScreenDisplayMode.TEXT_DISPLAY_MODE_UP_CENTER)
                screen.displayBitmap(compositeBitmap, BitmapAlign.BITMAP_ALIGN_CENTER)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed: ${e.message}")
        }
    }

    private fun calculateTextSize(text: String, paint: Paint, maxWidth: Float, maxHeight: Float, minSize: Float, maxSize: Float): Float {
        var size = maxSize
        paint.textSize = size
        while (size > minSize) {
            if (paint.measureText(text) <= maxWidth && (paint.descent() - paint.ascent()) <= maxHeight) break
            size -= 1f
            paint.textSize = size
        }
        return size
    }

    fun showFromByteArray(context: Context, qrBytes: ByteArray, title: String? = null, amount: String? = null) {
        val bitmap = BitmapFactory.decodeByteArray(qrBytes, 0, qrBytes.size)
        if (bitmap != null) {
            showQrCode(context, bitmap, title, amount)
        }
    }

    fun showMessage(message: String) {
        if (!initialize()) return
        try {
            smallScreen?.displayText(message, com.topwise.cloudpos.aidl.smallscreen.SmallScreenTextSize.TEXT_SIZE_NORMAL, SmallScreenDisplayMode.TEXT_DISPLAY_MODE_UP_CENTER)
        } catch (e: Exception) {
            Log.e(TAG, "Failed: ${e.message}")
        }
    }

    fun clear() { try { smallScreen?.stopAppControl() } catch (e: Exception) {} }
    fun close() { try { smallScreen?.stopAppControl(); smallScreen = null; initialized = false } catch (e: Exception) {} }
}