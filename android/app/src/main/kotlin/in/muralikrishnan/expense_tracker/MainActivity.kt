package `in`.muralikrishnan.expense_tracker

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.ContactsContract
import android.provider.Telephony
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val SMS_CHANNEL = "in.muralikrishnan.expense_tracker/sms"
        private const val CONTACTS_CHANNEL = "in.muralikrishnan.expense_tracker/contacts"
        private const val REQ_READ_SMS = 1001
        private const val REQ_PICK_CONTACT = 1002
    }

    private var pendingPermResult: MethodChannel.Result? = null
    private var pendingContactResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots and hide sensitive expense data in Android task switcher (VAPT)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                    "requestPermission" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        if (granted) {
                            result.success(true)
                        } else {
                            pendingPermResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.READ_SMS),
                                REQ_READ_SMS
                            )
                        }
                    }
                    "readInbox" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        if (!granted) {
                            result.error("PERMISSION_DENIED", "READ_SMS permission not granted", null)
                            return@setMethodCallHandler
                        }
                        val sinceMs = (call.argument<Number>("sinceMs")?.toLong())
                            ?: (System.currentTimeMillis() - 30L * 24 * 60 * 60 * 1000)
                        result.success(readDebitCandidates(sinceMs))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, CONTACTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickContact") {
                    pendingContactResult = result
                    val intent = Intent(
                        Intent.ACTION_PICK,
                        ContactsContract.CommonDataKinds.Phone.CONTENT_URI
                    )
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, REQ_PICK_CONTACT)
                } else {
                    result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_CONTACT) {
            val res = pendingContactResult
            pendingContactResult = null
            if (res == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                res.success(null)
                return
            }
            val uri = data.data!!
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val numIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val name = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "" else ""
                    val phone = if (numIdx >= 0) cursor.getString(numIdx) ?: "" else ""
                    res.success(mapOf("name" to name, "phone" to phone))
                    return
                }
            }
            res.success(null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_READ_SMS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermResult?.success(granted)
            pendingPermResult = null
        }
    }

    private fun readDebitCandidates(sinceMs: Long): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )
        val selection = "${Telephony.Sms.DATE} >= ?"
        val selectionArgs = arrayOf(sinceMs.toString())
        val sortOrder = "${Telephony.Sms.DATE} DESC LIMIT 150"

        contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder
        )?.use { cursor ->
            val idIdx = cursor.getColumnIndex(Telephony.Sms._ID)
            val addrIdx = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = cursor.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = cursor.getColumnIndex(Telephony.Sms.DATE)
            while (cursor.moveToNext()) {
                val id = if (idIdx >= 0) cursor.getString(idIdx) ?: "" else ""
                val address = if (addrIdx >= 0) cursor.getString(addrIdx) ?: "" else ""
                val body = if (bodyIdx >= 0) cursor.getString(bodyIdx) ?: "" else ""
                val dateMs = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L
                list.add(
                    mapOf(
                        "id" to id,
                        "address" to address,
                        "body" to body,
                        "dateMs" to dateMs
                    )
                )
            }
        }
        return list
    }
}
