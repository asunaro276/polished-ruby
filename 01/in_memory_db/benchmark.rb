require 'benchmark'
require 'objspace'

# 問題: 以下の2つの検索ユースケースを効率的にサポートするデータベースを設計せよ
# 1. 特定のアルバムに参加している全アーティストを取得する
# 2. 特定のアルバム内の特定のトラックに参加している全アーティストを取得する

# Test Data Generation
# Structure: [[album_name, track_number, artist_name], ...]
def generate_data
  100.times.flat_map do |i|
    10.times.map do |j|
      ["Album #{i}", j, "Artist #{j}"]
    end
  end
end

DATA = generate_data

# Implementation 1: Hybrid Hash
class Implementation1
  def initialize
    # keys are albums, values are arrays of artists
    # example: { "Album 1" => ["Artist 1", "Artist 2"] }
    @album_artists = {}
    
    # keys are arrays of [album, track], values are arrays of artists
    # example: { ["Album 1", 1] => ["Artist 1"] }
    @album_track_artists = {}
  end

  def add(album, track, artist)
    (@album_artists[album] ||= []) << artist
    (@album_track_artists[[album, track]] ||= []) << artist
  end

  def lookup(album, track_n = nil)
    if track_n
      @album_track_artists[[album, track_n]]
    else
      @album_artists[album]
    end
  end
end

# Implementation 2: Nested Hash
class Implementation2
  def initialize
    # keys are albums, values are hashes where keys are tracks and values are arrays of artists
    # example: { "Album 1" => { 1 => ["Artist 1"], 2 => ["Artist 2"] } }
    @albums = {}
  end

  def add(album, track, artist)
    ((@albums[album] ||= {})[track] ||= []) << artist
  end

  def lookup(album, track_n = nil)
    if track_n
      @albums.dig(album, track_n)
    else
      return [] unless @albums[album]
      a = @albums[album].each_value.to_a
      a.flatten!
      a.uniq!
      a
    end
  end
end

# Implementation 3: Array Optimization
class Implementation3
  def initialize
    # keys are albums, values are arrays where index 0 is all artists, and index n is artists for track n
    # example: { "Album 1" => [["Artist 1", "Artist 2"], ["Artist 1"], ["Artist 2"]] }
    @albums = {}
  end

  def add(album, track, artist)
    album_array = @albums[album] ||= [[]]
    album_array[0] << artist
    (album_array[track] ||= []) << artist
  end

  def finalize!
    @albums.each_value do |array|
      array[0].uniq!
    end
  end

  def lookup(album, track = 0)
    @albums.dig(album, track)
  end
end

def measure_memory
  GC.start
  before = ObjectSpace.memsize_of_all
  yield
  GC.start
  after = ObjectSpace.memsize_of_all
  (after - before) / 1024.0 # KB
end

puts "=== Benchmark Report ==="
puts "Data size: #{DATA.size} items"
puts "\n"

impls = {
  "Impl 1 (Hybrid Hash)" => Implementation1.new,
  "Impl 2 (Nested Hash)" => Implementation2.new,
  "Impl 3 (Array Opt) " => Implementation3.new
}

Benchmark.bm(20) do |x|
  puts "--- Construction Time ---"
  impls.each do |name, db|
    x.report(name) do
      DATA.each { |album, track, artist| db.add(album, track, artist) }
      db.finalize! if db.respond_to?(:finalize!)
    end
  end
end

# Verification
puts "\n--- Verification ---"
ref_res = impls.values.first.lookup("Album 1")
impls.each do |name, db|
  res = db.lookup("Album 1")
  if (res - ref_res).empty? && (ref_res - res).empty?
    puts "#{name}: OK"
  else
    puts "#{name}: FAILED (Expected #{ref_res}, got #{res})"
  end
end

Benchmark.bm(20) do |x|
  puts "\n--- Lookup Time (Album) ---"
  impls.each do |name, db|
    x.report(name) do
      10000.times { db.lookup("Album 1") }
    end
  end

  puts "\n--- Lookup Time (Track) ---"
  impls.each do |name, db|
    x.report(name) do
      10000.times { db.lookup("Album 1", 5) }
    end
  end
end

puts "\n--- Memory Estimate (Rough) ---"
# Note: Accurate memory measurement in Ruby is hard without external tools.
# Re-instantiating to measure individual memory footprint roughly.

{
  "Impl 1 (Hybrid Hash)" => Implementation1,
  "Impl 2 (Nested Hash)" => Implementation2,
  "Impl 3 (Array Opt) " => Implementation3
}.each do |name, klass|
  mem = measure_memory do
    db = klass.new
    DATA.each { |album, track, artist| db.add(album, track, artist) }
    db.finalize! if db.respond_to?(:finalize!)
    # Keep db alive for measurement
    @keep_alive = db 
  end
  puts "#{name}: ~#{mem.round(2)} KB (Delta)"
end
