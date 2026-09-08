package com.example.biocollarsystem

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.Properties
import javax.mail.*
import javax.mail.internet.InternetAddress
import javax.mail.internet.MimeBodyPart
import javax.mail.internet.MimeMessage
import javax.mail.internet.MimeMultipart
import javax.mail.Part
import javax.mail.util.ByteArrayDataSource
import java.net.URL
import javax.activation.DataHandler

class MainActivity : FlutterActivity() {
    private val CHANNEL = "email_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendEmail") {
                    val email = call.argument<String>("email")
                    val subject = call.argument<String>("subject")
                    val bodyHtml = call.argument<String>("message")

                    if (email != null && subject != null && bodyHtml != null) {
                        Executors.newSingleThreadExecutor().execute {
                            sendStyledEmail(email, subject, bodyHtml)
                        }
                        result.success("Email Sent")
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing data", null)
                    }
                }
            }
    }

    private fun sendStyledEmail(email: String, subject: String, bodyHtml: String) {
        val username = "emaal7739@gmail.com"
        val password = "kylbjhalbyylnmbd"

        val props = Properties().apply {
            put("mail.smtp.auth", "true")
            put("mail.smtp.starttls.enable", "true")
            put("mail.smtp.host", "smtp.gmail.com")
            put("mail.smtp.port", "587")
        }

        val session = Session.getInstance(props, object : Authenticator() {
            override fun getPasswordAuthentication(): PasswordAuthentication {
                return PasswordAuthentication(username, password)
            }
        })

        try {
            val gold = "#FFC107"
            val brown = "#D7B899"
            val brownDark = "#8D6E63"
            val redSoft = "#F28B82"

            val htmlMessage = """
                <html>
                  <body style="margin:0;padding:24px;background:$brown;font-family:Arial,Helvetica,sans-serif;">
                    <div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,.08);">
                      <div style="background:$gold;padding:18px 24px;display:flex;align-items:center;gap:12px;">
                        <img src="cid:biocollar_logo" alt="BioCollar" style="width:48px;height:48px;border-radius:12px;display:block;"/>
                        <h2 style="margin:0;color:#222;font-size:22px;letter-spacing:.3px;">BioCollar Password Reset</h2>
                      </div>
                      <div style="padding:24px 24px 8px 24px;color:#333;">
                        <p style="margin:0 0 12px 0;">We received a request to reset your BioCollar password.</p>
                        <p style="margin:0 0 16px 0;">Use the code/instructions below to verify your identity:</p>
                        <div style="margin:18px 0;padding:16px;text-align:center;border:2px dashed $brownDark;border-radius:12px;background:#FAFAFA;color:#111;font-size:18px;">
                          $bodyHtml
                        </div>
                        <p style="margin:12px 0 0 0;color:#555;font-size:13px;">If you didn’t request this, you can safely ignore this email.</p>
                      </div>
                      <div style="padding:14px 24px;background:$redSoft;color:#fff;font-size:12px;text-align:center;">
                        © BioCollar — This is an automated message, please do not reply.
                      </div>
                    </div>
                  </body>
                </html>
            """.trimIndent()

            val related = MimeMultipart("related")

            val htmlPart = MimeBodyPart().apply {
                setContent(htmlMessage, "text/html; charset=utf-8")
            }
            related.addBodyPart(htmlPart)

            val logoBytes = URL("https://i.ibb.co/7tTHC5HV/logo.png").readBytes()
            val imagePart = MimeBodyPart().apply {
                dataHandler = DataHandler(ByteArrayDataSource(logoBytes, "image/png"))
                fileName = "logo.png"
                setHeader("Content-ID", "<biocollar_logo>")
                disposition = Part.INLINE
            }
            related.addBodyPart(imagePart)

            val msg = MimeMessage(session).apply {
                setFrom(InternetAddress(username, "BioCollar"))
                setRecipients(Message.RecipientType.TO, InternetAddress.parse(email))
                setSubject(subject)
                setContent(related)
            }

            Transport.send(msg)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
