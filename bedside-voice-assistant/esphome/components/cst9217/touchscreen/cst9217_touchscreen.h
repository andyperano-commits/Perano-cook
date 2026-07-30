#pragma once

// CST9217 capacitive touch driver, ported from Waveshare's own SensorLib
// (TouchDrvCST92xx.cpp/.h, github.com/waveshareteam/ESP32-S3-Touch-AMOLED-1.75C)
// since ESPHome has no built-in driver for this chip family. Only the
// runtime touch-read path is ported here (chip ID probe + point polling);
// the original driver's firmware-update path is intentionally left out —
// this component only reads touches, it doesn't reflash the controller.
//
// UNTESTED ON HARDWARE: written from the reference driver's protocol
// without a physical board available in the environment that wrote it.
// The register sequence below is transcribed faithfully, but the first
// real compile + flash is what actually proves it out.

#include "esphome/components/i2c/i2c.h"
#include "esphome/components/touchscreen/touchscreen.h"
#include "esphome/core/component.h"
#include "esphome/core/hal.h"
#include "esphome/core/log.h"

namespace esphome::cst9217 {

static const char *const TAG = "cst9217.touchscreen";

// 16-bit "register" addresses, matching Waveshare's TouchDrvCST92xx —
// this chip addresses registers as two raw bytes (MSB, LSB) rather than
// the single-byte scheme most touch controllers use.
static const uint16_t REG_READ_COMMAND = 0xD000;    // point data page
static const uint16_t REG_ENTER_CMD_INFO = 0xD1FC;  // checkcode, command-mode readback
static const uint16_t REG_CHIP_INFO = 0xD204;       // project ID / chip type

static const uint8_t CMD_ENTER_COMMAND_MODE = 0x01;  // written to 8-bit register 0xD1
static const uint8_t ACK_BYTE = 0xAB;

static const uint16_t CST9220_CHIP_ID = 0x9220;
static const uint16_t CST9217_CHIP_ID = 0x9217;

static const uint8_t MAX_TOUCH_POINTS = 2;
// header(2) + up to 2 points * 5 bytes + a 2-byte gap before the 2nd point,
// per the original driver's read_buffer sizing (MAX_FINGER_NUM * 5 + 5).
static const uint8_t POINT_BUFFER_SIZE = MAX_TOUCH_POINTS * 5 + 5;

class CST9217Touchscreen : public touchscreen::Touchscreen, public i2c::I2CDevice {
 public:
  void setup() override;
  void update_touches() override;
  void dump_config() override;

  void set_interrupt_pin(InternalGPIOPin *pin) { this->interrupt_pin_ = pin; }
  void set_reset_pin(GPIOPin *pin) { this->reset_pin_ = pin; }

 protected:
  void continue_setup_();
  bool probe_chip_id_();

  InternalGPIOPin *interrupt_pin_{};
  GPIOPin *reset_pin_{};
  uint16_t chip_id_{0};
  bool chip_id_confirmed_{false};
};

}  // namespace esphome::cst9217
