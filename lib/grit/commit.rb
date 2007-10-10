class Grit
  Commit = Struct.new(:id, :parents, :tree, :author, :authored_date, :committer, :committed_date)
end