$redis = Redis.new(
  url: ENV.fetch('REDIS_URL') {
    'redis://localhost:6379/0'
  }
)

class GameReplay
  def self.save(snake_id, map, state)
    t = Time.now.to_i
    $redis.zadd snake_id, t, Marshal.dump({map: map, state: state, t: t})
  end

  def self.record_time_of_death(snake_id, length)
    $redis.zadd "snakes", length, snake_id
  end

  def self.last_moves(snake_id)
    moves = $redis.zrevrangebyscore snake_id, "+inf", "-inf", limit: [0, 5]

    moves.map{|m| Marshal.load(m) }
  end
end