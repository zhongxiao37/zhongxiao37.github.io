require_relative 'lib/selenium_core.rb'

browser_login

run_revenue_report_for_event(options['event_id'], options['start_dt'], options['end_dt'])

analysis_revenue_report

sleep(10)

driver.quit