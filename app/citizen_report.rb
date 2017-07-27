require 'set'
require 'unirest'
require 'uri'
require 'highline'
require 'date'
require 'time'
require 'configatron'
require 'json'
require 'prawn'
require "prawn/table"
require 'fileutils'
require_relative '../config/configatron/defaults.rb'
require_relative 'call_square.rb'
require_relative 'accounting_report.rb'
require_relative 'tips_report.rb'
require_relative 'helpers.rb'
require_relative 'settlements.rb'
require_relative 'empty_report.rb'

class MakeReport
  include Helper
   
  # ACCESS_TOKEN = configatron.access_token
  # # The base URL for every Connect API request
  # CONNECT_HOST = 'https://connect.squareup.com'
  # # Standard HTTP headers for every Connect API request
  # REQUEST_HEADERS = {
  #   'Authorization' => 'Bearer ' + ACCESS_TOKEN,
  #   'Accept' => 'application/json',
  #   'Content-Type' => 'application/json'
  # }
  # #unique store id
  # LOCATION_ID = configatron.location_id

  Prawn::Font::AFM.hide_m17n_warning = true

def initialize
   #AM PM shift hours
   @am_start = 'T01:00:00-05:00'
   @am_end   = 'T16:00:00-05:00'
   @pm_start = 'T16:00:00-05:00'
   @pm_end   = 'T23:45:00-05:00'
   
end

def menu #what type of report to run & set variables accordingly
   @tip_data = {}
   @accounting_data = {}
 
   cli = HighLine.new
    start_menu = [ "AM tips report",
                   "PM tips report",
                   "AM tips report with custom date",
                   "PM tips report with custom date",
                   "Accountant report",
                   "Accountant report with custom date",
                   "Accountant report with date range",
                   "Help",
                   "Quit" 
                  ]

    cli.choose do |menu|
      menu.prompt = 'Make your choice: '
      menu.choices(*start_menu) do |chosen|   
      case chosen
          when "AM tips report"
            @begin_time = Date.today.to_s + @am_start
            @end_time = Date.today.to_s + @am_end  
            @tip_data = {'date' => Date.today, 'report_type' => 'AM'}
   
          when "PM tips report"
            @begin_time = Date.today.to_s + @pm_start
            @end_time = Date.today.to_s +  @pm_end
            @tip_data = {'date' => Date.today, 'report_type' => 'PM'}

          when "AM tips report with custom date"
            cli = HighLine.new
            custom_date = cli.ask("Enter date? ", Date) {
            |q| q.default = Date.today.to_s;
              q.validate = lambda { |p| Date.parse(p) <= Date.today };
              q.responses[:not_valid] = "Enter a valid date less than or equal to today"}
            @begin_time = custom_date.to_s + @am_start
            @end_time = custom_date.to_s + @am_end
            @tip_data = {'date' => custom_date, 'report_type' => 'AM'}

          when "PM tips report with custom date"
            cli = HighLine.new
            custom_date = cli.ask("Enter date? ", Date) {
            |q| q.default = Date.today.to_s;
                q.validate = lambda { |p| Date.parse(p) <= Date.today };
                q.responses[:not_valid] = "Enter a valid date less than or equal to today"}
            @begin_time = Time.parse(custom_date.to_s + @pm_start).iso8601
            @end_time = Time.parse(custom_date.to_s + @pm_end).iso8601
            report_type = 'PM'
            @tip_data = {'date' => custom_date, 'report_type' => 'PM'}           

          when "Accountant report"
            @begin_time = Date.today.to_s + @am_start
            @end_time = Date.today.to_s + @pm_end
            @accounting_data = {'date' => Date.today, 'report_type' => 'Acc'}

          when "Accountant report with custom date"
            cli = HighLine.new
            custom_date = cli.ask("Enter date? ", Date) {
            |q| q.default = Date.today.to_s;
                q.validate = lambda { |p| Date.parse(p) <= Date.today };
                q.responses[:not_valid] = "Enter a valid date less than or equal to today"}
            @begin_time = custom_date.to_s + @am_start
            @end_time = custom_date.to_s + @pm_end
            @accounting_data = {'date' => custom_date, 'report_type' => 'Acc'}

          when "Accountant report with date range"
            cli = HighLine.new
            custom_date_start = cli.ask("Enter start date? ", Date) {
            |q| q.default = Date.today.to_s;
                q.validate = lambda { |p| Date.parse(p) <= Date.today };
                q.responses[:not_valid] = "Enter a valid date less than or equal to today"}
            custom_date_end = cli.ask("Enter end date? ", Date) {
            |q| q.default = Date.today.to_s;
                q.validate = lambda { |p| Date.parse(p) <= Date.today };
                q.responses[:not_valid] = "Enter a valid date less than or equal to today"} 
            @custom_date_start = custom_date_start
            @custom_date_end = custom_date_end
            @accounting_data = {'report_type' => 'batch'}                

          when "Help"
            puts "  "
            puts "AM tips report / AM tips report with custom date: "
            puts "Run AM tips report once at the end of Lunch "
            puts "Run AM tips report with custom date for previous dates, use date format (YYYY-mm-dd)"
            puts "AM tips report for current day only " 
            puts "Info necessary to complete the form: "
            puts "  - number of breakfast servers & their names"
            puts "  - cash & credit tips paid out to breakfast servers"
            puts "  - number of lunch servers (not including the cashier) & their names"
            puts "  - cash tips collected for lunch shift"
            puts "  "
            puts "PM tips report / PM tips report with custom date: "
            puts "Run PM tips report once at the end of dinner "
            puts "Run PM tips report with custom date for previous dates, use date format (YYYY-mm-dd)"
            puts "Info necessary to complete the form: "
            puts "  - number of dinner servers (not including the cashier) & their names"
            puts "  - cash tips collected for dinner shift"
            puts " "
            puts "Accountant report / Accountant report with custom date:"
            puts "Run once daily after square drawer has been closed on all devices"
            puts "Run Accountant report with custom date for previous dates, use date format (YYYY-mm-dd) "
            puts "Accountant reports get payout info from Square. For payouts to be included in the report, include "
            puts "'food', 'office', 'supplies', 'repairs' or 'special', respectivly in the description field when doing payouts "
            puts "  "
            puts "Accountant report with date range"
            puts "Use date format (YYYY-mm-dd) for both start date and end date"
            puts "  "
          when "Quit"
            puts "Ok, see you."
            exit 0

         end
      end
    end

  build_reports
 
