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

class MakeReport

  ACCESS_TOKEN = configatron.access_token
  # The base URL for every Connect API request
  CONNECT_HOST = 'https://connect.squareup.com'
  # Standard HTTP headers for every Connect API request
  REQUEST_HEADERS = {
    'Authorization' => 'Bearer ' + ACCESS_TOKEN,
    'Accept' => 'application/json',
    'Content-Type' => 'application/json'
  }
  #unique id
  LOCATION_ID = configatron.location_id

  Prawn::Font::AFM.hide_m17n_warning = true

def initialize
   #AM PM shift hours
   @am_start = 'T03:00:00-05:00'
   @am_end   = 'T16:00:00-05:00'
   @pm_start = 'T16:00:00-05:00'
   @pm_end   = 'T23:45:00-05:00'
end

def menu #what type of report to run 
   @shift_data = {}
  
   cli = HighLine.new
    start_menu = [ "AM shift report",
                   "PM shift report",
                   "AM shift report with custom date",
                   "PM shift report with custom date",
                   "Accountant report",
                   "Accountant report with custom date",
                   "Quit" 
                  ]

    cli.choose do |menu|
      menu.prompt = 'Make your choice: '
      menu.choices(*start_menu) do |chosen|   
      case chosen
          when "AM shift report"
            @begin_time = Date.today.to_s + @am_start
            @end_time = Date.today.to_s + @am_end 
            @date = Date.today 
            @report_type = 'AM'

          when "PM shift report"
            @begin_time = Date.today.to_s + @pm_start
            @end_time = Date.today.to_s +  @pm_end
            @date = Date.today 
            @report_type = 'PM'

          when "AM shift report with custom date"
            cli = HighLine.new
            custom_date = cli.ask("Enter date? ", Date) {
            |q| q.default = Date.today.to_s;
              q.validate = lambda { |p| Date.parse(p) <= Date.today };
              q.responses[:not_valid] = "Enter a valid date less than or equal to today"}
            @begin_time = custom_date.to_s + @am_start
            @end_time = custom_date.to_s + @am_end
            @date = custom_date 
            @report_type = 'AM'

         when "PM shift report with custom date"
            cli = HighLine.new
            custom_date = cli.ask("Enter date? ", Date) {
            |q| q.default = Date.today.to_s;
                q.validate = lambda { |p| Date.parse(p) <= Date.today };
                q.responses[:not_valid] = "Enter a valid date less than or equal to today"}
            @begin_time = Time.parse(custom_date.to_s + @pm_start).iso8601
            @end_time = Time.parse(custom_date.to_s + @pm_end).iso8601
            @date = custom_date 
            @report_type = 'PM'           

          when "Accountant report"
            @begin_time = Date.today.to_s + @am_start
            @end_time = Date.today.to_s + @pm_end
            @date = Date.today 
            @report_type = 'Acc'

          when "Accountant report with custom date"
            cli = HighLine.new
            custom_date = cli.ask("Enter date? ", Date) {
            |q| q.default = Date.today.to_s;
                q.validate = lambda { |p| Date.parse(p) <= Date.today };
                q.responses[:not_valid] = "Enter a valid date less than or equal to today"}
            @begin_time = custom_date.to_s + @am_start
            @end_time = custom_date.to_s + @pm_end
            @date = custom_date 
            @report_type = 'Acc'
          
          when "Quit"
            puts "Ok, see you."
            exit 0

         end
      end
    end

  @shift_data = {'date' => @date.strftime("%A %b %e %Y "), 'report_type' => @report_type}
   
  build_reports
 
end

def build_reports
  if @shift_data['report_type'] == 'AM' || @shift_data['report_type'] == 'PM'
    count_register
    interview
    poll_square
    do_the_math(@payments)
    cli_out
    looking_good
    to_pdf
    cleanup #+ return to menu
  else
    accounting_interview
    poll_square
    do_the_math(@payments)
    accounting_math 
    accounting_pdf
    cleanup #+ return to menu
  end

end

