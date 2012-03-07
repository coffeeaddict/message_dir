require 'spec_helper'
require 'simple_uuid'

describe MessageDir::Message do
  before :all do
    @dir = MessageDir.new(Dir.mktmpdir(nil, '/tmp'))
  end

  after :all do
    FileUtils.remove_entry_secure @dir.path
  end

  describe "On initialize" do
    before :each do
      uuid = SimpleUUID::UUID.new
      File.open(File.join(@dir.path, "new", uuid.to_guid), "w") do |f|
        f.puts "hello"
      end
      @new = uuid.to_guid

      uuid = SimpleUUID::UUID.new
      File.open(File.join(@dir.path, "cur", uuid.to_guid), "w") do |f|
        f.puts "world"
      end
      @cur = uuid.to_guid
    end

    it "should not open a message without a guid" do
      msg = MessageDir::Message.new(@dir)
      msg.fh.should be_nil
    end

    it "should not create a message with a non existing guid" do
      msg = MessageDir::Message.new(@dir, "24319b5c-5cc8-11e1-8312-67c6faefd181")
      msg.fh.should be_nil
    end

    it "should open a message with an existing guid" do
      msg = MessageDir::Message.new(@dir, @new)
      msg.fh.should be_kind_of(File)
      msg.fh.should_not be_closed
    end

    it "should find a message in cur as well" do
      msg = MessageDir::Message.new(@dir, @cur)
      msg.fh.should be_kind_of(File)
      msg.fh.should_not be_closed
    end
  end

  describe "With new" do
    before :each do
      @msg = MessageDir::Message.new(@dir)
    end

    it "should create a message in new" do
      @msg.new do |fh|
        fh.puts "i am the new message"
      end

      @msg.uuid.should be_kind_of(SimpleUUID::UUID)
      @msg.guid.should be_kind_of(String)
      @msg.guid.should_not be_empty

      @msg.fh.should_not be_closed
      @msg.fh.read.should =~ /i am the new message/

      @msg.spot.should == :new
      @msg.path.should =~ /new\//
    end

    it "should keep a message in tmp while not done" do
      Thread.new do
        @msg.new do |fh|
          fh.puts "a part"
          sleep 4
          fh.puts "and another"
        end
      end

      sleep 1

      files = Dir[File.join(@dir.path, "tmp", "*")]
      files.count.should == 1
    end
  end

  describe "Current" do
    it "should move a message to cur/" do
      msg = MessageDir::Message.new(@dir).new do |fh|
        fh.puts "i am the message"
      end

      msg.spot.should == :new

      msg.cur
      msg.spot.should == :cur
      msg.path.should =~ /cur\//
    end

    it "should keep an open filehandle" do
      msg = MessageDir::Message.new(@dir).new do |fh|
        fh.puts "i am the message"
      end.cur

      msg.spot.should == :cur
      msg.fh.should_not be_closed
    end
  end

end