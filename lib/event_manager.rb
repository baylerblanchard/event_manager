require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def find_peak_times(times)
  reg_per_hour = {}

  times.each do |timestamp|
    hour = DateTime.strptime(timestamp, '%m/%d/%y %H:%M').hour
    reg_per_hour[hour] ||= 0
    reg_per_hour[hour] += 1
  end

  max_reg = reg_per_hour.values.max

  peak_hours = reg_per_hour.select { |_hour, count| count == max_reg}.keys

  [max_reg, peak_hours]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s.gsub(/\D/, '').sub(/^1/, '')
  if phone_number.length < 10
    puts "Phone number not active: #{phone_number}"
  end
  phone_number
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

regdate_array = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  regdate = row[:regdate]
  regdate_array << regdate

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  # Print the form letter before saving

  save_thank_you_letter(id, form_letter)
end

reg_times, peak_time = find_peak_times(regdate_array)


puts "The most registrations in an hour: #{reg_times}"
puts "The most registrations occurred at hour(s): #{peak_time.join(', ')}"
# work on the date and time later
