#!/usr/bin/evn ruby

require "selenium-webdriver"
require 'csv'
require 'ruby-debug'
require 'logger'

class Date
  def to_s
    strftime('%m/%d/%Y')
  end
end


class PriceScraper

  DATE_RANGE = (Date.new(2011,7,27)..Date.new(2011,8,29))
  MIN_DAYS_STAY = 7
  MAX_DAYS_STAY = 13

  def initialize(driver, filename)
    @filename = filename
    @driver = driver
    @log = Logger.new(STDOUT)
    @log.level = Logger::WARN
  end

  def run
    CSV.open(@filename, 'w') do |f|      
      f << %w(airport1 airport2 date1 airport3 airport4 date2 price1 price2 price3)
    end
    dates_for do |date1, date2|
      search_for("NYC", "XNN", date1, "Kathmandu", "NYC", date2, 0)
    end
    @driver.quit
  end

  def dates_for
    # I used to search multiple specific date ranges, so the map
    {DATE_RANGE => DATE_RANGE}.each do |leaveDates,  returnDates|
      leaveDates.each do |date1|
        returnDates.each do |date2| 
          trip_duration = date2.mjd - date1.mjd
          if trip_duration > MIN_DAYS_STAY && trip_duration < MAX_DAYS_STAY
            yield date1, date2
          end
        end
      end
    end
  end

  private

  def search_for(airport1, airport2, date1, airport3, airport4, date2, attempts) 
    begin
      @driver.navigate.to "http://www.travelocity.com/Flights?IgnoreIpRedirect=yes"
      @driver.find_element(:xpath, "//input[@name='flightType' and @value='multicity']").click
      el = @driver.find_element(:name, 'leavingFrom1')
      el.clear
      el.send_keys airport1
      el = @driver.find_element(:name, 'goingTo1')
      el.clear
      el.send_keys airport2
      el = @driver.find_element(:name, 'leavingDate1')
      el.clear
      el.send_keys date1.to_s
      @driver.find_element(:name, 'leavingFrom2').send_keys airport3
      @driver.find_element(:name, 'goingTo2').send_keys airport4
      @driver.find_element(:name, 'leavingDate2').send_keys date2.to_s
      
      @driver.find_element(:id, 'FObutton').click
      wait_for_results_page_to_load
      
      el = @driver.find_element(:id, 'tfGrid')
      top_4_prices = el.find_elements(:class, 'tfPrice').reduce([]) {|c,i| c << i.find_element(:class, 'perPerson').text.match(/Total \$(.*)/)[1].gsub(',','')}[0...4]
      save_to_file(airport1, airport2, date1, airport3, airport4, date2, top_4_prices)
    rescue Selenium::WebDriver::Error::WebDriverError, Timeout::Error => e
      if (attempts > 3)
        @log.error("3 attempts timed out, aborting this search, resume with next. #{e}") 
        save_to_file(airport1, airport2, date1, airport3, airport4, date2, ['error'])
      end
      @log.warn("Attempt #{attempts}. Exception for #{[airport1, airport2, date1, airport3, airport4, date2]} #{e}")
      search_for(airport1, airport2, date1, airport3, airport4, date2, attempts+1) 
    end

  end
  
  def save_to_file(airport1, airport2, date1, airport3, airport4, date2, top_4_prices) 
    CSV.open(@filename, 'a') do |f|
      f << [airport1, airport2, date1, airport3, airport4, date2] + top_4_prices
    end
  end

  def wait_for_results_page_to_load
    (1..30).each do 
      break if @driver.title.match(/Travelocity.*Outbound.*Search.*Results/)
      sleep(0.5)
    end
    sleep(0.5) # try to prevent timeouts
  end

  
end

if __FILE__ == $0
  PriceScraper.new(Selenium::WebDriver.for(:firefox, :profile => 'selenium-no-img'), 'price_results.csv').run
end
