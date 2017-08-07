require 'selenium_core'

describe 'Endurance revenue report test suits:' do

  before do
    browser_login
  end

  describe "run event revenue report" do

    before do
      run_revenue_report_for_event(options['event_id'], options['start_dt'], options['end_dt'])
    end

    it "event revenue report should match" do

      expect(driver.find_element(:xpath, "//li[@id='totalNetIncome']/div[@class='value']").text).to eql(options['totalNetIncome'])
      expect(driver.find_element(:xpath, "//li[@id='payments']/div[@class='value']").text).to eql(options['payments'])
      expect(driver.find_element(:xpath, "//li[@id='registrationNetIncome']/div[@class='value']").text).to eql(options['registrationNetIncome'])
      expect(driver.find_element(:xpath, "//li[@id='otherNetIncome']/div[@class='value']").text).to eql(options['otherNetIncome'])
      expect(driver.find_element(:xpath, "//li[@id='discounts']/div[@class='value']").text).to eql(options['discounts'])
      expect(driver.find_element(:xpath, "//li[@id='processingFees']/div[@class='value']").text).to eql(options['processingFees'])

    end

  end

end