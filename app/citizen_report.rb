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
   @pm_start = 'T16:30:00-05:00'
   @pm_end   = 'T24:00:00-05:00'
end

def menu #what type of report to run 
   @shift_data = {}
	 temp_hash = {}
	
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
			      @begin_time = Date.today.to_s +  @am_start
					  @end_time = Date.today.to_s +  @am_end
					  @date = Date.today 
					  @report_type = 'AM'

			    when "PM shift report"
			    	@begin_time = Date.today.to_s + @pm_start
					  @end_time = Date.today.to_s + @pm_end
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
            @begin_time = custom_date.to_s + @pm_start
            @end_time = custom_date.to_s + @pm_end
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
    to_pdf
    cleanup #+ return to menu
  else
    #  accounting_interview
    poll_square
    accounting_math(@payments)
    #accounting_pdf
    #cleanup #+ return to menu
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

  #get lunch data
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
                    total_tips = am_tips = am_tips_each = lunch_tips = lunch_tips_each = dinner_tips_each = 
                    lunch_tips = dinner_tips = food_sales = 0
  gift_card = []
  temp_hash = {}
  
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
    			cash_sales 	= cash_sales + payment['tender'][0]['total_money']['amount'] 
    		when "Credit Card"  
    			credit_card_sales	= credit_card_sales + payment['tender'][0]['total_money']['amount']
    		when "MERCHANT_GIFT_CARD"  
    			gift_card_sales = gift_card_sales + payment['tender'][0]['total_money']['amount']
    		when "CHECK"
    			check_sales	= check_sales	+ payment['tender'][0]['total_money']['amount']
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
 
  #base_purchases = collected_money - taxes - tips + refunds
 
  #report type data specific => reuse poll_square for both report types 
  if @shift_data['report_type'] = 'AM' || @shift_data['report_type'] = 'PM'

      #register_count -payouts -purchases -drops +pay_ins +cash_refund +cash_sales -tips(credit payouts) 
      register_close = (@shift_data['register_count'] - @shift_data['payouts'] - @shift_data['purchases'] - 
                        @shift_data['drops']+ @shift_data['pay_ins'] + (cash_refund) + (cash_sales)  - (tips)  
                       )
      difference = @shift_data['register_start'] - (register_close + (tips) - (cash_sales) + (cash_refund))
  end

  # get tip data am lunch pm
  cash_tips_collected = @shift_data['cash_tips'] + @shift_data['cash_b_tips']
  total_tips =  cash_tips_collected + tips

  if @shift_data['report_type'] = 'AM'
    am_tips         =  @shift_data['cash_b_tips'] + @shift_data['credit_b_tips'] 
    am_tips_each    = fm(am_tips/@shift_data['b_server_names'].size)
    lunch_tips      = fm(total_tips - am_tips)
    lunch_tips_each = fm((total_tips - am_tips)/@shift_data['server_names'].size) 
  elsif @shift_data['report_type'] = 'PM'     
    dinner_tips_each  = (total_tips/@shift_data['server_names'].size) 
  end 
          

#######!!!!!!!!!!add gift_card_sales to register total and account for it in reg diff
#######          remove gift cards sold from overall food sales/ abc sales

  #add responses to hash
  temp_hash = { 'transactions'  => transactions,
          'refunds'             => fm(refunds), 
          'cash_refunds'        => fm(cash_refund),
          'credit_refunds'      => fm(cc_refund), 
          'gift_cards_sold'     => fm(gift_cards_sold), #value of new cards sold
          'gift_card_sales'     => fm(gift_card_sales), #value of card sales
          'gift_card'           => gift_card,  #array of new cards sold
          'cash_sales'          => fm(cash_sales),
          'credit_card_sales'   => fm(credit_card_sales),
          'check_sales'         => fm(check_sales),

          'gross sales'         => fm(collected_money - taxes - tips + refunds),
          'net_sales'           => fm(collected_money - taxes - tips + refunds - discounts),
          'net_total'           => fm(net_money + refunds - returned_processing_fees),
          'food_sales'          => fm(collected_money - taxes - tips + refunds - discounts - gift_cards_sold), #-abc sales
        #  'abc_sales'           => fm() net_sales - food_sales - gift_cards_sold
        #  'abc_split'           => fm() beer/wine, liquor

          'discounts'           => fm(discounts),
          'fees'                => fm(processing_fees),
          'fees_returned'       => fm(returned_processing_fees),
          'tax_collected'       => fm(taxes),
          'total_tips'          => fm(total_tips),
          'cash_tips_collected' => fm(cash_tips_collected),
          'cc_tips_collected'   => fm(tips), 
          'am_tips'             => fm(am_tips),
          'am_tips_each'        => am_tips_each,
          'lunch_tips'          => lunch_tips,
          'lunch_tips_each'     => lunch_tips_each,
          'dinner_tips_each'    => dinner_tips_each,                        
          'register_close'      => fm(register_close),
          'difference'          => fm(difference)
        }
    @shift_data.merge!(temp_hash)


  
