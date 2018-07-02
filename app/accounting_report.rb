#accounting_report

def get_shift_ids  
  @shift_ids = []
  #URL-encode all parameters
  parameters = URI.encode_www_form(
    'begin_time' => @begin_time,
    'end_time'   => @end_time      
  )
   
  connect_string = '/cash-drawer-shifts?' + parameters  
  ids = CallSquare.new.api_call connect_string
 
  ids.each do |ids|
    @shift_ids  << ids['id']
  end

  return @shift_ids

end

def get_shift_events(shift_ids)
   shift_events = []
  
  shift_ids.each do |id|
    connect_string = '/cash-drawer-shifts/' + id 
    events = CallSquare.new.events_api_call connect_string
    shift_events += events
  end


  parse_events(shift_events)

end

#parse events and get food_purchases, supplies, repairs, office_supplies, other totals
#payouts description must include the words 'food', 'office', 'supplies', 'repairs' or 'special' to be included in payouts
def parse_events(shift_events) 
 
  
  food_purchases = supplies = repairs = office_supplies = other = 0
  shift_events.each do |e|
    e['events'].each do |p|
      if !p['description'].empty?  && !p['description'].downcase.include?("tip")

        #total up payouts - each category must include (food, office, supplies, repairs or special) in
        #the description to be included in cash payouts for the accounting report.

        case p['description'].downcase
        when /food/
          food_purchases += p['event_money']['amount']
        when /office/
          office_supplies += p['event_money']['amount']
        when /supplies/
          supplies += p['event_money']['amount']
        when /repair/ 
          repairs += p['event_money']['amount']
        when /special/
          other += p['event_money']['amount']
        end

      end
   end
 end
 
   temp_hash = {'food_purchases'  => food_purchases,
                'office_supplies' => office_supplies,
                'supplies'        => supplies,
                'repairs'         => repairs,
                'other'           => other 
              }

   @accounting_data.merge!(temp_hash) 
 
end

def poll_square
    @payments = []

    #URL-encode all parameters
    parameters = URI.encode_www_form(
      'begin_time' => @begin_time,
      'end_time'   => @end_time      
    )

    connect_string = '/payments?' + parameters
    @payments = CallSquare.new.api_call connect_string
  
end

