require 'benchmark'

# TimeFilterクラスの定義
class TimeFilter
  attr_reader :start, :finish
  def initialize(start, finish)
    @start = start
    @finish = finish
  end

  def to_proc
    proc do |value|
      next false if start && value < start
      next false if finish && value > finish
      true
    end
  end
end

# 各パターンの定義
t1 = TimeFilter.new(Time.local(2026, 1), Time.local(2026, 2))
t2 = TimeFilter.new(Time.local(2026, 1), Time.local(2026, 2))
t3 = TimeFilter.new(Time.local(2026, 1), Time.local(2026, 2))
t4 = TimeFilter.new(Time.local(2026, 1), Time.local(2026, 2))

def t2.to_proc
  proc do |value|
    start = self.start
    finish = self.finish
    next false if start && value < start
    next false if finish && value > finish
    true
  end
end

def t3.to_proc
  start = self.start
  finish = self.finish
  proc do |value|
    next false if start && value < start
    next false if finish && value > finish
    true
  end
end

def t4.to_proc
  start = self.start
  finish = self.finish
  if start && finish
    proc{|value| value >= start && value <= finish}
  elsif start
    proc{|value| value >= start}
  elsif finish
    proc{|value| value <= finish}
  else
    proc{|value| true}
  end
end

# テストデータの生成
times = (1..100000).map { Time.local(2026, 1, rand(1..28)) }

puts '各実装パターンのパフォーマンス比較:'
puts '=' * 70
puts "データ数: #{times.size}件"
puts "実行回数: 10回"
puts '=' * 70
puts

Benchmark.bm(35) do |x|
  x.report('t1 (instance vars in proc):') do
    10.times { times.select(&t1) }
  end

  x.report('t2 (local vars in proc):') do
    10.times { times.select(&t2) }
  end

  x.report('t3 (local vars outside proc):') do
    10.times { times.select(&t3) }
  end

  x.report('t4 (optimized conditions):') do
    10.times { times.select(&t4) }
  end
end

puts
puts '解説:'
puts 't1: インスタンス変数にprocの中から直接アクセス'
puts 't2: procの中でローカル変数に代入してからアクセス'
puts 't3: procの外側でローカル変数に代入(クロージャー)'
puts 't4: 事前に条件を評価して最適化されたprocを返す'
