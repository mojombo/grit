#
# converted from the gitrb project
#
# authors:
#    Matthias Lederhofer <matled@gmx.net>
#    Simon 'corecode' Schubert <corecode@fs.ei.tum.de>
#
# provides native ruby access to git objects and pack files
#

require 'digest/sha1'

module Grit
  module GitRuby
    module Internal
      OBJ_NONE = 0
      OBJ_COMMIT = 1
      OBJ_TREE = 2
      OBJ_BLOB = 3
      OBJ_TAG = 4

      OBJ_TYPES = [nil, :commit, :tree, :blob, :tag].freeze

      class RawObject
        attr_accessor :type, :content
        def initialize(type, content)
          @type = type
          @content = content
        end

        def sha1
          Digest::SHA1.digest("%s %d\0" % [@type, @content.length] + @content)
        end
      end
    end
  end
end
