# this implements a file-based 'file index', an simple index of
# all of the reachable commits in a repo, along with the parents
# and which files were modified during each commit
#
# this class looks for a file named '[.git]/file-index', generated via:
#
# git log --pretty=oneline --name-only --parents --reverse --all > file-index
#
# for this to work properly, you'll want to add the following as a post-receive hook
# to keep the index up to date
#
# git log --pretty=oneline --name-only --parents --reverse [old-rev]..[new-rev] >> file-index
#
module Grit
  module GitRuby

  class FileIndex

    class IndexFileNotFound < StandardError
    end

    class UnsupportedRef < StandardError
    end

    class << self
      attr_accessor :max_file_size
    end

    self.max_file_size = 10_000_000 # ~10M

    attr_reader :files

    # initializes index given repo_path
    def initialize(repo_path)
      @index_file = File.join(repo_path, 'file-index')
      if File.file?(@index_file) && (File.size(@index_file) < Grit::GitRuby::FileIndex.max_file_size)
        read_index
      else
        raise IndexFileNotFound
      end
    end

    # returns count of all commits
    def count_all
      @sha_count
    end

    # returns count of all commits reachable from SHA
    # note: originally did this recursively, but ruby gets pissed about that on
    # really big repos where the stack level gets 'too deep' (thats what she said)
    def count(commit_sha)
      commits_from(commit_sha).size
    end

    # builds a list of all commits reachable from a single commit
    def commits_from(commit_sha)
      raise UnsupportedRef if commit_sha.is_a? Array

      already = {}
      final = []
      left_to_do = [commit_sha]

      while commit_sha = left_to_do.shift
        next if already[commit_sha]

        final << commit_sha
        already[commit_sha] = true

        commit = @commit_index[commit_sha]
        commit[:parents].each do |sha|
          left_to_do << sha
        end if commit
      end

      sort_commits(final)
    end

    def sort_commits(sha_array)
      sha_array.sort { |a, b| @commit_order[b].to_i <=> @commit_order[a].to_i }
    end

    # returns files changed at commit sha
    def files(commit_sha)
      @commit_index[commit_sha][:files] rescue nil
    end

    # returns all commits for a file
    def commits_for(file)
      @all_files[file]
    end

    # returns the shas of the last commits for all
    # the files in [] from commit_sha
    # files_matcher can be a regexp or an array
    def last_commits(commit_sha, files_matcher)
      acceptable = commits_from(commit_sha)

      matches = {}

      if files_matcher.is_a? Regexp
        files = @all_files.keys.select { |file| file =~ files_matcher }
        files_matcher = files
      end

      if files_matcher.is_a? Array
        # find the last commit for each file in the array
        files_matcher.each do |f|
          @all_files[f].each do |try|
            if acceptable.include?(try)
              matches[f] = try
              break
            end
          end if @all_files[f]
        end
      end

      matches
    end

    private

      # read and parse the file-index data
      def read_index
        f = File.new(@index_file)
        @sha_count = 0
        @commit_index = {}
        @commit_order = {}
        @all_files = {}
        while line = f.gets
          if /^(\w{40})/.match(line)
            shas = line.scan(/(\w{40})/)
            current_sha = shas.shift.first
            parents = shas.map { |sha| sha.first }
            @commit_index[current_sha] = {:files => [], :parents => parents }
            @commit_order[current_sha] = @sha_count
            @sha_count += 1
          else
            file_name = line.chomp
            tree = ''
            File.dirname(file_name).split('/').each do |part|
              next if part == '.'
              tree += part + '/'
              @all_files[tree] ||= []
              @all_files[tree].unshift(current_sha)
            end
            @all_files[file_name] ||= []
            @all_files[file_name].unshift(current_sha)
            @commit_index[current_sha][:files] << file_name
          end
        end
      end

  end

  end
end


# benchmark testing on big-ass repos

