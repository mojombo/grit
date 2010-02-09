#
# converted from the gitrb project
#
# authors:
#    Matthias Lederhofer <matled@gmx.net>
#    Simon 'corecode' Schubert <corecode@fs.ei.tum.de>
#    Scott Chacon <schacon@gmail.com>
#
# provides native ruby access to git objects and pack files
#

require 'zlib'
require 'digest/sha1'
require 'grit/git-ruby/internal/raw_object'

module Grit
  module GitRuby
    module Internal
      class LooseObjectError < StandardError
      end

      class LooseStorage
        def initialize(directory)
          @directory = directory
        end

        def [](sha1)
          sha1 = sha1.unpack("H*")[0]
          begin
            return nil unless sha1[0...2] && sha1[2..39]
            path = @directory + '/' + sha1[0...2] + '/' + sha1[2..39]
            get_raw_object(File.read(path))
          rescue Errno::ENOENT
            nil
          end
        end

        def get_raw_object(buf)
          if buf.length < 2
            raise LooseObjectError, "object file too small"
          end

          if legacy_loose_object?(buf)
            content = Zlib::Inflate.inflate(buf)
            header, content = content.split(/\0/, 2)
            if !header || !content
              raise LooseObjectError, "invalid object header"
            end
            type, size = header.split(/ /, 2)
            if !%w(blob tree commit tag).include?(type) || size !~ /^\d+$/
              raise LooseObjectError, "invalid object header"
            end
            type = type.to_sym
            size = size.to_i
          else
            type, size, used = unpack_object_header_gently(buf)
            content = Zlib::Inflate.inflate(buf[used..-1])
          end
          raise LooseObjectError, "size mismatch" if content.length != size
          return RawObject.new(type, content)
        end

        # currently, I'm using the legacy format because it's easier to do
        # this function takes content and a type and writes out the loose object and returns a sha
        def put_raw_object(content, type)
          size = content.length.to_s
          LooseStorage.verify_header(type, size)

          header = "#{type} #{size}\0"
          store = header + content

          sha1 = Digest::SHA1.hexdigest(store)
          path = @directory+'/'+sha1[0...2]+'/'+sha1[2..40]

          if !File.exists?(path)
            content = Zlib::Deflate.deflate(store)

            FileUtils.mkdir_p(@directory+'/'+sha1[0...2])
            File.open(path, 'wb') do |f|
              f.write content
            end
          end
          return sha1
        end

        # simply figure out the sha
        def self.calculate_sha(content, type)
          size = content.length.to_s
          verify_header(type, size)
          header = "#{type} #{size}\0"
          store = header + content

          Digest::SHA1.hexdigest(store)
        end

        def self.verify_header(type, size)
          if !%w(blob tree commit tag).include?(type) || size !~ /^\d+$/
            raise LooseObjectError, "invalid object header"
          end
        end

        # private
        def unpack_object_header_gently(buf)
          used = 0
          c = buf.getord(used)
          used += 1

          type = (c >> 4) & 7;
          size = c & 15;
          shift = 4;
          while c & 0x80 != 0
            if buf.length <= used
              raise LooseObjectError, "object file too short"
            end
            c = buf.getord(used)
            used += 1

            size += (c & 0x7f) << shift
            shift += 7
          end
          type = OBJ_TYPES[type]
          if ![:blob, :tree, :commit, :tag].include?(type)
            raise LooseObjectError, "invalid loose object type"
          end
          return [type, size, used]
        end
        private :unpack_object_header_gently

        def legacy_loose_object?(buf)
          word = (buf.getord(0) << 8) + buf.getord(1)
          buf.getord(0) == 0x78 && word % 31 == 0
        end
        private :legacy_loose_object?
      end
    end
  end
end
