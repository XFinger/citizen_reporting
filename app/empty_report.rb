#pdf placeholder for 0 reporting days

def blank_pdf #non event days
  Prawn::Document.generate("#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf" ) do |pdf|
   

    pdf.text("Citizen", size: 14, style: :bold)
    pdf.text(@accounting_data['date'].strftime("%m-%d-%Y"), size: 15, style: :bold)
    pdf.move_down 15
    pdf.text("Nothing to report!", size:14, style: :bold)
 
  end

  #move file to docs/pdf folder
  FileUtils.move  "#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf" , "../docs/pdf/#{@accounting_data['date'].strftime("%m-%d-%Y")}_accounting.pdf"

end