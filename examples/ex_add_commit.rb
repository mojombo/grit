require '../lib/grit'

count = 1
Dir.chdir("/Users/schacon/projects/atest") do
  r = Grit::Repo.new('.')
  while(count < 10) do
    fname = Time.now.to_i.to_s + count.to_s
    File.open(fname, 'w') { |f| f.write('hellor ' + fname) }
    r.add(fname)
    count += 1
  end
  r.commit_index('my commit')
end