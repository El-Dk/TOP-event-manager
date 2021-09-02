# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
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

def clean_phone_number(number)
  phone_number = number.split(/[^0-9]/).join
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..10]
  else
    'No Number'
  end
end

def peak_value(hours)
  peak_times = hours.values[0]
  hours.reduce(hours.keys[0]) do |peak, (hour, hour_times)|
    if peak_times < hour_times
      peak_times = hour_times
      hour
    else
      peak
    end
  end
end

puts 'EventManager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hours = Hash.new(0)
days = Hash.new(0)

days_of_the_week = %w[Sunday Monday Tuesday Wednesday Thrusday Friday Saturday]

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  reg_date = Time.strptime(row[:regdate], '%m/%d/%y %H:%M')
  hours[reg_date.hour] += 1
  days[reg_date.wday] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

puts "Peak Hour: #{peak_value(hours)}"
puts "Peak Day: #{days_of_the_week[peak_value(days)]}"
