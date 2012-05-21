require File.dirname(__FILE__) + '/helper'

class TestCommitParse < Test::Unit::TestCase
  def setup
@output = %Q{
commit 36a1987cd891fa82d9981886c3abbbe82c428c0d
tree 26f2c1ebc2d0485de222f13ebf812456ee8a7cb8
parent 31ae98359d26ff89b745c4f8094093cbf6ccbdc6
parent 0d9f4f135eb6dea06bdcb7065b1e4ff78274a5e9
author Linus Torvalds <torvalds@linux-foundation.org> 1337273075 -0700
committer Linus Torvalds <torvalds@linux-foundation.org> 1337273075 -0700
mergetag object 0d9f4f135eb6dea06bdcb7065b1e4ff78274a5e9
 type commit
 tag md-3.4-fixes
 tagger NeilBrown <neilb@suse.de> 1337229653 +1000
 
 md: 2 fixes for 3.4
 tagger NeilBrown <neilb@suse.de> 1337229653 +1000
 
 md: 2 fixes for 3.4
 
 one fixes a bug in the new raid10 resize code so is relevant
 to 3.4 only
 Other fixes a bug in the use of md by dm-raid, so is relevant
 to any kernel with dm-raid support
 -----BEGIN PGP SIGNATURE-----
 Version: GnuPG v2.0.18 (GNU/Linux)
 
 iQIVAwUAT7SBkznsnt1WYoG5AQK3wQ//Q2sPicPHb5MNGTTBpphYo1QWo+l9jFHs
 ZDBM+MaiNJg3kBN5ueUU+MENvLcaA5+zoxsGVBXBKyXr70ffqiQcLXyU7fHwrGu3
 5MD36p55ZPnq2pemCrp4qdTXEUabmDb+0/R7e5lywnzNdbmCAfh4uYih0VPiaClV
 ihq/Ci12TDnezmLjksc09OCquhm0s3zH2BnMCVdmSAkhnXCxTeZ45s/ob71Y2xvj
 cJ15SYlAG4t0QCikL5R8pZtkh0h2SuUhufDE09eD8yT4RGO4PHSQ4oHujajftzey
 9sB0NGH7Yla8gOXjA+EpzKPaiqtZxJB+1v/bhqA2FoOYAks8VoFfeqgwUbPYE7bk
 GIfGB4hFsUXaJo13uzofyJXBIp9mM/J5Sk1VJsiLE85P7wewg6N199B8lpC3lFDw
 tMLjfTMJzFOUqZBESjJoxyrc4fairZ9VCUWwpqjuioLO50e+lOi/jQHTspX78e+w
 GxgjHp8hh0RqQiTkl7vIz9KVcQIeOTG9uzz61IuDp15cRSrMs6E8gVKoX8gKW9g2
 Hec17fdG/H6ZeZa7MB9GzUD4HCj0PRbODQ3/fPhUdsbgtQjOvsVUH8LCRRU0U6cb
 YF+qsDFtUF7QT2kNbrs9R6adGj97c2HWUMyRWMQAXGuL5TkstvhrRv/rk1+bv2VG
 w7ptbiklj7o=
 =9zxe
 -----END PGP SIGNATURE-----

    Merge tag 'md-3.4-fixes' of git://neil.brown.name/md
    
    Pull two md fixes from NeilBrown:
     "One fixes a bug in the new raid10 resize code so is relevant to 3.4
      only.
    
      The other fixes a bug in the use of md by dm-raid, so is relevant to
      any kernel with dm-raid support"
    
    * tag 'md-3.4-fixes' of git://neil.brown.name/md:
      MD: Add del_timer_sync to mddev_suspend (fix nasty panic)
      md/raid10: set dev_sectors properly when resizing devices in array.

commit 31ae98359d26ff89b745c4f8094093cbf6ccbdc6
tree 26f2c1ebc2d0485de222f13ebf812456ee8a7cb8
parent 31ae98359d26ff89b745c4f8094093cbf6ccbdc6
parent 0d9f4f135eb6dea06bdcb7065b1e4ff78274a5e9
author Linus Torvalds <torvalds@linux-foundation.org> 1337273075 -0700
committer Linus Torvalds <torvalds@linux-foundation.org> 1337273075 -0700

    Simple Commit
}
  end

  def test_list_from_string
    commits = Grit::Commit.list_from_string(nil, @output)

    assert_equal 2, commits.size
    assert_equal "36a1987cd891fa82d9981886c3abbbe82c428c0d", commits.first.id
    assert_equal "31ae98359d26ff89b745c4f8094093cbf6ccbdc6", commits.last.id
    assert_equal "Merge tag 'md-3.4-fixes' of git", commits.first.message[0..30]
  end
end

