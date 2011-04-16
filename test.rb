$:.unshift("#{File.dirname(__FILE__)}")
require 'price_scraper'
require 'test/unit'


class TestPriceScraper < Test::Unit::TestCase

  class ::PriceScraper
    private
    def wait_for_results_page_to_load 
      #do not slow tests down
    end
  end

  class MockEverything
    def to_ary 
      ['MockEverythingHackToMakeRubyHappy']
    end
    private 
    def method_missing(*ignored)
      return MockEverything.new
    end
  end

  TEST_CSV_FILE = '/tmp/junk-test-file'
  def set_up
    `rm -f #{TEST_CSV_FILE}`
  end

  def test_builds_date_ranges
    ps = PriceScraper.new(nil, TEST_CSV_FILE)
    c = []
    ps.dates_for do |date1, date2|
      c << [date1, date2]
    end
    #pp c.reduce([]) {|all, e| all << e.reduce([]) {|all,d| all << d.to_s}}
    c.each do |e| 
      days_diff = e[1].mjd - e[0].mjd
      assert(days_diff > PriceScraper::MIN_DAYS_STAY, 'Days to search stay should all over the max diff')
      assert(days_diff < PriceScraper::MAX_DAYS_STAY, 'Days to search should all be under the min diff')
    end
  end

  class ErrorDriver < MockEverything
    def initialize
      @calls = 0
    end
    def find_element(*args)
      @calls = @calls + 1
      raise Selenium::WebDriver::Error::WebDriverError if @calls < 3
      return MockEverything.new
    end
  end

  def test_will_retry_if_a_timout_exception    
    ps = PriceScraper.new(ErrorDriver.new, TEST_CSV_FILE)
    ps.run    
  end

end


