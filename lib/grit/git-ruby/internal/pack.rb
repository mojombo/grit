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
require 'grit/git-ruby/internal/raw_object'
require 'grit/git-ruby/internal/mmap'

module Grit 
  module GitRuby 
    module Internal
      class PackFormatError < StandardError
      end

      class PackStorage
        OBJ_OFS_DELTA = 6
        OBJ_REF_DELTA = 7

        FanOutCount = 256
        SHA1Size = 20
        IdxOffsetSize = 4
        OffsetSize = 4
        OffsetStart = FanOutCount * IdxOffsetSize
        SHA1Start = OffsetStart + OffsetSize
        EntrySize = OffsetSize + SHA1Size

        def initialize(file)
          if file =~ /\.idx$/
            file = file[0...-3] + 'pack'
          end

          @name = file
          
          with_idx do |idx|
            @offsets = [0]
            FanOutCount.times do |i|
              pos = idx[i * IdxOffsetSize,IdxOffsetSize].unpack('N')[0]
              if pos < @offsets[i]
                raise PackFormatError, "pack #@name has discontinuous index #{i}"
              end
              @offsets << pos
            end

            @size = @offsets[-1]
          end
        end
        
        def with_idx(index_file = nil)
          if !index_file
            index_file = @name
            idxfile = File.open(@name[0...-4]+'idx')
          else
            idxfile = File.open(index_file)
          end
          idx = Mmap.new(idxfile)
          yield idx
          idx.unmap
          idxfile.close
        end
        
        def with_packfile
          packfile = File.open(@name)
          yield packfile
          packfile.close
        end
        
        # given an index file, list out the shas that it's packfile contains
        def self.get_shas(index_file)
          with_idx(index_file) do |idx|
            @offsets = [0]
            FanOutCount.times do |i|
              pos = idx[i * IdxOffsetSize,IdxOffsetSize].unpack('N')[0]
              if pos < @offsets[i]
                raise PackFormatError, "pack #@name has discontinuous index #{i}"
              end
              @offsets << pos
            end
        
            @size = @offsets[-1]
            shas = []
          
            pos = SHA1Start
            @size.times do
              sha1 = idx[pos,SHA1Size]
              pos += EntrySize
              shas << sha1.unpack("H*").first
            end
            shas
          end
        end

        def name
          @name
        end
        
        def close
          # shouldnt be anything open now
        end

        def [](sha1)
          offset = find_object(sha1)
          return nil if !offset
          return parse_object(offset)
        end

        def each_entry
          with_idx do |idx|
            pos = OffsetStart
            @size.times do
              offset = idx[pos,OffsetSize].unpack('N')[0]
              sha1 = idx[pos+OffsetSize,SHA1Size]
              pos += EntrySize
              yield sha1, offset
            end
          end
        end

        def each_sha1
          with_idx do |idx|
            # unpacking the offset is quite expensive, so
            # we avoid using #each
            pos = SHA1Start
            @size.times do
              sha1 = idx[pos,SHA1Size]
              pos += EntrySize
              yield sha1
            end
          end
        end

        def find_object(sha1)
          obj = nil
          with_idx do |idx|
            obj = find_object_in_index(idx, sha1)
          end
          obj
        end    
        private :find_object

        def find_object_in_index(idx, sha1)
          slot = sha1[0]
          return nil if !slot
          first, last = @offsets[slot,2] 
          while first < last
            mid = (first + last) / 2
            midsha1 = idx[SHA1Start + mid * EntrySize,SHA1Size]
            cmp = midsha1 <=> sha1

            if cmp < 0
              first = mid + 1
            elsif cmp > 0
              last = mid
            else
              pos = OffsetStart + mid * EntrySize
              offset = idx[pos,OffsetSize].unpack('N')[0]
              return offset
            end
          end
          nil
        end

        def parse_object(offset)
          obj = nil
          with_packfile do |packfile|
            data, type = unpack_object(packfile, offset)
            obj = RawObject.new(OBJ_TYPES[type], data)
          end
          obj
        end
        protected :parse_object

        def unpack_object(packfile, offset)
          obj_offset = offset
          packfile.seek(offset)

          c = packfile.read(1)[0]
          size = c & 0xf
          type = (c >> 4) & 7
          shift = 4
          offset += 1
          while c & 0x80 != 0
            c = packfile.read(1)[0]
            size |= ((c & 0x7f) << shift)
            shift += 7
            offset += 1
          end
        
          case type
          when OBJ_OFS_DELTA, OBJ_REF_DELTA
            data, type = unpack_deltified(type, offset, obj_offset, size)
          when OBJ_COMMIT, OBJ_TREE, OBJ_BLOB, OBJ_TAG
            data = unpack_compressed(offset, size)
          else
            raise PackFormatError, "invalid type #{type}"
          end
          [data, type]
        end
        private :unpack_object

        def unpack_deltified(type, offset, obj_offset, size)
          base = nil
          type = nil
          delta = nil
          with_packfile do |packfile|
            packfile.seek(offset)
            data = packfile.read(SHA1Size)

            if type == OBJ_OFS_DELTA
              i = 0
              c = data[i]
              base_offset = c & 0x7f
              while c & 0x80 != 0
                c = data[i += 1]
                base_offset += 1
                base_offset <<= 7
                base_offset |= c & 0x7f
              end
              base_offset = obj_offset - base_offset
              offset += i + 1
            else
              base_offset = find_object(data)
              offset += SHA1Size
            end

            base, type = unpack_object(packfile, base_offset)
            delta = unpack_compressed(offset, size)
          end
          [patch_delta(base, delta), type]
        end
        private :unpack_deltified

        def unpack_compressed(offset, destsize)
          outdata = ""
          with_packfile do |packfile|
            packfile.seek(offset)
            zstr = Zlib::Inflate.new
            while outdata.size < destsize
              indata = packfile.read(4096)
              if indata.size == 0
                raise PackFormatError, 'error reading pack data'
              end
              outdata += zstr.inflate(indata)
            end
            if outdata.size > destsize
              raise PackFormatError, 'error reading pack data'
            end
            zstr.close
          end
          outdata
        end
        private :unpack_compressed

        def patch_delta(base, delta)
          src_size, pos = patch_delta_header_size(delta, 0)
          if src_size != base.size
            raise PackFormatError, 'invalid delta data'
          end

          dest_size, pos = patch_delta_header_size(delta, pos)
          dest = ""
          while pos < delta.size
            c = delta[pos]
            pos += 1
            if c & 0x80 != 0
              pos -= 1
              cp_off = cp_size = 0
              cp_off = delta[pos += 1] if c & 0x01 != 0
              cp_off |= delta[pos += 1] << 8 if c & 0x02 != 0
              cp_off |= delta[pos += 1] << 16 if c & 0x04 != 0
              cp_off |= delta[pos += 1] << 24 if c & 0x08 != 0
              cp_size = delta[pos += 1] if c & 0x10 != 0
              cp_size |= delta[pos += 1] << 8 if c & 0x20 != 0
              cp_size |= delta[pos += 1] << 16 if c & 0x40 != 0
              cp_size = 0x10000 if cp_size == 0
              pos += 1
              dest += base[cp_off,cp_size]
            elsif c != 0
              dest += delta[pos,c]
              pos += c
            else
              raise PackFormatError, 'invalid delta data'
            end
          end
          dest
        end
        private :patch_delta

        def patch_delta_header_size(delta, pos)
          size = 0
          shift = 0
          begin
            c = delta[pos]
            if c == nil
              raise PackFormatError, 'invalid delta header'
            end
            pos += 1
            size |= (c & 0x7f) << shift
            shift += 7
          end while c & 0x80 != 0
          [size, pos]
        end
        private :patch_delta_header_size
      end
    end
  end 
end
