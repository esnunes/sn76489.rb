# frozen_string_literal: true

module SN76489
  class Chip
    CH_0_TONE = 0b000
    CH_0_VOL = 0b001
    CH_1_TONE = 0b010
    CH_1_VOL = 0b011
    CH_2_TONE = 0b100
    CH_2_VOL = 0b101
    NOISE_CONTROL = 0b110
    NOISE_VOL = 0b111

    VOL_TABLE = [
      32767, 26028, 20675, 16422, 13045, 10362, 8231, 6568, 5193, 4125, 3277,
      2603, 2067, 1642, 1304, 0,
    ]
    VOL_MAX = VOL_TABLE.first
    VOL_MUTE = VOL_TABLE.last

    attr_reader :regs
    attr_reader :clock

    def initialize(clock: 3579545, sample_rate: 44100)
      @clock = clock
      @sample_rate = sample_rate
      @tick_size = clock / 16.0 / sample_rate
      @regs = Array.new(8) { 0 }
      @counters = Array.new(3) { -1 }
      @flip_flops = Array.new(3) { -1 }

      reset
    end

    def reset
      @regs[CH_0_VOL] = 0xf
      @regs[CH_1_VOL] = 0xf
      @regs[CH_2_VOL] = 0xf
    end

    def write(byte)
      latch = (byte >> 7) & 1 == 1

      if latch
        @latched_reg = byte >> 4 & 0x7
        @regs[@latched_reg] = byte & 0xf
        @regs[@latched_reg] &= 0x7 if @latched_reg == NOISE_CONTROL
      else
        case @latched_reg
        when CH_0_TONE, CH_1_TONE, CH_2_TONE
          @regs[@latched_reg] |= (byte & 0x3f) << 4
        when CH_0_VOL, CH_1_VOL, CH_2_VOL, NOISE_VOL
          @regs[@latched_reg] = byte & 0xf
        when NOISE_CONTROL
          @regs[@latched_reg] = byte & 0x7
        end
      end
    end

    def tick(length)
      Array.new(length).map do
        for i in 0..2 do
          @counters[i] -= @tick_size
          if @counters[i] < 0
            @counters[i] = @regs[i << 1] + @counters[i]
            @flip_flops[i] *= -1
          end
        end

        res = [
          @flip_flops[0] * VOL_TABLE[@regs[CH_0_VOL]],
          @flip_flops[1] * VOL_TABLE[@regs[CH_1_VOL]],
          @flip_flops[2] * VOL_TABLE[@regs[CH_2_VOL]],
        ].sum
        res = VOL_TABLE.first if res > VOL_TABLE.first
        res = VOL_TABLE.first * -1 if res < VOL_TABLE.first * -1
        res
      end
    end

    def set_volume(channel:, value:)
      byte = 0b1001_0000
      byte |= channel << 5
      byte |= VOL_TABLE.index(value)
      write(byte)
    end

    def set_tone(channel:, freq:)
      clock_freq = @clock / (32 * freq)
      byte = 0b1000_0000
      byte |= channel << 5
      byte |= clock_freq & 0xf
      write(byte)
      byte = 0b0000_0000
      byte |= (clock_freq & 0x3ff) >> 4
      write(byte)
    end
  end
end