def count_register #get total of register at end of shift. convert floats to integers represent total in pennies.
  temp_hash = {}
  register_count = check = penny =  nickle = dime = quarter = dollar =
  five = ten = twenty = fifty = hundred = 0

  puts "Count the Register. \nUse quantity not value => 102 pennies not 1.02: "
  cli = HighLine.new
  penny   =  cli.ask("Pennies: ", Integer ) {|q| q.in = 0..3000}
  nickle  =  cli.ask("Nickles: ", Integer ) {|q| q.in = 0..3000}
  dime    =  cli.ask("Dimes: ", Integer ) {|q| q.in = 0..3000}
  quarter =  cli.ask("Quarters: ", Integer) {|q| q.in = 0..3000}
  puts "Cash. Use Quantity not value => 5 five dollar bills not 25 dollars:"
  dollar  =  cli.ask("$1: ", Integer ) {|q| q.in = 0..10000}
  five    =  cli.ask("$5: ", Integer ) {|q| q.in = 0..10000} 
  ten     =  cli.ask("$10: ", Integer ) {|q| q.in = 0..10000}
  twenty  =  cli.ask("$20: ", Integer ) {|q| q.in = 0..10000}
  fifty   =  cli.ask("$50: ", Integer ) {|q| q.in = 0..10000}
  hundred =  cli.ask("$100: ", Integer ) {|q| q.in = 0..10000}     
  check   =  cli.ask("Total check value: ", Float )  {|q| q.in = 0..1000}

  change = penny + (nickle*5) + (dime*10) + (quarter*25) 
  cash = (dollar*100) + (five*500) + (ten*1000) + (twenty*2000)+ (fifty*5000)+ (hundred*10000)
  register_count =  change + cash + to_pennies(check)               

  #add responses to hash
  temp_hash = {'register_count' =>  register_count}
  @shift_data.merge!(temp_hash)

end

def interview #get servers count & names, payouts, pay-ins ...              
  bcount = count = servers_count = register_start = payouts = purchases = pay_ins = 
  drops = cash_tips = cash_b_tips = credit_b_tips = b_servers_count = 0
  
  server_names = []
  b_server_names = []
  temp_hash = {}

  cli = HighLine.new
  cashier = cli.ask( "Cashier Name: ", String)
  server_names << cashier

  #get breakfast wait staff name, cc tips & cash tips
  if @shift_data['report_type'] == 'AM' 
    b_servers_count = cli.ask("Number of Servers for Breakfast Shift: ", Integer)
     if b_servers_count > 0
        b_servers_count.times do  
          bcount += 1
          b_server_names << cli.ask( "Breakfast Server # #{bcount} name: ", String)
        end
        cash_b_tips   = cli.ask("Cash Tips (Breakfast Shift): ", Float)
        credit_b_tips = cli.ask("Credit Tips (Breakfash Shift): ", Float)
    end
  end

  #get lunch/dinner data
  servers_count = cli.ask( "Number of Servers (lunch/dinner don't include cashier): ", Integer)
  servers_count.times do  
    count += 1
    server_names << cli.ask( "server # #{count} name: ", String)
  end

  cash_tips        = cli.ask( "Cash Tips (lunch/dinner): ", Float)
  register_start   = cli.ask( "Register Open: ", Float)
  payouts          = cli.ask( "Payouts: ", Float)
  purchases        = cli.ask( "Purchases: ", Float)
  pay_ins          = cli.ask( "Pay Ins: ", Float)
  drops            = cli.ask( "Drops: ", Float)
  notes            = cli.ask( "Shift Notes (weather, holiday, special events ... ): ", String)

  #add responses to hash
  temp_hash = { 'register_start'  =>  to_pennies(register_start),
                'b_server_names'  =>  b_server_names, 
                'cash_b_tips'     =>  to_pennies(cash_b_tips),
                'credit_b_tips'   =>  to_pennies(credit_b_tips), 
                'cashier'         =>  cashier.capitalize, 
                'server_names'    =>  server_names,
                'cash_tips'       =>  to_pennies(cash_tips),                  
                'payouts'         =>  to_pennies(payouts), 
                'purchases'       =>  to_pennies(purchases), 
                'pay_ins'         =>  to_pennies(pay_ins), 
                'drops'           =>  to_pennies(drops), 
                'notes'           =>  notes
              } 
  @shift_data.merge!(temp_hash)

end

