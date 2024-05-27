package com.example.usbserial

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.TextView
import android.widget.Button
import android.widget.EditText
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import java.io.IOException
import androidx.appcompat.app.AppCompatActivity
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import android.util.Log

class MainActivity : AppCompatActivity() {

    private val TAG = "12388"

    private lateinit var textView: TextView
    private lateinit var editTextMessage: EditText
    private lateinit var buttonSend: Button

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var readRunnable: Runnable

    private var port: UsbSerialPort? = null
    private var connection: UsbDeviceConnection? = null

    private val ACTION_USB_PERMISSION = "com.example.usbserial.USB_PERMISSION"
    private lateinit var usbManager: UsbManager

    private val PREFS_NAME = "MyPrefs"
    private val PREF_EDIT_TEXT_MESSAGE = "editTextMessage"

    private var canSendUdpMessage = true

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                        if (device != null) {
                            Log.d(TAG, "Broadcast received. Device: $device")
                            if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                                Log.d(TAG, "권한 부여됨: $device")
                                setupDevice(device)
                            } else {
                                runOnUiThread {
                                    textView.text = "Permission denied for device $device"
                                }
                                Log.d(TAG, "권한 거부됨: $device")
                            }
                        } else {
                            Log.d(TAG, "Received ACTION_USB_PERMISSION with null device")
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    device?.let {
                        Log.d(TAG, "Device attached: $it")
                        if (usbManager.hasPermission(it)) {
                            setupDevice(it)
                        } else {
                            val permissionIntent = PendingIntent.getBroadcast(context, 0, Intent(ACTION_USB_PERMISSION).apply {
                                putExtra(UsbManager.EXTRA_DEVICE, it)
                            }, PendingIntent.FLAG_MUTABLE)
                            usbManager.requestPermission(it, permissionIntent)
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)

                    device?.let {
                        Log.d(TAG, "Device detached: $it")
                        if (it == port?.device) {
                            port?.close()
                            port = null
                            connection?.close()
                            connection = null
                        }
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        textView = findViewById(R.id.textView)
        editTextMessage = findViewById(R.id.editTextMessage)
        buttonSend = findViewById(R.id.buttonSend)

        usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

        val savedMessage = getSavedMessage()
        editTextMessage.setText(savedMessage)

        /* buttonSend.setOnClickListener {
            val message = editTextMessage.text.toString()
            sendUdpMessage(message)
        }*/

        Log.d(TAG, "USB 장치 검색 시작")

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        filter.addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
        filter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        registerReceiver(usbReceiver, filter)

        discoverUsbDevices()
    }

    private fun discoverUsbDevices() {
        val deviceList = usbManager.deviceList
        if (deviceList.isEmpty()) {
            textView.text = "No USB devices found."
            return
        }

        for (device in deviceList.values) {
            Log.d(TAG, "Discovered device: $device")
            if (usbManager.hasPermission(device)) {
                Log.d(TAG, "이미 권한이 있는 장치: $device")
                setupDevice(device)
            } else {
                val permissionIntent = PendingIntent.getBroadcast(this, 0, Intent(ACTION_USB_PERMISSION).apply {
                    putExtra(UsbManager.EXTRA_DEVICE, device) }, PendingIntent.FLAG_MUTABLE)
                usbManager.requestPermission(device, permissionIntent)
                Log.d(TAG, "USB 권한 요청: $device")
            }
        }
    }


    private fun setupDevice(device: UsbDevice) {
        try {
            connection = usbManager.openDevice(device)
            if (connection == null) {
                runOnUiThread {
                    textView.text = "Failed to open device."
                }
                Log.d(TAG, "Failed to open device: $device")
                return
            }
            port = UsbSerialProber.getDefaultProber().probeDevice(device)?.ports?.get(0)
            port?.open(connection)
            port?.setParameters(115200, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
            Log.d(TAG, "장치 설정 완료: $device")

            readRunnable = object : Runnable {
                override fun run() {
                    readFromUsbSerial()
                    handler.postDelayed(this, 0)
                }
            }

            handler.post(readRunnable)
        } catch (e: Exception) {
            runOnUiThread {
                textView.text = "Error setting up device: ${e.message}"
            }
            Log.d(TAG, "Error setting up device: ${e.message}")
        }
    }

    private fun readFromUsbSerial() {
        port?.let { port ->
            try {
                val buffer = ByteArray(64)
                val numBytesRead = port.read(buffer, 1000)
                val readData = String(buffer, 0, numBytesRead)

                /*runOnUiThread {
                    textView.text = readData
                }*/
                Log.d(TAG, "데이터 읽기 성공: $readData")
                checkAndOpen(readData)
            } catch (e: IOException) {
                runOnUiThread {
                    textView.text = "Error reading from USB device: ${e.message}"
                }
                Log.d(TAG, "Error reading USB device: ${e.message}")
            }
        }
    }
    private fun checkAndOpen(string: String) {

            val flaotValue = string.trim().toFloatOrNull()
            if (flaotValue != null) {
                runOnUiThread {
                    textView.text = string
                }
                if(flaotValue < 0.1 && canSendUdpMessage) {
                    val message = editTextMessage.text.toString()
                    sendUdpMessage(message)
                    Log.d(TAG, "open ${string}")
                    canSendUdpMessage = false
                    handler.postDelayed({
                        Log.d(TAG, "5초 후에 실행됨")
                        canSendUdpMessage = true
                    }, 5000)
                }

        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(readRunnable)
        port?.close()
        connection?.close()
        unregisterReceiver(usbReceiver)
        saveMessage(editTextMessage.text.toString())
    }
    override fun onPause() {
        super.onPause()
        saveMessage(editTextMessage.text.toString())
    }
    override fun onStop() {
        super.onStop()
        saveMessage(editTextMessage.text.toString())
    }

    private fun sendUdpMessage(message: String) { //udp 메시지 전송
        Thread {
            try {
                DatagramSocket().use { socket ->
                    val serverAddr = InetAddress.getByName("222.113.3.212")
                    val serverPort = 8080
                    val buffer = message.toByteArray()
                    val packet = DatagramPacket(buffer, buffer.size, serverAddr, serverPort)
                    socket.send(packet)
                    Log.d(TAG, "UDP 메시지 전송 성공: $message")
                }
            } catch (e: Exception) {
                Log.e(TAG, "UDP 메시지 전송 실패: ${e.message}")
            }
        }.start()
    }
    private fun saveMessage(message: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        editor.putString(PREF_EDIT_TEXT_MESSAGE, message)
        editor.apply()
    }
    private fun getSavedMessage(): String {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(PREF_EDIT_TEXT_MESSAGE, "") ?: ""
    }
}