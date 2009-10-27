begin
  require 'sequel'

  module Grit

    class CommitDb

      SCHEMA_VERSION = 1

      attr_accessor :db, :git

      def initialize(git_obj, index_location = nil)
        @git = git_obj
        db_file = File.join(index_location || @git.git_dir, 'commit_db')
        if !File.exists?(db_file)
          @db = Sequel.open "sqlite:///#{db_file}"
          setup_tables
        else
          @db = Sequel.open "sqlite:///#{db_file}"
        end
      end

      def rev_list(branch, options)
      end

      def update_db(branch = nil)
        # find all refs/heads, for each
        # add branch if not there
        # go though all commits in branch
          # add new commit_branches a
          # and commit_nodes for each new one
          # stop if reach commit that already has branch and node links
      end

      def setup_tables
        @db << "create table meta (meta_key text, meta_value text)"
        @db[:meta] << {:meta_key => 'schema', :meta_value => SCHEMA_VERSION}

        @db << "create table commits (id integer, sha text, author_date integer)"
        @db << "create table nodes (id integer, path text, type text)"
        @db << "create table branches (id integer, ref text, commit_id integer)"

        @db << "create table commit_branches (commit_id integer, branch_id integer)"
        @db << "create table commit_nodes (commit_id integer, node_id integer, node_sha string)"
      end

    end
  end

rescue LoadError
  # no commit db
end