def poll_square
    @payments = []

  # URL-encode all parameters
  parameters = URI.encode_www_form(
    'begin_time' => @begin_time,
    'end_time'   => @end_time
  )
 
    request_path = CONNECT_HOST + '/v1/' + LOCATION_ID + '/payments?' + parameters
    more_results = true
    while more_results do

      # Send a GET request to the List Payments endpoint
      response = Unirest.get request_path,
                   headers: REQUEST_HEADERS,
                   parameters: parameters
             
      # Read the converted JSON body into the cumulative array of results
      @payments += response.body

      # Check whether pagination information is included in a response header, indicating more results
      if response.headers.has_key?(:link)
        pagination_header = response.headers[:link]
        if pagination_header.include? "rel='next'"
           
          # Extract the next batch URL from the header.
          #
          # Pagination headers have the following format:
          # <https://connect.squareup.com/v1/MERCHANT_ID/payments?batch_token=BATCH_TOKEN>;rel='next'
          # This line extracts the URL from the angle brackets surrounding it.
          request_path = pagination_header.split('<')[1].split('>')[0]
        else
          more_results = false
        end
      else
        more_results = false
      end
  end

   
end

def do_the_math(payments)
 
  # Variables - set all to zero
  collected_money = taxes = tips = discounts = processing_fees = cash_sales = gift_card_sales = check_sales =
                    credit_card_sales = returned_processing_fees = net_money = refunds = gift_cards_sold = 
                    counter = cc_refund = cash_refund = transactions = register_close = cash_tips_collected =
                    total_tips = food_sales = credit_tips =  beer_money = wine_money = liquor_money = 
                    alco_discount = food_discount = retail_sales = retail_tax = 0
  gift_card = []
  temp_hash = {}
  shift_tips = {}
  breakfast_tips = {}
  lunch_tips = {}
  dinner_tips = {}
  abc_sales = {}
  
  # Add values to each cumulative variable
  
  for payment in payments
    transactions    += 1
      collected_money = collected_money + payment['total_collected_money']['amount'] 
      taxes           = taxes           + payment['tax_money']['amount']
      tips            = tips            + payment['tip_money']['amount']
      discounts       = discounts       + payment['discount_money']['amount']
      processing_fees = processing_fees + payment['processing_fee_money']['amount']
      net_money       = net_money       + payment['net_total_money']['amount']
      refunds         = refunds         + payment['refunded_money']['amount']
    
    #breakdown of payment types
      transaction_type = payment['tender'][0]['name']
      case transaction_type
         when "Cash"
          cash_sales  = cash_sales + payment['tender'][0]['total_money']['amount'] 
        when "Credit Card"  
          credit_card_sales = credit_card_sales + payment['tender'][0]['total_money']['amount']
        when "MERCHANT_GIFT_CARD"  
          gift_card_sales = gift_card_sales + payment['tender'][0]['total_money']['amount']
        when "CHECK"
          check_sales = check_sales + payment['tender'][0]['total_money']['amount']
      end
   
    #get alcohol sales & discounts
     payment['itemizations'].each do |alco|
       if alco['item_detail']['category_name'] == 'Beer'
         beer_money += alco['gross_sales_money']['amount']
         alco_discount += alco['discount_money']['amount'] 
        
       elsif alco['item_detail']['category_name'] == 'Wine'
         wine_money += alco['gross_sales_money']['amount']
         alco_discount += alco['discount_money']['amount'] 
  
       elsif alco['item_detail']['category_name'] == 'Liquor'
         liquor_money += alco['gross_sales_money']['amount']
         alco_discount += alco['discount_money']['amount']       
       end
     end 
     
     abc_sales = {'abc_total'     => beer_money + wine_money + liquor_money,
                  'beer_money'    => beer_money,
                  'wine_money'    => wine_money,
                  'liquor_money'  => liquor_money
                }

    #split food/alcohol discounts (negative numbers)
    food_discount = discounts - alco_discount

    #get retail sales and associated tax value
    payment['itemizations'].each do |ret|
      if ret['item_detail']['category_name'] == 'Retail'
        retail_sales += ret['gross_sales_money']['amount']
        retail_tax   += ret['gross_sales_money']['amount'] * 0.05300000
      end
    end    


    #get array of new gift card sales
    payment['itemizations'].each do |gc|
      if gc['name'] == 'Gift Certificate'
        gift_card << gc['net_sales_money']['amount']  #array of new gc sold 
        gift_cards_sold += gc['net_sales_money']['amount'] #total value of new gift cards
      end
    end
     
    
    #get breakdown of refunded money type (cash/credit)
     if  payment['tender'][0]['refunded_money']['amount'] < 0
        if payment['tender'][0]['type'] == 'CREDIT_CARD'
          cc_refund += payment['tender'][0]['refunded_money']['amount']
        else
          cash_refund += payment['tender'][0]['refunded_money']['amount']
        end
    end 
  
    #If a processing fee was applied to the payment AND some portion of the payment was refunded...
    if payment['processing_fee_money']['amount'] < 0 && payment['refunded_money']['amount'] < 0
        # ...calculate the percentage of the payment that was refunded...
        percentage_refunded = payment['refunded_money']['amount'] / payment['total_collected_money']['amount'].to_f
        # ...and multiply that percentage by the original processing fee
        returned_processing_fees = returned_processing_fees + (payment['processing_fee_money']['amount'] * percentage_refunded) 
    end     
  end
 
  #get credit_tips for accounting report
  credit_tips = tips
 
  #report type data specific => reuse poll_square for both report types 
  #register math
  if @shift_data['report_type'] == 'AM' || @shift_data['report_type'] == 'PM'

      #register_count -payouts -purchases -drops +pay_ins +cash_refund +cash_sales -tips(credit payouts)  + gift_card_sales
      register_close = (@shift_data['register_count'] - @shift_data['payouts'] - @shift_data['purchases'] - 
                        @shift_data['drops'] + @shift_data['pay_ins'] + cash_refund + cash_sales - tips + 
                        gift_card_sales )
      difference = @shift_data['register_start'] - (register_close + tips - cash_sales + cash_refund - gift_card_sales)
  

      # get tip data breakfast & lunch or dinner
      cash_tips_collected = @shift_data['cash_tips'] + @shift_data['cash_b_tips']
      total_tips =  cash_tips_collected + tips
    
      #tip hash - total, breakfast, lunch, dinner  => total, cash, credit
      shift_tips        =  { 'total'   => total_tips,
                            'cash'    => cash_tips_collected, 
                            'credit'  => tips }
      
      
      if @shift_data['report_type'] == 'AM' 
        
        #avoid division by 0 in edge case where there are no tips or there is no breakfast server
        if (@shift_data['cash_b_tips'] + @shift_data['credit_b_tips']) > 0 && @shift_data['b_server_names'].size > 0
          breakfast_tips  = { 'total'   => @shift_data['cash_b_tips'] + @shift_data['credit_b_tips'],  
                              'cash'    => @shift_data['cash_b_tips'], 
                              'credit'  => @shift_data['credit_b_tips'],    
                              'each'    => (@shift_data['cash_b_tips'] + @shift_data['credit_b_tips'])/@shift_data['b_server_names'].size }
        end

        lunch_tips      = { 'total'   => total_tips - (@shift_data['cash_b_tips'] + @shift_data['credit_b_tips']), 
                            'cash'    => cash_tips_collected - @shift_data['cash_b_tips'], 
                            'credit'  => tips - @shift_data['credit_b_tips'],
                            'each'    => (total_tips - (@shift_data['cash_b_tips'] + @shift_data['credit_b_tips']))/@shift_data['server_names'].size }
      else
    
        dinner_tips     = { 'each'    => total_tips/@shift_data['server_names'].size }
      end
  end

  #add responses to hash
  temp_hash = { 'transactions'  => transactions,
          'refunds'             => refunds, 
          'cash_refunds'        => cash_refund,
          'credit_refunds'      => cc_refund, 
          'gift_cards_sold'     => gift_cards_sold, #value of new cards sold
          'gift_card_sales'     => gift_card_sales, #value of card sales
          'gift_card'           => gift_card,  #array of new cards sold
          'cash_sales'          => cash_sales,
          'credit_card_sales'   => credit_card_sales,
          'check_sales'         => check_sales,
          'gross_sales'         => collected_money - taxes - tips + refunds,
          'net_sales'           => collected_money - taxes - tips + refunds + discounts,
          'net_total'           => net_money + refunds - returned_processing_fees,
          'food_sales'          => collected_money - taxes - tips + refunds - gift_cards_sold - beer_money - wine_money - liquor_money - retail_sales,
          'abc_sales'           => abc_sales,
          'retail_sales'        => retail_sales,
          'retail_tax'          => retail_tax,
          'discounts'           => discounts,
          'food_discount'       => food_discount,
          'alco_discount'       => alco_discount,
          'fees'                => processing_fees,
          'fees_returned'       => returned_processing_fees,
          'tax_collected'       => taxes,
          'city_tax'            => (collected_money -taxes - tips + refunds + discounts),
          'credit_tips'         => credit_tips,
          'shift_tips'          => shift_tips,
          'breakfast_tips'      => breakfast_tips, 
          'lunch_tips'          => lunch_tips,
          'dinner_tips'         => dinner_tips,         
          'register_close'      => register_close,
          'difference'          => difference
        }
    @shift_data.merge!(temp_hash)
