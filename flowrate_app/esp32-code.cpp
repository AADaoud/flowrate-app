#include <Arduino.h>
#include <NimBLEDevice.h>
#include <WiFi.h>
#include <Wire.h>
#include "driver/rtc_io.h"
#include "soc/rtc_cntl_reg.h"

// ==========================================================
// CONFIGURATION
// ==========================================================

// ADC pin for battery voltage divider (UPDATED)
const int ADC_BATTERY_PIN = 5;

// Divider ratio (100k / 100k)
const float BATTERY_DIVIDER_RATIO = 2.0f;

// LiPo cutoff / full
const float BATTERY_FULL_VOLTAGE  = 4.20f;
const float BATTERY_EMPTY_VOLTAGE = 3.20f;

// BLE UUIDs — do NOT modify
static NimBLEUUID SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static NimBLEUUID CHARACTERISTIC_UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

NimBLECharacteristic* pCharacteristic;

// ==========================================================
// LOW FREQUENCY MODE ON BATTERY
// ==========================================================

// 1 = reduce sampling + BLE update rate when on battery
// 0 = always use normal rate
static const int LOW_FREQ_ON_BATTERY = 1;

// Update intervals
static const unsigned long LOOP_INTERVAL_USB    = 800;   // ms (unchanged behavior)
static const unsigned long LOOP_INTERVAL_BATTERY = 3000; // ms (~0.33 Hz, low power)

// ==========================================================
// POWER OPTIMIZATION (unchanged behavior)
// ==========================================================
void optimizePower() {
    WiFi.mode(WIFI_OFF);
    WiFi.disconnect(true);

    WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

    setCpuFrequencyMhz(80);

    NimBLEDevice::setPower(ESP_PWR_LVL_N12);
}

// ==========================================================
// ADS1115 LOW-LEVEL DRIVER
// ==========================================================

#define ADS1115_ADDR 0x48

// 🔧 DIFFERENTIAL A0–A1, ±0.256V range, 1600 SPS
uint16_t ADS1115_CONFIG =
    0x8000 | // Start single conversion
    0x4000 | // MUX = AIN0 - AIN1 (DIFFERENTIAL) is 0x0000 <- IMPORTANT
    0x0400 | // PGA = ±0.256V (7.8125 µV / bit)
    0x0100 | // 1600 SPS
    0x0003;  // Single-shot mode

bool ads1115_writeConfig(uint16_t cfg) {
    Wire.beginTransmission(ADS1115_ADDR);
    Wire.write(0x01);
    Wire.write(cfg >> 8);
    Wire.write(cfg & 0xFF);
    return (Wire.endTransmission() == 0);
}

int16_t ads1115_readConversion() {
    Wire.beginTransmission(ADS1115_ADDR);
    Wire.write(0x00);
    if (Wire.endTransmission() != 0) return 0x8000;

    Wire.requestFrom(ADS1115_ADDR, 2);
    if (Wire.available() < 2) return 0x8000;

    return (Wire.read() << 8) | Wire.read();
}

// 🔧 returns volts (signed differential)
float ads1115_readDiffVoltage() {
    if (!ads1115_writeConfig(ADS1115_CONFIG))
        return 0.0f;

    delay(2); // enough for 1600 SPS

    int16_t raw = ads1115_readConversion();
    if (raw == 0x8000) return 0.0f;

    // ±0.256V → 7.8125 µV per bit
    return raw * 0.0000078125f;
}

// ==========================================================
// VELOCITY VIA ADS1115 (same scaling)
// ==========================================================
float readVelocity() {
    float voltage = ads1115_readDiffVoltage();
    return voltage * 25.0f;
}

// ==========================================================
// BATTERY MEASUREMENT (unchanged logic, new pin)
// ==========================================================

int stableADCRead(int pin) {
    const int N = 32;
    uint16_t samples[N];

    for (int i = 0; i < N; i++) {
        samples[i] = analogRead(pin);
        delayMicroseconds(150);
    }

    uint16_t minV = 65535;
    uint16_t maxV = 0;
    uint32_t sum = 0;

    for (int i = 0; i < N; i++) {
        uint16_t v = samples[i];
        minV = min(minV, v);
        maxV = max(maxV, v);
        sum += v;
    }

    sum -= minV;
    sum -= maxV;

    return sum / (N - 2);
}

int readBatteryPercent() {
    int raw = stableADCRead(ADC_BATTERY_PIN);

    float vin = (raw / 4095.0f) * 3.3f * BATTERY_DIVIDER_RATIO;

    if (vin <= BATTERY_EMPTY_VOLTAGE) return 0;
    if (vin >= BATTERY_FULL_VOLTAGE) return 100;

    return (int)(100.0f *
        (vin - BATTERY_EMPTY_VOLTAGE) /
        (BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE));
}

// ==========================================================
// BLE CALLBACKS (unchanged)
// ==========================================================
class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer*) override {
        Serial.println("[BLE] Client connected");
    }
    void onDisconnect(NimBLEServer*) override {
        Serial.println("[BLE] Client disconnected → restarting advertising");
        NimBLEDevice::startAdvertising();
    }
};

// ==========================================================
// SETUP
// ==========================================================

void setup() {
    Serial.begin(115200);
    delay(300);

    optimizePower();
    delay(100);
    
    Wire.begin(8, 9);

    analogReadResolution(12);
    pinMode(ADC_BATTERY_PIN, INPUT);

    NimBLEDevice::init("ESP32-Flow");

    NimBLEServer* server = NimBLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());

    NimBLEService* service = server->createService(SERVICE_UUID);

    pCharacteristic = service->createCharacteristic(
        CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );

    service->start();

    NimBLEAdvertisementData adv;
    adv.setName("ESP32-Flow");
    adv.setCompleteServices(SERVICE_UUID);

    NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
    advertising->setAdvertisementData(adv);
    advertising->start();

    Serial.println("BLE advertising started");
}

// ==========================================================
// LOOP (unchanged behavior)
// ==========================================================

void loop() {
    static unsigned long last = 0;

    unsigned long interval = LOOP_INTERVAL_USB;

    if (LOW_FREQ_ON_BATTERY) {
        // If USB is NOT connected, assume battery
        interval = (Serial.availableForWrite() > 0) ?
           LOOP_INTERVAL_USB :
           LOOP_INTERVAL_BATTERY;
    }

    if (millis() - last >= interval) {

        last = millis();

        float velocity = readVelocity();
        int battery    = readBatteryPercent();

        char json[48];
        snprintf(json, sizeof(json),
                 "{\"v\":%.1f,\"b\":%d}", velocity, battery);

        pCharacteristic->setValue((uint8_t*)json, strlen(json));
        pCharacteristic->notify();

        Serial.println(json);
    }

    delay(10);
}
