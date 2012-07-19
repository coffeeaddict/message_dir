require 'spec_helper'
require 'tmpdir'

describe MessageDir do
  before :each do
    @path = Dir.mktmpdir(nil, '/tmp')
  end

  after :each do
    FileUtils.remove_entry_secure @path
  end

  it "should create a tree structure at a designated directory" do
    expect {
      MessageDir.new(@path)
    }.to change {
      %w(tmp new cur).collect do |spot|
        File.directory?(File.join(@path, spot))
      end
    }
  end

  subject { MessageDir.new(@path) }

  it "should create a new message" do
    msg = subject.new
    File.exists?(msg.path).should == true
    msg.path.should =~ Regexp.new(subject.path.new)
  end

  it "should provide new messages open for reading" do
    msg = subject.new

    msg.size.should == 0

    expect { msg.syswrite("failure") }.to raise_error(IOError)
  end

  it "should provide new messages in block style" do
    msg = subject.new do |fh|
      fh.puts "I is a message"
    end

    msg.path.should =~ Regexp.new(subject.path.new)

    msg.pos.should == 0

    expect { msg.syswrite("failure") }.to raise_error(IOError)

    msg.read.should == "I is a message\n"
  end

  it "should handle exceptions when creating messages" do
    expect {
      subject.new do |fh|
        raise "an error"
      end
    }.to_not raise_error

    msg = subject.new do |fh|
      fh.puts "some info"
      raise
    end

    msg.should_not be_nil
    msg.read.should == "some info\n"
  end

  it "should place a new message in tmp during creation" do
    msg = subject.new do |fh|
      fh.puts "I am not in new"
      raise
    end

    msg.path.should =~ Regexp.new(subject.path.tmp)
  end

  it "should move a message to cur" do
    msg = subject.new do |fh|
      fh.puts "I am now in cur"
    end

    msg.read.should == "I am now in cur\n"

    subject.cur(msg)

    msg.should_not be_closed
    msg.path.should =~ Regexp.new(subject.path.cur)

    msg.read.should == "I am now in cur\n"
  end

  it "should move a message to cur over the message" do
    msg = subject.new do |fh|
      fh.puts "i am to be curred"
    end

    msg.cur!

    msg.should_not be_closed
    msg.path.should =~ Regexp.new(subject.path.cur)
    msg.read.should == "i am to be curred\n"
  end

  describe "listing messages" do
    it "should list no messages when empty" do
      subject.messages
      subject.messages.should be_empty
    end

    it "should list all messages" do
      3.times do |i|
        msg = subject.new do |fh|
          fh.puts "i am message #{i}"
        end
      end

      subject.messages.count.should == 3
    end

    it "should list all messages in new" do
      3.times do |i|
        msg = subject.new do |fh|
          fh.puts "i am message #{i}"
        end

        msg.cur! if i == 1
      end

      subject.msgs(:new).count.should == 2
    end

    it "should list all messages in cur" do
      3.times do |i|
        msg = subject.new do |fh|
          fh.puts "i am message #{i}"
        end

        msg.cur! if i != 1
      end

      subject.msgs(:cur).count.should == 2
    end

    it "should list all messages in tmp" do
      3.times do |i|
        msg = subject.new do |fh|
          fh.puts "i am message #{i}"
        end
        msg.move(subject.path.tmp)
      end

      subject.msgs(:tmp).count.should == 3
    end
  end

  describe "accessing messages" do
    before :each do
      3.times { subject.new }
      3.times { subject.new.cur! }
    end

    it "should provide access to a message in new" do
      subject.msgs(:new).should be_any
      subject.msgs(:new).first.should be_kind_of(MessageDir::Message)
    end

    it "should provide access to a message in cur" do
      subject.msgs(:cur).should be_any
      subject.msgs(:cur).first.should be_kind_of(MessageDir::Message)
    end

    it "should provide access to a message based on UUID" do
      msg  = subject.msgs(:new).first
      same = subject.message(msg.guid)

      same.should be_kind_of(MessageDir::Message)

      msg.should == same
    end
  end

  describe "locking" do
    before :each do
      3.times { subject.new }
    end

    it "should not lock messages by default" do
      msg = subject.msgs.first
      msg.should_not be_locked
    end

    it "should lock messages" do
      msg = subject.msgs.first
      msg.lock
      msg.should be_locked
    end

    it "should unlock messages" do
      msg = subject.msgs.first
      msg.lock
      msg.should be_locked

      msg.unlock
      msg.should_not be_locked
    end

    it "should lock message in block style" do
      msg = subject.msgs.first
      msg.should_not be_locked

      msg.lock do
        msg.should be_locked

        msg.open(File::WRONLY|File::APPEND) do |fh|
          fh.puts "Placed in a locked file"
        end
      end

      msg.should_not be_locked
    end
  end


  describe "processing" do
    before :each do
      3.times do |i|
        msg = subject.new do |fh|
          fh.puts "I am new"
        end

        msg.cur! if i == 1
      end
    end

    it "should process messages" do
      msg = subject.msgs.first
      subject.process(msg, File::WRONLY|File::TRUNC) do |fh|
        fh.puts "I am processed"
      end

      msg.read.should == "I am processed\n"
    end

    it "should process messages read-only per default" do
      msg = subject.msgs.first
      msg.process do |fh|
        expect { fh.syswrite(" ") }.to raise_error(IOError)
      end
    end

    it "should move messages to tmp for processing" do
      msg = subject.msgs(:cur).first

      msg.process do |fh|
        fh.path.should =~ Regexp.new(subject.path.tmp)
        msg.path.should =~ Regexp.new(subject.path.tmp)
      end

      msg.path.should =~ Regexp.new(subject.path.cur)
    end

    it "should lock messages when processing" do
      msg = subject.msgs(:cur).first
      msg.should_not be_locked
      msg.process do |fh|
        msg.should be_locked
        msg.lock_file.should =~ Regexp.new(subject.path.tmp)
      end

      msg.should_not be_locked
    end
  end

  describe "removing" do
    before :each do
      3.times do |i|
        msg = subject.new do |fh|
          fh.puts "I am new"
        end

        msg.cur! if i == 1
      end
    end

    it "should remove a message" do
      msg = subject.msgs.last

      subject.rm(msg).should be_true
      File.exists?(msg.path).should be_false
    end

    it "should not remove a message when locked" do
      msg = subject.msgs.last
      msg.lock

      msg.rm.should_not be_true
      File.exists?(msg.path).should_not be_false
    end
  end

  describe "errors" do
    it "should create an .err file on error in block" do
      msg = subject.new do |fh|
        fh.puts "I am new"
        fh.error = "I have errors"
      end
      File.exists?(msg.path).should be_true
      File.exists?(msg.path + ".err").should be_true
    end

    it "should create an .err file on error" do
      msg = subject.new do |fh|
        fh.puts "I am new"
      end
      msg.error = "I have errors"

      File.exists?(msg.path).should be_true
      File.exists?(msg.path + ".err").should be_true
    end

    it "should return the contents of the .err file" do
      msg = subject.new do |fh|
        fh.error = "No waaaaaay"
      end

      msg.error.should == "No waaaaaay\n"
    end

    it ".err files should be skipped in listings" do
      msg = subject.new do |fh|
        fh.error = "error"
      end

     subject.msgs.should_not be_empty
   end
  end
end
