class MessageDir
  class Message
    def initialize(master, path, uuid)
      @master = master
      @path   = path
      @uuid   = uuid
      @io     = nil

      self.create if !File.exists?(self.path)
      @locked = File.exists?(self.lock_file)
      open
    end

    def self.load(master, path)
      self.new(master, File.dirname(path), SimpleUUID::UUID.new(File.basename(path)))
    end

    def path
      File.join(@path, @uuid.to_guid)
    end

    def guid
      @uuid.to_guid
    end

    def spot
      File.basename(@path).to_sym
    end

    def create
      open(File::CREAT|File::WRONLY) do |f|
        # write 1 byte and truncate to force existance of the file
        f.syswrite("i")
        f.truncate(0)
      end
    end

    def process(mode=File::RDONLY, &block)
      @master.process(self, mode, &block)
    end

    def open(mode=File::RDONLY, &block)
      close

      # make sure them files are synced
      mode |= File::SYNC unless mode & File::SYNC == File::SYNC

      @io = File.open(self.path, mode, &block)
    end

    def fh
      @io
    end

    def move(path)
      raise "Can't move a locked file" if locked?

      close
      FileUtils.mv(self.path, File.join(path, self.guid))
      @path = path
      open
    end

    def rm
      @master.rm(self)
    end

    def close
      @io.close unless closed?
    rescue
      true
    end

    def closed?
      @io.closed?
    rescue
      return true
    end

    def cur!
      @master.cur(self)
    end

    def ==(other)
      other.path == self.path && self.guid == other.guid
    end

    def locked?
      @locked == true ? true : false || File.exists?(lock_file)
    end

    def lock_file
      "#{path}.lock"
    end

    def lock
      return if locked?

      File.open(lock_file, File::CREAT|File::WRONLY) do |lf|
        res = lf.flock(File::LOCK_EX|File::LOCK_NB)
        raise "Could not obtain a lock on the lock file" if res == false
        lf.flock(File::LOCK_UN)
      end

      if block_given?
        yield
        unlock
      else
        @locked = true
      end
    end
    alias_method :lock!, :lock

    def unlock
      File.open(lock_file, File::CREAT|File::WRONLY) do |lf|
        res = lf.flock(File::LOCK_EX|File::LOCK_NB)
        raise "Could not obtain a lock on the lock file" if res == false
        lf.flock(File::LOCK_UN)
        File.unlink(lock_file)
      end
      @locked = false
    end

    def method_missing(method, *args, &block)
      super
    rescue NameError, NoMethodError => e
      @io.send(method, *args, &block)
    end

  end
end