if __FILE__ == $0

  #repo = '/Users/schacon/projects/git/.git'
  #commit = 'd8933f013a66cc1deadf83a9c24eccb6fee78a35'
  #file_list = ["builtin-merge-recursive.c", "git-send-email-script", "git-parse-remote.sh", "builtin-add.c", "merge-base.c", "read-cache.c", "fsck.h", "diff.c", "refs.c", "diffcore-rename.c", "epoch.c", "pack-intersect.c", "fast-import.c", "git-applypatch.sh", "git.spec.in", "rpush.c", "git-clone-script", "utf8.c", "git-external-diff-script", "builtin-init-db.c", "pack-redundant.c", "builtin-diff-index.c", "index.c", "update-index.c", "fetch-clone.c", "pager.c", "diff.h", "unpack-trees.c", "git-browse-help.sh", "git-rename-script", "refs.h", "get-tar-commit-id.c", "git-push.sh", "README", "delta.c", "mailsplit.c", "gitweb.cgi", "var.c", "epoch.h", "gsimm.c", "archive.c", "sideband.c", "utf8.h", "local-fetch.c", "git-request-pull-script", "builtin-send-pack.c", "blob.c", "builtin-ls-remote.c", "pretty.c", "git-diff.sh", "diffcore-break.c", "unpack-trees.h", "git-mv.perl", "interpolate.c", "builtin-diff-files.c", "delta.h", "commit-tree.c", "git-diff-script", "decorate.c", "builtin-name-rev.c", "tree-walk.c", "git-revert-script", "git-sh-setup.sh", "transport.c", "gsimm.h", "archive.h", "count-delta.c", "sideband.h", "git-merge.sh", "git-gui.sh", "git-core.spec.in", "cvs2git.c", "blob.h", "git.sh", "http-push.c", "builtin-commit-tree.c", "diff-helper.c", "builtin-push.c", "interpolate.h", "decorate.h", "git-citool", "dotest", "builtin-verify-tag.c", "git-mergetool.sh", "tree-walk.h", "log-tree.c", "name-rev.c", "applypatch", "cat-file.c", "test-delta.c", "server-info.c", "count-delta.h", "write-tree.c", "local-pull.c", "transport.h", "git-rm.sh", "unpack-objects.c", "xdiff-interface.c", "git-repack-script", "commit.c", "hash-object.c", "git-merge-recursive.py", "git-clone-dumb-http", "thread-utils.c", "git-send-email.perl", "git-whatchanged.sh", "log-tree.h", "builtin-annotate.c", "show-index.c", "pkt-line.c", "ident.c", "git-rebase-script", "name-hash.c", "git-archimport.perl", "xdiff-interface.h", "commit.h", "diff-lib.c", "wt-status.c", "base85.c", "builtin-fetch--tool.c", "unpack-file.c", "builtin-diff-stages.c", "merge-index.c", "color.c", "diff-tree.c", "git-checkout.sh", "thread-utils.h", "grep.c", "pkt-line.h", "builtin-help.c", "test-parse-options.c", "show-files.c", "git.sh.in", "pack.h", "wt-status.h", "git-prune-script", "test-sha1.c", "git-octopus.sh", "dump-cache-tree.c", "git-web--browse.sh", "builtin-upload-tar.c", "builtin-clone.c", "copy.c", "color.h", "show-branch.c", "peek-remote.c", "git-merge-recursive-old.py", "cmd-rename.sh", "git-apply-patch-script", "git-export.c", "git-relink-script", "grep.h", "usage.c", "git-fetch-dumb-http", "fsck-objects.c", "update-cache.c", "diff-stages.c", "patch-ids.c", "builtin-rev-list.c", "builtin-bundle.c", "builtin-show-branch.c", "builtin-pack-refs.c", "tree.c", "git.c", "verify_pack.c", "update-ref.c", "builtin-peek-remote.c", "diffcore-pathspec.c", "git-merge-octopus.sh", "git-show-branches-script", "builtin-archive.c", "builtin-unpack-objects.c", "git-rerere.perl", "walker.c", "builtin-mailsplit.c", "convert.c", "builtin-branch.c", "export.c", "patch-ids.h", "check-builtins.sh", "git-pull-script", "tree.h", "alloc.c", "git-commit.sh", "git-lost-found.sh", "mailmap.c", "rsh.c", "exec_cmd.c", "git-compat-util.h", "ws.c", "rev-list.c", "git-verify-tag.sh", "git-ls-remote-script", "mktree.c", "walker.h", "builtin-blame.c", "builtin-fsck.c", "setup.c", "git-cvsimport-script", "git-add.sh", "symlinks.c", "checkout-index.c", "receive-pack.c", "git-merge-one-file-script", "mailmap.h", "git-cvsimport.perl", "builtin-count.c", "exec_cmd.h", "builtin-stripspace.c", "git-grep.sh", "hash.c", "builtin-prune-packed.c", "git-rebase--interactive.sh", "rsh.h", "match-trees.c", "git-format-patch.sh", "git-push-script", "parse-options.c", "git-status-script", "http-walker.c", "pack-write.c", "git-status.sh", "diff-delta.c", "hash.h", "generate-cmdlist.sh", "config-set.c", "builtin-fetch.c", "ll-merge.c", "t1300-config-set.sh", "ls-tree.c", "write_or_die.c", "builtin-check-ref-format.c", "fetch-pack.c", "git-commit-script", "builtin-describe.c", "parse-options.h", "builtin-checkout.c", "prune-packed.c", "fixup-builtins", "http-fetch.c", "test-absolute-path.c", "git-log.sh", "builtin-merge-ours.c", "git-whatchanged", "pull.c", "merge-tree.c", "ll-merge.h", "builtin.h", "Makefile", "cache-tree.c", "builtin-log.c", "merge-cache.c", "fetch-pack.h", "git-shortlog.perl", "git-bisect-script", "git-am.sh", "check-ref-format.c", "git-count-objects-script", "mkdelta.c", "builtin-diff.c", "merge-recursive.c", "builtin-config.c", "gitenv.c", "describe.c", "git-add--interactive.perl", "pull.h", "builtin-apply.c", "diff-index.c", "ssh-pull.c", "builtin-merge-file.c", "strbuf.c", "git-submodule.sh", "repo-config.c", "run-command.c", "git-applymbox.sh", "cache-tree.h", "builtin-clean.c", "cache.h", "git-prune.sh", "fsck-cache.c", "builtin-remote.c", "sha1_file.c", "shallow.c", "merge-recursive.h", "builtin-checkout-index.c", "git-clone.sh", "builtin-mv.c", "builtin-reflog.c", "lockfile.c", "git-octopus-script", ".mailmap", "strbuf.h", "git-p4import.py", "builtin-repo-config.c", "patch-delta.c", "builtin-merge-base.c", "run-command.h", "check-racy.c", "git-filter-branch.sh", "git-branch.sh", "git-merge-stupid.sh", "diff-files.c", "test-sha1.sh", "COPYING", "git-lost+found.sh", "git-tag.sh", "git-branch-script", "check-files.c", "builtin-reset.c", "builtin-ls-files.c", "builtin-fmt-merge-msg.c", "builtin-for-each-ref.c", "csum-file.c", "git-gc.sh", "git-parse-remote-script", "command-list.txt", "builtin-pack-objects.c", "dir.c", "test-date.c", "builtin-grep.c", "list-objects.c", "clone-pack.c", "git-gui", "convert-cache.c", "git-reset-script", "checkout-cache.c", "git-ls-remote.sh", "read-tree.c", "git-instaweb.sh", "progress.c", "rabinpoly.c", "ls-files.c", "mktag.c", "gitMergeCommon.py", "git-merge-ours.sh", "rpull.c", "git-annotate.perl", "csum-file.h", "builtin-shortlog.c", "builtin-commit.c", "http-pull.c", "git-fetch.sh", "apply.c", "git-add-script", "dir.h", "diff-tree-helper.c", "list-objects.h", "rev-tree.c", "builtin-tar-tree.c", "progress.h", "builtin-pickaxe.c", "git-merge-fredrik.py", "path.c", "builtin-diff-tree.c", "rabinpoly.h", "builtin-ls-tree.c", "tar.h", "trace.c", "graph.c", "ssh-fetch.c", "show-diff.c", "sha1-lookup.c", "builtin-revert.c", "builtin-symbolic-ref.c", "builtin-write-tree.c", "git-sh-setup-script", "rev-cache.c", "blame.c", "builtin-mailinfo.c", "git-cherry", "git-resolve-script", "INSTALL", "git-findtags.perl", "diffcore-delta.c", "entry.c", "git-applypatch", "connect.c", "tar-tree.c", "graph.h", "missing-revs.c", "builtin-fast-export.c", "sha1-lookup.h", "rev-parse.c", "configure.ac", "rev-cache.h", "build-rev-cache.c", "reachable.c", "index-pack.c", "git", "send-pack.c", "git-cherry.sh", "git-tag-script", "revision.c", "CREDITS-GEN", "bundle.c", "mailinfo.c", "symbolic-ref.c", "attr.c", "git-archimport-script", "archive-zip.c", "diff-cache.c", "fetch.c", "builtin-gc.c", "git-remote.perl", "path-list.c", "ssh-upload.c", "reachable.h", "diff-no-index.c", "diffcore.h", "send-pack.h", "tree-diff.c", "git-checkout-script", "pack-revindex.c", "show-rev-cache.c", "TODO", "revision.h", "bundle.h", "unresolve.c", "git-deltafy-script", "git-relink.perl", "archive-tar.c", "attr.h", "git-resolve.sh", "config.mak.in", "builtin-update-index.c", "convert-objects.c", "fetch.h", "builtin-runstatus.c", "quote.c", "init-db.c", "git-shortlog", "builtin-prune.c", "builtin-rerere.c", "verify-pack.c", "gitk", "patch-id.c", ".gitattributes", "date.c", "git-format-patch-script", "path-list.h", "pack-revindex.h", "GIT-VERSION-GEN", "combine-diff.c", "environment.c", "git-cvsserver.perl", "git-repack.sh", "diffcore-order.c", "reflog-walk.c", "config.c", "test-match-trees.c", "git-svnimport.perl", "quote.h", "write-blob.c", "diffcore-pickaxe.c", "builtin-update-ref.c", "stripspace.c", "help.c", "pack-objects.c", "branch.c", "git-verify-tag-script", "TEST", "daemon.c", "remote.c", "git-log-script", "git-pull.sh", "git-quiltimport.sh", "git-count-objects.sh", "reflog-walk.h", "git-applymbox", "builtin-show-ref.c", "RelNotes", "git-fmt-merge-msg.perl", "git-rebase.sh", "git-parse-remote", "git-browse--help.sh", "git-stash.sh", "alias.c", "branch.h", "gitweb.pl", "builtin-upload-archive.c", "builtin-cat-file.c", "sha1_name.c", "http.c", "test-chmtime.c", "remote.h", "ssh-push.c", "tag.c", "update-server-info.c", "git-cvsexportcommit.perl", "builtin-check-attr.c", "git-revert.sh", "builtin-verify-pack.c", "object.c", "git-merge-resolve.sh", "shortlog.h", "git-fetch-script", "test-genrandom.c", "shell.c", "builtin-rm.c", "builtin-zip-tree.c", "upload-pack.c", "git-rename.perl", ".gitignore", "tag.h", "http.h", "git-request-pull.sh", "object.h", "git-svn.perl", "builtin-fetch-pack.c", "git-bisect.sh", "pack-check.c", "builtin-rev-parse.c", "object-refs.c", "test-gsimm.c", "builtin-read-tree.c", "git-help--browse.sh", "merge-file.c", "fsck.c", "builtin-tag.c", "builtin-http-fetch.c", "builtin-count-objects.c", "git-reset.sh", "git-clean.sh", "git-merge-one-file.sh", "ctype.c", "git-mktag.c", "imap-send.c"]

  repo = '/Users/schacon/projects/grit/.git'
  commit = 'c87612bc84c95ba9df17674d911dde10f34fefaa'

  require 'benchmark'

  Benchmark.bm(20) do |x|
    x.report('index build') do
      i = Grit::GitRuby::FileIndex.new(repo)
    end
    x.report('commit count') do
      i = Grit::GitRuby::FileIndex.new(repo)
      i.count(commit)
    end
    x.report('commits list') do
      i = Grit::GitRuby::FileIndex.new(repo)
      i.commits_from(commit)
    end
    x.report('last commits') do
      i = Grit::GitRuby::FileIndex.new(repo)
      #arr = i.last_commits(commit, file_list)
      arr = i.last_commits(commit, /^[^\/]*$/)
    end
  end
end