def do_the_math(payments)
  # Variables - set all to zero
  collected_money = taxes = tips = discounts = returned_processing_fees = processing_fees = cash_sales = 
                    gift_card_sales = check_sales = credit_card_sales = net_money = refunds = gift_cards_sold = 
                    cc_refund = cash_refund = food_sales = beer_money = wine_money = liquor_money = 
                    alco_discount = food_discount = retail_sales = retail_tax = cash_tax = credit_tax = 
                    cash_disbursements = charge_disbursements = total_receipts = cash_deposit = 
                    charge_deposit = count = gc_refund = 0
  
  gift_card = []
  temp_hash = {}
  shift_tips = {}
  abc_sales = {}
  
  # Add values to each cumulative variable
  
  for payment in payments
      
      collected_money = collected_money + payment['total_collected_money']['amount'] 
      taxes           = taxes           + payment['tax_money']['amount']
      tips            = tips            + payment['tip_money']['amount']
      discounts       = discounts       + payment['discount_money']['amount']
      processing_fees = processing_fees + payment['processing_fee_money']['amount']
      net_money       = net_money       + payment['net_total_money']['amount']
      refunds         = refunds         + payment['refunded_money']['amount']
    
    #breakdown of payment types
     
    payment['tender'].each do |payment_type|

      case payment_type['name']
         when "Cash"
          cash_sales  = cash_sales + payment_type['total_money']['amount']
        when "Credit Card"  
          credit_card_sales = credit_card_sales + payment_type['total_money']['amount']
        when "MERCHANT_GIFT_CARD"  || "OTHER"
          gift_card_sales = gift_card_sales + payment_type['total_money']['amount']
        when "CHECK"
          check_sales = check_sales + payment_type['total_money']['amount']
      end 
       
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

     abc_total = beer_money + wine_money + liquor_money
     abc_sales = {'abc_total'     => abc_total,
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
     
    
    #get breakdown of refunded money type (cash/credit/gc)
     if  payment['tender'][0]['refunded_money']['amount'] < 0
        if payment['tender'][0]['type'] == 'CREDIT_CARD'
          cc_refund += payment['tender'][0]['refunded_money']['amount']
        elsif payment['tender'][0]['type'] == 'CASH'
          cash_refund += payment['tender'][0]['refunded_money']['amount']
        elsif payment['tender'][0]['type'] == 'MERCHANT_GIFT_CARD' || payment['tender'][0]['type'] == 'OTHER'
          gc_refund += payment['tender'][0]['refunded_money']['amount']

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

  food_sales = collected_money - taxes - tips  - gift_cards_sold - abc_total - retail_sales #+refunds

#disbursement math
  cash_disbursements =   (@accounting_data['food_purchases'].abs  +
                          @accounting_data['supplies'].abs  +
                          @accounting_data['office_supplies'].abs  +
                          @accounting_data['repairs'].abs  +
                          @accounting_data['other'].abs  +
                          gift_card_sales - gc_refund.abs + tips)

  charge_disbursements = cc_refund + returned_processing_fees + processing_fees.abs
 
  total_disbursements = cash_disbursements + charge_disbursements - tips
  
  charge_deposit = credit_card_sales - charge_disbursements 
  
  cash_deposit = cash_sales + check_sales + gift_card_sales - cash_disbursements + cash_refund 
  
  city_tax = food_sales + abc_total 

  total_receipts = charge_deposit + cash_deposit + total_disbursements
 
   #add responses to hash
  temp_hash = { 'food_sales'              => food_sales,
                'abc_sales'               => abc_sales,
                'city_tax'                => city_tax * 0.07500,
                'total'                   => food_sales + gift_cards_sold + taxes +  abc_total + retail_sales,
                'retail_sales'            => retail_sales,
                'tax_collected'           => taxes,
                'retail_tax'              => retail_tax,
                'gift_cards_sold'         => gift_cards_sold, #value of new cards sold
                'cc_fees'                 =>  processing_fees - returned_processing_fees,
                'gift_card_sales'         =>  gift_card_sales + gc_refund, #value of card sales
                'charge_tip_payout'       =>  tips,
                'total_disbursements'     => total_disbursements,
                'cash_deposit'            => cash_deposit,
                'charge_deposit'          => charge_deposit,
                'total_receipts'          => total_receipts

        }
    @accounting_data.merge!(temp_hash)
    
end

def accounting_pdf #report for accountant
  Prawn::Document.generate("#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf" ) do |pdf|
     
    part1 = ([ [{:content =>  "Food Sales", :colspan => 2}, "600", fm(@accounting_data['food_sales'])],
               [{:content =>  "ABC Sales", :colspan => 2}, " ", fm(@accounting_data['abc_sales']['abc_total'])],
               [{:content =>  "Beer - Wine - Liquor", :colspan => 2}, " ", fm(@accounting_data['abc_sales']['beer_money']) + ' - ' + fm(@accounting_data['abc_sales']['wine_money']) + ' - ' + fm(@accounting_data['abc_sales']['liquor_money'])],
               [{:content =>  "Retail Sales", :colspan => 2}, " ", fm(@accounting_data['retail_sales'])],
               [{:content =>  "Sales Tax", :colspan => 2},"442", fm(@accounting_data['tax_collected']) + "  /  " + fm(@accounting_data['city_tax'])],
               [{:content =>  "Retail Tax", :colspan => 2}, " ", fm(@accounting_data['retail_tax'])],
               [{:content =>  "GC Sold", :colspan => 2}," ", fm(@accounting_data['gift_cards_sold'])],
               [{:content =>  "Total", :colspan => 2}," ", fm(@accounting_data['total'])],
               [{:content =>  " ", :colspan => 2}," "," "],    
               [{:content =>  "Food Purchases", :colspan => 2},"710",fm(@accounting_data['food_purchases'])],
               [{:content =>  "Supplies", :colspan => 2},"884", fm(@accounting_data['supplies'])],
               [{:content =>  "Repairs", :colspan => 2},"878", fm(@accounting_data['repairs'])],
               [{:content =>  "Office Supplies", :colspan => 2},"882", fm(@accounting_data['office_supplies'])],
               [{:content =>  "Special", :colspan => 2}," ", fm(@accounting_data['other'])],
               [{:content =>  "Credit Card Fee", :colspan => 2}, " ", fm(@accounting_data['cc_fees'])],
               [{:content =>  "GC Redeemed", :colspan => 2},"", fm(@accounting_data['gift_card_sales'])],
               [{:content =>  "Total Disbursements", :colspan => 2},"", fm(@accounting_data['total_disbursements'])],
               [{:content =>  "Charge Tip Payout", :colspan => 2},"", fm(@accounting_data['charge_tip_payout'])],
               [{:content =>  " ", :colspan => 2}," "," "], 
               [{:content =>  "Cash Deposit", :colspan => 2},"105", fm(@accounting_data['cash_deposit'])],
               [{:content =>  "Charge Balance", :colspan => 2}, "106", fm(@accounting_data['charge_deposit'])],
               [{:content =>  "Total Receipts", :colspan => 2},"", fm(@accounting_data['total_receipts'])],
               [{:content =>  " ", :colspan => 2}," "," "]              
      ])

    pdf.text("Citizen " + @accounting_data['date'].strftime("%m-%d-%Y"), size: 12, style: :bold)
    #pdf.move_down 5
    pdf.table(part1, :width => 500, :cell_style => { :border_width => [0,0], :size => 12, :height => 22,  font_style: :bold}) do
        column(0).align = :left
        column(1).align = :left
        column(2).align = :left  
        column(3).align = :right
    end
   
    if @pdf_switch == true
        settlement_data = []   
        @settlement_arry.each do |set|     
            settlement_data << [{:content => "Initiated On: " +  Date.parse(set['initiated_at']).to_s, :colspan => 4}] 
            settlement_data << [{:content =>  "Deposit", :colspan => 2}, "106", fm(set['deposit'])] 
            settlement_data << [{:content =>  "Capital", :colspan => 2}, " ", fm(set['capital'])] 
            settlement_data << [{:content =>  "Instant Deposit Fee ", :colspan => 2},"", fm(set['instant_dep_fee'])]
        end

        pdf.table(settlement_data, :width => 500, :cell_style => { :border_width => [0,0], size: 12, font_style: :bold}) do
            column(0).align = :left
            column(1).align = :left
            column(2).align = :left  
            column(3).align = :right
        end
  
    end
  end  



  #move file to docs/pdf folder
  FileUtils.move  "#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf" , "../docs/pdf/#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf"

end