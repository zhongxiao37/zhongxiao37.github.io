require "selenium-webdriver"
require 'active_support/core_ext/time'
require 'yaml'
# full API method document
# http://seleniumhq.github.io/selenium/docs/api/rb/Selenium/WebDriver/Wait.html#until-instance_method


def options
    config_file_path = 'config.yml'
    @options ||= YAML::load(File.read(config_file_path))
end

def driver
    opts = Selenium::WebDriver::Chrome::Options.new
    opts.add_argument('--ignore-certificate-errors')
    opts.add_argument('--disable-popup-blocking')
    opts.add_argument('--disable-translate')
    @driver ||= Selenium::WebDriver.for :chrome, options: opts
end

def waitor
    @waitor ||= Selenium::WebDriver::Wait.new(timeout: 30)
end

def wait_until_background_layer_gone

    begin
        while true
            driver.find_element(:xpath, "//div[@class='background']")
            sleep(1/2.0)
            # puts "Waiting for the background <div> disappears..."
        end
    rescue Selenium::WebDriver::Error::NoSuchElementError
        # puts "background <div> is gone!"
    rescue Exception => e
        p e
        raise # reraise other exception
    end
end

def previous_or_next_btn(date_str)
    Time.parse(date_str) < Time.now ? 'previous' : 'next'
end

def pick_specific_date(xpath, date_str)
    # navigate to previous month
    driver.find_element(:xpath, xpath).click

    while true
        begin
            driver.find_element(:xpath, "//td[@data-date='#{date_str}']")
            break
        rescue Selenium::WebDriver::Error::NoSuchElementError
            driver.find_element(:xpath, "//th[@class='#{previous_or_next_btn(date_str)}']/a").click
            sleep(1/2.0)
            next
        rescue Exception => e
            p e
            raise # reraise other exception
        end
    end

    if driver.find_element(:xpath, "//td[@data-date='#{date_str}']").attribute('class') == 'disabled'
        driver.find_element(:xpath, "//th[@class='#{previous_or_next_btn(date_str)}']/a").click
    end

    driver.find_element(:xpath, "//td[@data-date='#{date_str}']").click
end

def browser_login
    driver.navigate.to options['aui_base_url']+options['agency_name']

    element = driver.find_element(id: 'UserName')
    element.send_keys options['username']
    element = driver.find_element(id: 'Password')
    element.send_keys options['password']
    element.submit

    waitor.until { driver.find_element(id: "netIncomeSummaryItem").displayed? }

    agency_net_income_summary_value = driver.find_element(:xpath, "//li[@id='netIncomeSummaryItem']/div[@class='value']").text
    puts "agencyhome page is completed load. Agency Net Income is #{agency_net_income_summary_value}"
    # agency homepage is completely loaded
    # okay to move on

    p driver.manage.all_cookies
end

def run_revenue_report_for_event(event_id, start_dt, end_dt)
    driver.navigate.to options['aui_base_url']+options['agency_name'] + "#/active/endurance/financials/revenue?e=#{event_id}"

    waitor.until { driver.find_element(:id, "rangeCombo").displayed? }
    # there is a layer when loading the page, even the element can be found by Selenium
    # it's not clickable however. Wait for couple seconds until it's gone
    wait_until_background_layer_gone

    # select customer date range
    driver.find_element(:id, 'rangeCombo').click
    driver.find_element(:xpath, "//li[@data-value='CUSTOM_DATE_RANGE']/a").click

    pick_specific_date("//div[@id='startDateInput']", start_dt)
    pick_specific_date("//div[@id='endDateInput']", end_dt)

    driver.find_element(:id, 'updateButton').click

    waitor.until { driver.find_element(:id, "totalNetIncome").displayed? }
end

def analysis_revenue_report
    totalNetIncome = driver.find_element(:xpath, "//li[@id='totalNetIncome']/div[@class='value']").text

    compare_revenue_report('totalNetIncome', totalNetIncome, options['totalNetIncome'])
end

def compare_revenue_report(label, actual_value, expected_value)
    if actual_value == expected_value
        puts "#{label} matches"
    else
        puts "#{label} #{actual_value} does not match expected #{expected_value}"
        driver.save_screenshot("#{Time.now.strftime('%Y-%m-%d_%H%M%S')}_revenue_report.png")
    end
end
