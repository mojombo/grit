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

begin
  require 'mmap'
rescue LoadError

module Grit 
  module GitRuby 
    module Internal
      class Mmap
        def initialize(file)
          @file = file
          @offset = nil
        end

        def unmap
          @file = nil
        end

        def [](*idx)
          idx = idx[0] if idx.length == 1
          case idx
          when Range
            offset = idx.first
            len = idx.last - idx.first + idx.exclude_end? ? 0 : 1
          when Fixnum
            offset = idx
            len = nil
          when Array
            offset, len = idx
          else
            raise RuntimeError, "invalid index param: #{idx.class}"
          end
          if @offset != offset
            @file.seek(offset)
          end
          @offset = offset + len ? len : 1
          if not len
            @file.read(1)[0]
          else
            @file.read(len)
          end
        end
      end
    end
  end 
end

end     # rescue LoadError