end

def cli_out #output data to the screen

  puts " "
  puts " "
  puts 'Date             ' + @shift_data['date'] + @shift_data['report_type']
  puts 'Transactions     ' + @shift_data['transactions'].to_s
  puts 'Register Open    ' + fm(@shift_data['register_start']) 
  puts 'Register Close   ' + fm(@shift_data['register_close'])  
  puts 'Difference       ' + fm(@shift_data['difference']) 
  puts 'Tips             ' + fm(@shift_data['shift_tips']['total']) 
  puts " " 
end

def looking_good # based on cli_out info, continue to create pdf or restart the interview
    cli = HighLine.new
    start_menu = [ "Looks Good, create the pdf",
                   "Something isn't right, go back" 
                  ]

    cli.choose do |menu|
      menu.prompt = 'Make your choice: '
      menu.choices(*start_menu) do |chosen|   
        if chosen == "Something isn't right, go back" 
          system "clear" #clear the terminal
          menu #go back to main menu
        end
      end
    end
end


def to_pdf
  reg_data = []
  tip = []
  net_data = []

  Prawn::Document.generate("#{@date}_#{@shift_data['report_type']}_report.pdf" ) do |pdf|
    pdf.stroke_color 'e8ebef'
    
    #Register Data
    reg_data = ([["Cashier", @shift_data['cashier']],
                 ["Register Open", fm(@shift_data['register_start'])],
                 ["Cash Sales", fm(@shift_data['cash_sales'])],
                 ["Gift Certificate Sales", fm(@shift_data['gift_card_sales'])],
                 ["Check Sales", fm(@shift_data['check_sales'])],
                 ["Cash Returns", fm(@shift_data['cash_refunds'])],
                 ["Purchases", fm(@shift_data['purchases'])],
                 ["Payouts", fm(@shift_data['payouts'])],
                 ["Drops", fm(@shift_data['drops'])], 
                 ["Pay Ins", fm(@shift_data['pay_ins'])],
                 ["Register Close", fm(@shift_data['register_close'])],
                 ["Credit Tip Payouts", fm(@shift_data['shift_tips']['credit'])],
                 ["Register Difference", fm(@shift_data['difference'])]
      ])
    
    #Net Data
    net_data = ([["Gross Food Sales",fm(@shift_data['food_sales'])],
                 ["Gross ABC Sales", fm(@shift_data['abc_sales']['abc_total'])],
                 ["Gross Retail Sales", fm(@shift_data['retail_sales'])],
                 ["Gift Certificate Sold", fm(@shift_data['gift_cards_sold'])], #add array of ttl and each_value
                 ["Discounts Food/Alcohol", fm(@shift_data['food_discount']) + " / " + fm(@shift_data['alco_discount'])],
                 ["Returns", fm(@shift_data['refunds'])],
                 ["Total Sales", fm(@shift_data['gross_sales'])],
                 ["Tax on Sales", fm(@shift_data['tax_collected'])],
                 ["Transactions", @shift_data['transactions']]
      ]) 
    
    #Tip Data
    #adjust for pm shift don't show breakfast and rename lunch to dinner

    tip << ["Tips", "<font size='12'>(total - cash - credit)</font>" ] 
    tip << ["Total Tips", fm(@shift_data['shift_tips']['total']).to_s + " - " + fm(@shift_data['shift_tips']['cash']).to_s + " - " + fm(@shift_data['shift_tips']['credit']).to_s ] 

    
    if @shift_data['report_type'] == 'AM'
      if !@shift_data['breakfast_tips'].empty? #avoid edge case with division by 0
        tip <<  ["Breakfast Tips ", fm(@shift_data['breakfast_tips']['total']).to_s + " - " + fm(@shift_data['breakfast_tips']['cash']).to_s + " - " + fm(@shift_data['breakfast_tips']['credit']).to_s ] 
        @shift_data['b_server_names'].each do |bname|
          tip << ["\u2022  " + bname.capitalize, fm(@shift_data['breakfast_tips']['each'])]
        end
      end

      tip << ["Lunch Tips ", fm(@shift_data['lunch_tips']['total']).to_s + " - " + fm(@shift_data['lunch_tips']['cash']).to_s + " - " + fm(@shift_data['lunch_tips']['credit']).to_s ]
      @shift_data['server_names'].each do |name|
        tip << ["\u2022  " + name.capitalize, fm( @shift_data['lunch_tips']['each'])]
      end
    else
        @shift_data['server_names'].each do |name|
          tip << ["\u2022  " + name.capitalize,  fm(@shift_data['dinner_tips']['each'])]
        end
    end
 
    #if register diff = 0 show the duck
    if @shift_data['difference'] == 0  && Date.today > Date.new(2017,2,1)
      duck = "../assets/images/duckling3.png"
      pdf.image duck, :position => :right, :vposition => :top, :scale => 0.08
      pdf.move_up 40
    end
    
    pdf.text("Citizen Daily Reconciliation", size: 15, style: :bold)
    pdf.text(@shift_data['date'] + @shift_data['report_type'], size: 15, style: :bold)
    unless @shift_data['notes'].empty?
      pdf.move_down 10
      pdf.text("Shift Notes: " + @shift_data['notes'])
    end

    pdf.move_down 5 
    pdf.stroke_horizontal_rule
    pdf.move_down 5 
    pdf.table(reg_data, :cell_style =>
     { :padding => [3,0], :border_width => [0,0] }) do
        column(0).align = :left
        column(1).align = :right
        column(0).width = 230
        column(1).width = 80
      end 

    pdf.move_down 5
    pdf.stroke_horizontal_rule
    pdf.move_down 10
    pdf.table(tip, :cell_style =>
     { :padding => [3,0], :border_width => [0,0], :inline_format => true }) do
        column(0..2).align = :left
        column(0).width = 230
      end

    pdf.move_down 10
    pdf.stroke_horizontal_rule 
    pdf.move_down 5
    pdf.table(net_data, :cell_style =>
     { :padding => [3,0], :border_width => [0,0] }) do
        column(0).align = :left
        column(1).align = :right
        column(0).width = 230
        column(1).width = 80  
      end 

  end

  #includes path relative to windows - change or comment out on mac/linux
  FileUtils.move  "#{@date}_#{@shift_data['report_type']}_report.pdf" , "%UserProfile%/desktop/Reports/#{@date}_#{@shift_data['report_type']}_report.pdf"
