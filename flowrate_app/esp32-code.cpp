#include <Arduino.h>
#include <NimBLEDevice.h>

// ==========================================================
// CONFIGURATION
// ==========================================================

bool useAdc = false;

const int ADC_VELOCITY_PIN = 34;
const int ADC_BATTERY_PIN = 35;

const float BATTERY_DIVIDER_RATIO = 2.0f;
const float BATTERY_FULL_VOLTAGE  = 4.20f;
const float BATTERY_EMPTY_VOLTAGE = 3.20f;

static NimBLEUUID SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static NimBLEUUID CHARACTERISTIC_UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

NimBLECharacteristic* pCharacteristic;

// ==========================================================
// SENSOR FUNCTIONS
// ==========================================================

int dummyCounter = 0;

float readVelocity() {
    if (!useAdc) {
        dummyCounter += 3;
        return dummyCounter;
    }

    int raw = analogRead(ADC_VELOCITY_PIN);
    float v = (raw / 4095.0f) * 3.3f;
    return v * 25.0f;
}

int readBatteryPercent() {
    int raw = analogRead(ADC_BATTERY_PIN);
    float vin = (raw / 4095.0f) * 3.3f * BATTERY_DIVIDER_RATIO;

    if (vin < BATTERY_EMPTY_VOLTAGE) return 0;
    if (vin > BATTERY_FULL_VOLTAGE) return 100;

    return (int)(100.0f * (vin - BATTERY_EMPTY_VOLTAGE) /
                 (BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE));
}

// ==========================================================
// CALLBACKS — NimBLE 2.3.6 SAFE
// ==========================================================

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) {
        Serial.println("[BLE] Client connected");
    }

    void onDisconnect(NimBLEServer* pServer) {
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

    analogReadResolution(12);
    pinMode(ADC_VELOCITY_PIN, INPUT);
    pinMode(ADC_BATTERY_PIN, INPUT);

    NimBLEDevice::init("ESP32-Flow");
    NimBLEDevice::setPower(ESP_PWR_LVL_N12);

    NimBLEServer* server = NimBLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());

    NimBLEService* service = server->createService(SERVICE_UUID);

    pCharacteristic = service->createCharacteristic(
        CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );

    service->start();

    // -------- Advertising
    NimBLEAdvertisementData advData;
    advData.setName("ESP32-Flow");
    advData.setCompleteServices(SERVICE_UUID);

    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    adv->setAdvertisementData(advData);
    adv->start();

    Serial.println("BLE advertising started as ESP32-Flow");
}

// ==========================================================
// LOOP
// ==========================================================

void loop() {
    static unsigned long last = 0;
    if (millis() - last >= 1000) {
        last = millis();

        float vel = readVelocity();
        int batt  = readBatteryPercent();

        char json[32];
        snprintf(json, sizeof(json),
                "{\"v\":%.0f,\"b\":%d}", vel, batt);

        pCharacteristic->setValue((uint8_t*)json, strlen(json));
        pCharacteristic->notify();

        Serial.println(json);
    }

    delay(10);
}
