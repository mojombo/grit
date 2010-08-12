module Grit

  class Status
    include Enumerable

    attr_reader :files

    @base = nil
    @files = nil

    def initialize(base)
      @base = base
      construct_status
    end

    def changed
      @files.select { |k, f| f.type == 'M' }
    end

    def added
      @files.select { |k, f| f.type == 'A' }
    end

    def deleted
      @files.select { |k, f| f.type == 'D' }
    end

    def untracked
      @files.select { |k, f| f.untracked }
    end

    def pretty
      out = ''
      self.each do |file|
        out << file.path
        out << "\n\tsha(r) " + file.sha_repo.to_s + ' ' + file.mode_repo.to_s
        out << "\n\tsha(i) " + file.sha_index.to_s + ' ' + file.mode_index.to_s
        out << "\n\ttype   " + file.type.to_s
        out << "\n\tstage  " + file.stage.to_s
        out << "\n\tuntrac " + file.untracked.to_s
        out << "\n"
      end
      out << "\n"
      out
    end

    # enumerable method

    def [](file)
      @files[file]
    end

    def each
      @files.each do |k, file|
        yield file
      end
    end

    class StatusFile
      attr_accessor :path, :type, :stage, :untracked
      attr_accessor :mode_index, :mode_repo
      attr_accessor :sha_index, :sha_repo

      @base = nil

      def initialize(base, hash)
        @base = base
        @path = hash[:path]
        @type = hash[:type]
        @stage = hash[:stage]
        @mode_index = hash[:mode_index]
        @mode_repo = hash[:mode_repo]
        @sha_index = hash[:sha_index]
        @sha_repo = hash[:sha_repo]
        @untracked = hash[:untracked]
      end

      def blob(type = :index)
        if type == :repo
          @base.object(@sha_repo)
        else
          @base.object(@sha_index) rescue @base.object(@sha_repo)
        end
      end

    end

    private

      def construct_status
        @files = ls_files

        Dir.chdir(@base.working_dir) do
          # find untracked in working dir
          Dir.glob('**/*') do |file|
            if !@files[file]
              @files[file] = {:path => file, :untracked => true} if !File.directory?(file)
            end
          end

          # find modified in tree
         diff_files.each do |path, data|
            @files[path] ? @files[path].merge!(data) : @files[path] = data
          end

          # find added but not committed - new files
          diff_index('HEAD').each do |path, data|
            @files[path] ? @files[path].merge!(data) : @files[path] = data
          end

          @files.each do |k, file_hash|
            @files[k] = StatusFile.new(@base, file_hash)
          end
        end
      end

      # compares the index and the working directory
      def diff_files
        hsh = {}
        @base.git.diff_files.split("\n").each do |line|
          (info, file) = line.split("\t")
          (mode_src, mode_dest, sha_src, sha_dest, type) = info.split
          hsh[file] = {:path => file, :mode_file => mode_src.to_s[1, 7], :mode_index => mode_dest,
                        :sha_file => sha_src, :sha_index => sha_dest, :type => type}
        end
        hsh
      end

      # compares the index and the repository
      def diff_index(treeish)
        hsh = {}
        @base.git.diff_index({}, treeish).split("\n").each do |line|
          (info, file) = line.split("\t")
          (mode_src, mode_dest, sha_src, sha_dest, type) = info.split
          hsh[file] = {:path => file, :mode_repo => mode_src.to_s[1, 7], :mode_index => mode_dest,
                        :sha_repo => sha_src, :sha_index => sha_dest, :type => type}
        end
        hsh
      end

      def ls_files
        hsh = {}
        lines = @base.git.ls_files({:stage => true})
        lines.split("\n").each do |line|
          (info, file) = line.split("\t")
          (mode, sha, stage) = info.split
          hsh[file] = {:path => file, :mode_index => mode, :sha_index => sha, :stage => stage}
        end
        hsh
      end
  end

end