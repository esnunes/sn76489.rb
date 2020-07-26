# frozen_string_literal: true

require 'test_helper'

module SN76489
  class ChipTest < Test
    def setup
      @chip = Chip.new
    end

    def test_write_set_volume_channel_2
      @chip.write(0b1101_1101)

      assert_equal(0b1101, @chip.regs[Chip::CH_2_VOL])
    end

    def test_write_partially_set_tone_channel_2
      @chip.write(0b1100_1101)

      assert_equal(0b1101, @chip.regs[Chip::CH_2_TONE])
    end

    def test_write_set_tone_channel_2
      @chip.write(0b1100_1110)
      @chip.write(0b0000_1111)

      assert_equal(0b0011111110, @chip.regs[Chip::CH_2_TONE])
    end

    def test_write_override_volume_channel_2
      @chip.write(0b1101_1111)
      assert_equal(0b1111, @chip.regs[Chip::CH_2_VOL])

      @chip.write(0b0000_0000)
      assert_equal(0b0000, @chip.regs[Chip::CH_2_VOL])
    end

    def test_write_set_noise_control
      @chip.write(0b1110_0101)

      assert_equal(0b101, @chip.regs[Chip::NOISE_CONTROL])
    end

    def test_write_override_noise_control
      @chip.write(0b1110_0101)
      assert_equal(0b101, @chip.regs[Chip::NOISE_CONTROL])

      @chip.write(0b0000_0100)
      assert_equal(0b100, @chip.regs[Chip::NOISE_CONTROL])
    end

    def test_tick_1
      @chip.write(0b1001_0000) # set channel 0 volume max
      @chip.write(0b1000_1110) # set channel 0 tone 440hz
      @chip.write(0b0000_1111)

      buffer = @chip.tick(44100)

      assert_equal(44100, buffer.size)
      peaks = 0
      buffer.reduce(Chip::VOL_TABLE.first) do |m, b|
        if m != b
          peaks += 1 if b > 0
          m = b
        end
        m
      end
      assert_equal(440, peaks)
    end

    def test_tick_2
      @chip.write(0b1001_0000) # set channel 0 volume max
      @chip.write(0b1000_1100) # set channel 0 tone 440hz
      @chip.write(0b0001_1111)

      buffer = @chip.tick(44100)

      assert_equal(44100, buffer.size)
      peaks = 0
      buffer.reduce(Chip::VOL_TABLE.first) do |m, b|
        if m != b
          peaks += 1 if b > 0
          m = b
        end
        m
      end
      assert_equal(220, peaks)
    end

    def test_set_volume
      @chip.expects(:write).with(0b1101_1111)

      @chip.set_volume(channel: 2, level: Chip::VOL_MUTE)
    end

    def test_set_tone
      @chip.expects(:write).with(0b1100_1110)
      @chip.expects(:write).with(0b0000_1111)

      @chip.set_tone(channel: 2, freq: 440)
    end
  end
end
