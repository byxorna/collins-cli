require 'spec_helper'

describe Collins::CLI::Find do
  before(:each) do
    allow(Collins::CLI::Find).to receive(:format_assets).and_return(true)
    allow(Collins::CLI::Find).to receive_message_chain(:collins,:find).and_return([])
    subject { Collins::CLI::Find.new }
  end
  context "#parse!" do
    [
      %w|-h|,
      %w|-S allocated,maintenance|,
      %w|-n testnode -ais_vm:true|,
      %w|hostname|,
      %w|hostname -c tag|,
    ].each do |args|
      it "Should parse #{args.inspect} successfully" do
        expect{subject.parse!(args)}.to_not raise_error
      end
    end
    [
      %w|-OOOOOO|,
      %w|-K -Z_ LJIFJ?=I)|,
    ].each do |args|
      it "Should fail to parse unknown flags #{args.inspect}" do
        expect{subject.parse!(args)}.to raise_error
      end
    end
    it "requires arguments" do
      expect{subject.parse!([])}.to raise_error(/See --help/)
    end
  end

  context "#validate!" do
    it "raises if not yet parsed" do
      expect{subject.validate!}.to raise_error(/not yet parsed/)
    end
  end

  context "#run!" do
    it "raises if not yet parsed" do
      expect{subject.run!}.to raise_error(/not yet parsed/)
    end
    it "raises if not yet validated" do
      expect{subject.parse!(%w|-n nodeclass|).run!}.to raise_error(/not yet validated/)
    end
  end
end
