# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter 'test'
    command_name 'Mintest'
  end
end

require 'minitest/autorun'
require 'mocha/minitest'
require_relative '../lib/sn76489.rb'

module SN76489
  class Test < Minitest::Test
  end
end
