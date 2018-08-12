# encoding: utf-8

require 'digest/sha1'
require_relative 'rdup/version'

module RDup
  Defaults = {
    :show_mtime  => false,
    :deletion    => false,
    :dry_run     => false,
    :min_size    => 0,
    :header_size => 2 ** 14,
  }

  class FileStat
    attr_reader :size, :mtime
    attr_accessor :header_hash, :full_hash

    def initialize(size, mtime)
      @size = size
      @mtime = mtime
      @header_hash = nil
      @full_hash = nil
    end
  end

  class Scanner
    attr_accessor :opts, :files, :dirs
    attr_reader :stats, :header_hashes, :full_hashes
    attr_reader :size_map, :header_hash_map, :full_hash_map

    def initialize(opts)
      @opts = Defaults.dup
      @files = []
      @dirs = []
      @stats = {}
      @header_hashes = {}
      @full_hashes = {}
      @size_map = {}
      @header_hash_map = {}
      @full_hash_map = {}

      @opts.update(opts)

      opts[:arguments].each do |path|
        if File.file?(path)
          @files << path
        elsif File.directory?(path)
          @dirs << path
        else
          STDERR.puts "Warning: skip `#{dir}' because it's neither a file nor a directory"
        end
      end
    end

    def run
      find_all_files
      fcount = @stats.size
      puts "Found #{fcount} files to be compared for duplication."
      if fcount == 0
        return
      end

      build_size_map
      reduce_groups(@size_map)
      gcount = @size_map.size
      fcount = count_files(@size_map)
      puts "Found #{gcount} sets of files with identical sizes. (#{fcount} files in total)"
      if fcount == 0
        return
      end

      build_header_hash_map
      reduce_groups(@header_hash_map)
      gcount = @header_hash_map.size
      fcount = count_files(@header_hash_map)
      puts "Found #{gcount} sets of files with identical header hashes. (#{fcount} files in total)"
      if fcount == 0
        return
      end

      build_full_hash_map
      reduce_groups(@full_hash_map)
      gcount = @full_hash_map.size
      fcount = count_files(@full_hash_map)
      puts "Found #{gcount} sets of files with identical hashes. (#{fcount} files in total)"
      if fcount == 0
        return
      end

      @full_hash_map.each_with_index do |pair, i|
        full_hash, group = pair
        size = @stats[group[0]].size
        puts "\n[#{i + 1}/#{gcount}] SHA1: #{full_hash}, Size: #{csf(size)} bytes"
        group.each_with_index do |path, j|
          stat = @stats[path]
          if @opts[:show_mtime]
            puts "  #{j + 1}) #{stat.mtime}  #{path}"
          else
            puts "  #{j + 1}) #{path}"
          end
        end

        if @opts[:deletion]
          survivals = which_to_preserve(group)
          group.each_with_index do |path, index|
            if survivals.include?(index + 1)
              puts "  [+] #{path}"
            else
              puts "  [-] #{path}"
              remove_file(path) unless @opts[:dry_run]
            end
          end
        end
      end
    end

    private

    def find_all_files
      @files.each do |path|
        stat = File.stat(path)
        if stat.size >= @opts[:min_size]
          @stats[path] = FileStat.new(stat.size, stat.mtime)
        else
          @files.delete(path)
        end
      end

      pwd = Dir.pwd
      @dirs.each do |dir|
        begin
          Dir.chdir(dir)
          Dir['**/*'].each do |path|
            stat = File.stat(path)
            if stat.file? and stat.size >= @opts[:min_size]
              path = File.join(dir, path)
              @files << path
              @stats[path] = FileStat.new(stat.size, stat.mtime)
            end
          end
        rescue => e
          STDERR.puts "Error: #{e}"
        ensure
          Dir.chdir(pwd)
        end
      end
    end

    # Group the files by size
    # @size_map: file_size => [file1, file2, ...]
    def build_size_map
      @stats.each do |path, stat|
        size = stat.size
        if @size_map.has_key?(size)
          @size_map[size] << path
        else
          @size_map[size] = [path]
        end
      end
    end

    # @header_hash_map: header_hash => [file1, file2, ...]
    def build_header_hash_map
      header_size = @opts[:header_size]
      @size_map.each do |size, paths|
        paths.each do |path|
          header = File.open(path, 'rb'){|f| f.read(header_size)}
          header = '' if header.nil?  # empty file

          header_hash = Digest::SHA1.new.hexdigest(header)
          @stats[path].header_hash = header_hash
          @stats[path].full_hash = header_hash if size <= header_size

          if @header_hash_map.has_key?(header_hash)
            @header_hash_map[header_hash] << path
          else
            @header_hash_map[header_hash] = [path]
          end
        end
      end
    end

    # @header_hash_map: full_hash => [file1, file2, ...]
    def build_full_hash_map
      @header_hash_map.each_value do |paths|
        paths.each do |path|
          stat = @stats[path]
          if stat.size <= @opts[:header_size]
            full_hash = stat.full_hash
          else
            full_hash = Digest::SHA1.new.file(path).hexdigest
            @stats[path].full_hash = full_hash
          end

          if @full_hash_map.has_key?(full_hash)
            @full_hash_map[full_hash] << path
          else
            @full_hash_map[full_hash] = [path]
          end
        end
      end
    end

    def reduce_groups(map)
      map.delete_if {|key, paths| paths.size == 1}
    end

    def count_files(map)
      map.values.flatten.size
    end

    # Comma-separated format
    def csf(number)
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    # Ask the user which files to preserve.
    # Return an array of numbers
    def which_to_preserve(group)
      while true
        all = 1.upto(group.size).to_a
        print "Which to preserve (#{all.join(',')} or all): "
        input = STDIN.readline.strip
        if input.empty?
          # continue
        elsif ['a', 'all'].include?(input.downcase)
          return all
        elsif input =~ /^[\d\s,]+$/
          nums = input.split(/[,\s]+/).delete_if(&:empty?).map(&:to_i)
          if nums.empty?
            STDERR.puts 'Illegal answer. Please input some numbers.'
          elsif nums.min < 1 || nums.max > group.size
            STDERR.puts "Illegal number. Allowed range: [1, #{group.size}]"
          else # good answer
            return nums
          end
        else
          STDERR.puts 'Illegal answer. Only numbers/commas/spaces allowed.'
        end
      end
    end

    def remove_file(path)
      begin
        File.unlink(path)
      rescue => e
        STDERR.puts "Error: #{e}"
      end
    end
  end
end
