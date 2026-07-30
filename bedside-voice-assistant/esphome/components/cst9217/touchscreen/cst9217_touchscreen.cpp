#include "cst9217_touchscreen.h"
#include "esphome/core/helpers.h"

namespace esphome::cst9217 {

bool CST9217Touchscreen::probe_chip_id_() {
  // Enter command mode (8-bit register 0xD1, value 0x01) — the chip's
  // point-data page (0xD000, used in update_touches()) works without
  // this, but the chip-info page used here for identification needs it.
  if (!this->write_byte(0xD1, CMD_ENTER_COMMAND_MODE)) {
    return false;
  }
  delay(10);

  uint8_t info[4];
  if (this->read_register16(REG_CHIP_INFO, info, sizeof(info)) != i2c::ERROR_OK) {
    return false;
  }
  this->chip_id_ = (static_cast<uint16_t>(info[3]) << 8) | info[2];
  return this->chip_id_ == CST9220_CHIP_ID || this->chip_id_ == CST9217_CHIP_ID;
}

void CST9217Touchscreen::continue_setup_() {
  if (this->interrupt_pin_ != nullptr) {
    this->interrupt_pin_->setup();
    this->attach_interrupt_(this->interrupt_pin_, gpio::INTERRUPT_FALLING_EDGE);
  }

  this->chip_id_confirmed_ = this->probe_chip_id_();
  if (!this->chip_id_confirmed_) {
    // Don't mark_failed(): the identification handshake is the part of
    // this port least likely to be exactly right on the first try, but
    // the actual touch-point read in update_touches() is independent of
    // it, so it's worth letting touch input keep trying either way.
    ESP_LOGW(TAG, "Could not confirm CST9217/CST9220 chip ID (got 0x%04X) - continuing anyway", this->chip_id_);
  }

  if (this->x_raw_max_ == this->x_raw_min_) {
    this->x_raw_max_ = this->display_->get_native_width();
  }
  if (this->y_raw_max_ == this->y_raw_min_) {
    this->y_raw_max_ = this->display_->get_native_height();
  }
}

void CST9217Touchscreen::setup() {
  if (this->reset_pin_ != nullptr) {
    this->reset_pin_->setup();
    this->reset_pin_->digital_write(false);
    delay(10);
    this->reset_pin_->digital_write(true);
    // Datasheet/driver wait 30ms after reset before the chip responds.
    this->set_timeout(30, [this] { this->continue_setup_(); });
  } else {
    this->continue_setup_();
  }
}

void CST9217Touchscreen::update_touches() {
  uint8_t buf[POINT_BUFFER_SIZE] = {0};
  if (this->read_register16(REG_READ_COMMAND, buf, sizeof(buf)) != i2c::ERROR_OK) {
    this->status_set_warning();
    return;
  }

  // Acknowledge the read so the chip prepares the next sample.
  uint8_t ack = ACK_BYTE;
  this->write_register16(REG_READ_COMMAND, &ack, 1);

  if (buf[6] != ACK_BYTE) {
    // Not a real fault - the chip just wasn't ready with fresh data yet.
    return;
  }

  uint8_t num_points = buf[5] & 0x7F;
  if (num_points == 0 || num_points > MAX_TOUCH_POINTS) {
    return;
  }

  for (uint8_t i = 0; i < num_points; i++) {
    // Point records are 5 bytes each, with an extra 2-byte gap before the
    // second point - this offset quirk is transcribed as-is from the
    // reference driver, not something to "simplify" without a board to
    // verify against.
    const uint8_t *point = buf + (i * 5) + (i == 0 ? 0 : 2);
    uint8_t event = point[0] & 0x0F;
    if (event != 0x06) {
      continue;  // 0x06 = valid finger-down sample, per the reference driver
    }
    uint8_t id = point[0] >> 4;
    uint16_t x = (static_cast<uint16_t>(point[1]) << 4) | (point[3] >> 4);
    uint16_t y = (static_cast<uint16_t>(point[2]) << 4) | (point[3] & 0x0F);
    ESP_LOGV(TAG, "Touch %u: %u,%u", id, x, y);
    this->add_raw_touch_position_(id, x, y);
  }
}

void CST9217Touchscreen::dump_config() {
  ESP_LOGCONFIG(TAG,
                "CST9217 Touchscreen:\n"
                "  X Raw Min: %d, X Raw Max: %d\n"
                "  Y Raw Min: %d, Y Raw Max: %d",
                this->x_raw_min_, this->x_raw_max_, this->y_raw_min_, this->y_raw_max_);
  LOG_I2C_DEVICE(this);
  LOG_PIN("  Interrupt Pin: ", this->interrupt_pin_);
  LOG_PIN("  Reset Pin: ", this->reset_pin_);
  if (this->chip_id_confirmed_) {
    ESP_LOGCONFIG(TAG, "  Chip ID confirmed: 0x%04X", this->chip_id_);
  } else {
    ESP_LOGCONFIG(TAG, "  Chip ID NOT confirmed (got 0x%04X) - touch may not work", this->chip_id_);
  }
}

}  // namespace esphome::cst9217
