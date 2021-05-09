# frozen_string_literal: true

module SN76489
  class Driver
    class Clock
      def initialize(parent:, divider: 1.0)
        @parent = parent
        @divider = divider

        @cycles = 0
      end

      def step_to(parent_cycle)
        remaining_cycles = (parent_cycle / @divider).ceil - @cycles
        @cycles += remaining_cycles
        remaining_cycles
      end
    end

    def initialize(clock:)
      @clock = clock
    end

    def step_to(system_cycles)
      cycles = @clock.step_to(system_cycles)
      while cycles.positive?
        # do things
      end
    end
  end
end