end

def cli_out #output data to the screen
  
  puts 'Date            ' + @shift_data['date'] + @shift_data['report_type']
  puts 'Transactions    ' + @shift_data['transactions'].to_s
  puts 'Register Open   ' + @shift_data['register_start'].to_s
  puts 'Pay-ins         ' + @shift_data['pay_ins'].to_s
  puts 'Payouts         ' + @shift_data['payouts'].to_s
  puts 'Purchases       ' + @shift_data['purchases'].to_s 
  puts 'Drops           ' + @shift_data['drops'].to_s
  puts 'Register Count  ' + @shift_data['register_count'].to_s 
  puts 'Cash Sales      ' + @shift_data['cash_sales'].to_s
  puts 'Check Sales     ' + @shift_data['check_sales'].to_s
  puts 'Gift Card Sales ' + @shift_data['gift_card_sales'].to_s
  puts 'Cash refunds    ' + @shift_data['cash_refunds'].to_s
  puts 'Cash Tips       ' + @shift_data['cash_tips_collected'].to_s
  puts 'CC Tips         ' + @shift_data['cc_tips_collected'].to_s
  puts 'Register Close  ' + @shift_data['register_close'].to_s  

end

def to_pdf
  reg_data = []
  tip = []
  net_data = []

 print_hash

  Prawn::Document.generate('hello.pdf') do |pdf|
    pdf.stroke_color 'e8ebef'
    #Register Data
    reg_data = ([["Cashier", @shift_data['cashier']],
                 ["Register Open", @shift_data['register_start']],
                 ["Cash Sales", @shift_data['cash_sales']],
                 ["Gift Certificate Sales", @shift_data['gift_card_sales']],
                 ["Check Sales", @shift_data['check_sales']],
                 ["Cash Returns", @shift_data['cash_refunds']],
                 ["Purchases", @shift_data['purchases']],
                 ["Payouts", @shift_data['payouts']],
                 ["Drops", @shift_data['drops']], 
                 ["Pay Ins", @shift_data['pay_ins']],
                 ["Register Close", @shift_data['register_close']],
                 ["Credit Tip Payouts", @shift_data['cc_tips_collected']],
                 ["Register Difference", @shift_data['difference']]
      ])
    #Net Data
    net_data = ([["Net Food Sales",@shift_data['food_sales']],
                 ["Net ABC Sales", "pending data "],
                 ["Gift Certificate Sold", @shift_data['gift_cards_sold']], #add array of ttl and each_value
                 ["Discounts", @shift_data['discounts']],
                 ["Returns", @shift_data['refunds']],
                 ["Net Sales", @shift_data['net_sales']],
                 ["Tax on Sales", @shift_data['tax_collected']],
                 ["Transactions", @shift_data['transactions']]
      ]) 
    
    #Split up tips
    tip << (["Total Tips (ttl-cash-credit)", @shift_data['total_tips'].to_s + " - " + @shift_data['cash_tips_collected'].to_s + " - " + @shift_data['cc_tips_collected'].to_s ]) 
    tip << (["Breakfast Tips", @shift_data['am_tips']])
    @shift_data['b_server_names'].each do |bname|
      tip << (["\u2022  " + bname.capitalize, @shift_data['am_tips_each']])
    end
     
    tip << (["Lunch Tips",  @shift_data['lunch_tips']])
    
    @shift_data['server_names'].each do |name|
      tip << (["\u2022  " + name.capitalize,  @shift_data['lunch_tips_each']])
    end


    if @shift_data['difference'] == 0
      duck = "../assets/images/duckling3.png"
      pdf.image duck, :position => :right, :vposition => :top, :scale => 0.08
      pdf.move_up 40
    end
    
    pdf.text("Citizen Daily Reconciliation", size: 15, style: :bold)
    pdf.text(@shift_data['date'] + @shift_data['report_type'], size: 15, style: :bold  )   
    pdf.move_down 5 
    pdf.stroke_horizontal_rule
    pdf.move_down 5 
    pdf.table(reg_data, :cell_style =>
     { :padding => [3,5], :border_width => [0,0], :width => 200 }) 
    pdf.move_down 5
    pdf.stroke_horizontal_rule
    pdf.move_down 5
    pdf.table(tip, :cell_style =>
     { :padding => [3,5], :border_width => [0,0], :width => 200 }) 
    pdf.move_down 5
    pdf.stroke_horizontal_rule 
    pdf.move_down 5
    pdf.table(net_data, :cell_style =>
     { :padding => [3,5], :border_width => [0,0], :width => 200 })

    unless @shift_data['notes'].empty?
      pdf.move_down 10
      pdf.text("Shift Notes: " + @shift_data['notes'], :padding => [3,5])
    end
  end
