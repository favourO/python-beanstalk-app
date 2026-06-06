package com.phora.gtl1_watch

import android.Manifest
import android.app.Activity
import android.app.Application
import android.bluetooth.BluetoothGatt
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import com.clj.fastble.BleManager
import com.clj.fastble.callback.BleGattCallback
import com.clj.fastble.callback.BleNotifyCallback
import com.clj.fastble.callback.BleScanCallback
import com.clj.fastble.data.BleDevice
import com.clj.fastble.exception.BleException
import com.clj.fastble.scan.BleScanRuleConfig
import com.google.protobuf.NullValue
import com.realsil.sdk.core.RtkConfigure
import com.realsil.sdk.core.RtkCore
import com.realsil.sdk.dfu.RtkDfu
import com.starmax.bluetoothsdk.Notify
import com.starmax.bluetoothsdk.StarmaxBleClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.reactivex.disposables.Disposable
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Calendar
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PhoraGtl1WatchPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var applicationContext: Context
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var eventSink: EventChannel.EventSink? = null
    private var currentDevice: BleDevice? = null
    private var currentGatt: BluetoothGatt? = null
    private val scannedDevices = linkedMapOf<String, BleDevice>()
    private var realtimeDisposable: Disposable? = null
    private var pendingPermissionAction: (() -> Unit)? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "phora/gtl1_watch")
        eventChannel = EventChannel(binding.binaryMessenger, "phora/gtl1_watch/events")
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        initializeSdk()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        realtimeDisposable?.dispose()
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanDevices" -> withPermissions(result) { scanDevices(result) }
            "connect" -> withPermissions(result) {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId.isNullOrBlank()) {
                    result.error("invalid_args", "deviceId is required", null)
                    return@withPermissions
                }
                connect(deviceId, result)
            }
            "disconnect" -> disconnect(result)
            "syncDeviceTime" -> withPermissions(result) {
                executor.execute {
                    runCatching {
                        StarmaxBleClient.instance.setTime().blockingGet()
                    }.onSuccess { postResult(result, null) }
                        .onFailure { postError(result, "time_sync_failed", it.message) }
                }
            }
            "getBattery" -> withPermissions(result) {
                executor.execute {
                    runCatching {
                        val response = StarmaxBleClient.instance.getPower().blockingGet()
                        mapOf(
                            "level" to response.power,
                            "isCharging" to response.isCharge,
                        )
                    }.onSuccess { postResult(result, it) }
                        .onFailure { postError(result, "battery_failed", it.message) }
                }
            }
            "getCurrentHealth" -> withPermissions(result) {
                executor.execute {
                    runCatching {
                        currentHealthInternal()
                    }.onSuccess { postResult(result, it) }
                        .onFailure { postError(result, "current_health_failed", it.message) }
                }
            }
            "syncToday" -> withPermissions(result) {
                executor.execute {
                    runCatching {
                        syncDateInternal(LocalDate.now())
                    }.onSuccess { postResult(result, it) }
                        .onFailure { postError(result, "sync_failed", it.message) }
                }
            }
            "syncDate" -> withPermissions(result) {
                val rawDate = call.argument<String>("date")
                val date = parseDate(rawDate)
                if (date == null) {
                    result.error("invalid_args", "date is required in YYYY-MM-DD", null)
                    return@withPermissions
                }
                executor.execute {
                    runCatching {
                        syncDateInternal(date)
                    }.onSuccess { postResult(result, it) }
                        .onFailure { postError(result, "sync_failed", it.message) }
                }
            }
            "syncRange" -> withPermissions(result) {
                val start = parseDate(call.argument<String>("start"))
                val end = parseDate(call.argument<String>("end"))
                if (start == null || end == null) {
                    result.error("invalid_args", "start and end are required", null)
                    return@withPermissions
                }
                executor.execute {
                    runCatching {
                        val items = mutableListOf<Map<String, Any?>>()
                        var cursor: LocalDate = start
                        while (!cursor.isAfter(end)) {
                            items += syncDateInternal(cursor)
                            cursor = cursor.plusDays(1)
                        }
                        items
                    }.onSuccess { postResult(result, it) }
                        .onFailure { postError(result, "sync_failed", it.message) }
                }
            }
            "getFemaleHealth" -> withPermissions(result) {
                executor.execute {
                    runCatching { getFemaleHealthInternal() }
                        .onSuccess { postResult(result, it) }
                        .onFailure { postError(result, "female_health_failed", it.message) }
                }
            }
            "setFemaleHealth" -> withPermissions(result) {
                val periodDays = call.argument<Int>("periodDays")
                val cycleDays = call.argument<Int>("cycleDays")
                val lastPeriodDate = parseDate(call.argument<String>("lastPeriodDate"))
                if (periodDays == null || cycleDays == null || lastPeriodDate == null) {
                    result.error(
                        "invalid_args",
                        "periodDays, cycleDays and lastPeriodDate are required",
                        null,
                    )
                    return@withPermissions
                }
                executor.execute {
                    runCatching {
                        setFemaleHealthInternal(periodDays, cycleDays, lastPeriodDate)
                    }.onSuccess { postResult(result, null) }
                        .onFailure { postError(result, "female_health_failed", it.message) }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        subscribeRealtime()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        realtimeDisposable?.dispose()
        realtimeDisposable = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        onDetachedFromActivityForConfigChanges()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE_PERMISSIONS) {
            return false
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        val action = pendingPermissionAction
        pendingPermissionAction = null
        if (granted) {
            action?.invoke()
        }
        return true
    }

    private fun initializeSdk() {
        runCatching { System.loadLibrary("slm_m1_crack") }
        val app = applicationContext.applicationContext as? Application
            ?: throw IllegalStateException("Application context is required")
        BleManager.getInstance().init(app)
        BleManager.getInstance()
            .enableLog(false)
            .setReConnectCount(0, 1000)
            .setConnectOverTime(10000)
            .setOperateTimeout(5000)

        val configure = RtkConfigure.Builder()
            .debugEnabled(false)
            .printLog(false)
            .logTag("PhoraGTL1")
            .build()
        runCatching {
            RtkCore.initialize(applicationContext, configure)
            RtkDfu.initialize(applicationContext, true)
        }

        StarmaxBleClient.instance.setWrite { bytes ->
            sendMsg(bytes)
        }
    }

    private fun withPermissions(result: MethodChannel.Result, action: () -> Unit) {
        val missing = requiredPermissions().filter {
            ActivityCompat.checkSelfPermission(applicationContext, it) !=
                PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            action()
            return
        }
        val hostActivity = activity
        if (hostActivity == null) {
            result.error("permissions", "Bluetooth permissions are missing and no activity is attached", null)
            return
        }
        pendingPermissionAction = action
        ActivityCompat.requestPermissions(
            hostActivity,
            missing.toTypedArray(),
            REQUEST_CODE_PERMISSIONS,
        )
    }

    private fun requiredPermissions(): List<String> {
        return buildList {
            add(Manifest.permission.ACCESS_FINE_LOCATION)
            add(Manifest.permission.ACCESS_COARSE_LOCATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(Manifest.permission.BLUETOOTH_SCAN)
                add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }
    }

    private fun scanDevices(result: MethodChannel.Result) {
        scannedDevices.clear()
        BleManager.getInstance().initScanRule(
            BleScanRuleConfig.Builder()
                .setScanTimeOut(10_000)
                .build(),
        )
        BleManager.getInstance().scan(object : BleScanCallback() {
            override fun onScanStarted(success: Boolean) {
                if (!success) {
                    postError(result, "scan_failed", "Scan could not start")
                }
            }

            override fun onScanning(bleDevice: BleDevice?) {
                if (bleDevice?.mac != null &&
                    bleDevice.rssi >= -100 &&
                    bleDevice.name != null &&
                    bleDevice.isGtl1Device() &&
                    !scannedDevices.containsKey(bleDevice.mac)
                ) {
                    scannedDevices[bleDevice.mac] = bleDevice
                    emitEvent(
                        mapOf(
                            "type" to "scan_result",
                            "device" to bleDevice.toMap(),
                        ),
                    )
                }
            }

            override fun onScanFinished(scanResultList: MutableList<BleDevice>?) {
                val devices = scannedDevices.values.map { it.toMap() }
                postResult(result, devices)
            }
        })
    }

    private fun connect(deviceId: String, result: MethodChannel.Result) {
        val device = scannedDevices[deviceId]
        if (device == null) {
            result.error("not_found", "Device $deviceId was not found in the latest scan", null)
            return
        }
        if (!device.isGtl1Device()) {
            result.error("unsupported_device", "Only GTL1 devices can be connected", null)
            return
        }
        BleManager.getInstance().connect(device, object : BleGattCallback() {
            override fun onStartConnect() = Unit

            override fun onConnectFail(bleDevice: BleDevice?, exception: BleException?) {
                postError(result, "connect_failed", exception?.description ?: "Bluetooth connect failed")
                emitEvent(mapOf("type" to "connection", "state" to "failed"))
            }

            override fun onConnectSuccess(
                bleDevice: BleDevice?,
                gatt: BluetoothGatt?,
                status: Int,
            ) {
                currentDevice = bleDevice
                currentGatt = gatt
                openNotify(bleDevice, result)
            }

            override fun onDisConnected(
                isActiveDisConnected: Boolean,
                device: BleDevice?,
                gatt: BluetoothGatt?,
                status: Int,
            ) {
                currentDevice = null
                currentGatt = null
                emitEvent(mapOf("type" to "connection", "state" to "disconnected"))
            }
        })
    }

    private fun openNotify(bleDevice: BleDevice?, result: MethodChannel.Result) {
        if (bleDevice == null) {
            result.error("connect_failed", "Connected device is null", null)
            return
        }
        BleManager.getInstance().notify(
            bleDevice,
            SERVICE_UUID,
            NOTIFY_UUID,
            object : BleNotifyCallback() {
                override fun onNotifySuccess() {
                    subscribeRealtime()
                    postResult(result, mapOf("status" to "connected"))
                    emitEvent(
                        mapOf(
                            "type" to "connection",
                            "state" to "connected",
                            "deviceId" to (bleDevice.mac ?: ""),
                            "name" to (bleDevice.name ?: ""),
                        ),
                    )
                }

                override fun onNotifyFailure(exception: BleException) {
                    postError(result, "notify_failed", exception.description)
                }

                override fun onCharacteristicChanged(data: ByteArray) {
                    StarmaxBleClient.instance.notify(data)
                }
            },
        )
    }

    private fun disconnect(result: MethodChannel.Result) {
        currentDevice?.let { BleManager.getInstance().disconnect(it) }
        currentDevice = null
        currentGatt = null
        realtimeDisposable?.dispose()
        realtimeDisposable = null
        result.success(null)
    }

    private fun subscribeRealtime() {
        realtimeDisposable?.dispose()
        if (eventSink == null) {
            return
        }
        realtimeDisposable =
            StarmaxBleClient.instance.realTimeDataStream().subscribe({ data ->
                emitEvent(
                    mapOf(
                        "type" to "realtime",
                        "steps" to data.steps,
                        "heartRate" to data.heartRate,
                        "bloodOxygen" to data.bloodOxygen,
                        "temperature" to normalizeTemperature(data.temp),
                        "stress" to averageOf(listOf(data.bloodPressureSs, data.bloodPressureFz)),
                        "raw" to mapOf(
                            "calorie" to data.calore,
                            "distance" to data.distance,
                            "bloodPressureSs" to data.bloodPressureSs,
                            "bloodPressureFz" to data.bloodPressureFz,
                            "bloodSugar" to data.bloodSugar,
                            "gSensors" to data.gensorsList.map { mapOf("x" to it.x, "y" to it.y, "z" to it.z) },
                        ),
                    ),
                )
            }, { error ->
                emitEvent(mapOf("type" to "error", "message" to (error.message ?: "Realtime stream failed")))
            })
    }

    private fun syncDateInternal(date: LocalDate): Map<String, Any?> {
        requireConnected()
        val calendar = Calendar.getInstance().apply {
            set(Calendar.YEAR, date.year)
            set(Calendar.MONTH, date.monthValue - 1)
            set(Calendar.DAY_OF_MONTH, date.dayOfMonth)
        }

        val stepHistory = StarmaxBleClient.instance.getStepHistory(calendar).blockingGet()
        val heartHistory = StarmaxBleClient.instance.getHeartRateHistory(calendar).blockingGet()
        val oxygenHistory = StarmaxBleClient.instance.getBloodOxygenHistory(calendar).blockingGet()
        val sleepHistory = StarmaxBleClient.instance.getSleepHistory(calendar).blockingGet()
        val tempHistory = StarmaxBleClient.instance.getTempHistory(calendar).blockingGet()
        val pressureHistory = StarmaxBleClient.instance.getPressureHistory(calendar).blockingGet()

        val stepSamples = stepHistory.stepsList.map {
            mapOf(
                "hour" to it.hour,
                "minute" to it.minute,
                "steps" to it.steps,
                "calorie" to it.calorie,
                "distance" to it.distance,
            )
        }
        val heartValues = heartHistory.dataList.map { it.value }
        val oxygenValues = oxygenHistory.dataList.map { it.value }
        val tempValues = tempHistory.dataList.map { normalizeTemperature(it.value) }
        val stressValues = pressureHistory.dataList.map { it.value }
        val sleepInterval = sleepHistory.interval.takeIf { it > 0 } ?: stepHistory.interval.takeIf { it > 0 } ?: 10
        val sleepSummary = summarizeSleep(sleepHistory.dataList.map { it.status }, sleepInterval)

        return mapOf(
            "date" to date.format(DateTimeFormatter.ISO_LOCAL_DATE),
            "steps" to stepSamples.sumOf { (it["steps"] as Int) },
            "caloriesKcal" to stepSamples.sumOf { normalizeCalories((it["calorie"] as Number).toDouble()) },
            "distanceMeters" to stepSamples.sumOf { (it["distance"] as Number).toDouble() },
            "heartRate" to mapOf(
                "resting" to (heartValues.minOrNull() ?: 0),
                "avg" to averageOf(heartValues),
                "min" to (heartValues.minOrNull() ?: 0),
                "max" to (heartValues.maxOrNull() ?: 0),
            ),
            "sleep" to sleepSummary,
            "bloodOxygen" to mapOf(
                "avg" to averageOf(oxygenValues),
                "min" to (oxygenValues.minOrNull() ?: 0),
            ),
            "temperature" to mapOf(
                "avg" to averageOfDouble(tempValues),
            ),
            "stress" to mapOf(
                "avg" to averageOf(stressValues),
            ),
            "sourceDevice" to (currentDevice?.name ?: currentDevice?.mac ?: "gtl1_watch"),
            "syncTimestamp" to java.time.Instant.now().toString(),
            "raw" to mapOf(
                "stepSamples" to stepSamples,
                "heartRateSamples" to heartHistory.dataList.map {
                    mapOf("hour" to it.hour, "minute" to it.minute, "value" to it.value)
                },
                "sleepSamples" to sleepHistory.dataList.map {
                    mapOf("hour" to it.hour, "minute" to it.minute, "status" to it.status)
                },
                "bloodOxygenSamples" to oxygenHistory.dataList.map {
                    mapOf("hour" to it.hour, "minute" to it.minute, "value" to it.value)
                },
                "temperatureSamples" to tempHistory.dataList.map {
                    mapOf("hour" to it.hour, "minute" to it.minute, "value" to normalizeTemperature(it.value))
                },
                "stressSamples" to pressureHistory.dataList.map {
                    mapOf("hour" to it.hour, "minute" to it.minute, "value" to it.value)
                },
            ),
        )
    }

    private fun currentHealthInternal(): Map<String, Any?> {
        requireConnected()
        val data = StarmaxBleClient.instance.getHealthDetail().blockingGet()
        val currentHeartRate = data.currentHeartRate
        val currentBloodOxygen = data.currentBloodOxygen
        return mapOf(
            "date" to LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE),
            "steps" to data.totalSteps,
            "caloriesKcal" to normalizeCalories(data.totalHeat.toDouble()),
            "distanceMeters" to data.totalDistance,
            "heartRate" to mapOf(
                "resting" to currentHeartRate,
                "avg" to currentHeartRate,
                "min" to currentHeartRate,
                "max" to currentHeartRate,
            ),
            "sleep" to mapOf(
                "totalMinutes" to data.totalSleep,
                "deepMinutes" to data.totalDeepSleep,
                "lightMinutes" to data.totalLightSleep,
                "awakeMinutes" to 0,
            ),
            "bloodOxygen" to mapOf(
                "avg" to currentBloodOxygen,
                "min" to currentBloodOxygen,
            ),
            "temperature" to mapOf(
                "avg" to normalizeTemperature(data.currentTemp),
            ),
            "stress" to mapOf(
                "avg" to data.currentPressure,
            ),
            "sourceDevice" to (currentDevice?.name ?: currentDevice?.mac ?: "gtl1_watch"),
            "syncTimestamp" to java.time.Instant.now().toString(),
            "raw" to mapOf(
                "currentHealth" to mapOf(
                    "totalHeat" to data.totalHeat,
                    "totalDistance" to data.totalDistance,
                    "currentSs" to data.currentSs,
                    "currentFz" to data.currentFz,
                    "currentMai" to data.currentMai,
                    "currentMet" to data.currentMet,
                    "currentBloodSugar" to data.currentBloodSugar,
                    "isWear" to data.isWear,
                ),
            ),
        )
    }

    private fun getFemaleHealthInternal(): Map<String, Any?> {
        requireConnected()
        val response = StarmaxBleClient.instance.getFemaleHealth().blockingGet()
        return mapOf(
            "periodDays" to response.numberOfDays,
            "cycleDays" to response.cycleDays,
            "lastPeriodDate" to formatDate(response.year, response.month, response.day),
        )
    }

    private fun setFemaleHealthInternal(periodDays: Int, cycleDays: Int, lastPeriodDate: LocalDate) {
        requireConnected()
        val calendar = Calendar.getInstance().apply {
            set(Calendar.YEAR, lastPeriodDate.year)
            set(Calendar.MONTH, lastPeriodDate.monthValue - 1)
            set(Calendar.DAY_OF_MONTH, lastPeriodDate.dayOfMonth)
        }
        StarmaxBleClient.instance
            .setFemaleHealth(periodDays, cycleDays, calendar)
            .blockingGet()
    }

    private fun requireConnected() {
        check(currentDevice != null) { "Watch is not connected" }
    }

    private fun sendMsg(bytes: ByteArray) {
        val device = currentDevice ?: return
        BleManager.getInstance().write(
            device,
            SERVICE_UUID,
            WRITE_UUID,
            bytes,
            object : com.clj.fastble.callback.BleWriteCallback() {
                override fun onWriteSuccess(
                    current: Int,
                    total: Int,
                    justWrite: ByteArray?,
                ) = Unit

                override fun onWriteFailure(exception: BleException?) = Unit
            },
        )
    }

    private fun summarizeSleep(statuses: List<Int>, interval: Int): Map<String, Int> {
        var deepMinutes = 0
        var lightMinutes = 0
        var awakeMinutes = 0
        for (status in statuses) {
            when (status) {
                2, 130 -> lightMinutes += interval
                3, 131, 5, 133 -> deepMinutes += interval
                4, 132 -> awakeMinutes += interval
            }
        }
        return mapOf(
            "totalMinutes" to (deepMinutes + lightMinutes + awakeMinutes),
            "deepMinutes" to deepMinutes,
            "lightMinutes" to lightMinutes,
            "awakeMinutes" to awakeMinutes,
        )
    }

    private fun averageOf(values: List<Int>): Int {
        if (values.isEmpty()) return 0
        return values.sum() / values.size
    }

    private fun averageOfDouble(values: List<Double>): Double {
        if (values.isEmpty()) return 0.0
        return ((values.sum() / values.size) * 10).toInt() / 10.0
    }

    private fun normalizeTemperature(value: Int): Double {
        return if (value >= 100) value / 10.0 else value.toDouble()
    }

    private fun normalizeCalories(value: Double): Double {
        return if (value > 1000) value / 100.0 else value
    }

    private fun parseDate(raw: String?): LocalDate? {
        if (raw.isNullOrBlank()) return null
        return runCatching { LocalDate.parse(raw, DateTimeFormatter.ISO_LOCAL_DATE) }.getOrNull()
    }

    private fun formatDate(year: Int, month: Int, day: Int): String {
        return LocalDate.of(year, month.coerceAtLeast(1), day.coerceAtLeast(1))
            .format(DateTimeFormatter.ISO_LOCAL_DATE)
    }

    private fun emitEvent(event: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(event) }
    }

    private fun postResult(result: MethodChannel.Result, payload: Any?) {
        mainHandler.post { result.success(payload) }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String?) {
        mainHandler.post { result.error(code, message, null) }
    }

    private fun BleDevice.toMap(): Map<String, Any?> {
        val manufacturer = starmaxManufacturerInfo(scanRecord)
        return mapOf(
            "id" to (mac ?: ""),
            "name" to (name ?: "GTL1 Watch"),
            "rssi" to rssi,
            "metadata" to mapOf(
                "deviceName" to device?.name,
                "connected" to (this == currentDevice),
                "manufacturerPrefix" to manufacturer.prefix,
                "manufacturerMac" to manufacturer.mac,
                "isStarmax" to manufacturer.isStarmax,
                "broadcast" to manufacturer.broadcast,
            ),
        )
    }

    private fun BleDevice.isGtl1Device(): Boolean {
        val advertisedName = name.orEmpty()
        val platformName = device?.name.orEmpty()
        return advertisedName.contains("GTL1", ignoreCase = true) ||
            platformName.contains("GTL1", ignoreCase = true)
    }

    private data class StarmaxManufacturerInfo(
        val prefix: String?,
        val mac: String?,
        val isStarmax: Boolean,
        val broadcast: String?,
    )

    private fun starmaxManufacturerInfo(scanRecord: ByteArray?): StarmaxManufacturerInfo {
        if (scanRecord == null) {
            return StarmaxManufacturerInfo(null, null, false, null)
        }
        var index = 0
        while (index < scanRecord.size - 1) {
            val len = scanRecord[index].toInt() and 0xFF
            if (len == 0 || index + len >= scanRecord.size) {
                break
            }
            val type = scanRecord[index + 1].toInt() and 0xFF
            val start = index + 2
            val endExclusive = index + 1 + len
            val raw = scanRecord.copyOfRange(start, endExclusive)
            if (type == 0xFF && raw.size >= 2) {
                val prefix = raw.copyOfRange(0, 2).toHex()
                val macBytes = when {
                    raw.size > 8 -> raw.copyOfRange(2, 8)
                    raw.size >= 6 -> raw.copyOfRange(raw.size - 6, raw.size)
                    else -> null
                }
                val mac = macBytes?.joinToString(":") { "%02X".format(it.toInt() and 0xFF) }
                val broadcast = when {
                    raw.size > 20 &&
                        raw[0] == 0x00.toByte() &&
                        raw[1] == 0x02.toByte() &&
                        raw[2] == 0xAA.toByte() &&
                        raw[3] == 0xEE.toByte() -> "health_broadcast"
                    raw.size > 14 &&
                        raw[0] == 0x00.toByte() &&
                        raw[1] == 0x02.toByte() &&
                        raw[2] == 0xBB.toByte() &&
                        raw[3] == 0xEE.toByte() -> "battery_broadcast"
                    else -> null
                }
                return StarmaxManufacturerInfo(prefix, mac, prefix == "0001", broadcast)
            }
            index += 1 + len
        }
        return StarmaxManufacturerInfo(null, null, false, null)
    }

    private fun ByteArray.toHex(): String {
        return joinToString("") { "%02X".format(it.toInt() and 0xFF) }
    }

    companion object {
        private const val REQUEST_CODE_PERMISSIONS = 8472
        private const val SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9d"
        private const val WRITE_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9d"
        private const val NOTIFY_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9d"
    }
}
