# frozen_string_literal: true

module SN76489
  class Chip
    class Oscillator
      def initialize
        @counter = 0
        @length = 0
        @next_length = 0
      end

      def length=(next_length)
        @next_length = next_length
      end

      def tick(cycles = 1)
        @counter += cycles
        if @counter > @length
          @prev_length = @length
          @length = @next_length

        end
        @counter = @next_length if @counter.zero?

      end
    end

    CH_0_TONE = 0b000
    CH_0_VOL = 0b001
    CH_1_TONE = 0b010
    CH_1_VOL = 0b011
    CH_2_TONE = 0b100
    CH_2_VOL = 0b101
    NOISE_CONTROL = 0b110
    NOISE_VOL = 0b111

    NOISE_PERIODIC = 0
    NOISE_WHITE = 1

    NOISE_CLOCK_HIGH = 0b00
    NOISE_CLOCK_MEDIUM = 0b01
    NOISE_CLOCK_LOW = 0b10
    NOISE_CLOCK_CH_2 = 0b11

    VOL_TABLE = [
      32767, 26028, 20675, 16422, 13045, 10362, 8231, 6568, 5193, 4125, 3277,
      2603, 2067, 1642, 1304, 0,
    ]
    VOL_MAX = VOL_TABLE.size - 1
    VOL_MUTE = 0

    attr_reader :regs
    # attr_reader :clock

    def initialize(system_clock: 3579545, sample_rate: 44100, divider: 16.0)
      @sample_rate = sample_rate
      @divider = divider
      @internal_clock = system_clock / divider
      @tick_size = clock / 16.0 / sample_rate
      @regs = Array.new(8) { 0 }
      @counters = Array.new(4) { -1 }
      @flip_flops = Array.new(4) { -1 }
      @lfsr = 1 << 15

      reset
    end

    def reset
      @regs[CH_0_VOL] = 0xf
      @regs[CH_1_VOL] = 0xf
      @regs[CH_2_VOL] = 0xf
      @regs[NOISE_VOL] = 0xf
      @cycle = 0
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

    def step_to(system_cycle)
      cycles = system_cycle - @cycle
    end

    def tick(length)
      Array.new(length).map do
        # tone
        for i in 0..2 do
          @counters[i] -= @tick_size
          if @counters[i] < 0
            @counters[i] = @regs[i << 1] + @counters[i]
            @flip_flops[i] *= -1
          end
        end

        # noise
        @counters[3] -= @tick_size
        if @counters[3] < 0
          @counters[3] += noise_freq
          @flip_flops[3] *= -1
          shift_lfsr if @flip_flops[3].positive?
        end

        res = [
          @flip_flops[0] * VOL_TABLE[@regs[CH_0_VOL]],
          @flip_flops[1] * VOL_TABLE[@regs[CH_1_VOL]],
          @flip_flops[2] * VOL_TABLE[@regs[CH_2_VOL]],
          (@lfsr & 1) * VOL_TABLE[@regs[NOISE_VOL]],
        ].sum
        res = VOL_TABLE.first if res > VOL_TABLE.first
        res = VOL_TABLE.first * -1 if res < VOL_TABLE.first * -1
        res
      end
    end

    def set_volume(channel:, level:)
      byte = 0b1001_0000
      byte |= channel << 5
      byte |= (0xf - level) & 0xf
      write(byte)
    end

    def set_tone(channel:, freq:)
      hz = @internal_clock / (2 * freq)
      set_tone_hz(channel: channel, hz: hz)
    end

    def set_tone_hz(channel:, hz:)
      byte = 0b1000_0000
      byte |= channel << 5
      byte |= hz & 0xf
      write(byte)
      byte = 0b0000_0000
      byte |= (hz & 0x3ff) >> 4
      write(byte)
    end

    def set_noise(type:, clock:)
      byte = 0b1110_0000
      byte |= type << 2
      byte |= clock
      write(byte)
    end

    def noise_freq
      case (@regs[NOISE_CONTROL] & 0b11)
      when 0b00
        0x10
      when 0b01
        0x20
      when 0b10
        0x40
      else
        @regs[CH_2_TONE]
      end
    end

    def noise_white?
      (@regs[NOISE_CONTROL] & (1 << 2)).positive?
    end

    private

    def shift_lfsr
      @lfsr = (@lfsr >> 1) | ((noise_white? ? parity(@lfsr & 0x0009) : @lfsr & 1) << 15)
      @lfsr
    end

    def parity(val)
      val ^= val >> 8
      val ^= val >> 4
      val ^= val >> 2
      val ^= val >> 1
      val & 1
    end
  end
end
