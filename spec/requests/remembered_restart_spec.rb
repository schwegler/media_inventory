# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'Remembered sign-in across application process restart' do
  it 'restores with the same synthetic test key and persistent database in a fresh process' do
    Dir.mktmpdir('remembered-restart-') do |directory|
      env = {
        'RAILS_ENV' => 'test', 'DATABASE_URL' => "sqlite3:#{directory}/restart.sqlite3",
        'SECRET_KEY_BASE' => 'synthetic-restart-test-key-' * 4,
        'REMEMBER_RESTART_STATE' => "#{directory}/state.json"
      }
      %w[issue restore].each do |phase|
        output, error, status = Open3.capture3(env.merge('REMEMBER_RESTART_PHASE' => phase),
                                               'bundle', 'exec', 'rails', 'runner', 'spec/scripts/remembered_restart.rb')
        expect(status.success?).to be(true), "#{phase} process failed: #{output}\n#{error}"
        expect(output).to include('PASS')
      end
    end
  end
end