end

def accounting_interview #get data for daily accounting sheet
    @accounting_data = {}
    temp_hash = {}
    supplies = repairs = laundry = office_supplies = food_purchases = 0

    q = HighLine.new
      food_purchases  = q.ask("Food Purchases: ", Float) 
      supplies        = q.ask("Supplies: ", Float) 
      repairs         = q.ask("Repairs: ", Float) 
      laundry         = q.ask("Laundry: ", Float) 
      office_supplies = q.ask("Office Supplies: ", Float) 

    temp_hash = { 'food_purchases'  =>  to_pennies(food_purchases),
                  'supplies'        =>  to_pennies(supplies),
                  'repairs'         =>  to_pennies(repairs),
                  'laundry'         =>  to_pennies(laundry),
                  'office_supplies' =>  to_pennies(office_supplies)
              }
    @accounting_data.merge!(temp_hash)

end

def accounting_math 

  
  total_dispursments = (@accounting_data['food_purchases'] +
                        @accounting_data['supplies'] +
                        @accounting_data['repairs'] +
                        @accounting_data['laundry'] +
                        @accounting_data['office_supplies']) 
  
  charge_deposit = @shift_data['credit_card_sales'] + @shift_data['credit_refunds'] + @shift_data['fees'] + @shift_data['fees_returned'] +  @shift_data['credit_tips']
  city_tax = (@shift_data['food_sales'] + @shift_data['abc_sales']['abc_total'] + @shift_data['retail_sales']) * 0.05300000
  
  temp_hash = { 'food_sales'              => @shift_data['food_sales'],  
                'abc_sales'               => @shift_data['abc_sales']['abc_total'],
                'retail_sales'            => "soon",
                'gc_sold'                 => @shift_data['gift_cards_sold'],
                'city_tax'                => city_tax,
                'total'                   => @shift_data['food_sales'] + @shift_data['gift_cards_sold'] + @shift_data['tax_collected'] + @shift_data['abc_sales']['abc_total'] + @shift_data['retail_sales'],  
                'cc_fees'                 => @shift_data['fees'] - @shift_data['fees_returned'],
                'gift_certificate_sales'  => @shift_data['gift_card_sales'],
                'charge_tip_payout'       => @shift_data['credit_tips'],
                'total_dispursements'     => total_dispursments,
                'cash_deposit'            => @shift_data['cash_sales'] - @shift_data['cash_refunds'] - @shift_data['credit_tips'],
                'charge_deposit'          => charge_deposit

              }
  @accounting_data.merge!(temp_hash)
  
  
