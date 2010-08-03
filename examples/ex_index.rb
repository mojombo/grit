require '../lib/grit'

count = 1
Dir.chdir("/Users/schacon/projects/atest") do
  r = Grit::Repo.new('.')
  i = r.index
  while(count < 10) do
    fname = Time.now.to_i.to_s + count.to_s
    i.add(fname, 'hello ' + fname)
    count += 1
  end
  count = 5
  while(count < 10) do
    puts "HELLO"
    fname = Time.now.to_i.to_s + count.to_s
    i.add('test/' + fname, 'hello ' + fname)
    count += 1
  end
  puts i.commit('my commit')
  puts i.inspect
end