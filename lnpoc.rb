require 'rubygems'
require 'sinatra'
require 'pg'
require 'sequel'
require 'markaby'
require 'logger'

$LOAD_PATH.unshift Pathname(__dir__).expand_path
require 'listener'

def database_url
  ENV.fetch('DATABASE_URL') { 'postgres:///lnpoc' }
end

def raw_connection
  uri = URI.parse(database_url)
  opts = { dbname: uri.path[1..-1] }
  opts.merge!(host: uri.host, user: uri.user, password: uri.password) if uri.host
  PG.connect(opts)
end

DB = Sequel.connect(database_url)

# Wipe database, setup table and fill with example data on each
# restart
require 'setup'

class Score < Sequel::Model
end

class Highscore
  include Enumerable

  def initialize
    @scores = Score.order(Sequel.desc(:score), :player).first(10)
  end

  def each(&block)
    @scores.each(&block)
  end
end

highscore = Highscore.new
logger = Logger.new(STDOUT)
listener = Listener.new(raw_connection, logger)
mutex = Mutex.new

listener.on('scores') do
  logger.info 'New highscore'
  mutex.synchronize { highscore = Highscore.new }
end

listener.start

get '/' do
  mine = params['mine'].to_i

  index_view(highscore, mine)
end

post '/' do
  DB.transaction do
    DB[:scores].where(player: params[:player]).delete
    DB[:scores].insert(player: params[:player], score: params[:score].to_i)
  end
  markaby do
    p 'Thanks, scores have been updated.'
    a 'Back to Highscore', href: '/'
  end
end


def index_view(highscore, mine)
  markaby do
    style <<-CSS
      td { text-align: right; padding: 0.2em 2em; }
    CSS
    h1 'Highscore'
    table do
      tr do
        th 'Player'
        th 'Score'
        th 'Difference to mine'
      end
      highscore.each do |score|
        tr do
          td score.player
          td score.score
          td format('%+i', score.score - mine)
        end
      end
    end
    random_link = "/?mine=#{rand(1000)}"
    p do
      "Call with parameter 'mine' to set a score to compare to," \
      " e.g. <a href='#{random_link}'>#{random_link}</a>."
    end

    p do
      'Set new score:'
    end
    form(method: 'POST') do
      label do
        self << 'Player'
        input(name: 'player')
      end
      label do
        self << 'Score'
        input(name: 'score')
      end
      input(type: 'submit')
    end
  end
end