end

def accounting_pdf #report for accountant
  Prawn::Document.generate("#{@date}_accounting.pdf" ) do |pdf|
   

    part1 = ([ [{:content =>  "Food Sales", :colspan => 2}, "600", fm(@accounting_data['food_sales'])],
               [{:content =>  "ABC Sales", :colspan => 2}, " ", fm(@accounting_data['abc_sales'])],
               [{:content =>  "Retail Sales", :colspan => 2}, " ", fm(@shift_data['retail_sales'])],
               [{:content =>  "Sales Tax", :colspan => 2},"442", fm(@shift_data['tax_collected']) + "  /  " + fm(@accounting_data['city_tax'])],
               [{:content =>  "Retail Tax", :colspan => 2}, " ", fm(@shift_data['retail_tax'])],
               [{:content =>  "GC Sold", :colspan => 2}," ", fm(@accounting_data['gc_sold'])],
               [{:content =>  "Total", :colspan => 2}," ", fm(@accounting_data['total'])],
               [{:content =>  " ", :colspan => 2}," "," "],    
               [{:content =>  "Food Purchases", :colspan => 2},"710",fm(@accounting_data['food_purchases'])],
               [{:content =>  "Supplies", :colspan => 2},"884", fm(@accounting_data['supplies'])],
               [{:content =>  "Repairs", :colspan => 2},"878", fm(@accounting_data['repairs'])],
               [{:content =>  "Laundry", :colspan => 2},"858", fm(@accounting_data['laundry'])],
               [{:content =>  "Office Supplies", :colspan => 2},"882", fm(@accounting_data['office_supplies'])],
               [{:content =>  "Credit Card Fee", :colspan => 2}, " ", fm(@accounting_data['cc_fees'])],
               [{:content =>  "GC Redeemed", :colspan => 2},"",fm(@accounting_data['gift_certificate_sales'])],
               [{:content =>  "Charge Tip Payout", :colspan => 2},"",fm(@shift_data['credit_tips'])],
               [{:content =>  "Total Disbursements", :colspan => 2},"",fm(@accounting_data['total_dispursements'])],
               [{:content =>  " ", :colspan => 2}," "," "], 
               [{:content =>  "Cash Deposit", :colspan => 2},"105",fm(@accounting_data['cash_deposit'])],
               [{:content =>  "Charge Deposit", :colspan => 2}, "106",fm(@accounting_data['charge_deposit'])],
               [{:content =>  "Total Receipts", :colspan => 2},"",fm(@accounting_data['cash_deposit'] + @accounting_data['charge_deposit'])]
      ])

    pdf.text("Citizen", size: 16, style: :bold)
    pdf.text(@shift_data['date'], size: 16, style: :bold)
    pdf.move_down 20
    pdf.table(part1, :width => 500, :cell_style =>
     { :border_width => [0,0], size: 15, style: :bold}) do
        column(0).align = :left
        column(1).align = :left
        column(2).align = :left  
        column(3).align = :right
      end
 
  end

  #includes path relative to windows - change or comment out on mac/linux
  FileUtils.move  "#{@date}_accounting.pdf" , "%UserProfile%/desktop/Reports/#{@date}_accounting.pdf"
end

def cleanup #move generated files to google drive folder clear the terminal and return to the menu
  
  system "clear"  #clear the terminal
  puts 'PDF document created'
  puts ' '
  menu            #go back to main menu

end

#dev tool to print the shift_data hash
def print_hash
  puts '________________________________________'
  @shift_data.each do |key, value|
      puts key + ' : ' + value.to_s
      puts value.class
  end
  puts '________________________________________'

end

# Helper to convert floats to  integers (pennies)
def to_pennies(dec)
  pennies = (dec * 100).to_int
  return pennies
end

# Helper function to convert cent-based money amounts to dollars and cents
def fm(money)
  money_string = format("%.2f", (money.abs/100.to_f))
  if money < 0
    money_string = '-' + money_string
  end
  return money_string
end

end

MakeReport.new.menu