end

def build_reports
  if @tip_data['report_type'] == 'AM' || @tip_data['report_type'] == 'PM'    
    interview
    square_tips
    split_tips(@tips)
    cli_out
    looking_good
    to_pdf
    cleanup #+ return to menu
  elsif @accounting_data['report_type'] == 'Acc'
    route_reports
    cleanup #+ return to menu
  elsif @accounting_data['report_type'] == 'batch'
    batch_reports
    cleanup #+ return to menu
  else #help
    menu
  end

end

def batch_reports
  (@custom_date_start..@custom_date_end).each do |b|
    @accounting_data = {} #reset hash for each date
    @begin_time = b.to_s + @am_start 
    @end_time = b.to_s + @pm_end      
    @accounting_data = {'date' => b, 'report_type' => 'Acc'} 
    route_reports
    puts b.to_s + " pdf complete."
  end 
  
end

def route_reports #decide what reports to run based on availability of data
  @pdf_switch = false
  get_shift_ids #returns @shift_ids
  get_settlement_ids #returns @settlement_ids
  
  if @shift_ids.empty? && @settlement_ids.empty?
    blank_pdf #print pdf placeholder
  elsif @shift_ids.size > 0 && @settlement_ids.empty? 
    #just get shift events
    get_shift_events(@shift_ids)
    poll_square
    do_the_math(@payments)
    accounting_pdf
  elsif @shift_ids.empty? && @settlement_ids.size > 0
    #just get settlements
    parse_settelments(@settlement_ids)   
    settlements_pdf
  else
    #get both settlements and shift events
    @pdf_switch = true #toggle reporting pdf to add shift events
    parse_settelments(@settlement_ids)   
    get_shift_events(@shift_ids)
    poll_square
    do_the_math(@payments)
    accounting_pdf 
  end
  
  #cleanup #+ return to menu

end


end

MakeReport.new.menu