end

def accounting_interview #get data for daily accounting sheet
    @accounting_data = {}
    cli = HighLine.new
    food_purchases = cli.ask( "Food Purchases: ", Float),
    supplies = cli.ask( "Supplies: ", Float),
    repairs = cli.ask( "Repairs: ", Float),
    laundry = cli.ask( "Laundry: ", Float),
    office_supplies = cli.ask( "Office Supplies: ", Float) 
    temp_hash = { 'food_purchases ' =>  food_purchases,
                  'supplies' => supplies,
                  'repairs' => repairs,
                  'laundry' => laundry,
                  'office_supplies' => office_supplies
              }
    @accounting_data.merge!(temp_hash)

end

def accounting_math(payments)
  tax_ary = {}
  tax_ary << @shift_data['tax_collected']
  tax_ary << ttl_tax * 6%
  total_dispursments = (@accounting_data['food_purchases'] +
                        @accounting_data['supplies'] +
                        @accounting_data['repairs'] +
                        @accounting_data['laundry'] +
                        @accounting_data['office_supplies']) 
  charge_deposit = @shift_data['credit_card_sales'] + @shift_data['credit_refunds'] + @shift_data['credit_card_fees'] -  @shift_data['cc_tips_collected']

  temp_hash = { 'food_sales' =>  @shift_data['net_total'],
                'abc_sales' => " ",
                'sales_tax' =>   tax_ary,
                'total' =>  (@shift_data['net_total'] + @shift_data['tax_collected']),
                'cc_fees' => @shift_data['fees'] - @shift_data['fees_returned'],
                'gift_certificate_sales' => @shift_data['gift_card_sales'],
                'charge_tip_payout' => @shift_data['cc_tips_collected'],
                'total_dispursements' => total_dispursments,
                'cash_deposit' => (@shift_data['cash_sales'] - @shift_data['cash_refunds']),
                'charge_deposit' => charge_deposit

              }
  @accounting_data.merge!(temp_hash)
  puts @accounting_data
  
end

def accounting_pdf #report for accountant
  Prawn::Document.generate("#{Date.today}_accounting.pdf" ) do |pdf|
   

    part1 = ([ [{:content => "Food Sales", :colspan => 2}, "600", "5555.55"],
               [{:content => "ABC Sales", :colspan => 2}, " ", "  "],
               [{:content => "Sales Tax", :colspan => 2},"442",""],
               [{:content =>  "Total", :colspan => 2}," "," "],
               [{:content =>  " ", :colspan => 2}," "," "],    
               [{:content =>  "Food Purchases", :colspan => 2},"710","5555.55"],
               [{:content =>  "Supplies", :colspan => 2},"884",""],
               [{:content =>  "Repairs", :colspan => 2},"878",""],
               [{:content =>  "Laundry", :colspan => 2},"858",""],
               [{:content =>  "Office Supplies", :colspan => 2},"882",""],
               [{:content =>  "Credit Card Fee", :colspan => 2}],
               [{:content =>  "GC Redeemed", :colspan => 2},"",""],
               [{:content =>  "Charge Tip Payout", :colspan => 2},"",""],
               [{:content =>  "Total Disbursements", :colspan => 2},"",""],
               [{:content =>  " ", :colspan => 2}," "," "], 
               [{:content =>  "Cash Deposit", :colspan => 2},"105",""],
               [{:content =>  "Charge Deposit", :colspan => 2}, "106",""],
               [{:content =>  "Total Receipts", :colspan => 2},"","Total Receipts"]
      ])

    pdf.text("Citizen", size: 16, style: :bold)
    pdf.text(@shift_data['date'], size: 16, style: :bold)
    pdf.move_down 20
    pdf.table(part1, :width => 600, :cell_style =>
     { :border_width => [0,0], size: 15, style: :bold })
 
  end

end

def cleanup #move generated files to google drive folder
  
  #system "clear" #clear the terminal
  menu #go back to main menu

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

