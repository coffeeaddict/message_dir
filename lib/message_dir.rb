require "message_dir/version"
require "message_dir/message"
require 'simple_uuid'
require 'fileutils'

class MessageDir
  SPOTS = %w(tmp new cur)

  attr_reader :path

  def initialize(path)
    @path = MessageDir::Path.new(path)

    create_tree
  end

  def create_tree
    SPOTS.each do |spot|
      FileUtils.mkdir_p @path.send(spot)
    end
  end

  def new(&block)
    uuid = SimpleUUID::UUID.new
    msg  = Message.new(self, path.new, uuid)

    if block_given?
      begin
        msg.move(path.tmp)

        msg.open(File::TRUNC|File::WRONLY) do |fh|
          yield fh
        end

        msg.move(path.new)
      rescue Exception => ex
        # silently ignore errors
      ensure
        # make sure the message is written
        msg.close
      end
    end

    msg.open(File::RDONLY)
    msg.seek(0,0)

    return msg
  end

  def cur(msg)
    return if msg.spot == :cur
    msg.move(path.cur)
  end

  def messages(where=nil)
    spots = where.nil? ? SPOTS : [ where ]

    # find all the wanted paths
    paths = spots.collect do |spot|
      Dir[File.join(path.send(spot), '*')].select do |path|
        path !~ /\.(lock|err)$/ && File.file?(path)
      end
    end.flatten

    # load all the wanted messages
    paths.collect do |path|
      Message.load(self, path)
    end
  end
  alias_method :msgs, :messages

  def message(uuid)
    uuid = uuid.to_guid if uuid.is_a? SimpleUUID::UUID
    messages.select { |msg| msg.guid == uuid }.first
  end

  def process(msg, mode=File::RDONLY, &block)
    raise "No block given" if !block_given?

    # move to tmp and open with block for the given mode
    before = msg.spot
    msg.move(path.tmp) unless before == :tmp
    msg.lock do
      msg.open(mode, &block)
    end

    # move back re-open with default mode
    msg.move(path.send(before)) unless before == :tmp
    msg.open
  end

  def rm(msg)
    return false if msg.locked?
    File.unlink(msg.path) == 1 ? true : false
  end

  class Path
    def initialize(root)
      @root = root
    end

    def method_missing(method, *args, &block)
      super
    rescue NoMethodError => e
      if [ :new, :cur, :tmp ].include?(method)
        return File.join(@root, method.to_s)
      end
    end
  end
end
