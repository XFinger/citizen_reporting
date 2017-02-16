#Tips_report

def interview #get servers count & names, tips             
   count = cash_tips = cash_b_tips = credit_b_tips = b_servers_count = bcount= 0
  
  server_names = []
  b_server_names = []
  temp_hash = {}

  cli = HighLine.new
  cashier = cli.ask( "Cashier Name: ", String)
  server_names << cashier

  #get breakfast wait staff name, cc tips & cash tips
  if @tip_data['report_type'] == 'AM' 
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

  #add responses to hash
  temp_hash = { 'b_server_names'  =>  b_server_names, 
                'cash_b_tips'     =>  to_pennies(cash_b_tips),
                'credit_b_tips'   =>  to_pennies(credit_b_tips), 
                'cashier'         =>  cashier.capitalize, 
                'server_names'    =>  server_names,
                'cash_tips'       =>  to_pennies(cash_tips),                  
              }

  @tip_data.merge!(temp_hash)

end

def square_tips #get tips data from square
 
 # URL-encode all parameters
 parameters = URI.encode_www_form(
    'begin_time' =>  @begin_time,
    'end_time'   =>  @end_time
  ) 
 
 connect_string = '/payments?' + parameters
 @tips = CallSquare.new.api_call connect_string

end

def split_tips(payments)
 
  # Variables - set all to zero
  cash_tips_collected = total_tips = credit_tips = tips = 0
  shift_tips = {}
  breakfast_tips = {}
  lunch_tips = {}
  dinner_tips = {}

  for payment in payments
     tips = tips + payment['tip_money']['amount']
  end
  
  # get tip data breakfast & lunch or dinner
  cash_tips_collected = @tip_data['cash_tips'] + @tip_data['cash_b_tips']
  total_tips =  cash_tips_collected + tips
    
  #tip hash - total, breakfast, lunch, dinner  => total, cash, credit
  shift_tips        =  { 'total'   => total_tips,
                         'cash'    => cash_tips_collected, 
                         'credit'  => tips }
        
  if @tip_data['report_type'] == 'AM' 
    
    #avoid division by 0 in edge case where there are no tips or there is no breakfast server
    if (@tip_data['cash_b_tips'] + @tip_data['credit_b_tips']) > 0 && @tip_data['b_server_names'].size > 0
      breakfast_tips  = { 'total'   => @tip_data['cash_b_tips'] + @tip_data['credit_b_tips'],  
                          'cash'    => @tip_data['cash_b_tips'], 
                          'credit'  => @tip_data['credit_b_tips'],    
                          'each'    => (@tip_data['cash_b_tips'] + @tip_data['credit_b_tips'])/@tip_data['b_server_names'].size }
    end

      lunch_tips      = { 'total'   => total_tips - (@tip_data['cash_b_tips'] + @tip_data['credit_b_tips']), 
                          'cash'    => cash_tips_collected - @tip_data['cash_b_tips'], 
                          'credit'  => tips - @tip_data['credit_b_tips'],
                          'each'    => (total_tips - (@tip_data['cash_b_tips'] + @tip_data['credit_b_tips']))/@tip_data['server_names'].size }
    else
      
      dinner_tips     = { 'each'    => total_tips/@tip_data['server_names'].size }
    end
  

  #add responses to hash
  temp_hash = {
          'credit_tips'         => tips,
          'shift_tips'          => shift_tips,
          'breakfast_tips'      => breakfast_tips, 
          'lunch_tips'          => lunch_tips,
          'dinner_tips'         => dinner_tips,         
                  }

    @tip_data.merge!(temp_hash)
end

def cli_out #output data to the screen

  puts " "
  puts 'Date          ' + @tip_data['date'].strftime("%m-%d-%Y") + @tip_data['report_type']
  puts 'Total Tips    ' + fm(@tip_data['shift_tips']['total']) 

  if @tip_data['report_type'] == 'AM'
      if !@tip_data['breakfast_tips'].empty? #avoid edge case with division by 0
        puts "Breakfast Tips  " + fm(@tip_data['breakfast_tips']['total']).to_s 
        @tip_data['b_server_names'].each do |bname|
          puts bname.capitalize + "    " + fm(@tip_data['breakfast_tips']['each']).to_s
        end
      end

      puts "Lunch Tips  " + fm(@tip_data['lunch_tips']['total']).to_s 
      @tip_data['server_names'].each do |name|
        puts name.capitalize +  "    " + fm( @tip_data['lunch_tips']['each']).to_s 
      end
  else
        @tip_data['server_names'].each do |name|
        puts name.capitalize + "    " + fm(@tip_data['dinner_tips']['each']).to_s 
      end
  end
  puts " " 

end


def to_pdf
 
  tip = []

  Prawn::Document.generate("tips_report") do |pdf|
    pdf.stroke_color 'e8ebef'
    
    #Tip Data
    #adjust for pm shift don't show breakfast and rename lunch to dinner

    tip << ["Tips", "<font size='12'>(total - cash - credit)</font>" ] 
    tip << ["Total Tips", fm(@tip_data['shift_tips']['total']).to_s + " - " + fm(@tip_data['shift_tips']['cash']).to_s + " - " + fm(@tip_data['shift_tips']['credit']).to_s ] 
    
    if @tip_data['report_type'] == 'AM'
      if !@tip_data['breakfast_tips'].empty? #avoid edge case with division by 0
        tip <<  ["Breakfast Tips ", fm(@tip_data['breakfast_tips']['total']).to_s + " - " + fm(@tip_data['breakfast_tips']['cash']).to_s + " - " + fm(@tip_data['breakfast_tips']['credit']).to_s ] 
        @tip_data['b_server_names'].each do |bname|
          tip << ["\u2022  " + bname.capitalize, fm(@tip_data['breakfast_tips']['each'])]
        end
      end

      tip << ["Lunch Tips ", fm(@tip_data['lunch_tips']['total']).to_s + " - " + fm(@tip_data['lunch_tips']['cash']).to_s + " - " + fm(@tip_data['lunch_tips']['credit']).to_s ]
      @tip_data['server_names'].each do |name|
        tip << ["\u2022  " + name.capitalize, fm( @tip_data['lunch_tips']['each'])]
      end
    else
        @tip_data['server_names'].each do |name|
          tip << ["\u2022  " + name.capitalize,  fm(@tip_data['dinner_tips']['each'])]
        end
    end
    
    pdf.text("Citizen Tip Data", size: 15, style: :bold)
    pdf.text(@tip_data['date'].strftime("%A %b %e %Y ") + @tip_data['report_type'], size: 15, style: :bold)
    pdf.text("Cashier: " + @tip_data['cashier'])

    pdf.move_down 3 
    pdf.stroke_horizontal_rule
    pdf.move_down 3 
     
    pdf.table(tip, :cell_style =>
     { :padding => [3,0], :border_width => [0,0], :inline_format => true }) do
        column(0..2).align = :left
        column(0).width = 230
      end
end
 
  #move file to docs/pdf folder
  FileUtils.move  "tips_report" , "../docs/pdf/#{@tip_data['date'].strftime("%m-%d-%Y")}_#{@tip_data['report_type']}_tips_report.pdf"

end


